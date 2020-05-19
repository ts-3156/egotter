# == Schema Information
#
# Table name: create_periodic_report_requests
#
#  id          :bigint(8)        not null, primary key
#  user_id     :integer          not null
#  status      :string(191)      default(""), not null
#  finished_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_create_periodic_report_requests_on_created_at  (created_at)
#  index_create_periodic_report_requests_on_user_id     (user_id)
#

class CreatePeriodicReportRequest < ApplicationRecord
  include Concerns::Request::Runnable
  belongs_to :user

  validates :user_id, presence: true

  attr_accessor :check_allotted_messages_count, :check_following_status, :check_interval, :check_credentials, :check_twitter_user
  attr_accessor :worker_context

  def perform!
    logger.debug { "#{self.class}##{__method__} check_allotted_messages_count=#{check_allotted_messages_count} check_following_status=#{check_following_status} check_interval=#{check_interval} check_credentials=#{check_credentials} check_twitter_user=#{check_twitter_user} worker_context=#{worker_context}" }

    return unless validate_report!

    if check_twitter_user
      create_new_twitter_user_record
    end

    # If an administrator makes a request immediately after processing a user's request, it may be skipped
    jid = CreatePeriodicReportMessageWorker.perform_async(user_id, build_report_options)
    update(status: 'message_skipped') unless jid
  end

  def validate_report!
    return if check_credentials && !CredentialsValidator.new(self).validate_and_deliver!
    return if check_interval && !IntervalValidator.new(self).validate_and_deliver!
    return if check_following_status && !FollowingStatusValidator.new(self).validate_and_deliver!
    return if check_allotted_messages_count && !AllottedMessagesCountValidator.new(self).validate_and_deliver!

    true
  end

  class Validator
    def initialize(request)
      @request = request
    end

    def validate_and_deliver!
      result = validate!

      unless result
        deliver!
      end

      result
    end

    private

    def user_id
      @request.user_id
    end

    def user_or_egotter_requested_job?
      @request.worker_context == CreateUserRequestedPeriodicReportWorker ||
          @request.worker_context == CreateEgotterRequestedPeriodicReportWorker
    end

    def logger
      Rails.logger
    end
  end

  class CredentialsValidator < Validator
    def validate!
      @request.user.api_client.verify_credentials
      true
    rescue => e
      logger.info "#{self.class}##{__method__} #{e.inspect} request=#{@request.inspect}"
      @request.update(status: 'unauthorized')

      false
    end

    def deliver!
      if user_or_egotter_requested_job?
        jid = CreatePeriodicReportMessageWorker.perform_async(user_id, unauthorized: true)
        @request.update(status: 'unauthorized,message_skipped') unless jid
      end
    end
  end

  class IntervalValidator < Validator
    def validate!
      if CreatePeriodicReportRequest.interval_too_short?(include_user_id: user_id, reject_id: @request.id)
        @request.update(status: 'interval_too_short')

        false
      else
        true
      end
    end

    def deliver!
      if user_or_egotter_requested_job?
        if ScheduledJob.exists?(user_id: user_id)
          @request.update(status: 'interval_too_short,scheduled_job_exists')
          scheduled_jid = ScheduledJob.find_by(user_id: user_id)&.jid

          if scheduled_jid
            jid = CreatePeriodicReportMessageWorker.perform_async(user_id, scheduled_job_exists: true, scheduled_jid: scheduled_jid)
            @request.update(status: 'interval_too_short,scheduled_job_exists,message_skipped') unless jid
          else
            logger.warn "#{self.class}##{__method__} scheduled job exists and jid is invalid request=#{@request.inspect}"
            @request.update(status: 'interval_too_short,scheduled_job_exists,jid_not_found')
          end
        else
          @request.update(status: 'interval_too_short,scheduled_job_created')
          scheduled_jid = ScheduledJob.create(user_id: user_id).jid

          if scheduled_jid
            jid = CreatePeriodicReportMessageWorker.perform_async(user_id, scheduled_job_created: true, scheduled_jid: scheduled_jid)
            @request.update(status: 'interval_too_short,scheduled_job_created,message_skipped') unless jid
          else
            logger.warn "#{self.class}##{__method__} scheduled job is created and jid is invalid request=#{@request.inspect}"
            @request.update(status: 'interval_too_short,scheduled_job_created,jid_not_found')
          end
        end
      end
    end
  end

  class ScheduledJob
    attr_reader :jid, :perform_at

    def initialize(jid, perform_at)
      @jid = jid
      @perform_at = perform_at
    end

    WORKER_CLASS = CreateUserRequestedPeriodicReportWorker

    class << self
      def exists?(user_id:)
        fetch_scheduled_jobs(WORKER_CLASS).any? do |job|
          options = job.args.last
          options.is_a?(Hash) && options['user_id'] == user_id && options['scheduled_request']
        end
      end

      def create(user_id:)
        request = CreatePeriodicReportRequest.create(user_id: user_id)
        time = CreatePeriodicReportRequest.next_creation_time(user_id)
        jid = WORKER_CLASS.perform_at(time, request.id, user_id: user_id, scheduled_request: true)
        new(jid, time)
      end

      def find_by(user_id: nil, jid: nil)
        job = fetch_scheduled_jobs(WORKER_CLASS).find do |job|
          if user_id
            options = job.args.last
            options.is_a?(Hash) && options['user_id'] == user_id && options['scheduled_request']
          else
            job.jid == jid
          end
        end

        job ? new(job.jid, Time.zone.at(job.score)) : nil
      end

      private

      def fetch_scheduled_jobs(worker_class)
        Sidekiq::ScheduledSet.new.scan(worker_class.name).select do |job|
          job.klass == worker_class.name
        end
      end
    end
  end

  class FollowingStatusValidator < Validator
    def validate!
      user = @request.user
      return true if EgotterFollower.exists?(uid: user.uid)
      return true if user.api_client.twitter.friendship?(user.uid, User::EGOTTER_UID)

      @request.update(status: 'not_following')

      false
    rescue => e
      logger.info "#{self.class}##{__method__} #{e.inspect} request=#{@request.inspect}"
      true
    end

    def deliver!
      if user_or_egotter_requested_job?
        jid = CreatePeriodicReportMessageWorker.perform_async(@request.user_id, not_following: true)
        @request.update(status: 'not_following,message_skipped') unless jid
      end
    end
  end

  class AllottedMessagesCountValidator < Validator
    def validate!
      user = @request.user
      return true unless GlobalDirectMessageReceivedFlag.new.received?(user.uid)

      send_count = GlobalSendDirectMessageCountByUser.new.count(user.uid)
      return true if send_count <= 3

      @request.update(status: 'soft_limited')

      false
    end

    def deliver!
      jid = CreatePeriodicReportMessageWorker.perform_async(user_id, sending_soft_limited: true)
      @request.update(status: 'soft_limited,message_skipped') unless jid
    end
  end

  def create_new_twitter_user_record
    request = CreateTwitterUserRequest.create(
        requested_by: self.class,
        user_id: user_id,
        uid: user.uid)

    CreateTwitterUserTask.new(request).start!(:periodic_reports)
  rescue CreateTwitterUserRequest::TooShortCreateInterval,
      CreateTwitterUserRequest::NotChanged => e
    logger.info "#{self.class}##{__method__} #{e.inspect} request_id=#{id} create_request_id=#{request&.id}"
  rescue => e
    logger.warn "#{self.class}##{__method__} #{e.inspect} request_id=#{id} create_request_id=#{request&.id}"
  end

  PERIOD_START = 1.day

  def build_report_options
    start_date = PERIOD_START.ago
    end_date = Time.zone.now

    # To specify start_date, UnfriendsBuilder is used
    builder = UnfriendsBuilder.new(user.uid, start_date: start_date, end_date: end_date)
    unfriends = TwitterDB::User.where_and_order_by_field(uids: builder.unfriends.flatten.take(10)).map(&:screen_name)
    unfollowers = TwitterDB::User.where_and_order_by_field(uids: builder.unfollowers.flatten.take(10)).map(&:screen_name)

    first_user = TwitterUser.find_by(id: builder.first_user&.id)
    last_user = TwitterUser.find_by(id: builder.last_user&.id)

    {
        request_id: id,
        start_date: start_date,
        end_date: end_date,
        first_friends_count: first_user&.friends_count,
        first_followers_count: first_user&.followers_count,
        last_friends_count: last_user&.friends_count,
        last_followers_count: last_user&.followers_count,
        unfriends: unfriends,
        unfollowers: unfollowers,
        worker_context: worker_context
    }
  end

  SHORT_INTERVAL = TwitterUser::CREATE_RECORD_INTERVAL
  SUFFICIENT_INTERVAL = 6.hours

  class << self
    def next_creation_time(user_id)
      last_request = fetch_last_request(include_user_id: user_id, reject_id: nil)
      previous_time = last_request ? last_request.created_at : Time.zone.now
      previous_time + SHORT_INTERVAL + 1.second
    end

    def fetch_last_request(include_user_id:, reject_id:)
      query = correctly_completed
      query = query.where(user_id: include_user_id) if include_user_id
      query = query.where.not(id: reject_id) if reject_id
      query.order(created_at: :desc).first
    end

    def interval_too_short?(include_user_id:, reject_id:)
      last_request = fetch_last_request(include_user_id: include_user_id, reject_id: reject_id)
      last_request && last_request.finished_at > SHORT_INTERVAL.ago
    end

    def sufficient_interval?(user_id)
      last_request = fetch_last_request(include_user_id: user_id, reject_id: nil)
      !last_request || last_request.finished_at < SUFFICIENT_INTERVAL.ago
    end

    def correctly_completed
      where(status: '').where.not(finished_at: nil)
    end
  end
end
