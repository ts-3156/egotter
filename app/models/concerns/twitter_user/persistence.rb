require 'active_support/concern'
module Concerns::TwitterUser::Persistence
  extend ActiveSupport::Concern

  class_methods do
  end

  included do
    # Relations are created on `after_commit` in order to avoid long transaction.
    # With transactional_fixtures = true, after_commit callbacks is not fired.
    Rails.env.test? ? after_create { put_relations_back } : after_commit(on: :create) { put_relations_back }
  end

  private

  def put_relations_back
    statuses.each { |r| r.from_id = id }
    mentions.each { |r| r.from_id = id }
    search_results.each { |r| r.from_id = id }
    favorites.each { |r| r.from_id = id }

    options = {validate: false}

    silent_transaction { statuses.each_slice(1000) { |ary| Status.import(ary, options) } }
    silent_transaction { mentions.each_slice(1000) { |ary| Mention.import(ary, options) } }
    silent_transaction { search_results.each_slice(1000) { |ary| SearchResult.import(ary, options) } }
    silent_transaction { favorites.each_slice(1000) { |ary| Favorite.import(ary, options) } }

    if Rails.env.test?
      friendships.each { |f| f.from_id = id }.each(&:save!)
      followerships.each { |f| f.from_id = id }.each(&:save!)
    end
  rescue => e
    # ActiveRecord::RecordNotFound Couldn't find TwitterUser with 'id'=00000
    # ActiveRecord::StatementInvalid Mysql2::Error: Deadlock found when trying to get lock;
    logger.warn "#{self.class}##{__method__}: #{e.class} #{e.message.truncate(120)} #{id} #{uid} #{screen_name}"
    logger.info e.backtrace.join("\n")
    destroy
  end

  def silent_transaction(&block)
    Rails.logger.silence { ActiveRecord::Base.transaction(&block) }
  end
end
