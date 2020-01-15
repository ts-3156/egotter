module Taskbooks
  module ListTask
    def build(params)
      role = params['role']

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
      attr_reader :action

      def initialize
        @action = :list
      end
    end

    class WebTask < Task
      def initialize(params)
        @state = params['state'].to_s.empty? ? 'healthy' : params['state']
        @delim = params['delim'] || ' '

        target_group_arn = params['target-group'] || ENV['AWS_TARGET_GROUP']
        @target_group = ::DeployRuby::Aws::TargetGroup.new(target_group_arn)
      end

      def run
        puts @target_group.instances(state: @state).map(&:name).join(@delim)
      end
    end

    class SidekiqTask < Task
      def initialize(params)
        @delim = params['delim'] || ' '
      end

      def run
        instances =
            ::DeployRuby::Aws::EC2.retrieve_instances.map do |i|
              ::DeployRuby::Aws::Instance.new(i)
            end.select do |i|
              i.name.start_with?('egotter_sidekiq')
            end
        puts instances.map(&:name).join(@delim)
      end
    end
  end
end
