class SendMetricsToSlackWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'misc', retry: 0, backtrace: false

  def perform
    if Rails.env.development?
      SlackClient.send_message('-- start --', channel: SlackClient::MONITORING)
      SlackClient.send_message('-- start --', channel: SlackClient::SIDEKIQ_MONITORING)
      SlackClient.send_message('-- start --', channel: SlackClient::TABLE_MONITORING)
      SlackClient.send_message('-- start --', channel: SlackClient::MESSAGING_MONITORING)
    end

    send_table_metrics
    send_user_metrics
    send_twitter_user_metrics
    send_google_analytics_metrics
    send_prompt_report_metrics
    send_sidekiq_queue_metrics
    send_sidekiq_worker_metrics
    send_nginx_metrics

    if Rails.env.development?
      SlackClient.send_message('-- end --', channel: SlackClient::MONITORING)
      SlackClient.send_message('-- end --', channel: SlackClient::SIDEKIQ_MONITORING)
      SlackClient.send_message('-- end --', channel: SlackClient::TABLE_MONITORING)
      SlackClient.send_message('-- end --', channel: SlackClient::MESSAGING_MONITORING)
    end
  rescue => e
    logger.warn "#{e.class} #{e.message}"
    logger.info e.backtrace.join("\n")
  end

  def send_table_metrics
    stats = {}
    [
        User,
        Visitor,
        SearchLog,
        SearchErrorLog,
        SignInLog,
        TwitterUser,
        SearchHistory,
        Job,
        FollowRequest,
        UnfollowRequest,
        ForbiddenUser,
        NotFoundUser,
        BlockedUser
    ].map do |klass|
      stats[klass.to_s] = klass.where(created_at: 1.hour.ago..Time.zone.now).size
    end
    stats = stats.sort_by {|k, _| k}.to_h
    SlackClient.send_message(SlackClient.format(stats), channel: SlackClient::TABLE_MONITORING)
  end

  def send_user_metrics
    stats = {
        first_access: User.where(first_access_at: 1.hour.ago..Time.zone.now).size,
        last_access: User.where(last_access_at: 1.hour.ago..Time.zone.now).size
    }

    SlackClient.send_message(SlackClient.format(stats))
  end

  def send_twitter_user_metrics
    users = TwitterUser.where(created_at: 1.hour.ago..Time.zone.now)

    friends_count = []
    followers_count = []
    friends_size = []
    followers_size = []

    users.each do |user|
      friends_count << user.friends_count
      followers_count << user.followers_count
      friends_size << user.friends_size
      followers_size << user.followers_size
    end
    size = users.size

    stats = {
        size: size,
        creation_completed: users.creation_completed.size,
        friends_count: {
            avg: sprintf("%.1f", divide(friends_count.sum, size)),
            min: friends_count.min,
            max: friends_count.max
        },
        followers_count: {
            avg: sprintf("%.1f", divide(followers_count.sum, size)),
            min: followers_count.min,
            max: followers_count.max
        },
        friends_size: {
            avg: sprintf("%.1f", divide(friends_size.sum, size)),
            min: friends_size.min,
            max: friends_size.max
        },
        followers_size: {
            avg: sprintf("%.1f", divide(followers_size.sum, size)),
            min: followers_size.min,
            max: followers_size.max
        }
    }

    SlackClient.send_message(SlackClient.format(stats))
  end

  def send_google_analytics_metrics
    stats = {'rt:activeUsers' => GoogleAnalyticsClient.new.active_users}
    SlackClient.send_message(SlackClient.format(stats))
  end

  def send_prompt_report_metrics
    condition = {created_at: 1.hour.ago..Time.zone.now}
    stats = {
        prompt_reports: PromptReport.where(condition).size,
        'prompt_reports(read)' => PromptReport.where(condition.merge(read_at: 1.hour.ago..Time.zone.now)).size,
        create_prompt_report_logs: CreatePromptReportLog.where(condition).size,
    }

    SlackClient.send_message(SlackClient.format(stats))
  end

  def send_sidekiq_queue_metrics
    queues = Sidekiq::Queue.all.select {|queue| queue.latency > 0}.sort_by(&:name)
    queues = queues.map do |queue|
      [queue.name, {size: queue.size, latency: sprintf("%.3f", queue.latency)}]
    end.to_h
    SlackClient.send_message(SlackClient.format(queues), channel: SlackClient::SIDEKIQ_MONITORING)
  end

  def send_sidekiq_worker_metrics
    types = Rails.env.development? ? %w(sidekiq_all) : %w(sidekiq sidekiq_misc sidekiq_import)
    types.each do |type|
      stats = SidekiqStats.new(type).to_a.sort_by {|k, _| k}.to_h
      SlackClient.send_message(SlackClient.format(stats), channel: SlackClient::SIDEKIQ_MONITORING)
    end
  end

  def send_nginx_metrics
    stats = NginxStats.new
    SlackClient.send_message(SlackClient.format(stats))
  end

  def divide(num1, num2)
    num1 / num2
  rescue ZeroDivisionError => e
    0
  end
end
