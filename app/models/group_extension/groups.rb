#
# Module that extends Group behavior.
#
# Handles all the group <> group relationships
#
module GroupExtension::Groups

  def self.included(base)
    base.extend ClassMethods
    base.send :include, InstanceMethods

    base.instance_eval do

      has_many :federatings, dependent: :destroy
      has_many :networks, through: :federatings
      has_one :council, class_name: 'Council', foreign_key: 'parent_id',
        dependent: :destroy

      has_many :committees, foreign_key: 'parent_id', dependent: :destroy do
        def add!(*args)
          committee = self.create! *args
          proxy_association.owner.org_structure_changed
          proxy_association.owner.save!
          # no idea why this is needed:
          proxy_association.reset
          committee
        end

        def remove!(committee)
          self.delete(committee)
          proxy_association.owner.org_structure_changed
          proxy_association.owner.save!
          proxy_association.reset
        end

      end
      # Committees are children! They must respect their parent group.
      alias_method :children, :committees

      has_many :real_committees,
        foreign_key: 'parent_id',
        class_name: 'Committee',
        conditions: {type: 'Committee'} do
        # UPGRADE: This is a workaround for the lack of declaring a
        # query DISTINCT and having that applied to the final query.
        # it won't be needed anymore as soon as .distinct can be used
        # with rails 4.0
        def with_access(access)
          super(access).only_select("DISTINCT groups.*")
        end
      end

    end
  end

  ##
  ## CLASS METHODS
  ##

  module ClassMethods
    def pagination_letters_for(groups)
      pagination_letters = []
      groups.each do |g|
        pagination_letters << g.full_name.first.upcase if g.full_name
        pagination_letters << g.name.first.upcase if g.name
      end

      return pagination_letters.uniq!
    end

    # Returns a list of group ids for the page namespace of every group id
    # passed in. wtf does this mean? for each group id, we get the ids
    # of all its relatives (parents, children, siblings).
    def namespace_ids(ids)
      ids = [ids] unless ids.is_a? Array
      return [] unless ids.any?
      parentids = parent_ids(ids)
      return (ids + parentids + committee_ids(ids+parentids)).flatten.uniq
    end

    # returns an array of committee ids given an array of group ids.
    def committee_ids(ids)
      ids = [ids] unless ids.instance_of? Array
      return [] unless ids.any?
      ids = ids.join(',')
      Group.connection.select_values(
        "SELECT groups.id FROM groups WHERE parent_id IN (#{ids})"
      ).collect{|id|id.to_i}
    end

    def parent_ids(ids)
      ids = [ids] unless ids.instance_of? Array
      return [] unless ids.any?
      ids = ids.join(',')
      Group.connection.select_values(
        "SELECT groups.parent_id FROM groups WHERE groups.id IN (#{ids})"
      ).collect{|id|id.to_i}
    end

    def can_have_committees?
      Conf.committees
    end

    def can_have_council?
      Conf.councils && self.can_have_committees?
    end


  end

  ##
  ## INSTANCE METHODS
  ##

  module InstanceMethods

    def add_council!(attributes = {})
      # creating a new council for a new group
      # the council members will be able to remove other members
      if self.memberships.count < 2
        attributes[:full_council_powers] = true
      end

      new_council = create_council! attributes
      self.org_structure_changed
      # let's remove this redundant column at some point
      self.council_id = new_council.id
      self.save!
      new_council
    end

    # returns an array of all children ids and self id (but not parents).
    # this is used to determine if a group has access to a page.
    def group_and_committee_ids
      @group_ids ||= ([self.id] + Group.committee_ids(self.id))
    end

    # returns an array of committees visible to the given user
    def committees_for(user)
      self.real_committees.with_access(user => :view)
    end

    # whenever the structure of this group has changed
    # (ie a committee or network has been added or removed)
    # this function should be called. Afterward, a save is required.
    def org_structure_changed(child=nil)
      User.clear_membership_cache(user_ids)
      self.version += 1
    end

    # overridden for Networks
    def groups() [] end

    def member_of?(network)
      network_ids.include?(network.id)
    end

    def has_a_council?
      self.council != nil
    end

  end

end
