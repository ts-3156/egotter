require 'active_support/concern'

module TwitterUserApi
  extend ActiveSupport::Concern

  included do
  end

  class_methods do
  end

  def one_sided_friends_rate
    # Use #friends_count instead of #friend_uids.size to reduce calls to the external API
    (one_sided_friendships.size.to_f / friends_count) rescue 0.0
  end

  def one_sided_followers_rate
    # Use #followers_count instead of #follower_uids.size to reduce calls to the external API
    (one_sided_followerships.size.to_f / followers_count) rescue 0.0
  end

  def mutual_friends_rate
    (mutual_friendships.size.to_f / (friend_uids | follower_uids).size) rescue 0.0
  end

  # TODO Remove later
  def status_interval_avg
    statuses_interval || calc_statuses_interval
  end

  # TODO Remove later
  def follow_back_rate
    send(:[], :follow_back_rate) || calc_follow_back_rate
  end

  # TODO Remove later
  def reverse_follow_back_rate
    send(:[], :reverse_follow_back_rate) || calc_reverse_follow_back_rate
  end
end
