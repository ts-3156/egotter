module SearchHistoriesHelper
  def latest_search_histories
    if request.from_crawler? || from_minor_crawler?(request.user_agent)
      []
    else
      user_signed_in? ? SearchHistory.latest(user_id: current_user_id) : SearchHistory.latest(session_id: session[:fingerprint])
    end
  end

  def today_search_histories_size
    start = 1.day.ago
    SearchHistory.where(created_at: start..Time.zone.now, session_id: session[:fingerprint]).size
  end
end
