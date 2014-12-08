require 'test_helper'

class ThemeControllerTest < ActionController::TestCase
  def test_caches
    assert ThemeController.perform_caching
    assert ThemeController.new.perform_caching
  end

end
