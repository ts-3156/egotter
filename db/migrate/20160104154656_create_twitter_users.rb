class CreateTwitterUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :twitter_users do |t|
      t.integer  :user_id,                  null: false, default: -1
      t.bigint   :uid,                      null: false
      t.string   :screen_name,              null: false
      t.integer  :friends_size,             null: false, default: -1
      t.integer  :followers_size,           null: false, default: -1
      t.integer  :friends_count,            null: false, default: -1
      t.integer  :followers_count,          null: false, default: -1
      t.integer  :statuses_interval,        null: true
      t.float    :follow_back_rate,         null: true
      t.float    :reverse_follow_back_rate, null: true
      t.integer  :new_friends_size,         null: true
      t.integer  :new_followers_size,       null: true
      t.integer  :unfriends_size,           null: true
      t.integer  :unfollowers_size,         null: true
      t.integer  :mutual_unfriends_size,    null: true
      t.integer  :one_sided_friends_size,   null: true
      t.integer  :one_sided_followers_size, null: true
      t.integer  :mutual_friends_size,      null: true
      t.integer  :inactive_friends_size,    null: true
      t.integer  :inactive_followers_size,  null: true
      t.bigint   :top_follower_uid,         null: true
      t.datetime :cache_created_at,         null: true
      t.datetime :assembled_at,             null: true

      t.timestamps null: false

      t.index :uid
      t.index :screen_name
      t.index :created_at
      t.index [:uid, :created_at]
    end
  end
end
