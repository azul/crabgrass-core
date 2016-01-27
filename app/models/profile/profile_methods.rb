=begin

  a mix-in for Group and User associations with Profiles.
  TODO: filter on language too

=end

module ProfileMethods

  # returns the best profile for user to see
  def visible_by(user)
    if user
      owner = proxy_association.owner
      relationships = owner.relationships_to(user)

      # site relationship settings are for user <=> user relationships only
      filter_relationships_for_site(relationships) unless owner.is_a? Group

      profile = find_by_access(*relationships)
    else
      profile = find_by_access :stranger
    end
    profile || build
  end

  # returns the first profile that matches one of the access symbols in *arg
  # in this order of precedence: foe, friend, peer, fof, stranger.
  def find_by_access(*args)
    return find_by_no_access if args.empty?

    args.map!{|i| if i==:member; :friend; else; i; end}

    conditions = args.collect{|access| "profiles.`#{access}` = ?"}.join(' OR ')
    where([conditions] + ([true] * args.size)).
      order('foe DESC, friend DESC, peer DESC, fof DESC, stranger DESC').
      first
  end

  def find_by_no_access
    fields = [:foe, :friend, :peer, :fof, :stranger]
    conditions = fields.collect{|access| "profiles.`#{access}` = ?"}.join(' AND ')
    where([conditions] + ([false] * fields.size)).first
  end

  # a shortcut to grab the 'public' profile
  def public
    profile_options = {stranger: true}

    @public_profile ||= (find_by_access(:stranger) || create_or_build(profile_options))
  end

  # a shortcut to grab the 'private' profile
  def private
    @private_profile ||= (find_by_access(:friend) || create_or_build(friend: true))
  end

  def hidden
    @hidden_profile ||= (find_by_access || create_or_build)
  end

  def create_or_build(args={})
    if proxy_association.owner.new_record?
      build(args)
    else
      create(args)
    end
  end

  protected

  def filter_relationships_for_site(relationships)
    # filter possible profiles on current_site
    if site = Site.current
      relationships.delete(:stranger) unless site.profile_enabled? 'public'
      relationships.delete(:friend) unless site.profile_enabled? 'private'
    end
  end
end

