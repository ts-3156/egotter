module SearchesHelper
  def build_twitter_user(screen_name)
    twitter_user = TwitterUser.order(created_at: :desc).find_by(screen_name: screen_name)
    return twitter_user if twitter_user

    user = client.user(screen_name)
    TwitterUser.build_by_user(user)

  rescue => e
    if e.message == 'User not found.'
      CreateNotFoundUserWorker.perform_async(screen_name)
    elsif e.message == 'User has been suspended.'
      CreateForbiddenUserWorker.perform_async(screen_name)
    end

    twitter_exception_handler(e, screen_name)
  end

  def root_path_for(controller:)
    if %w(one_sided_friends unfriends relationships inactive_friends friends conversations clusters).include? controller
      send("#{controller}_top_path")
    else
      root_path
    end
  end

  def app_name_for(controller:)
    if %w(one_sided_friends unfriends relationships inactive_friends friends conversations clusters).include? controller
      send(:t, "#{controller}.new.title_html")
    else
      t('searches.common.egotter')
    end
  end

  def search_path_for(menu, screen_name)
    case menu.to_s
      when *%w(friends followers close_friends favorite_friends usage_stats unfriends unfollowers blocking_or_blocked inactive_friends inactive_followers one_sided_friends one_sided_followers mutual_friends)
        send("#{menu.to_s.singularize}_path", screen_name: screen_name)
      when *%w(replying replied)
        conversation_path(screen_name: screen_name, type: menu)
      when *%w(clusters clusters_belong_to)
        cluster_path(screen_name: screen_name)
      else
        raise "#{__method__}: invalid menu #{menu}"
    end
  end

  def searches_path_for(controller:, screen_name: '', via: '')
    options = {screen_name: screen_name, via: via}.delete_if { |_, v| v.empty? }
    if %w(relationships conversations clusters).include? controller
      send("#{controller}_path", options)
    else
      searches_path(options)
    end
  end

  def title_for(menu, screen_name)
    case menu.to_sym
      when *%i(friends followers close_friends favorite_friends usage_stats unfriends unfollowers blocking_or_blocked inactive_friends inactive_followers one_sided_friends one_sided_followers mutual_friends) then t("#{menu}.show.summary_title")
      when :clusters_belong_to then t("searches.clusters_belong_to.name")
      else t("searches.#{menu}.title", user: mention_name(screen_name))
    end
  end

  def description_for(menu, screen_name)
    case menu.to_sym
      when *%i(friends followers close_friends favorite_friends unfriends unfollowers blocking_or_blocked inactive_friends inactive_followers one_sided_friends one_sided_followers mutual_friends)
        t("#{menu}.show.page_description", user: mention_name(screen_name))
      else t("searches.#{menu}.description", user: mention_name(screen_name))
    end
  end

  def fetch_twitter_user_from_cache(uid)
    attrs = Util::ValidTwitterUserSet.new(redis).get(uid)
    return nil if attrs.nil?

    TwitterUser.new(
      uid: attrs['uid'],
      screen_name: attrs['screen_name'],
      user_info: attrs['user_info'],
    )
  end

  def save_twitter_user_to_cache(uid, screen_name:, user_info:)
    Util::ValidTwitterUserSet.new(redis).set(
      uid,
      {uid: uid, screen_name: screen_name, user_info: user_info}
    )
  end

  def reject_crawler
    if request.from_crawler?
      render text: t('before_sign_in.reject_crawler')
    end
  end
end
