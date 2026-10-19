require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "gets root" do
    get root_url
    assert_response :success
    assert_select "h1", "Crails"
  end
end
