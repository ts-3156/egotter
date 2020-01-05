require "open3"

module Taskbooks
  module DeployTask
    def build(params)
      role = params['role']
      hosts = params['hosts'].split(',')

      if role == 'web'
        if hosts.size > 1
          EnumerableTask.new(hosts.map { |host| WebTask.new(host) })
        else
          WebTask.new(hosts[0])
        end
      elsif role == 'sidekiq'
        if hosts.size > 1
          EnumerableTask.new(hosts.map { |host| SidekiqTask.new(host) })
        else
          SidekiqTask.new(hosts[0])
        end
      else
        raise "Invalid role #{role}"
      end
    end

    module_function :build

    module DSL
      def backend(host, dir, cmd)
        execute(host, "cd #{dir} && #{cmd}")
      end

      private

      def execute(host, cmd)
        logger.info cyan(%Q(ssh #{host})) + ' ' + green(%Q("#{cmd}"))
        out, err, status = Open3.capture3(%Q(ssh #{host} "#{cmd}"))
        if status.exitstatus == 0
          logger.info out
          logger.info blue("true(success)")
        else
          logger.error red(err)
          logger.error red("false(exit)")
          exit
        end
      end

      def red(str)
        "\e[31m#{str}\e[0m"
      end

      def green(str)
        "\e[32m#{str}\e[0m"
      end

      def blue(str)
        "\e[34m#{str}\e[0m"
      end

      def cyan(str)
        "\e[36m#{str}\e[0m"
      end
    end

    class Task < ::DeployRuby::Task
      include DSL

      attr_reader :host

      def initialize(host)
        @host = host
      end

      def current_dir
        '/var/egotter'
      end

      def backend(cmd)
        super(@host, current_dir, cmd)
      end

      def ssh_connection_test
        backend('echo "ssh connection test"')
      end
    end

    class WebTask < Task
      def initialize(host)
        super

        @instance = ::DeployRuby::Aws::Instance.retrieve_by(name: host)
        @target_group = ::DeployRuby::Aws::TargetGroup.new(ENV['AWS_TARGET_GROUP'])
      end

      def before_run
        ssh_connection_test
        @target_group.deregister(@instance.id)
      end

      def run
        before_run

        [
            'git fetch origin',
            'git log --oneline master..origin/master',
            'git pull origin master',
            'bundle check || bundle install --path .bundle --without test development',
            'RAILS_ENV=production bundle exec rake assets:precompile',
            'sudo cp ./setup/etc/nginx/nginx.conf /etc/nginx/nginx.conf',
            'sudo cp ./setup/etc/init.d/puma /etc/init.d/',
            'sudo cp ./setup/etc/init.d/egotter /etc/init.d/',
            'sudo service nginx restart',
            'sudo service puma restart',
        ].each do |cmd|
          backend(cmd)
        end

        after_run
      end

      def after_run
        backend('ab -n 500 -c 10 http://localhost:80/')
        @target_group.register(@instance.id)
      end
    end

    class SidekiqTask < Task
      def before_run
        ssh_connection_test
      end

      def run
        before_run

        [
            'git fetch origin',
            'git log --oneline master..origin/master',
            'git pull origin master',
            'bundle check || bundle install --path .bundle --without test development',
            'sudo cp ./setup/etc/init/sidekiq* /etc/init/',
            'sudo cp ./setup/etc/init.d/egotter /etc/init.d/',
            'sudo restart sidekiq_misc || :',
            'sudo restart sidekiq_prompt_reports || :',
            'sudo restart sidekiq || :',
            'sudo restart sidekiq_import || :',
            'sudo restart sidekiq_follow || :',
            'sudo restart sidekiq_unfollow || :',
        ].each do |cmd|
          backend(cmd)
        end
      end
    end
  end
end
