require 'rails_helper'

RSpec.describe DeleteTweetsRequest, type: :model do
  let(:user) { create(:user, authorized: true) }
  let(:request) { DeleteTweetsRequest.create(user: user) }

  describe '#finished!' do
    subject { request.finished! }
    it do
      freeze_time do
        expect(request).to receive(:update!).with(finished_at: Time.zone.now)
        expect(request).not_to receive(:tweet_finished_message)
        expect(request).not_to receive(:send_finished_message)
        subject
      end
    end
  end

  describe '#perform!' do
    let(:tweets) { 'tweets' }
    let(:subject) { request.perform! }

    it do
      expect(request).to receive(:verify_credentials!)
      expect(request).to receive(:tweets_exist!)
      expect(request).to receive(:fetch_statuses!).and_return(tweets)
      expect(request).to receive(:filter_statuses!).with(tweets).and_return(tweets)
      expect(request).to receive(:filtered_tweets_exist!).with(tweets)
      expect(request).to receive(:destroy_statuses!).with(tweets)
      subject
    end
  end

  describe '#verify_credentials!' do
    let(:subject) { request.verify_credentials! }
    before { request.instance_variable_set(:@retries, 1) }

    context 'user is authorized' do
      before { user.update(authorized: true) }
      it do
        expect(request).to receive_message_chain(:api_client, :verify_credentials)
        subject
      end
    end

    context 'user is not authorized' do
      before { user.update(authorized: false) }
      it { expect { subject }.to raise_error(described_class::Unauthorized) }
    end

    context 'Twitter::Error::TooManyRequests is raised' do
      before { allow(request).to receive_message_chain(:api_client, :verify_credentials).and_raise(Twitter::Error::TooManyRequests) }
      it do
        expect(request).not_to receive(:exception_handler)
        subject
      end
    end

    context 'exception is raised' do
      let(:error) { RuntimeError.new('error') }
      before { allow(request).to receive_message_chain(:api_client, :verify_credentials).and_raise(error) }
      it do
        expect(request).to receive(:exception_handler).with(error, :verify_credentials!)
        subject
      end
    end
  end

  describe '#tweets_exist!' do
    let(:user_response) { double('user_response', statuses_count: count) }
    let(:subject) { request.tweets_exist! }
    before { request.instance_variable_set(:@retries, 1) }

    before { allow(request).to receive_message_chain(:api_client, :user).with(user.uid).and_return(user_response) }

    context 'statuses_count is 0' do
      let(:count) { 0 }
      it { expect { subject }.to raise_error(described_class::TweetsNotFound) }
    end

    context 'statuses_count is not 0' do
      let(:count) { 100 }
      it { expect { subject }.not_to raise_error }
    end

    context 'exception is raised' do
      let(:count) { -1 }
      let(:error) { RuntimeError.new('error') }
      before { allow(request).to receive_message_chain(:api_client, :user).and_raise(error) }
      it do
        expect(request).to receive(:exception_handler).with(error, :tweets_exist!)
        subject
      end
    end
  end

  describe '#fetch_statuses!' do
    let(:tweets) do
      [
          double('tweet', id: 200, created_at: 1.day.ago),
          double('tweet', id: 100, created_at: 1.day.ago)
      ]
    end
    subject { request.fetch_statuses! }

    before do
      allow(request).to receive_message_chain(:api_client, :user_timeline).
          with(count: 200).and_return(tweets)
      allow(request).to receive_message_chain(:api_client, :user_timeline).
          with(count: 200, max_id:  99).and_return([])
    end

    it { is_expected.to match_array(tweets) }

    context 'tweets is empty' do
      let(:tweets) { [] }
      it do
        expect { subject }.to raise_error(described_class::TweetsNotFound)
      end
    end
  end

  describe '#filter_statuses!' do
    let(:tweets) do
      [
          double('tweet1', id: 200, created_at: Time.zone.parse('2021-04-10')),
          double('tweet2', id: 100, created_at: Time.zone.parse('2021-04-01'))
      ]
    end
    subject { request.filter_statuses!(tweets) }

    it { is_expected.to match_array(tweets) }

    context ':since_date is specified' do
      before { request.update!(since_date: Time.zone.parse('2021-04-05')) }
      it { is_expected.to match_array([tweets[0]]) }
    end

    context ':until_date is specified' do
      before { request.update!(until_date: Time.zone.parse('2021-04-05')) }
      it { is_expected.to match_array([tweets[1]]) }
    end
  end

  describe '#destroy_statuses!' do
    let(:tweets) do
      [double('tweet', id: 1), double('tweet', id: 2)]
    end
    subject { request.destroy_statuses!(tweets) }

    it do
      tweets.each do |tweet|
        expect(DeleteTweetWorker).to receive(:perform_async).with(user.id, tweet.id, request_id: request.id, last_tweet: tweet == tweets.last)
      end
      subject
    end
  end

  describe '#exception_handler' do
    subject { request.exception_handler(exception, :last_method) }

    context 'exception is a kind of Error' do
      let(:exception) { described_class::InvalidToken.new }
      it { expect { subject }.to raise_error(exception) }
    end

    context 'exception is Twitter::Error::TooManyRequests' do
      let(:exception) { Twitter::Error::TooManyRequests.new }
      it { expect { subject }.to raise_error(described_class::TooManyRequests) }
    end
  end
end
