# I want to print this class name to sidekiq.log.
class CreateAndroidRequestedPeriodicReportWorker < CreatePeriodicReportWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'report_high', retry: 0, backtrace: false
end
