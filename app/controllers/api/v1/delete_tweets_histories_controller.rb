module Api
  module V1
    class DeleteTweetsHistoriesController < ApplicationController

      before_action :reject_crawler
      before_action :require_login!

      def index
        requests = [
            DeleteTweetsRequest.where(user_id: current_user.id).order(created_at: :desc).limit(100),
            DeleteTweetsBySearchRequest.where(user_id: current_user.id).order(created_at: :desc).limit(100),
            DeleteTweetsByArchiveRequest.where(user_id: current_user.id).order(created_at: :desc).limit(100)
        ].flatten.sort_by { |r| -r.created_at.to_i }.take(10)

        render json: {requests: to_json(requests)}
      end

      private

      def to_json(requests)
        requests.map do |req|
          {
              type: request_type(req.class),
              reservations_count: req.reservations_count,
              deletions_count: req.respond_to?(:deletions_count) ? req.deletions_count : req.destroy_count,
              created_at: request_time(req.created_at),

          }
        end
      end

      def request_type(klass)
        if klass == DeleteTweetsRequest
          t('delete_tweets.free.title')
        elsif klass == DeleteTweetsBySearchRequest
          t('delete_tweets.search.title')
        elsif klass == DeleteTweetsByArchiveRequest
          t('delete_tweets.premium.title')
        else
          t('delete_tweets.free.title')
        end
      end

      def request_time(time)
        time = time.in_time_zone('Tokyo')
        if time.today?
          l(time, format: :delete_tweets_short)
        else
          l(time, format: :delete_tweets_long)
        end
      end
    end
  end
end
