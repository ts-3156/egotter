class CommonFollowersController < ApplicationController
  include SearchRequestConcern

  before_action(only: :show) { require_login! }
  before_action(only: :show) { twitter_user_persisted?(current_user.uid) }

  def show
    @active_tab = 1
    render template: 'result_pages/show' unless performed?
  end
end
