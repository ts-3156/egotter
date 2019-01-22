require 'active_support/concern'

module Concerns::TwitterUser::Batch
  extend ActiveSupport::Concern

  class Batch
    def self.fetch_and_create(uid, create_twitter_user: true)
      user = User.authorized.find_by(uid: uid)
      user = OldUser.authorized.find_by(uid: uid) unless user
      client = user ? user.api_client : Bot.api_client

      t_user =
        fetch_user(uid, client: client) do |ex|
          user&.update(authorized: false) if ex.message == 'Invalid or expired token.'
        end
      return unless t_user
      t_user = Hashie::Mash.new(t_user)

      twitter_user = TwitterUser.build_by_user(t_user)
      twitter_user.user_id = user ? user.id : -1

      if t_user.suspended
        create_friendless_record(twitter_user, create_twitter_user: create_twitter_user)
        logger "Suspended#{'(create)' if twitter_user.persisted?} #{uid}"
        return twitter_user.persisted? ? twitter_user : nil
      end

      if t_user.protected && client.verify_credentials[:id] != t_user.id
        friendship_uid = ::TwitterDB::Friendship.where(user_uid: User.authorized.pluck(:uid), friend_uid: uid).first&.user_uid
        if friendship_uid
          logger "Change a client to update #{uid} from #{client.verify_credentials[:id]} to #{friendship_uid}"
          client = User.find_by(uid: friendship_uid).api_client
        else
          create_friendless_record(twitter_user, create_twitter_user: create_twitter_user)
          logger "Protected#{'(create)' if twitter_user.persisted?} #{uid}"
          return twitter_user.persisted? ? twitter_user : nil
        end
      end

      if twitter_user.too_many_friends?(login_user: user)
        create_friendless_record(twitter_user, create_twitter_user: create_twitter_user)
        logger "Too many friends#{'(create)' if twitter_user.persisted?} #{uid}"
        return twitter_user.persisted? ? twitter_user : nil
      end

      friend_uids, follower_uids =
        fetch_friend_ids_and_follower_ids(uid, client: client) do |ex|
          user&.update(authorized: false) if ex.message == 'Invalid or expired token.'
        end
      return if friend_uids.nil? || follower_uids.nil?

      if (t_user.friends_count - friend_uids.size).abs >= 5 || (t_user.followers_count - follower_uids.size).abs >= 5
        if rake_task?
          twitter_user, friend_uids, follower_uids = confirm_continue_or_not(twitter_user, friend_uids, follower_uids, client: client)
        else
          raise "Inconsistent #{uid} count [#{t_user.friends_count}, #{t_user.followers_count}] size [#{friend_uids.size}, #{follower_uids.size}]"
        end
      end

      if twitter_user_changed?(TwitterUser.latest(uid), friend_uids, follower_uids)
        if create_twitter_user && create_twitter_user(twitter_user, friend_uids, follower_uids)
          logger "Created #{uid}"
        end
      else
        logger "Not changed #{uid}"
      end

      create_twitter_db_user(twitter_user, friend_uids, follower_uids, client: client)

      twitter_user.persisted? ? twitter_user : nil
    end

    class << self
      %i(fetch_and_create).each do |name|
        alias_method "orig_#{name}", name
        define_method(name) do |*args|
          Rails.logger.silence(Logger::WARN) { send("orig_#{name}", *args) }
        end
      end
    end

    def self.fetch_user(uid, client:)
      tries ||= 3
      client.user(uid)
    rescue => e
      if e.message == 'Invalid or expired token.'
        logger "Invalid token(user) #{uid}"
      elsif e.message == 'Not authorized.'
        logger "Not authorized #{uid}"
      elsif e.message == 'User not found.'
        logger "Not found #{uid}"
      elsif e.message == 'To protect our users from spam and other malicious activity, this account is temporarily locked. Please log in to https://twitter.com to unlock your account.'
        logger "Temporarily locked #{uid}"
      elsif retryable?(e)
        (tries -= 1).zero? ? logger("Retry limit exceeded(user) #{uid}") : retry
      else
        logger "client.user: #{e.class} #{e.message} #{uid}"
      end

      yield(e) if block_given?

      nil
    end

    def self.fetch_friend_ids_and_follower_ids(uid, client:)
      tries ||= 3
      client.friend_ids_and_follower_ids(uid)
    rescue => e
      if e.message == 'Invalid or expired token.'
        logger "Invalid token(friend_ids) #{uid}"
      elsif retryable?(e)
        (tries -= 1).zero? ? logger("Retry limit exceeded(friend_ids) #{uid}") : retry
      else
        logger "client.friend_ids: #{e.class} #{e.message} #{uid}"
      end

      yield(e) if block_given?

      [nil, nil]
    end

    private

    def self.confirm_continue_or_not(twitter_user, friend_uids, follower_uids, client:)
      begin
        logger "Inconsistent #{twitter_user.uid} count [#{twitter_user.friends_count}, #{twitter_user.followers_count}] size [#{friend_uids.size}, #{follower_uids.size}]"
        print 'Continue [r,y,n]? '

        case STDIN.gets.chomp.to_s
          when 'r'
            twitter_user = TwitterUser.build_by_user(client.user(twitter_user.uid.to_i, cache: false))
            friend_uids, follower_uids = client.friend_ids_and_follower_ids(twitter_user.uid.to_i, cache: false)
          when 'y'
            return [twitter_user, friend_uids, follower_uids]
          else raise
        end
      end while true
    end

    def self.retryable?(ex)
      # Twitter::Error::InternalServerError Internal error
      # Twitter::Error::ServiceUnavailable Over capacity
      # Twitter::Error execution expired
      # Twitter::Error Connection reset by peer - SSL_connect

      ['Internal error', 'Over capacity', 'execution expired'].include?(ex.message) ||
        (ex.class == Twitter::Error::ServiceUnavailable && ex.message == '')
    end

    def self.create_friendless_record(twitter_user, create_twitter_user:)
      ActiveRecord::Base.transaction do
        if create_twitter_user && !TwitterUser.exists?(uid: twitter_user.uid)
          twitter_user.assign_attributes(friends_size: 0, followers_size: 0)
          twitter_user.save!(validate: false)
        end

        user = ::TwitterDB::User.find_or_initialize_by(uid: twitter_user.uid)
        user.assign_attributes(screen_name: twitter_user.screen_name, user_info: twitter_user.user_info)
        user.assign_attributes(friends_size: -1, followers_size: -1) if user.new_record?
        user.save!
      end
    end

    def self.create_twitter_user(twitter_user, friend_uids, follower_uids)
      begin
        ActiveRecord::Base.transaction do
          twitter_user.assign_attributes(friends_size: friend_uids.size, followers_size: follower_uids.size)
          twitter_user.save!(validate: false)
          Friendships.import(twitter_user.id, friend_uids, follower_uids)
        end
      rescue => e
        logger "Friendships.import: #{e.class} #{e.message.truncate(100)} #{twitter_user.uid}"
        return false
      end

      uid = twitter_user.uid.to_i
      latest = TwitterUser.latest(uid)

      begin
        Unfriendship.import_from!(uid, latest.unfriendships)
        Unfollowership.import_from!(uid, latest.unfollowerships)

        OneSidedFriendship.import_from!(uid, twitter_user.calc_one_sided_friend_uids)
        OneSidedFollowership.import_from!(uid, twitter_user.calc_one_sided_follower_uids)
        MutualFriendship.import_from!(uid, twitter_user.calc_mutual_friend_uids)
      rescue => e
        logger "Unfriendships.import: #{e.class} #{e.message.truncate(100)} #{uid}"
        return false
      end

      true
    end

    def self.create_twitter_db_user(twitter_user, friend_uids, follower_uids, client:)
      begin
        ::TwitterDB::User::Batch.fetch_and_import((friend_uids + follower_uids).uniq, client: client)
      rescue => e
        logger "TwitterDB::User::Batch.fetch_and_import: #{e.class} #{e.message.truncate(100)} #{twitter_user.uid}"
        return
      end

      begin
        ActiveRecord::Base.transaction do
          ::TwitterDB::User.find_or_initialize_by(uid: twitter_user.uid).update!(screen_name: twitter_user.screen_name, user_info: twitter_user.user_info, friends_size: friend_uids.size, followers_size: follower_uids.size)
          ::TwitterDB::Friendships.import(twitter_user.uid, friend_uids, follower_uids)
        end
      rescue => e
        logger "TwitterDB::Friendships.import: #{e.class} #{e.message.truncate(100)} #{twitter_user.uid}"
      end
    end

    def self.twitter_user_changed?(twitter_user, friend_uids, follower_uids)
      twitter_user.nil? ||
        twitter_user.friendships.pluck(:friend_uid).sort != friend_uids.sort ||
        twitter_user.followerships.pluck(:follower_uid).sort != follower_uids.sort
    end

    def self.rake_task?
      File.basename($0) == 'rake'
    end

    def self.logger(message)
      rake_task? ? puts(message) : Rails.logger.warn(message)
    end
  end
end
