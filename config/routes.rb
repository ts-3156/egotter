Rails.application.routes.draw do
  if ENV['MAINTENANCE'] == '1'
    root 'misc#maintenance'
    match '*path' => 'misc#maintenance', via: :all
  else
    root 'home#new'
    get 'start', to: 'home#start', as: 'start'
  end

  namespace :api, {format: 'json'} do
    namespace :v1 do
      Search::API_V1_NAMES.each do |menu|
        get "#{menu}/summary", to: "#{menu}#summary"
        get "#{menu}/list", to: "#{menu}#list"
      end
      get "close_friends", to: "close_friends#show"
      get "word_clouds", to: "word_clouds#show"
      get "friend_insights/profiles_count", to: "friend_insights#profiles_count"
      get "friend_insights/locations_count", to: "friend_insights#locations_count"
      get "friend_insights/tweet_times", to: "friend_insights#tweet_times"
      get "follower_insights/profiles_count", to: "follower_insights#profiles_count"
      get "follower_insights/locations_count", to: "follower_insights#locations_count"
      get "follower_insights/tweet_times", to: "follower_insights#tweet_times"
      get "secret_accounts", to: "secret_accounts#show"

      get "summary/summary", to: "summary#summary"
      get 'account_statuses', to: 'account_statuses#show'

      post 'users/update_instance_id', to: 'users#update_instance_id'
      post 'users/update_device_token', to: 'users#update_device_token'
      post 'periodic_report_settings', to: 'periodic_report_settings#update'
      post 'create_periodic_tweet_requests', to: 'create_periodic_tweet_requests#update'
      resources :share_tweets, only: %i(create)
    end
  end

  get 'l/:name', to: 'landing_pages#new'

  get 'delete_tweets', to: 'delete_tweets#new'
  get 'delete_tweets/mypage', to: 'delete_tweets#show', as: :delete_tweets_mypage
  post "delete_tweets", to: "delete_tweets#delete"

  delete "reset_egotter", to: "reset_egotter#reset"
  post "reset_cache", to: "reset_cache#reset"

  namespace :directory do
    get "profiles(/:id1(/:id2))", to: "profiles#show", as: :profile
    get "timelines(/:id1(/:id2))", to: "timelines#show", as: :timeline
  end

  %i(maintenance privacy_policy terms_of_service specified_commercial_transactions support).each do |name|
    get name, to: "misc##{name}", as: name
  end

  %i(
    profiles
    friends
    followers
    statuses
    audience_insights
    close_friends
    favorite_friends
    usage_stats
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
  ).each do |controller_name|
    resources controller_name, only: %i(show), param: :screen_name
  end

  resources 'secret_accounts', only: %i(show), param: :screen_name

  get 'profiles/:screen_name/latest', to: redirect("/profiles/%{screen_name}")

  %i(
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
  ).each do |controller_name|
    get "#{controller_name}/:screen_name/all", to: redirect("/#{controller_name}/%{screen_name}")
  end
  match 'statuses/:screen_name/oembed' => proc { [404, {'Content-Type' => 'text/plain'}, ''] }, via: :get

  get 'one_sided_friends', to: 'one_sided_friends#new', as: :one_sided_friends_top
  get 'unfriends', to: 'unfriends#new', as: :unfriends_top
  get 'inactive_friends', to: 'inactive_friends#new', as: :inactive_friends_top
  get 'friends', to: 'friends#new', as: :friends_top

  resources :word_clouds, only: %i(show), param: :screen_name

  resources :clusters, only: %i(show), param: :screen_name
  get 'clusters', to: 'clusters#new', as: :clusters_top

  resources :personality_insights, only: %i(show), param: :screen_name
  get 'personality_insights', to: 'personality_insights#new', as: :personality_insights_top

  resources :searches, only: %i(create), param: :screen_name
  get 'waiting/:uid', to: 'waiting#new', as: :waiting

  resources :twitter_users, only: %i(create show), param: :uid
  get 'twitter_users/:uid/changes', to: 'twitter_users#changes', as: :twitter_users_changes

  resources :timelines, only: %i(show), param: :screen_name

  get 'not_found/:screen_name', to: redirect("/profiles/%{screen_name}"), as: 'not_found'
  get 'not_found/:screen_name/latest', to: redirect("/profiles/%{screen_name}")
  get 'forbidden/:screen_name', to: redirect("/profiles/%{screen_name}"), as: 'forbidden'
  get 'forbidden/:screen_name/latest', to: redirect("/profiles/%{screen_name}")
  get 'blocked/:screen_name', to: redirect("/profiles/%{screen_name}"), as: 'blocked'
  get 'blocked/:screen_name/latest', to: redirect("/profiles/%{screen_name}")
  get 'protected/:screen_name', to: redirect("/profiles/%{screen_name}"), as: 'protected'
  get 'protected/:screen_name/latest', to: redirect("/profiles/%{screen_name}")

  get 'follow', to: 'follows#show'
  resources :follows, only: %i(create)
  resources :unfollows, only: %i(create)

  get 'tokimeki_unfollow', to: 'tokimeki_unfollow#new', as: :tokimeki_unfollow_top
  get 'tokimeki_unfollow/cleanup', to: 'tokimeki_unfollow#cleanup', as: :tokimeki_unfollow_cleanup
  post 'tokimeki_unfollow/unfollow', to: 'tokimeki_unfollow#unfollow', as: :tokimeki_unfollow_unfollow
  post 'tokimeki_unfollow/keep', to: 'tokimeki_unfollow#keep', as: :tokimeki_unfollow_keep

  resources :settings, only: :index
  get 'settings/follow_requests', to: "settings#follow_requests"
  get 'settings/unfollow_requests', to: "settings#unfollow_requests"

  get 'pricing', to: "pricing#new"
  resources :orders, only: %i(create destroy)
  get 'orders/success', to: "orders#success"
  get 'orders/cancel', to: "orders#cancel"
  post 'orders/checkout_session_completed', to: "orders#checkout_session_completed"

  get 'webhook/twitter', to: 'webhook#challenge'
  post 'webhook/twitter', to: 'webhook#twitter'

  get 'adsense', to: 'adsense#new'
  get 'search_histories', to: 'search_histories#new'
  get 'load_public_tweets', to: 'public_tweets#load', as: :load_public_tweets

  %i(sign_in after_sign_in after_sign_up goodbye).each do |name|
    get name, to: "login##{name}", as: name
  end
  delete :sign_out, to: "login#sign_out", as: :sign_out
  get 'welcome', to: "welcome#new"

  get 'search_count', to: 'search_count#new'

  devise_for :users, skip: %i(sessions confirmations registrations passwords unlocks), controllers: {omniauth_callbacks: 'users/omniauth_callbacks'}
  devise_scope :user do
    get '_sign_out' => 'users/sessions#destroy', :as => :destroy_user_session
  end

  authenticate :user, lambda { |u| [User::ADMIN_UID, User::EGOTTER_UID].include?(u.uid) } do
    match 'app_stats' => proc {
      [200, {'Content-Type' => 'text/plain'}, [AppStat.new.to_s]]
    }, via: :get
  end

  require 'sidekiq/web'
  if Rails.env.production?
    authenticate :user, lambda { |u| [User::ADMIN_UID, User::EGOTTER_UID].include?(u.uid) } do
      mount Sidekiq::Web => '/sidekiq'
      mount Blazer::Engine, at: '/blazer' if defined?(Blazer::Engine)
    end
  elsif Rails.env.development?
    mount Sidekiq::Web => '/sidekiq'
    mount Blazer::Engine, at: '/blazer'
  end

  match '*unmatched_route', to: 'application#not_found', via: :all
end
