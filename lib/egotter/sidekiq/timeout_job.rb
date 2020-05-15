module Egotter
  module Sidekiq
    class TimeoutJob
      include JobCallbackUtil

      def call(worker, msg, queue, &block)
        if worker.respond_to?(:timeout_in)
          yield_with_timeout(worker, msg['args'], worker.timeout_in, &block)
        elsif worker.respond_to?(:timeout_in_v2)
          define_timeout_related_methods(worker, msg)
          yield_with_timeout_v2(worker, msg['args'], worker.timeout_in, &block)
        else
          yield
        end
      end

      def define_timeout_related_methods(worker, msg)
        timeout_started_at = Time.now
        worker.define_singleton_method(:timeout?) do
          Time.now - timeout_started_at > worker.timeout_in
        end

        worker.define_singleton_method(:timeout!) do
          raise 'Time is up!'
        end
      end

      def yield_with_timeout(worker, args, timeout_in, &block)
        Timeout.timeout(timeout_in) do
          yield
        end
      rescue Timeout::Error => e
        worker.logger.info "#{e.class}: #{e.message} #{timeout_in} #{args.inspect.truncate(100)}"
        worker.logger.info e.backtrace.join("\n")

        perform_callback(worker, :after_timeout, args)

        nil
      end

      def yield_with_timeout_v2(worker, args, timeout_in, &block)
        Timeout.timeout(timeout_in) do
          yield
        end
      rescue Timeout::Error => e
        worker.logger.info "#{e.class}: #{e.message} #{timeout_in} #{args.inspect.truncate(100)}"
        worker.logger.info e.backtrace.join("\n")

        perform_callback(worker, :after_timeout, args)

        nil
      rescue => e
        if e.message == 'Time is up!'
          worker.logger.info "#{e.class}: #{e.message} #{timeout_in} #{args.inspect.truncate(100)}"
          worker.logger.info e.backtrace.join("\n")

          perform_callback(worker, :after_timeout, args)

          nil
        else
          raise
        end
      end
    end
  end
end
