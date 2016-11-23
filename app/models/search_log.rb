# == Schema Information
#
# Table name: search_logs
#
#  id          :integer          not null, primary key
#  session_id  :string(191)      default(""), not null
#  user_id     :integer          default(-1), not null
#  uid         :string(191)      default(""), not null
#  screen_name :string(191)      default(""), not null
#  action      :string(191)      default(""), not null
#  ego_surfing :boolean          default(FALSE), not null
#  method      :string(191)      default(""), not null
#  device_type :string(191)      default(""), not null
#  os          :string(191)      default(""), not null
#  browser     :string(191)      default(""), not null
#  user_agent  :string(191)      default(""), not null
#  referer     :string(191)      default(""), not null
#  referral    :string(191)      default(""), not null
#  channel     :string(191)      default(""), not null
#  first_time  :boolean          default(FALSE), not null
#  landing     :boolean          default(FALSE), not null
#  medium      :string(191)      default(""), not null
#  created_at  :datetime         not null
#
# Indexes
#
#  index_search_logs_on_action          (action)
#  index_search_logs_on_created_at      (created_at)
#  index_search_logs_on_screen_name     (screen_name)
#  index_search_logs_on_session_id      (session_id)
#  index_search_logs_on_uid             (uid)
#  index_search_logs_on_uid_and_action  (uid,action)
#  index_search_logs_on_user_id         (user_id)
#

class SearchLog < ActiveRecord::Base

  def self.except_crawler
    where.not(device_type: %w(crawler UNKNOWN), session_id: -1)
  end

  def self.user_ids(*args)
    except_crawler
      .where(*args)
      .where.not(user_id: -1)
      .uniq
      .pluck(:user_id)
  end

  def self.session_ids(*args)
    except_crawler
      .where(*args)
      .uniq
      .pluck(:session_id)
  end
end
