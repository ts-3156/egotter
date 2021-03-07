# == Schema Information
#
# Table name: egotter_followers
#
#  id          :bigint(8)        not null, primary key
#  screen_name :string(191)      not null
#  uid         :bigint(8)        not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_egotter_followers_on_created_at  (created_at)
#  index_egotter_followers_on_uid         (uid) UNIQUE
#  index_egotter_followers_on_updated_at  (updated_at)
#

class EgotterFollower < ApplicationRecord
  validates_with Validations::ScreenNameValidator
  validates_with Validations::UidValidator

  class << self
    def collect_uids(uid = User::EGOTTER_UID)
      benchmark("collect_uids uid=#{uid}") do
        collect_with_max_id do |options|
          client = Bot.api_client.twitter
          client.follower_ids(uid, options)
        end
      end
    end

    def collect_with_max_id(&block)
      options = {count: 5000, cursor: -1}
      collection = []

      50.times do
        response = yield(options)
        break if response.nil?

        attrs = response.attrs
        collection.concat(attrs[:ids])

        break if attrs[:next_cursor] == 0

        options[:cursor] = attrs[:next_cursor]
      end

      collection
    end

    def import_uids(uids)
      uids.each_slice(1000).with_index do |uids_array, i|
        users = uids_array.map.with_index { |uid, i| new(uid: uid, screen_name: "sn#{i}") }
        benchmark("import_uids chunk=#{i} uids=#{uids_array.size}") do
          import users, on_duplicate_key_update: %i(uid), validate: false
        end
      end
    end

    def filter_unnecessary_uids(uids)
      benchmark("filter_unnecessary_uids uids=#{uids.size}") do
        pluck(:uid) - uids
      end
    end

    def delete_uids(uids)
      uids.each_slice(1000).with_index do |uids_array, i|
        benchmark("delete_uids chunk=#{i} uids=#{uids_array.size}") do
          where(uid: uids_array).delete_all
        end
      end
    end

    def benchmark(message, &block)
      super(message) do
        Rails.logger.silence(&block)
      end
    end
  end
end
