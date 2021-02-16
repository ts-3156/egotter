module Api
  module V1
    class TrendsController < ApplicationController

      layout false

      before_action { head :forbidden unless request.headers['HTTP_X_CSRF_TOKEN'] }
      before_action { set_trend }

      def words_count
        render json: {words_count: @trend.words_count_chart}
      end

      def times_count
        render json: {times_count: @trend.times_count_chart}
      end

      def users_count
        render json: {users_count: @trend.users_count_chart}
      end

      private

      def set_trend
        if user_signed_in? && current_user.admin?
          trend = Trend.find(params[:id])
        else
          trend = Trend.japan.latest_trends.top_10.find(params[:id])
        end
        @trend = TrendDecorator.new(trend)
      end
    end
  end
end
