# == Schema Information
#
# Table name: follow_requests
#
#  id            :integer          not null, primary key
#  user_id       :integer          not null
#  uid           :bigint(8)        not null
#  finished_at   :datetime
#  error_class   :string(191)      default(""), not null
#  error_message :string(191)      default(""), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_follow_requests_on_created_at  (created_at)
#  index_follow_requests_on_user_id     (user_id)
#

class FollowRequest < ApplicationRecord
  include Concerns::Request::FollowAndUnfollow
  include Concerns::Request::Runnable

  belongs_to :user
  validates :user_id, numericality: :only_integer
  validates :uid, numericality: :only_integer

  def perform!
    raise AlreadyFinished if finished?
    raise Unauthorized unless user.authorized?
    raise CanNotFollowYourself if user.uid == uid
    raise NotFound unless user_found?
    raise AlreadyRequestedToFollow if friendship_outgoing?
    raise AlreadyFollowing if friendship?

    raise GlobalTooManyFollows unless global_can_perform?
    raise UserTooManyFollows unless user_can_perform?

    begin
      client.follow!(uid)
    rescue Twitter::Error::Unauthorized => e
      raise Unauthorized.new(e.message)
    rescue Twitter::Error::Forbidden => e
      raise Forbidden.new(e.message)
    end
  end

  TOO_MANY_FOLLOWS_INTERVAL = 1.hour
  NORMAL_INTERVAL = 1.second

  def perform_interval
    if global_can_perform? && user_can_perform?
      NORMAL_INTERVAL
    else
      TOO_MANY_FOLLOWS_INTERVAL
    end
  end

  def global_can_perform?
    time = CreateFollowLog.global_last_too_many_follows_time
    time.nil? || time + TOO_MANY_FOLLOWS_INTERVAL < Time.zone.now
  end

  def user_can_perform?
    time = CreateFollowLog.user_last_too_many_follows_time(user_id)
    time.nil? || time + TOO_MANY_FOLLOWS_INTERVAL < Time.zone.now
  end

  def user_found?
    client.user?(uid)
  end

  def friendship_outgoing?
    client.friendships_outgoing.attrs[:ids].include?(uid)
  rescue => e
    logger.warn "#{__method__} #{e.class} #{e.message} #{self.inspect}"
    false
  end

  def friendship?
    client.friendship?(user.uid, uid)
  end

  def client
    @client ||= user.api_client.twitter
  end

  class Error < StandardError
  end

  class DeadErrorTellsNoTales < Error
    def initialize(*args)
      super('')
    end
  end

  class AlreadyFinished < DeadErrorTellsNoTales
  end

  class Unauthorized < Error
  end

  class Forbidden < Error
  end

  class GlobalTooManyFollows < DeadErrorTellsNoTales
  end

  class UserTooManyFollows < DeadErrorTellsNoTales
  end

  class CanNotFollowYourself < DeadErrorTellsNoTales
  end

  class NotFound < DeadErrorTellsNoTales
  end

  class AlreadyFollowing < DeadErrorTellsNoTales
  end

  class AlreadyRequestedToFollow < DeadErrorTellsNoTales
  end
end
