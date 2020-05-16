require_relative '../lib/deploy_ruby/aws/instance'

module Tasks
  module UninstallTask
    module Util
      def green(str)
        logger.info "\e[32m#{str}\e[0m"
      end

      def exec_command(host, cmd, dir: '/var/egotter', exception: true)
        raise 'Hostname is empty.' if host.to_s.empty?
        green("#{host} #{cmd}")
        system('ssh', host, "cd #{dir} && #{cmd}", exception: exception)
      end
    end

    class Task < ::DeployRuby::Task
      include Util

      def initialize(name)
        @name = name
      end

      def run_command(cmd, exception: true)
        exec_command(@name, cmd, exception: exception)
      end
    end

    class Web < Task
      def initialize(id)
        @id = id
        super(::DeployRuby::Aws::Instance.retrieve(id).name)
      end

      def uninstall
        stop_processes
      end

      def stop_processes
        [
            'sudo service nginx stop',
            'sudo service puma stop',
        ].each do |cmd|
          run_command(cmd)
        end

        self
      end
    end

    class Sidekiq < Task
      def initialize(id)
        @id = id
        super(::DeployRuby::Aws::Instance.retrieve(id).name)
      end

      def uninstall
        stop_processes
      end

      def stop_processes
        [
            'sudo stop sidekiq && tail -n 6 log/sidekiq.log || :',
            'sudo stop sidekiq_workers && tail -n 6 log/sidekiq.log || :',
            'sudo stop sidekiq_import && tail -n 6 log/sidekiq_import.log || :',
            'sudo stop sidekiq_misc && tail -n 6 log/sidekiq_misc.log || :',
            'sudo stop sidekiq_misc_workers && tail -n 6 log/sidekiq_misc.log || :',
            'sudo stop sidekiq_prompt_reports_workers && tail -n 6 log/sidekiq_prompt_reports.log || :',
        ].each do |cmd|
          run_command(cmd)
        end

        self
      end
    end
  end
end