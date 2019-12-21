module Egotter
  module Server
    module Installer
      module Util
        def green(str)
          puts "\e[32m#{str}\e[0m"
        end

        def red(str)
          puts "\e[31m#{str}\e[0m"
        end

        def test_ssh_connection(host)
          cmd = "ssh -q #{host} exit"
          green(cmd)
          30.times do |n|
            puts "waiting for test_ssh_connection #{host}"
            if system(cmd, exception: false)
              break
            else
              sleep 5
            end
            raise if n == 29
          end

          self
        end

        def append_to_ssh_config(id, host, public_ip)
          text = to_ssh_config(id, host, public_ip)
          puts text
          File.open('./ssh_config', 'a') { |f| f.puts(text) }

          self
        end

        def to_ssh_config(id, host, public_ip)
          <<~"TEXT"
            # #{id}
            Host #{host}
              HostName        #{public_ip}
              IdentityFile    ~/.ssh/egotter.pem
              User            ec2-user
          TEXT
        end

        def install_td_agent(host, src)
          [
              'test -f "/usr/sbin/td-agent" || curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent2.sh | sh',
              '/usr/sbin/td-agent-gem list | egrep "fluent-plugin-slack" >/dev/null 2>&1 || sudo /usr/sbin/td-agent-gem install fluent-plugin-slack',
              '/usr/sbin/td-agent-gem list | egrep "fluent-plugin-rewrite-tag-filter.+2\.2\.0" >/dev/null 2>&1 || sudo /usr/sbin/td-agent-gem install fluent-plugin-rewrite-tag-filter -v "2.2.0"',
          ].each { |cmd| exec_command(host, cmd) }

          conf = ERB.new(File.read(src)).result_with_hash(
              name: host,
              webhook_rails: ENV['SLACK_TD_AGENT_RAILS'],
              webhook_puma: ENV['SLACK_TD_AGENT_PUMA'],
              webhook_sidekiq: ENV['SLACK_TD_AGENT_SIDEKIQ'],
              webhook_sidekiq_import: ENV['SLACK_TD_AGENT_SIDEKIQ_IMPORT'],
              webhook_sidekiq_misc: ENV['SLACK_TD_AGENT_SIDEKIQ_MISC'],
              webhook_sidekiq_prompt_reports: ENV['SLACK_TD_AGENT_SIDEKIQ_PROMPT_REPORTS'],
              webhook_syslog: ENV['SLACK_TD_AGENT_SYSLOG'],
              webhook_error_log: ENV['SLACK_TD_AGENT_ERROR_LOG'],
          )

          upload_contents(host, conf, '/etc/td-agent/td-agent.conf')
        end

        def upload_file(host, src_path, dst_path)
          tmp_file = "#{File.basename(dst_path)}.#{Process.pid}.tmp"
          tmp_path = File.join('/var/egotter', tmp_file)

          system("rsync -auz #{src_path} #{host}:#{tmp_path}")

          if exec_command(host, "colordiff -u #{dst_path} #{tmp_path}", exception: false)
            exec_command(host, "rm #{tmp_path}")
          else
            puts dst_path
            exec_command(host, "sudo mv #{tmp_path} #{dst_path}")
          end

          self
        end

        def upload_contents(host, contents, dst_path)
          tmp_file = "upload_contents.#{Time.now.to_f}.#{Process.pid}.tmp"
          tmp_path = File.join(Dir.tmpdir, tmp_file)
          IO.binwrite(tmp_path, contents)
          upload_file(host, tmp_path, dst_path)
        ensure
          File.delete(tmp_path) if File.exists?(tmp_path)
        end

        def upload_env(host, src)
          contents = ::SecretFile.read(src)

          if contents.match?(/AWS_NAME_TAG="NONAME"/)
            contents.gsub!(/AWS_NAME_TAG="NONAME"/, "AWS_NAME_TAG=\"#{host}\"")
          end

          upload_contents(host, contents, '/var/egotter/.env')
        end

        def exec_command(host, cmd, dir: '/var/egotter', exception: true)
          raise 'Hostname is empty.' if host.to_s.empty?
          green("#{host} #{cmd}")
          system('ssh', host, "cd #{dir} && #{cmd}", exception: exception).tap { |r| puts r }
        end
      end
    end
  end
end