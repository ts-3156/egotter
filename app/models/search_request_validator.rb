class SearchRequestValidator
  def initialize(client, user)
    @client = client
    @user = user
  end

  def search_for_yourself?(screen_name)
    user_signed_in? && @user.uid == @client.user(screen_name)[:id]
  rescue => e
    logger.debug { "#{self.class}##{__method__} #{e.inspect} screen_name=#{screen_name}" }
    false
  end

  def user_requested_self_search_by_uid?(uid)
    user_signed_in? && @user.uid == uid.to_i
  end

  def blocked_user?(screen_name)
    return false unless user_signed_in?

    ApplicationRecord.benchmark("Benchmark SearchRequestValidator#blocked_user? screen_name=#{screen_name}", level: :info) do
      begin
        Timeout.timeout(5.seconds) do
          @client.user_timeline(screen_name, count: 1)
        end
      rescue Timeout::Error => e
        logger.info { "#{self.class}##{__method__} timeout screen_name=#{screen_name}" }
      end
    end

    false
  rescue => e
    logger.debug { "#{self.class}##{__method__} #{e.inspect} screen_name=#{screen_name}" }
    TwitterApiStatus.blocked?(e)
  end

  def protected_user?(screen_name)
    @client.user(screen_name)[:protected]
  rescue => e
    logger.debug { "#{self.class}##{__method__} #{e.inspect} screen_name=#{screen_name}" }
    TwitterApiStatus.protected?(e)
  end

  def timeline_readable?(screen_name)
    ApplicationRecord.benchmark("Benchmark SearchRequestValidator#timeline_readable? screen_name=#{screen_name}", level: :info) do
      begin
        Timeout.timeout(5.seconds) do
          @client.user_timeline(screen_name, count: 1)
        end
      rescue Timeout::Error => e
        logger.info { "#{self.class}##{__method__} timeout screen_name=#{screen_name}" }
      end
    end

    true
  rescue => e
    logger.debug { "#{self.class}##{__method__} #{e.inspect} screen_name=#{screen_name}" }
    !TwitterApiStatus.protected?(e)
  end

  private

  def user_signed_in?
    @user
  end

  def logger
    Rails.logger
  end
end
