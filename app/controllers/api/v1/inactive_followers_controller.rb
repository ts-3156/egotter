module Api
  module V1
    class InactiveFollowersController < ::Api::Base

      private

      def summary_uids(limit: 3)
        uids = @twitter_user.inactive_followerships.limit(limit).pluck(:follower_uid)
        size = @twitter_user.inactive_followerships.size
        [uids, size]
      end

      def list_users
        @twitter_user.inactive_followers
      end
    end
  end
end