require 'test_helper'

class RankedVotePageControllerTest < ActionController::TestCase
  fixtures :pages, :users, :user_participations, :polls, :possibles

  def setup
    @user = users(:orange)
    @page = FactoryGirl.create :ranked_vote_page, created_by: @user
    @poll = @page.data
  end

  def test_show_empty_redirects
    login_as @user
    get :show, id: @page.id
    assert_response :redirect
    assert_redirected_to @controller.send(:page_url, @page, action: :edit)
  end

  def test_show_with_possible
    login_as @user
    @poll.possibles.create name: "new option"
    get :show, id: @page.id
    assert_response :success
    assert_template 'ranked_vote_page/show'
  end

  def test_public_show_with_possible
    @poll.possibles.create name: "new option"
    @page.update_attributes public: true
    get :show, id: @page.id
    assert_response :success
    assert_template 'ranked_vote_page/show'
  end

  def test_edit
    login_as @user
    get :edit, id: @page
    assert_response :success
  end

end
