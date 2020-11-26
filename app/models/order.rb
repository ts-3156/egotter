# == Schema Information
#
# Table name: orders
#
#  id                      :bigint(8)        not null, primary key
#  ahoy_visit_id           :bigint(8)
#  user_id                 :integer          not null
#  email                   :string(191)
#  name                    :string(191)
#  price                   :integer
#  tax_rate                :decimal(4, 2)
#  trial_end               :integer
#  search_count            :integer          default(0), not null
#  follow_requests_count   :integer          default(0), not null
#  unfollow_requests_count :integer          default(0), not null
#  checkout_session_id     :string(191)
#  customer_id             :string(191)
#  subscription_id         :string(191)
#  canceled_at             :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
# Indexes
#
#  index_orders_on_user_id  (user_id)
#

class Order < ApplicationRecord
  belongs_to :user
  visitable :ahoy_visit

  validates :user_id, presence: true
  validates :name, presence: true
  validates :customer_id, presence: true
  validates :subscription_id, presence: true

  # TODO Other validations

  BASIC_PLAN_ID = ENV['STRIPE_BASIC_PLAN_ID']
  PRICE = 300
  TRIAL_DAYS = 14
  FREE_PLAN_USERS_LIMIT = 100
  BASIC_PLAN_USERS_LIMIT = 10000
  FREE_PLAN_BLOCKERS_LIMIT = 10
  BASIC_PLAN_BLOCKERS_LIMIT = 10000
  FREE_PLAN_TREND_TWEETS_LIMIT = 100
  BASIC_PLAN_TREND_TWEETS_LIMIT = 100000

  scope :unexpired, -> do
    where('customer_id is not null AND subscription_id is not null AND canceled_at is null')
  end

  class << self
    def create_by!(checkout_session:)
      create!(
          user_id: checkout_session.client_reference_id,
          email: checkout_session.customer_email,
          name: checkout_session.plan_name,
          price: checkout_session.plan_price,
          tax_rate: checkout_session.tax_rate,
          search_count: SearchCountLimitation::BASIC_PLAN,
          follow_requests_count: CreateFollowLimitation::BASIC_PLAN,
          unfollow_requests_count: CreateUnfollowLimitation::BASIC_PLAN,
          checkout_session_id: checkout_session.id,
          customer_id: checkout_session.customer_id,
          subscription_id: checkout_session.subscription_id
      )
    end
  end

  def save_stripe_attributes!
    if stripe_customer
      self.email = stripe_customer.email
    end

    if stripe_subscription
      self.name = stripe_subscription.name
      self.price = stripe_subscription.price

      if stripe_subscription.canceled_at
        self.canceled_at = stripe_subscription.canceled_at
      end

      if trial_end.nil?
        self.trial_end = stripe_subscription.trial_end
      end
    end

    if changed?
      save!
      SlackClient.orders.send_message("#{id} #{saved_changes.inspect}", title: '`Updated`')
      puts "Updated order_id=#{id} saved_changes=#{saved_changes.inspect}"
    end
  end

  def short_name
    if name.include?('（')
      name.split('（')[0]
    else
      name
    end
  end

  def stripe_customer
    @stripe_customer ||= (customer_id ? Customer.new(::Stripe::Customer.retrieve(customer_id)) : nil)
  end

  def stripe_subscription
    @stripe_subscription ||= (subscription_id ? Subscription.new(::Stripe::Subscription.retrieve(subscription_id)) : nil)
  end

  def stripe_checkout_session
    @stripe_checkout_session ||= (checkout_session_id ? Subscription.new(::Stripe::Checkout::Session.retrieve(checkout_session_id)) : nil)
  end

  def purchase_failed?
    customer_id.nil? || subscription_id.nil?
  end

  def trial_end_time
    Time.zone.at(trial_end)
  end

  def trial?
    Time.zone.now < trial_end_time
  end

  def sync_trial_end!
    update!(trial_end: stripe_subscription.trial_end)
  end

  def end_trial!
    ::Stripe::Subscription.update(subscription_id, trial_end: 'now')
    update!(trial_end: Time.zone.now.to_i)
  end

  def canceled?
    canceled_at.present?
  end

  def cancel!
    sub = ::Stripe::Subscription.delete(subscription_id)
    update!(canceled_at: Subscription.new(sub).canceled_at)
  end

  class Customer
    def initialize(customer)
      @customer = customer
    end

    def email
      @customer.email
    end

    def created_at
      Time.zone.at(@customer.created)
    end
  end

  class Subscription
    def initialize(subscription)
      @subscription = subscription
    end

    def name
      @subscription.items.data[0].plan.nickname
    end

    def price
      @subscription.items.data[0].plan.amount
    end

    def tax_rate
      @subscription.default_tax_rates[0].percentage / 100.0
    end

    def trial_end
      @subscription.trial_end
    end

    def trial?
      Time.zone.now < Time.zone.at(@subscription.trial_end)
    end

    def created_at
      Time.zone.at(@subscription.created)
    end

    def canceled_at
      @subscription.canceled_at ? Time.zone.at(@subscription.canceled_at) : nil
    end
  end

  class CheckoutSession
    def initialize(checkout_session)
      @checkout_session = checkout_session
    end

    def id
      @checkout_session.id
    end

    def client_reference_id
      @checkout_session.client_reference_id
    end

    def customer_id
      @checkout_session.customer
    end

    def subscription_id
      @checkout_session.subscription
    end

    def subscription
      @subscription ||= ::Stripe::Subscription.retrieve(subscription_id)
    end

    def customer_email
      @checkout_session.customer_email
    end

    def plan_name
      @checkout_session.display_items[0].plan.nickname
    end

    def plan_price
      @checkout_session.display_items[0].amount
    end

    def tax_rate
      subscription.default_tax_rates[0].percentage / 100.0
    end

    def created_at
      Time.zone.at(subscription.created)
    end

    def canceled_at
      subscription.canceled_at ? Time.zone.at(subscription.canceled_at) : nil
    end
  end
end
