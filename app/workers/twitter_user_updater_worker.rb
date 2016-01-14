class TwitterUserUpdaterWorker
  include Sidekiq::Worker
  sidekiq_options queue: :egotter, retry: 3, backtrace: true

  def perform(uid)
    u = client.user(uid.to_i) && client.user(uid.to_i)
    puts "[#{Time.zone.now}] #{user_name(u)} start"

    tu = TwitterUser.latest(u.id)
    if tu.blank?
      puts "[#{Time.zone.now}] #{user_name(u)} something is wrong(TwitterUser doesn't exist)"
      return
    end

    if tu.recently_created? || tu.recently_updated?
      puts "[#{Time.zone.now}] #{user_name(u)} skip"
      return
    end

    new_tu = TwitterUser.build_with_raw_twitter_data(client, u.id)
    if new_tu.save_raw_twitter_data
      puts "[#{Time.zone.now}] #{user_name(u)} create(new TwitterUser)"
    else
      puts "[#{Time.zone.now}] #{user_name(u)} do nothing"
    end
  end

  def user_name(u)
    "#{u.id},#{u.screen_name}"
  end

  def client
    raise 'create bot' if Bot.empty?
    bot = Bot.sample
    config = {
      consumer_key: ENV['TWITTER_CONSUMER_KEY'],
      consumer_secret: ENV['TWITTER_CONSUMER_SECRET'],
      access_token: bot.token,
      access_token_secret: bot.secret
    }
    c = ExTwitter.new(config)
    c.verify_credentials
    c
  end

end
