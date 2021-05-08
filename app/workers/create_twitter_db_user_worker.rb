require 'digest/md5'

class CreateTwitterDBUserWorker
  include Sidekiq::Worker
  include WorkerErrorHandler
  sidekiq_options queue: self, retry: 0, backtrace: false

  def unique_key(uids, options = {})
    Digest::MD5.hexdigest(uids.to_s)
  end

  def unique_in
    10.minutes
  end

  def _timeout_in
    10.seconds
  end

  # options:
  #   compressed
  #   force_update
  #   user_id
  #   enqueued_by
  def perform(uids, options = {})
    target_uids = uids.is_a?(String) ? decompress(uids) : uids

    if target_uids.empty?
      logger.warn "the size of uids is 0 options=#{options.inspect}"
      return
    end

    if target_uids.size > 100
      logger.warn "the size of uids is greater than 100 options=#{options.inspect}"
    end

    user = User.find_by(id: options['user_id']) if options['user_id'] && options['user_id'] != -1
    user = Bot unless user

    do_perform(user.api_client, target_uids, options)
  rescue => e
    if e.class == ApiClient::ContainStrangeUid && target_uids.size > 1
      slice_size = (target_uids.size > 10) ? 10 : 1
      target_uids.each_slice(slice_size) do |partial_uids|
        logger.info "Split uids and retry uids_size=#{partial_uids.size} uids=#{partial_uids}"
        self.class.perform_async(partial_uids, options)
      end
    else
      handle_worker_error(e, uids_size: target_uids.size, uids: target_uids, options: options)
      FailedCreateTwitterDBUserWorker.perform_async(target_uids, options.merge(klass: self.class, error_class: e.class))
    end
  end

  private

  def do_perform(client, uids, options)
    TwitterDBUserBatch.new(client).import!(uids, force_update: options['force_update'])
  rescue => e
    exception_handler(e)
    client = Bot.api_client
    retry
  end

  def exception_handler(e)
    @retries ||= 3

    if retryable_exception?(e)
      if (@retries -= 1) >= 0
        logger.info "Retry #{e.inspect.truncate(100)}"
      else
        raise RetryExhausted.new(e.inspect.truncate(100))
      end
    else
      raise e
    end
  end

  def retryable_exception?(e)
    TwitterApiStatus.unauthorized?(e) ||
        TwitterApiStatus.temporarily_locked?(e) ||
        TwitterApiStatus.forbidden?(e) ||
        TwitterApiStatus.too_many_requests?(e) ||
        ServiceStatus.retryable_error?(e)
  end

  class RetryExhausted < StandardError; end

  class << self
    def compress_and_perform_async(uids, options = {})
      if uids.size > 100
        uids.each_slice(100) do |uids_array|
          compress_and_perform_async(uids_array, options)
        end
      else
        uids = compress(uids)
        options[:compressed] = true
        perform_async(uids, options)
      end
    end

    def compress(uids)
      Base64.encode64(Zlib::Deflate.deflate(uids.join(',')))
    end
  end

  def decompress(data)
    Zlib::Inflate.inflate(Base64.decode64(data)).split(',').map(&:to_i)
  end
end
