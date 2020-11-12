class CreateBlockReportWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  def unique_key(user_id, options = {})
    user_id
  end

  def unique_in(*args)
    1.hour
  end

  # options:
  def perform(user_id, options = {})
    user = User.find(user_id)
    return unless user.authorized?
    return if StopBlockReportRequest.exists?(user_id: user.id)
    return unless BlockingRelationship.where(to_uid: user.uid).exists?

    if PeriodicReport.send_report_limited?(user.uid)
      logger.warn "Send block report later user_id=#{user_id} raised=false"
      CreateBlockReportWorker.perform_in(1.hour + rand(30).minutes, user_id, options.merge(delay: true))
      return
    end

    BlockReport.you_are_blocked(user.id).deliver!
  rescue => e
    if DirectMessageStatus.enhance_your_calm?(e)
      logger.warn "Send block report later user_id=#{user_id} raised=true"
      CreateBlockReportWorker.perform_in(1.hour + rand(30).minutes, user_id, options.merge(delay: true))
    elsif TwitterApiStatus.unauthorized?(e) ||
        DirectMessageStatus.protect_out_users_from_spam?(e) ||
        DirectMessageStatus.you_have_blocked?(e) ||
        DirectMessageStatus.not_allowed_to_access_or_delete?(e) ||
        DirectMessageStatus.cannot_send_messages?(e)
      # Do nothing
    else
      logger.warn "#{e.inspect} user_id=#{user_id} options=#{options.inspect}"
    end
  end
end
