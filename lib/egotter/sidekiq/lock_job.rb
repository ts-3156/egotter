require 'logger'

module Egotter
  module Sidekiq
    class LockJob
      def call(worker, msg, queue, &block)
        if worker.respond_to?(:lock_in)

          history = ::Egotter::Sidekiq::LockHistory.new(worker)

          if history.locked?
            logger.info { "job execution is locked. args=#{truncate(msg['args'].inspect)}" }
            worker.class.perform_in(worker.lock_in, *msg['args'])
            nil
          else
            history.lock
            begin
              yield
            ensure
              history.unlock
            end
          end
        else
          yield
        end
      end

      def truncate(text, length: 100)
        if text.length > length
          text.slice(0, length)
        else
          text
        end
      end

      def logger
        if defined?(::Sidekiq)
          ::Sidekiq.logger
        elsif defined?(::Rails)
          ::Rails.logger
        else
          ::Logger.new(STDOUT)
        end
      end
    end

    class LockHistory < ::Egotter::SortedSet
      def initialize(worker)
        super(Redis.client)

        @key = "#{self.class}:#{worker.class}:any_ids"
        @ttl = worker.lock_in

        @lock_count = worker.lock_count
      end

      def lock
        add(Time.zone.now.to_f)
      end

      def unlock
        if size > 0
          delete(to_a[0])
        end
      rescue => e
      end

      def locked?
        size >= @lock_count
      rescue => e
        false
      end
    end
  end
end
