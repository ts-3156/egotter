class CreateBackgroundForceUpdateLogs < ActiveRecord::Migration[4.2]
  def change
    create_table :background_force_update_logs do |t|
      t.string  :session_id,  null: false, default: ''
      t.integer :user_id,     null: false, default: -1
      t.string  :uid,         null: false, default: -1
      t.string  :screen_name, null: false, default: ''

      t.string  :action,      null: false, default: ''
      t.string  :bot_uid,     null: false, default: -1
      t.boolean :status,      null: false, default: false
      t.string  :reason,      null: false, default: ''
      t.text    :message,     null: false
      t.integer :call_count,  null: false, default: -1
      t.string  :via,         null: false, default: ''

      t.string  :device_type, null: false, default: ''
      t.string  :os,          null: false, default: ''
      t.string  :browser,     null: false, default: ''
      t.string  :user_agent,  null: false, default: ''
      t.string  :referer,     null: false, default: ''
      t.string  :referral,    null: false, default: ''
      t.string  :channel,     null: false, default: ''
      t.string  :medium,      null: false, default: ''

      t.datetime :created_at, null: false
    end
    add_index :background_force_update_logs, :user_id
    add_index :background_force_update_logs, :uid
    add_index :background_force_update_logs, :screen_name
    add_index :background_force_update_logs, :created_at
  end
end
