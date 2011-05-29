require 'test_helper'

class AjaxControllerTest < ActionController::TestCase
  test "should get load_news" do
    get :load_news
    assert_response :success
  end

end
