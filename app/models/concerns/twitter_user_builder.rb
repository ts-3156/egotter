require 'active_support/concern'

module TwitterUserBuilder
  extend ActiveSupport::Concern

  class_methods do
    def build_by(user:)
      new(
          uid: user[:id],
          screen_name: user[:screen_name],
          friends_count: user[:friends_count],
          followers_count: user[:followers_count],
          profile_text: filter_save_keys(user)
      )
    end

    private

    def filter_save_keys(user)
      user.symbolize_keys.slice(*TwitterUserProfile::SAVE_KEYS).to_json
    end
  end
end
