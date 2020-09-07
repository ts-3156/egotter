require 'rails_helper'

RSpec.describe Concerns::TwitterDB::User::Associations do
  describe '.where_and_order_by_field' do
    let(:uids) { [1, 2, 3] + (1..1200).to_a } # Including duplicate values
    subject { TwitterDB::User.where_and_order_by_field(uids: uids) }

    it do
      expect(TwitterDB::User).to receive(:where_and_order_by_field_each_slice).with((1..1000).to_a, nil, anything).and_return(['result1'])
      expect(TwitterDB::User).to receive(:where_and_order_by_field_each_slice).with((1001..1200).to_a, nil, anything).and_return(['result2'])
      is_expected.to eq(['result1', 'result2'])
    end
  end

  describe '.where_and_order_by_field_each_slice' do
    let(:users) { 3.times.map { create(:twitter_db_user) }.shuffle }
    let(:uids) { users.map(&:uid) }
    subject { TwitterDB::User.send(:where_and_order_by_field_each_slice, uids, nil) }

    it do
      expect(TwitterDB::User).to receive_message_chain(:where, :order_by_field).
          with(uid: uids).with(uids).and_return(users)
      is_expected.to eq(users)
    end
  end

  describe '.order_by_field' do
    let(:users) { 3.times.map { create(:twitter_db_user) }.shuffle }
    subject { TwitterDB::User.order_by_field(users.map(&:uid)) }
    it { expect(subject).to satisfy { |result| result.map(&:uid) == users.map(&:uid) } }
  end

  describe '.enqueue_update_job' do
    let(:uids) { (1..120).to_a }
    let(:uids1) { CreateTwitterDBUserWorker.compress((1..100).to_a) }
    let(:uids2) { CreateTwitterDBUserWorker.compress((101..120).to_a) }
    subject { TwitterDB::User.send(:enqueue_update_job, uids) }
    it do
      expect(CreateTwitterDBUserWorker).to receive(:perform_async).with(uids1, compressed: true, enqueued_by: an_instance_of(String))
      expect(CreateTwitterDBUserWorker).to receive(:perform_async).with(uids2, compressed: true, enqueued_by: an_instance_of(String))
      subject
    end
  end
end
