namespace :search_logs do
  desc 'Archive'
  task archive: :environment do
    year = ENV['YEAR']
    month = ENV['MONTH']
    raise 'Specify YEAR and MONTH' if year.blank? || month.blank?

    table_name = "search_logs_#{year}#{month}"
    ActiveRecord::Base.connection.execute("CREATE TABLE IF NOT EXISTS #{table_name} LIKE search_logs")
    ArchiveSearchLog = Class.new(ApplicationRecord) do; end.tap { |c| c.table_name = table_name }

    time = Time.zone.now.change(year: year, month: month)
    start_time = time.beginning_of_month.to_s(:db)
    end_time = time.end_of_month.to_s(:db)
    puts "start_time=#{start_time} end_time=#{end_time}"

    logs = SearchLog.where(created_at: start_time..end_time).where.not(device_type: %w(crawler UNKNOWN misc))
    logs_count = logs.select(:id).find_in_batches(batch_size: 100_000).lazy.map(&:size).sum
    puts "Archive #{logs_count} records to #{table_name}"

    ActiveRecord::Base.connection.execute("INSERT INTO #{table_name} #{logs.to_sql}")
    logs.select(:id).find_in_batches(batch_size: 100_000) do |group|
      SearchLog.where(id: group.map(&:id)).delete_all
    end
  end

  desc 'Delete'
  task delete: :environment do
    year = ENV['YEAR']
    month = ENV['MONTH']
    if year.blank? || month.blank?
      first_log = SearchLog.order(created_at: :asc).first
      year = first_log.year
      month = first_log.month
    end

    time = Time.zone.now.change(year: year, month: month)
    start_time = time.beginning_of_month.to_s(:db)
    end_time = time.end_of_month.to_s(:db)
    puts "start_time=#{start_time} end_time=#{end_time}"

    logs = SearchLog.where(created_at: start_time..end_time)
    logs_count = logs.select(:id).find_in_batches(batch_size: 100_000).lazy.map(&:size).sum
    puts "Delete #{logs_count} records from search_logs"

    if logs.any?
      logs.select(:id).find_in_batches(batch_size: 100_000) do |logs_array|
        SearchLog.where(id: logs_array.map(&:id)).delete_all
      end
    end
  end
end
