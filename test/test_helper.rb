if ENV["COVERAGE"]
  require 'simplecov'
  SimpleCov.start 'rails'
end

require 'minitest/autorun'

ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'rails/test_help'

##
## load all the test helpers
##

Dir[File.dirname(__FILE__) + '/helpers/*.rb'].each {|file| require file }

##
## misc.
##

class ActiveSupport::TestCase


  include AuthenticatedTestHelper
  include AssetTestHelper
  include LoginTestHelper
  include FixtureTestHelper
  include FunctionalTestHelper
  include DebugTestHelper
  include CrabgrassTestHelper
  include CachingTestHelper
  # for fixture_file_upload
  include ActionDispatch::TestProcess

  fixtures :all
  set_fixture_class castle_gates_keys: CastleGates::Key,
    federatings: Group::Federating,
    memberships: Group::Membership,
    relationships: User::Relationship,
    taggings: ActsAsTaggableOn::Tagging,
    tags: ActsAsTaggableOn::Tag,
    tokens: User::Token,
    "page/terms" => Page::Terms
end

require 'factory_girl'

class FactoryGirl::SyntaxRunner
  # for fixture_file_upload
  include ActionDispatch::TestProcess

  def self.fixture_path
    ActionController::TestCase.fixture_path
  end
end

##
## Integration Tests
## some special rules for integration tests
##

#
# mocha must be required last.
# the libraries that it patches must be loaded before it is.
#
require 'mocha/mini_test'

# ActiveSupport::HashWithIndifferentAccess#convert_value calls 'class' and 'is_a?'
# on all values. This happens when assembling 'assigns' in tests.
# This little hack will make those tests pass.
MiniTest::Mock.class_eval do
  def class
    MiniTest::Mock
  end

  def is_a?(klass)
    false
  end
end
