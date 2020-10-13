class UnfriendsController < ApplicationController
  include SearchRequestConcern
  include DownloadRequestConcern
  include JobQueueingConcern

  def new
  end

  def show
    @jid = enqueue_create_twitter_user_job_if_needed(@twitter_user.uid, user_id: current_user_id)
    @active_tab = 0
    render template: 'result_pages/show' unless performed?
  end

  def download
    data = data_for_download(@twitter_user.unfriends(limit: limit_for_download))
    send_data data, filename: filename_for_download(@twitter_user), type: 'text/csv; charset=utf-8'
  end
end
