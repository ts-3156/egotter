class FriendsController < ::Page::Base
  include Concerns::FriendsConcern

  before_action(only: %i(show)) do
    if request.format.html?
      if params[:type].present? && valid_screen_name?(params[:screen_name])
        case params[:type]
          when 'friends' then redirect_to(friend_path(screen_name: params[:screen_name]), status: 301)
          when 'followers' then redirect_to(follower_path(screen_name: params[:screen_name]), status: 301)
          when 'statuses' then redirect_to(status_path(screen_name: params[:screen_name]), status: 301)
        end
        logger.info "#{controller_name}##{action_name} redirect for backward compatibility type=#{params[:type]}"
      end
    else
      head :not_found
    end
  end

  def new
  end

  def show
    initialize_instance_variables
    @active_tab = 0
    render template: 'result_pages/show' unless performed?
  end
end
