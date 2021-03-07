#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'dotenv/load'

SETTINGS = [
    [2, 1], # 09
    [2, 1], # 10
    [3, 1], # 11
    [3, 1], # 12
    [3, 1], # 13
    [2, 1], # 14
    [2, 1], # 15
    [2, 1], # 16
    [2, 1], # 17
    [2, 1], # 18
    [2, 1], # 19
    [3, 1], # 20
    [3, 1], # 21
    [3, 1], # 22
    [2, 1], # 23
    [2, 1], # 00
    [2, 1], # 01
    [2, 1], # 02
    [1, 0], # 03
    [1, 0], # 04
    [1, 0], # 05
    [2, 1], # 06
    [3, 1], # 07
    [3, 1], # 08
]

def now
  Time.now.utc
end

# TODO Run the below task in Ruby

def adjust_server(role, instance_type, num, dry_run)
  params = "--adjust --role #{role} --instance-type #{instance_type} --count #{num} --without-tag"
  cmd = "cd /var/egotter && /usr/local/bin/bundle exec bin/deploy.rb #{params}"
  dry_run ? (puts cmd) : system(cmd)
  params
end

def list_server(role)
  cmd = "cd /var/egotter && /usr/local/bin/bundle exec bin/deploy.rb --list --role #{role}"
  `#{cmd}`.chomp
end

# TODO Set suitable instance_type
def adjust_web(dry_run)
  prev = list_server('web')
  count = SETTINGS[now.hour][0]
  count += 1 if active_users > 300
  count += 1 if active_users > 400
  instance_type = count >= 3 ? 't3.large' : 't3.medium'
  adjust_server('web', instance_type, count, dry_run)
  cur = list_server('web')
  post("prev=#{prev} cur=#{cur}") if prev != cur
end

def adjust_sidekiq(dry_run)
  prev = list_server('sidekiq')
  count = SETTINGS[now.hour][1]
  count += 1 if remaining_creation_jobs > 1000
  count += 1 if remaining_creation_jobs > 10000
  adjust_server('sidekiq', 'm5.large', count, dry_run)
  cur = list_server('sidekiq')
  post("prev=#{prev} cur=#{cur}") if prev != cur
end

def post(text)
  uri = URI.parse(ENV['SLACK_DEPLOY_URL'])
  Net::HTTP.post_form(uri, payload: {text: text}.to_json).body
end

def active_users
  unless @active_users
    uri = URI.parse('https://egotter.com/api/v1/access_stats?key=' + ENV['STATS_API_KEY'])
    @active_users = JSON.parse(Net::HTTP.get(uri))['active_users']
  end
  @active_users
rescue => e
  0
end

def remaining_creation_jobs
  unless @remaining_creation_jobs
    uri = URI.parse('https://egotter.com/api/v1/report_stats?key=' + ENV['REPORT_STATS_KEY'])
    JSON.parse(Net::HTTP.get(uri))['CreateReportTwitterUserWorker']
  end
  @remaining_creation_jobs
rescue => e
  0
end

def main
  dry_run = ENV['DRY_RUN'] == 'true'

  case ENV['ROLE']
  when 'web'
    adjust_web(dry_run)
  when 'sidekiq'
    adjust_sidekiq(dry_run)
  else
    raise "Invalid role value=#{ENV['ROLE']}"
  end
end

if __FILE__ == $0
  begin
    main
  rescue => e
    post("adjust_servers: #{e.inspect}")
  end
end
