require 'rails_helper'

RSpec.describe Egotter::Sidekiq::LockJob do
  context 'Server side job running' do
    class TestLockWorker
      include Sidekiq::Worker
      sidekiq_options queue: 'test', retry: 0, backtrace: false

      @@count = 0

      def lock_in
        3
      end

      def lock_count
        2
      end

      def perform(*args)
        @@count += 1
      end
    end

    before do
      Sidekiq::Testing.server_middleware do |chain|
        chain.add Egotter::Sidekiq::LockJob
      end

      Redis.client.flushdb
      TestLockWorker.clear
      TestLockWorker.class_variable_set(:@@count, 0)
    end

    specify 'Sidekiq server runs all jobs' do
      expect(TestLockWorker.jobs.size).to eq(0)

      TestLockWorker.perform_async(1)
      TestLockWorker.perform_async(1)
      TestLockWorker.perform_async(1)
      expect(TestLockWorker.jobs.size).to eq(3)

      TestLockWorker.drain
      expect(TestLockWorker.jobs.size).to eq(0)

      # Sidekiq server executes all queued jobs in a single thread
      expect(TestLockWorker.class_variable_get(:@@count)).to eq(3)
    end
  end
end

RSpec.describe Egotter::Sidekiq::LockHistory do
  class TestLockWorker
    def lock_in
      3
    end

    def lock_count
      2
    end
  end

  let(:history) { described_class.new(TestLockWorker.new) }

  before do
    Redis.client.flushdb
  end

  describe '#lock' do
    it do
      expect(history.size).to eq(0)

      history.lock
      expect(history.size).to eq(1)

      history.lock
      expect(history.size).to eq(2)
    end
  end

  describe '#unlock' do
    it do
      history.lock
      history.lock
      expect(history.size).to eq(2)

      history.unlock
      expect(history.size).to eq(1)

      history.unlock
      expect(history.size).to eq(0)
    end
  end

  describe '#locked?' do
    it do
      expect(history.locked?).to be_falsey

      history.lock
      expect(history.locked?).to be_falsey

      history.lock
      expect(history.locked?).to be_truthy

      travel TestLockWorker.new.lock_in

      expect(history.locked?).to be_falsey
    end
  end
end
