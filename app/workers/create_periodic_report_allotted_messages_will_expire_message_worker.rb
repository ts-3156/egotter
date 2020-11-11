class CreatePeriodicReportAllottedMessagesWillExpireMessageWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'messaging', retry: 0, backtrace: false

  def unique_key(user_id, options = {})
    user_id
  end

  def unique_in
    3.seconds
  end

  def after_skip(*args)
    logger.warn "The job of #{self.class} is skipped args=#{args.inspect}"
  end

  def _timeout_in
    10.seconds
  end

  # options:
  def perform(user_id, options = {})
    user = User.find(user_id)

    message = PeriodicReport.allotted_messages_will_expire_message(user.id).message
    quick_reply_buttons = PeriodicReport.will_expire_quick_reply_options
    event = PeriodicReport.build_direct_message_event(user.uid, message, quick_reply_buttons: quick_reply_buttons)
    User.egotter.api_client.create_direct_message_event(event: event)

  rescue => e
    if DirectMessageStatus.not_following_you?(e) || DirectMessageStatus.cannot_find_specified_user?(e)
      # Do nothing
    else
      logger.warn "#{e.inspect} user_id=#{user_id} options=#{options}"
      logger.info e.backtrace.join("\n")
    end
  end
end
