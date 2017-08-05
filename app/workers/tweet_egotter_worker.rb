class TweetEgotterWorker
  include Sidekiq::Worker
  include Concerns::WorkerUtils
  sidekiq_options queue: self, retry: 0, backtrace: false

  def perform(user_id, text)
    user = User.find(user_id)
    client = user.api_client

    # client.tweet ...
    logger.warn "#{user_id} #{text}"

  rescue Twitter::Error::Unauthorized => e
    handle_unauthorized_exception(e, user_id: user_id)
  rescue Twitter::Error::Forbidden => e
    message = "#{e.class} #{e.message} #{user_id}"
    FORBIDDEN_MESSAGES.include?(e.message) ? logger.info(message) : logger.warn(message)
  rescue => e
    logger.warn "#{e.class} #{e.message} #{user_id}"
  end
end
