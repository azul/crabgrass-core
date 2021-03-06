=begin

A person or group profile

Every person or group can have many profiles, each with different permissions
and for different languages. A given user will only see one of these profiles,
the one that matches their language and relationship to the user/group.

Order of profile presidence (user sees the first one that matches):
 (1) foe
 (2) friend   } the 'private' profile
 (3) peer     \  might see 'private' profile
 (4) fof      /  or might be see 'public' profile
 (5) stranger } the 'public' profile
  create_table "profiles", :force => true do |t|
    t.integer  "entity_id",              :limit => 11
    t.string   "entity_type"
    t.boolean  "stranger",                             :default => false, :null => false
    t.boolean  "peer",                                 :default => false, :null => false
    t.boolean  "friend",                               :default => false, :null => false
    t.boolean  "foe",                                  :default => false, :null => false
    t.string   "name_prefix"
    t.string   "first_name"
    t.string   "middle_name"
    t.string   "last_name"
    t.string   "name_suffix"
    t.string   "nickname"
    t.string   "role"
    t.string   "organization"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "birthday",               :limit => 8
    t.boolean  "fof",                                  :default => false, :null => false
    t.text     "summary"
    t.integer  "wiki_id",                :limit => 11
    t.integer  "photo_id",               :limit => 11
    t.integer  "layout_id",              :limit => 11
    t.integer  "membership_policy",      :limit => 11, :default => 0
    t.string   "language",               :limit => 5
    t.integer  "discussion_id",          :limit => 11
    t.string   "place"
    t.integer  "video_id",               :limit => 11
    t.text     "summary_html",
    t.integer  "geo_location_id"
  end

Currently unused: language.

=end

class Profile < ActiveRecord::Base

  belongs_to :language

  ##
  ## RELATIONSHIPS TO USERS AND GROUPS
  ##

  belongs_to :entity, polymorphic: true
  def user; entity; end
  def group; entity; end

  before_create :fix_polymorphic_single_table_inheritance
  def fix_polymorphic_single_table_inheritance
    self.entity_type = 'User' if self.entity_type =~ /User/
    self.entity_type = 'Group' if self.entity_type =~ /Group/
  end


  ##
  ## CONSTANTS
  ##

  # approval - user requests to join, group members approce (the default)
  # open - anyone can join the group
  MEMBERSHIP_POLICY = {approval: 0, open: 1}.freeze

  ##
  ## BASIC ATTRIBUTES
  ##

  format_attribute :summary

  def full_name
    [name_prefix, first_name, middle_name, last_name, name_suffix].reject(&:blank?) * ' '
  end
  alias_method :name,  :full_name

  def public?
    stranger?
  end

  def private?
    friend?
  end

  def hidden?
    # a profile is hidden if no relationship fields are set
    !(friend? || stranger? || fof? || foe? || peer?)
  end

  def type
    return 'public' if stranger?
    return 'private' if friend?
    return 'unknown'
  end

  def membership_policy_is? name
    self.membership_policy == MEMBERSHIP_POLICY[name.to_sym]
  end

  ##
  ## ASSOCIATED ATTRIBUTES
  ##

  belongs_to :wiki, dependent: :destroy
  belongs_to :wall,
   class_name: 'Discussion',
   foreign_key: 'discussion_id',
   dependent: :destroy

  # belongs_to :photo, :class_name => "Asset", :dependent => :destroy
  belongs_to :picture, dependent: :destroy
  belongs_to :video, class_name: "ExternalVideo", dependent: :destroy

  has_many :locations,
    class_name: '::ProfileLocation',
    dependent: :destroy

  has_many :email_addresses,
    class_name: '::ProfileEmailAddress',
    dependent: :destroy

  has_many :im_addresses,
    class_name: '::ProfileImAddress',
    dependent: :destroy

  has_many :phone_numbers,
    class_name: '::ProfilePhoneNumber',
    dependent: :destroy

  has_many :websites,
    class_name: '::ProfileWebsite',
    dependent: :destroy

  has_many :notes,
    class_name: '::ProfileNote',
    dependent: :destroy

  #has_many :crypt_keys,
  #  :class_name => '::ProfileCryptKey',
  #  :dependent => :destroy, :order => "preferred desc"

  belongs_to :geo_location

  # UNTESTED!
  #
  # you can be as specific as needed. From just the country down to
  # specifying the city id.
  def self.in_location(options)
    location_conditions = {
      country_id: options[:country_id],
      geo_admin_code_id: options[:state_id],
      geo_place_id: options[:city_id]
    }.delete_if{|k,v| v.blank?}
    joins(:geo_location).where(geo_location: location_conditions)
  end

  # takes a huge params hash that includes sub hashes for dependent collections
  # and saves it all to the database.
  def save_from_params(profile_params)

    valid_params = ["first_name", "middle_name", "last_name", "role",
      "organization", "place", "membership_policy",
      "peer", "picture", "video", "summary", "admins_may_moderate",
      "country_id","state_id","city_id"]

    collections = {
      'phone_numbers'   => ::ProfilePhoneNumber,   'locations' => ::ProfileLocation,
      'email_addresses' => ::ProfileEmailAddress,  'websites'  => ::ProfileWebsite,
      'im_addresses'    => ::ProfileImAddress,     'notes'     => ::ProfileNote
      # 'crypt_keys'      => ::ProfileCryptKey
    }

    profile_params.stringify_keys!

    params = profile_params.delete_if {|k, v| !valid_params.include?(k) && !collections.keys.include?(k)}
    params['summary_html'] = nil if params['summary'] == ""

    # save nil if value is an empty string:
    params.each do |key,value|
      params[key] = value.presence
    end

    # build objects from params
    collections.each do |collection_name, collection_class|
      params[collection_name] = profile_params[collection_name].collect do |key,value|
        # puts "%s.new ( %s )" % [collection_class, value.inspect]
        collection_class.create( value.merge('profile_id' => self.id.to_i) )
      end || [] rescue []
    end

    picture_params = params.delete('picture')
    if picture_params && picture_params['upload']
      params['picture'] = Picture.new(picture_params)
    end
    params['video'] = ExternalVideo.new(params.delete('video')) if params['video']

    geo_location_options = {
      geo_country_id: params.delete('country_id'),
      geo_admin_code_id: params.delete('state_id'),
      geo_place_id: params.delete('city_id'),
    }
    # prevent making blank geo_location objects
    if Geo::Country.exists?(geo_location_options[:geo_country_id])
      if self.geo_location.nil?
        params['geo_location'] = Geo::Location.new(geo_location_options)
      else
        ### do not create new records.
        self.geo_location.update_attributes(geo_location_options)
      end
    elsif !self.geo_location.nil?
      self.geo_location.destroy
    end

    self.update_attributes( params )
    self.reload # huh? why is this needed?
    self
  rescue ErrorMessage
    # In case the picture update did not work... let's keep the old one.
    self.picture_id = self.picture_id_was
    # still raise the error message
    raise
  end

  def cover
    self.picture || self.video
  end

  def country_id
    return nil if self.geo_location.nil?
    self.geo_location.geo_country_id.to_s
  end
  def state_id
    return nil if self.geo_location.nil?
    self.geo_location.geo_admin_code_id.to_s
  end
  def geo_city_name
    geo_location.try.geo_place.name
  end
  def city_id
    return nil if self.geo_location.nil?
    self.geo_location.geo_place_id
  end

  # UPGRADE FUNCTIONALITY

  def to_gates
    if self.entity.is_a? User
      self.to_user_gates
    elsif self.entity.is_a? Group
      self.to_group_gates
    end
  end

  def to_user_gates
    gates = [:view, :see_groups, :see_contacts, :pester, :request_contact]
    gates.select { |gate_name|
      # all gates correspond to may_* flags in the profile
      # (except for :view -> may_see)
      profile_flag = (gate_name == :view ? "may_see" : "may_#{gate_name}")
      self.send profile_flag
    }
  end

  def to_group_gates
    gates = [
      :view,
      :pester,
      :burden,
      :spy,
      :join,
      :request_membership,
      :see_members,
      :see_committees,
      :see_networks
    ]
    gates.select { |gate_name|
      # all gates correspond to may_* flags in the profile
      # (except for :view -> may_see and :join which replaces the membership_policy)
      if gate_name == :join
        self.membership_policy_is? :open
      else
        profile_flag = (gate_name == :view ? "may_see" : "may_#{gate_name}")
        self.send profile_flag
      end
    }
  end

  def summary_html
    super.try :html_safe
  end

  # DEPRECATED
  def create_wiki(opts = {})
    return wiki unless wiki.nil?
    opts[:profile] = self
    wiki = Wiki.create opts
    save
    wiki
  end

  # DEPRECATED
  def ensure_wall
  unless self.wall
  self.wall = Discussion.create
  self.save!
  end
  self.wall
  end

end # class
