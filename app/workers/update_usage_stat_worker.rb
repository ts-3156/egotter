class UpdateUsageStatWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'misc', retry: 0, backtrace: false

  def unique_key(uid, options = {})
    uid
  end

  def expire_in
    10.minutes
  end

  # options:
  #   user_id
  #   location
  def perform(uid, options = {})
    stat = UsageStat.find_by(uid: uid)
    return if stat&.fresh?

    twitter_user = TwitterUser.select(:uid, :screen_name, :created_at).latest_by(uid: uid)
    statuses =
        if twitter_user.status_tweets.any?
          twitter_user.status_tweets
        else
          user = User.find_by(id: options['user_id'])
          user = User.authorized.find_by(uid: uid) unless user
          client = user ? user.api_client : Bot.api_client
          client.user_timeline(uid.to_i).map { |s| TwitterDB::Status.build_by(twitter_user: twitter_user, status: s) }
        end

    if statuses.any?
      UsageStat.builder(uid).statuses(statuses).build.save!
    end
  rescue Twitter::Error::Unauthorized => e
    unless e.message == 'Invalid or expired token.'
      logger.warn "#{e.class}: #{e.message} #{uid}"
      logger.info e.backtrace.join("\n")
    end
  rescue => e
    logger.warn "#{e.class}: #{e.message} #{uid}"
    logger.info e.backtrace.join("\n")
  end
end
