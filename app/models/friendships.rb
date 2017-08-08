class Friendships
  def self.import(from_id, friend_uids, follower_uids)
    friendships = friend_uids.map.with_index { |friend_uid, i| [from_id, friend_uid.to_i, i] }
    followerships = follower_uids.map.with_index { |follower_uid, i| [from_id, follower_uid.to_i, i] }

    Friendship.delete_all(from_id: from_id) if Friendship.exists?(from_id: from_id)
    Friendship.import(%i(from_id friend_uid sequence), friendships, validate: false, timestamps: false)

    Followership.delete_all(from_id: from_id) if Followership.exists?(from_id: from_id)
    Followership.import(%i(from_id follower_uid sequence), followerships, validate: false, timestamps: false)
  end
end
