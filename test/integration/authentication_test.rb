require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "unauthenticated HTML request redirects to login" do
    get root_path
    assert_redirected_to login_path
    assert_equal "Please log in.", flash[:alert]
  end

  test "unauthenticated non-HTML request returns 401" do
    get root_path, headers: { "Accept" => "application/json" }
    assert_response :unauthorized
  end

  test "authenticated request reaches the protected page" do
    sign_in_as(users(:alice))
    get root_path
    assert_response :success
  end
end
