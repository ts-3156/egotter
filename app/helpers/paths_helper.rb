module PathsHelper
  def subroot_path(via: nil)
    via = current_via("#{via + '/' if via}root_path_for_#{controller_name}")
    case controller_name
    when 'close_friends', 'one_sided_friends', 'unfriends', 'inactive_friends', 'friends', 'clusters', 'personality_insights' then
      send("#{controller_name}_top_path", via: via)
    when 'timelines' then
      if @twitter_user
        timeline_path(@twitter_user, via: via)
      else
        root_path(via: via)
      end
    when 'delete_tweets' then
      delete_tweets_path(via: via)
    when 'delete_favorites' then
      delete_favorites_path(via: via)
    when 'tokimeki_unfollow' then
      tokimeki_unfollow_cleanup_path(via: via)
    when 'trends' then
      trends_path(via: via)
    else
      root_path(via: via)
    end
  end

  def download_path(resource, controller = nil)
    controller = controller_name unless controller
    case controller
    when 'friends'
      friend_download_path(resource, via: current_via)
    when 'followers'
      follower_download_path(resource, via: current_via)
    when 'mutual_friends'
      mutual_friend_download_path(resource, via: current_via)
    when 'one_sided_friends'
      one_sided_friend_download_path(resource, via: current_via)
    when 'one_sided_followers'
      one_sided_follower_download_path(resource, via: current_via)
    when 'inactive_mutual_friends'
      inactive_mutual_friend_download_path(resource, via: current_via)
    when 'inactive_friends'
      inactive_friend_download_path(resource, via: current_via)
    when 'inactive_followers'
      inactive_follower_download_path(resource, via: current_via)
    when 'mutual_unfriends'
      mutual_unfriend_download_path(resource, via: current_via)
    when 'unfriends'
      unfriend_download_path(resource, via: current_via)
    when 'unfollowers'
      unfollower_download_path(resource, via: current_via)
    else
      raise "#{__method__} Invalid controller_name value=#{controller_name}"
    end.html_safe
  end

  def feed_page_path(name, twitter_user)
    via = current_via("feed_#{name}")

    case name
    when 'close_friends'
      close_friend_path(twitter_user, via: via)
    when 'common_friends'
      common_friend_path(twitter_user, via: via)
    when 'common_followers'
      common_follower_path(twitter_user, via: via)
    when 'unfriends'
      unfriend_path(twitter_user, via: via)
    when 'unfollowers'
      unfollower_path(twitter_user, via: via)
    when 'mutual_unfriends'
      mutual_unfriend_path(twitter_user, via: via)
    when 'blockers'
      nil
    when 'muters'
      nil
    when 'mutual_friends'
      mutual_friend_path(twitter_user, via: via)
    when 'one_sided_friends'
      one_sided_friend_path(twitter_user, via: via)
    when 'one_sided_followers'
      one_sided_follower_path(twitter_user, via: via)
    when 'replying'
      replying_path(twitter_user, via: via)
    when 'replied'
      replied_path(twitter_user, via: via)
    when 'favorite_friends'
      favorite_friend_path(twitter_user, via: via)
    when 'inactive_friends'
      inactive_friend_path(twitter_user, via: via)
    when 'inactive_followers'
      inactive_follower_path(twitter_user, via: via)
    else
      raise "#{__method__} Invalid name value=#{name}"
    end
  end

  # TODO Don't use #send
  def api_users_path
    if controller_name == 'blockers'
      api_v1_blockers_list_path(via: current_via)
    else
      send("api_v1_#{controller_name}_list_path", via: current_via)
    end.html_safe
  end

  def api_summary_path(name, twitter_user)
    via = current_via("feed_#{name}")

    case name
    when 'close_friends'
      api_v1_close_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'common_friends'
      api_v1_common_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'common_followers'
      api_v1_common_followers_summary_path(uid: twitter_user.uid, via: via)
    when 'unfriends'
      api_v1_unfriends_summary_path(uid: twitter_user.uid, via: via)
    when 'unfollowers'
      api_v1_unfollowers_summary_path(uid: twitter_user.uid, via: via)
    when 'mutual_unfriends'
      api_v1_mutual_unfriends_summary_path(uid: twitter_user.uid, via: via)
    when 'blockers'
      nil
    when 'muters'
      nil
    when 'mutual_friends'
      api_v1_mutual_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'one_sided_friends'
      api_v1_one_sided_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'one_sided_followers'
      api_v1_one_sided_followers_summary_path(uid: twitter_user.uid, via: via)
    when 'replying'
      api_v1_replying_summary_path(uid: twitter_user.uid, via: via)
    when 'replied'
      api_v1_replied_summary_path(uid: twitter_user.uid, via: via)
    when 'favorite_friends'
      api_v1_favorite_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'inactive_friends'
      api_v1_inactive_friends_summary_path(uid: twitter_user.uid, via: via)
    when 'inactive_followers'
      api_v1_inactive_followers_summary_path(uid: twitter_user.uid, via: via)
    else
      raise "#{__method__} Invalid name value=#{name}"
    end
  end

  def api_trend_words_count_path(trend_id)
    api_v1_trends_words_count_path(id: trend_id)
  end

  def api_trend_profile_words_count_path(trend_id)
    api_v1_trends_profile_words_count_path(id: trend_id)
  end

  def api_trend_times_count_path(trend_id)
    api_v1_trends_times_count_path(id: trend_id)
  end

  def api_trend_users_count_path(trend_id)
    api_v1_trends_users_count_path(id: trend_id)
  end

  def api_profiles_count_path(twitter_user)
    case controller_name
    when 'friends'
      api_v1_friend_insights_profiles_count_path(uid: twitter_user.uid, via: current_via)
    when 'followers'
      api_v1_follower_insights_profiles_count_path(uid: twitter_user.uid, via: current_via)
    else
      raise "#{__method__} Invalid controller_name value=#{controller_name}"
    end.html_safe
  end

  def api_locations_count_path(twitter_user)
    case controller_name
    when 'friends'
      api_v1_friend_insights_locations_count_path(uid: twitter_user.uid, via: current_via)
    when 'followers'
      api_v1_follower_insights_locations_count_path(uid: twitter_user.uid, via: current_via)
    else
      raise "#{__method__} Invalid controller_name value=#{controller_name}"
    end.html_safe
  end

  def api_tweet_times_path(uid:)
    case controller_name
    when 'friends'
      api_v1_friend_insights_tweet_times_path(uid: uid, via: current_via)
    when 'followers'
      api_v1_follower_insights_tweet_times_path(uid: uid, via: current_via)
    else
      raise "#{__method__} Invalid controller_name value=#{controller_name}"
    end.html_safe
  end

  def redirect_path_for_after_waiting(screen_name)
    options = {
        screen_name: screen_name,
        follow_dialog: params[:follow_dialog],
        sign_in_dialog: params[:sign_in_dialog],
        share_dialog: params[:share_dialog],
        purchase_dialog: params[:purchase_dialog],
        via: current_via,
    }.compact

    case controller_path
    when 'timelines'
      timeline_path(options)
    when 'close_friends'
      close_friend_path(options)
    when 'unfriends'
      unfriend_path(options)
    when 'unfollowers'
      unfollower_path(options)
    when 'mutual_unfriends'
      mutual_unfriend_path(options)
    when 'replying'
      replying_path(options)
    when 'replied'
      replied_path(options)
    else
      raise "#{__method__} Invalid controller_path value=#{controller_path}"
    end
  end

  def sign_in_and_timeline_path(twitter_user, via:, follow: false)
    via = current_via(via)
    sign_in_path(follow: follow, via: via, redirect_path: timeline_path(twitter_user, via: via))
  end

  def scheduled_tweets_url(via: nil, utm_source: nil, utm_medium: nil, utm_campaign: nil)
    params = {
        via: via,
        utm_source: utm_source,
        utm_medium: utm_medium,
        utm_campaign: utm_campaign,
    }.select { |_, v| v }.to_param
    "https://scheduled-tweets.egotter.com?#{params}"
  end

  def meta_og_image_url
    if controller_name == 'personality_insights'
      image_url('/egotter_personality_insight_840x450.jpg?loc=og_image')
    elsif controller_name == 'close_friends' && action_name == 'show' && @twitter_user
      CloseFriendsOgImage.lambda_url(@twitter_user.uid)
    elsif controller_name == 'delete_tweets'
      # TODO
      image_url('/egotter_like_app_store_840x450.png?loc=og_image')
    else
      image_url('/egotter_like_app_store_840x450.png?loc=og_image')
    end
  rescue => e
    image_url('/egotter_like_app_store_840x450.png?loc=og_image_error')
  end

  def transcription_ai_url
    'https://transcription-ai.com?via=egotter_footer&utm_source=egotter-footer&utm_medium=web&utm_campaign=egotter'
  end

  def android_app_url
    'https://play.google.com/store/apps/details?id=com.egotter&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'
  end

  def allysocial_url(via)
    "https://searchfollowers.com/?via=egotter_#{via}"
  end

  def egotter_ads_form_url
    'https://docs.google.com/forms/d/e/1FAIpQLSdZc8a6tS0OhddM_c_XKljYm4hSCSwLx3iIiymVqOFs_40qiw/viewform'
  end

  def custom_support_form_url
    'https://docs.google.com/forms/d/e/1FAIpQLScGxNuSm1na2yQeUwuoHoS37T3zLDMwnOpccZV4R1S_Ac3zLw/viewform'
  end

  def twitter_applications_url
    'https://twitter.com/settings/applications/185425'
  end

  def base_shop_1_month_url
    'https://egotter.thebase.in/items/44366397'
  end

  def base_shop_6_months_url
    'https://egotter.thebase.in/items/44708302'
  end

  def base_shop_12_months_url
    'https://egotter.thebase.in/items/44708346'
  end

  def force_sign_in_path(options)
    sign_in_path(options.merge(force_login: true))
  end

  def current_via(suffix = nil)
    via = "#{controller_name}/#{action_name}"
    via += "/#{suffix}" if suffix
    via
  end
end
