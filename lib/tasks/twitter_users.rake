namespace :twitter_users do
  desc 'add user_info_gzip'
  task add_user_info_gzip: :environment do
    ActiveRecord::Base.connection.execute('ALTER TABLE twitter_users ADD user_info_gzip BLOB NOT NULL AFTER user_info')
  end

  desc 'compress user_info'
  task compress_user_info: :environment do
    TwitterUser.find_each(batch_size: 100) do |tu|
      gzip = ActiveSupport::Gzip.compress(tu.user_info)
      tu.user_info_gzip = gzip
      tu.save!
    end
  end
end