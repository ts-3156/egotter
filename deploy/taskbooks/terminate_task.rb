require_relative '../../app/models/cloud_watch_client'

require_relative '../tasks/uninstall_task'

module Taskbooks
  module TerminateTask
    def build(params)
      role = params['role']

      if role == 'auto'
        name = params['instance-name']

        if name.to_s.include?('_web')
          role = 'web'
        elsif name.to_s.include?('_sidekiq')
          role = 'sidekiq'
        else
          raise 'role is auto, but collect role is not found'
        end

        params['role'] = role
      end

      if role == 'web'
        WebTask.new(params)
      elsif role == 'sidekiq'
        SidekiqTask.new(params)
      else
        raise "Invalid role #{role}"
      end
    end

    module_function :build

    class Task < ::DeployRuby::Task
      attr_reader :action, :instance

      def initialize
        @action = :terminate
        @instance = nil
        @role = nil
        @terminated = nil
      end

      def run
        after_terminate if @terminated
      end

      def after_terminate
        CloudWatchClient::Dashboard.new('egotter-linux-system').
            remove_cpu_utilization(@role, @terminated.id).
            remove_memory_utilization(@role, @terminated.id).
            remove_cpu_credit_balance(@role, @terminated.id).
            remove_disk_space_utilization(@role, @terminated.id).
            update
      end
    end

    class WebTask < Task
      def initialize(params)
        super()
        @role = params['role']

        target_group_arn = params['target-group'] || ENV['AWS_TARGET_GROUP']
        @target_group = ::DeployRuby::Aws::TargetGroup.new(target_group_arn)
      end

      def run
        instance = @target_group.oldest_instance
        if instance && @target_group.deregister(instance.id)
          Tasks::UninstallTask::Web.new(instance.id).uninstall
          instance.terminate
          @instance = @terminated = instance
        end

        super
      end
    end

    class SidekiqTask < Task
      def initialize(params)
        super()
        @params = params
        @role = params['role']
      end

      def run
        instance = ::DeployRuby::Aws::Instance.retrieve_by(id: @params['instance-id'], name: @params['instance-name'])
        if instance
          Tasks::UninstallTask::Sidekiq.new(instance.id).uninstall
          instance.terminate
          @instance = @terminated = instance
        end

        super
      end
    end
  end
end
