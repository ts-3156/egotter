namespace :visitor_engagement_stats do
  desc 'update'
  task update: :environment do |t|
    start_day = ENV['START'] ? Time.zone.parse(ENV['START']) : (Time.zone.now - 40.days)
    end_day = ENV['END'] ? Time.zone.parse(ENV['END']) : Time.zone.now
    stats = []
    diffs = (1..30).to_a
    columns = %i(total) + diffs.map { |n| "#{n}_days" } + diffs.map { |n| "before_#{n}_days" }
    task_start = Time.zone.now

    puts "\n#{t.name} started:"
    puts "  start: #{task_start}\n\n"

    (start_day.to_date..end_day.to_date).each do |day|
      session_ids = SearchLog.session_ids(created_at: day.to_time.all_day)

      stat = VisitorEngagementStat.find_or_initialize_by(date: day)
      stat.total = session_ids.size
      counts = session_ids.each_with_object(Hash.new(0)) { |id, memo| memo[id] += 1 }
      diffs.each do |diff|
        ids = SearchLog.session_ids(session_id: session_ids, created_at: (day - diff.day).to_time.all_day)
        ids.each { |id| counts[id] += 1 }
        stat["before_#{diff}_days"] = ids.size
      end

      diffs.each do |diff|
        stat["#{diff}_days"] = counts.select { |_, v| v == diff }.size
      end
      stats << stat if stat.changed?

      puts "#{day}: #{columns.map { |c| stat[c] }.join(', ')}"
    end

    if stats.any?
      VisitorEngagementStat.import(stats, on_duplicate_key_update: columns, validate: false)
    end

    puts "\n#{t.name} finished:"
    puts "  start: #{task_start}, finish: #{Time.zone.now}"
  end
end
