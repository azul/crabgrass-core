module UserExtension
module Visibility

  LEVELS = [:friends, :peers, :users, :public]

  def visibility
    LEVELS[read_attribute(:visibility)
  end

  def visibility=(value)
    write_attribute :visibility, LEVELS.index(value)
  end

  def visibility?(value)
    read_attribute :visibility == LEVELS.index(value)
  end

  def visible_to?(user)
    visibility?(:public) ||
      visibility?(:users) && user.real? ||
      visibility?(:peers) && user.peer_of?(self) ||
      user.friend_of?(self)
  end

  def visible_to(user)
    if user.real?
      where '(users.id IN (?)) OR (users.visibility >= ? AND users.id IN (?)) OR (users.visibility >= ?)',
        user.friend_ids, LEVELS.index(:peers), user.peer_ids, LEVELS.index(:users)
    else
      where visibility: LEVELS.index(:public)
    end
  end
end
end
