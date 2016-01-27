#
# The abstract super-class for the main controller of each page type.
#

class Page::BaseController < ApplicationController

  public

  before_filter :login_required, except: :show
  before_filter :authorization_required
  before_filter :bust_cache, only: :show
  permissions :pages
  guard :may_ACTION_page?
  guard print: :may_show_page?
  guard update: :may_edit_page?

  layout 'page'

  permission_helper 'posts'

  # the page banner has links that the user cannot see when unauthorized, like membership.
  # so, we must load the appropriate permissions from groups.
  permission_helper 'group/memberships', 'group/base', 'me'

  helper 'page/base', 'page/sidebar', 'page/post'

  ##
  ## FILTERS
  ## (the order matters!)
  ##

  prepend_before_filter :default_fetch_data, except: :new

  append_before_filter :default_setup_options
  append_before_filter :load_posts

  # after_filters are processed the inside out.
  # So whatever is defined first will be processed last
  # ... after all the others
  after_filter :save_if_needed, except: :create
  after_filter :update_viewed, only: :show
  after_filter :update_view_count, only: [:show, :edit, :create]

  include Page::BeforeFilters

  ##
  ## CONSTRUCTOR
  ##

  hide_action :initialize
  # if the page controller is call by our custom DispatchController,
  # objects which have already been loaded will be passed to the tool
  # via this initialize method.
  def initialize(seed={})
    super()
    @user  = seed[:user]   # the user context, if any
    @group = seed[:group]  # the group context, if any
    @page  = seed[:page]   # the page object, if already fetched
  end

  protected

  # to be overridden by subclasses
  def fetch_data; end
  def setup_options; end

  ##
  ## PAGE OPTIONS
  ## subclasses can control how a page is displayed by changing these values.
  ## they should do so by defining setup_options() and modifying @options member
  ## variable (which is of type Page::BaseController::Options)
  ##

  class Options
    attr_accessor :show_posts     # show comments for this page?
    attr_accessor :show_reply     # show form to post new comment?
    attr_accessor :show_assets    # show assets for this page?
    attr_accessor :show_tags      # show tags for this page?
    attr_accessor :show_sidebar   # show the page sidebar?
    attr_accessor :show_tabs      # load 'tabs' partial?
    attr_accessor :title          # html title
  end

  ##
  ## CONTEXT
  ##

  def setup_context
    if @page and @page.owner
      if @page.owner == current_user
        @context = Context::Me.new(current_user)
      else
        @context = Context.find(@page.owner)
      end
    end
    super
  end

end

