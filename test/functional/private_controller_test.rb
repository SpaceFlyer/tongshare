require 'test_helper'

class PrivateControllerTest < ActionController::TestCase
  test "should get get_diff" do
    get :get_diff
    assert_response :success
  end

end
