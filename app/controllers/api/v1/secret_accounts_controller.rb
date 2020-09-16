module Api
  module V1
    class SecretAccountsController < ApplicationController
      include Concerns::ApiRequestConcern

      MIN_FOLLOWERS_COUNT = 1000
      MAX_FOLLOWERS_COUNT = 3000
      MAX_SIZE = 5000

      def show
        render json: {friends: to_hash(filter(@twitter_user.friends))}
      end

      private

      def filter(users, min_followers_count: MIN_FOLLOWERS_COUNT, max_followers_count: MAX_FOLLOWERS_COUNT, max_size: MAX_SIZE)
        users.select { |u| (min_followers_count..max_followers_count).include? u.followers_count }.take(max_size)
      end

      def to_hash(users)
        users.map do |u|
          {
              screen_name: u.screen_name,
              description: u.description,
              profile_image_url: u.profile_image_url_https,
          }
        end
      end

      class Filter
        def initialize(min_followers_count: MIN_FOLLOWERS_COUNT, max_followers_count: MAX_FOLLOWERS_COUNT, max_size: MAX_SIZE)
          @min_followers_count = min_followers_count
          @max_followers_count = max_followers_count
          @max_size = max_size
        end

        def apply(users)

        end
      end
    end
  end
end