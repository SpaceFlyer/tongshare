require 'test_helper'

class SmsControllerTest < ActionController::TestCase
  test "should get edit" do
    get :edit
    assert_response :success
  end

  test "should get confirm" do
    get :confirm
    assert_response :success
  end

end
