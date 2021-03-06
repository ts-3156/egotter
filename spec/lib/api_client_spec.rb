require 'rails_helper'

RSpec.describe ApiClient, type: :model do
  let(:user) { create(:user) }
  let(:credential_token) { create(:credential_token, user_id: user.id) }
  let(:client) { double('client', access_token: credential_token.token, access_token_secret: credential_token.secret) }
  let(:instance) { ApiClient.new(client, user) }

  describe '#create_direct_message' do
    let(:request) { double('request') }
    subject { instance.create_direct_message(1, 'text') }

    it do
      expect(client).to receive_message_chain(:twitter, :create_direct_message_event).with(1, 'text')
      subject
    end

    context 'async is true' do
      subject { instance.create_direct_message(1, 'text', async: true) }

      before do
        allow(CreateDirectMessageRequest).to receive(:create).with(sender_id: user.uid, recipient_id: 1, properties: {message: 'text'}).and_return(request)
      end

      it do
        expect(request).to receive(:perform)
        subject
      end
    end
  end

  describe '#create_direct_message_event' do
    let(:response) { {message_create: {message_data: {text: 'text'}}} }
    subject { instance.create_direct_message_event(1, 'text') }
    before { allow(instance).to receive(:twitter).and_return(client) }

    it do
      expect(client).to receive(:create_direct_message_event).with(1, 'text').and_return(response)
      expect(DirectMessage).to receive(:new).with(event: response).and_return('dm')
      is_expected.to eq('dm')
    end

    context 'an exception is raised' do
      before { allow(client).to receive(:create_direct_message_event).and_raise('anything') }
      it do
        expect(CreateDirectMessageErrorLogWorker).to receive(:perform_async).with(any_args)
        expect(instance).to receive(:update_blocker_status).with(any_args)
        expect { subject }.to raise_error('anything')
      end
    end
  end

  describe '#method_missing' do
    subject { instance.send(:method_missing, :user, 1) }

    context 'client responds to specified method' do
      before { allow(client).to receive(:respond_to?).with(:user).and_return(true) }
      it do
        expect(client).to receive(:user).with(1).and_return('user')
        is_expected.to eq('user')
      end
    end

    context "client doesn't respond to specified method" do
      before { allow(client).to receive(:respond_to?).with(:user).and_return(false) }
      it do
        expect(client).not_to receive(:user)
        expect { subject }.to raise_error(NameError) # Or NoMethodError
      end
    end

    context 'exception is raised' do
      let(:error) { NameError.new }
      before { allow(client).to receive(:respond_to?).with(:user).and_raise(error) }
      it do
        expect(instance).to receive(:update_authorization_status).with(error)
        expect(instance).to receive(:update_lock_status).with(error)
        expect(instance).to receive(:create_not_found_user).with(error, :user, 1)
        expect(instance).to receive(:create_forbidden_user).with(error, :user, 1)
        expect { subject }.to raise_error(error) # Or NoMethodError
      end
    end
  end

  describe '#update_blocker_status' do
    let(:error) { RuntimeError.new('error') }
    subject { instance.update_blocker_status(error) }

    context 'token is invalid' do
      let(:user) { create(:user) }
      before do
        allow(DirectMessageStatus).to receive(:you_have_blocked?).with(error).and_return(true)
        allow(User).to receive(:find_by_token).with(client.access_token, client.access_token_secret).and_return(user)
      end
      it do
        expect(CreateEgotterBlockerWorker).to receive(:perform_async).with(user.uid)
        expect(CreateViolationEventWorker).to receive(:perform_async).with(user.id, 'Blocking egotter')
        subject
      end
    end
  end

  describe '#update_authorization_status' do
    let(:error) { RuntimeError.new('error') }
    subject { instance.update_authorization_status(error) }

    context 'token is invalid' do
      let(:user) { create(:user) }
      before do
        allow(TwitterApiStatus).to receive(:unauthorized?).with(error).and_return(true)
        allow(User).to receive(:find_by_token).with(client.access_token, client.access_token_secret).and_return(user)
      end
      it do
        expect(UpdateAuthorizedWorker).to receive(:perform_async).with(user.id)
        subject
      end
    end
  end

  describe '#update_lock_status' do
    let(:error) { RuntimeError.new('error') }
    subject { instance.update_lock_status(error) }

    context 'user is locked' do
      let(:user) { create(:user) }
      before do
        allow(TwitterApiStatus).to receive(:temporarily_locked?).with(error).and_return(true)
        allow(User).to receive(:find_by_token).with(client.access_token, client.access_token_secret).and_return(user)
      end
      it do
        expect(UpdateLockedWorker).to receive(:perform_async).with(user.id)
        subject
      end
    end
  end

  describe '#create_not_found_user' do
    let(:error) { Twitter::Error::NotFound.new('User not found.') }
    subject { instance.create_not_found_user(error, :user, 'name') }
    it do
      expect(CreateNotFoundUserWorker).to receive(:perform_async).with('name', anything)
      subject
    end
  end

  describe '#create_forbidden_user' do
    let(:error) { Twitter::Error::Forbidden.new('User has been suspended.') }
    subject { instance.create_forbidden_user(error, :user, 'name') }
    it do
      expect(CreateForbiddenUserWorker).to receive(:perform_async).with('name', anything)
      subject
    end
  end

  describe '.config' do
    let(:option) do
      {
          consumer_key: 'ck',
          consumer_secret: 'cs',
          access_token: 'at',
          access_token_secret: 'ats',
      }
    end

    context 'without option' do
      let(:config) { ApiClient.config }

      it 'returns Hash' do
        expect(config).to be_a_kind_of(Hash)
        option.each_key do |key|
          expect(config.has_key?(key)).to be_truthy
        end
      end
    end

    context 'with option' do
      let(:config) { ApiClient.config(option) }

      it 'overrides config' do
        option.each_key do |key|
          expect(option[key]).to eq(config[key])
        end
      end
    end
  end

  describe '.instance' do
    subject { described_class.instance }

    it 'returns ApiClient' do
      is_expected.to be_a_kind_of(ApiClient)
    end

    context 'With empty options' do
      it do
        expect(TwitterWithAutoPagination::Client).to receive(:new)
        subject
      end
    end
  end
end

RSpec.describe ApiClient::TwitterWrapper, type: :model do
  let(:api_client) { double('api_client') }
  let(:twitter) { double('twitter') }
  let(:instance) { described_class.new(api_client, twitter) }

  describe '#method_missing' do
    subject { instance.send(:method_missing, :user, 1) }
    before { allow(twitter).to receive(:respond_to?).with(:user).and_return(true) }

    it do
      expect(twitter).to receive(:user).with(1)
      subject
    end

    context 'exception is raised' do
      before { allow(twitter).to receive(:user).with(1).and_raise('error') }
      it do
        expect(api_client).to receive(:update_authorization_status).with(anything)
        expect(api_client).to receive(:update_lock_status).with(anything)
        expect { subject }.to raise_error('error')
      end
    end
  end
end

RSpec.describe ApiClient::RequestWithRetryHandler, type: :model do
  let(:instance) { described_class.new(:method_name) }

  describe '#perform' do
    let(:block) { Proc.new { 'block_result' } }
    subject { instance.perform(&block) }

    it { is_expected.to eq('block_result') }

    context 'exception is raised' do
      let(:error) { RuntimeError.new('error') }
      let(:block) { Proc.new { raise error } }

      it { expect { subject }.to raise_error(error) }

      context 'the exception is not retryable' do
        it do
          expect(instance).to receive(:handle_retryable_error).with(error).and_call_original
          expect { subject }.to raise_error(error)
        end
      end

      context 'the exception is retryable' do
        let(:retry_count) { described_class::MAX_RETRIES + 1 }
        before { allow(ServiceStatus).to receive(:retryable_error?).with(error).and_return(true) }
        it do
          expect(instance).to receive(:handle_retryable_error).with(error).exactly(retry_count).times.and_call_original
          expect { subject }.to raise_error(ApiClient::RetryExhausted)
          expect(instance.instance_variable_get(:@retries)).to eq(retry_count)
        end
      end
    end
  end

  describe '#handle_retryable_error' do
    let(:error) { RuntimeError.new('error') }
    subject { instance.send(:handle_retryable_error, error) }

    context 'exception is retryable' do
      before { allow(ServiceStatus).to receive(:retryable_error?).with(error).and_return(true) }
      it { expect { subject }.not_to raise_error }
    end

    context 'exception is not retryable' do
      it { expect { subject }.to raise_error(error) }
    end
  end
end
