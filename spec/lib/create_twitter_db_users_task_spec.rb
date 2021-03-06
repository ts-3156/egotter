require 'rails_helper'

RSpec.describe CreateTwitterDBUsersTask, type: :model do
  let(:uids) { [1, 2, 3, 4, 5] }
  let(:users) { uids.map { |id| {id: id, screen_name: "sn-#{id}"} } }
  let(:twitter) { double('twitter') }
  let(:client) { double('client', twitter: twitter) }
  let(:instance) { described_class.new(uids) }

  before do
    allow(Bot).to receive(:api_client).and_return(client)
  end

  describe '#start' do
    subject { instance.start }

    it do
      expect(instance).to receive(:fetch_users).with(client, uids).and_return(users)
      expect(instance).not_to receive(:import_suspended_users)
      expect(instance).to receive(:reject_fresh_users).with(users).and_return(users)
      expect(instance).to receive(:import_users).with(users)
      subject
    end

    context 'suspended uids found' do
      let(:users) { uids.slice(0, 2).map { |id| {id: id, screen_name: "sn-#{id}"} } }
      it do
        expect(instance).to receive(:fetch_users).with(client, uids).and_return(users)
        expect(instance).to receive(:import_suspended_users).with(uids.slice(2, 3))
        expect(instance).to receive(:reject_fresh_users).with(users).and_return(users)
        expect(instance).to receive(:import_users).with(users)
        subject
      end
    end

    context ':force is true' do
      let(:instance) { described_class.new(uids, force: true) }
      it do
        expect(instance).to receive(:fetch_users).with(client, uids).and_return(users)
        expect(instance).not_to receive(:import_suspended_users)
        expect(instance).not_to receive(:reject_fresh_users)
        expect(instance).to receive(:import_users).with(users)
        subject
      end
    end
  end

  describe '#fetch_users' do
    subject { instance.send(:fetch_users, client, uids) }
    it do
      expect(twitter).to receive(:users).with(uids).and_return(users)
      subject
    end
  end

  describe '#import_users' do
    subject { instance.send(:import_users, users) }
    it do
      expect(TwitterDB::User).to receive(:import_by!).with(users: users)
      subject
    end
  end

  describe '#import_suspended_users' do
    let(:users) { uids.map { |id| Hashie::Mash.new(id: id, screen_name: 'suspended', description: '') } }
    subject { instance.send(:import_suspended_users, uids) }
    it do
      expect(TwitterDB::User).to receive(:import_by!).with(users: users)
      subject
    end
  end

  describe '#reject_fresh_users' do
    subject { instance.send(:reject_fresh_users, users) }
    it { expect(subject.map { |u| u[:id] }).to eq(users.map { |u| u[:id] }) }

    context 'a user is already persisted' do
      before { create(:twitter_db_user, uid: users[0][:id]) }
      it { expect(subject.map { |u| u[:id] }).to eq(users[1..-1].map { |u| u[:id] }) }
    end
  end

  describe '#reject_persisted_users' do
    # TODO
  end
end
