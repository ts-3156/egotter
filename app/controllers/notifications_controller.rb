class NotificationsController < ApplicationController
  include Logging
  include SearchesHelper

  before_action only: %i(index) do
    create_search_log(action: :notifications)
  end

  def index
    redirect_to '/' unless user_signed_in?

    @title = t('dictionary.bell')
    @items = NotificationMessage.where(user_id: current_user.id).order(created_at: :desc).limit(10)
  end
end
