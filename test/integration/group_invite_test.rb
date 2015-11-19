require 'integration_test'

class GroupInviteTest < IntegrationTest

  def test_invited_via_email
    @group = groups(:animals)
    @request = RequestToJoinUsViaEmail.create created_by: users(:blue),
      email: 'sometest@email.test',
      requestable: @group
    url = "/me/requests/#{@request.id}?code=#{@request.code}"
    visit url
    assert_content 'Login Required'
    signup
    click_on 'Approve'
    assert_content 'Approved'
    assert @group.memberships.where(user_id: @user).exists?
  end
end
