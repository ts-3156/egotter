crumb :root do
  link t('breadcrumb.root'), root_path(via: current_via('breadcrumb_root'))
end

crumb :start do |screen_name|
  link t('home.start.crumb_title'), start_path(via: current_via("breadcrumb_start"))
  parent :root
end

crumb :pricing do |screen_name|
  link t('pricing.new.crumb_title'), pricing_path(via: current_via("breadcrumb_pricing"))
  parent :root
end

crumb :timeline do |screen_name|
  link t('timelines.show.crumb_title', user: screen_name), timeline_path(screen_name: screen_name, via: current_via('breadcrumb_timeline'))
  parent :root
end

%w(
  statuses
  friends
  followers
  close_friends
  favorite_friends
  unfriends
  unfollowers
  blocking_or_blocked
  inactive_friends
  inactive_followers
  inactive_mutual_friends
  one_sided_friends
  one_sided_followers
  mutual_friends
  replying
  replied
  replying_and_replied
  common_friends
  common_followers
  common_mutual_friends
).each do |name|
  crumb name.singularize.to_sym do |screen_name|
    link current_crumb_title, send("#{name.singularize}_path", screen_name: screen_name, via: current_via("breadcrumb_#{name}"))
    parent :timeline, screen_name
  end
end

crumb :profile do |screen_name|
  link t('profiles.show.crumb_title', user: screen_name), profile_path(screen_name: screen_name, via: current_via("breadcrumb_profile"))
  parent :root
end

crumb :word_cloud do |screen_name|
  link t('word_clouds.show.crumb_title'), word_cloud_path(screen_name: screen_name, via: current_via("breadcrumb_word_cloud"))
  parent :timeline, screen_name
end

crumb :cluster do |screen_name|
  link t('clusters.new.crumb_title'), cluster_path(screen_name: screen_name, via: current_via("breadcrumb_cluster"))
  parent :timeline, screen_name
end

crumb :usage_stat do |screen_name|
  link t('usage_stats.show.crumb_title'), usage_stat_path(screen_name: screen_name, via: current_via("breadcrumb_usage_stat"))
  parent :timeline, screen_name
end

crumb :audience_insight do |screen_name|
  link t('audience_insights.show.crumb_title'), audience_insight_path(screen_name: screen_name, via: current_via("breadcrumb_audience_insight"))
  parent :timeline, screen_name
end

crumb :personality_insight do |screen_name|
  link t('personality_insights.show.crumb_title'), personality_insight_path(screen_name: screen_name, via: current_via("breadcrumb_personality_insight"))
  parent :timeline, screen_name
end

crumb :secret_account do |screen_name|
  link t('secret_accounts.show.crumb_title'), secret_account_path(screen_name: screen_name, via: current_via("breadcrumb_secret_account"))
  parent :timeline, screen_name
end
