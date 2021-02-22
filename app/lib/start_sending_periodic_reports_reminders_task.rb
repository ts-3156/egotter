class StartSendingPeriodicReportsRemindersTask
  attr_reader :user_ids

  def start!
    user_ids = initialize_user_ids
    return if user_ids.empty?

    create_requests(user_ids)
    create_jobs(user_ids)
  end

  def initialize_user_ids
    @user_ids = StartSendingPeriodicReportsTask.allotted_messages_will_expire_user_ids.uniq
  end

  def create_requests(user_ids)
    requests = user_ids.map { |user_id| RemindPeriodicReportRequest.new(user_id: user_id) }
    RemindPeriodicReportRequest.import requests, validate: false
  end

  def create_jobs(user_ids)
    user_ids.each.with_index do |user_id, i|
      CreatePeriodicReportAllottedMessagesWillExpireMessageWorker.perform_in(i.seconds, user_id)
    end
  end
end
