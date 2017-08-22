class UnfriendsAndUnfollowers < ::Base

  before_action(only: %i(show)) do
    @jid = add_create_twitter_user_worker_if_needed(@twitter_user.uid, user_id: current_user_id, screen_name: @twitter_user.screen_name)
  end

  def show
    @api_path = send("api_v1_#{controller_name}_list_path")
    @breadcrumb_name = controller_name.singularize.to_sym
    @canonical_url = send("#{controller_name.singularize}_url", @twitter_user)
    @canonical_path = send("#{controller_name.singularize}_path", @twitter_user)
    @page_title = t('.page_title', user: @twitter_user.mention_name)
    @stat = UsageStat.find_by(uid: @twitter_user.uid)

    counts = related_counts(@twitter_user)
    @meta_title = t('.meta_title', {user: @twitter_user.mention_name}.merge(counts))

    @page_description = t('.page_description', user: @twitter_user.mention_name)
    @meta_description = t('.meta_description', {user: @twitter_user.mention_name}.merge(counts))

    mention_names = @twitter_user.twitter_db_user.send(controller_name).select(:screen_name).limit(3).map(&:mention_name)
    names = '.' + honorific_names(mention_names)
    @tweet_text = t('.tweet_text', users: names, url: @canonical_url)
  end

  def related_counts(twitter_user)
    user = twitter_user.twitter_db_user
    {
      unfriends: user.unfriendships.size,
      unfollowers: user.unfollowerships.size,
      blocking_or_blocked: user.blocking_or_blocked_uids.size
    }
  end
end