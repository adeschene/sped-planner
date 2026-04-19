require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
  end

  test "GET /login renders the login form" do
    get login_path
    assert_response :success
  end

  test "POST /login with valid credentials signs in and redirects" do
    post login_path, params: { email: @alice.email, password: "password123" }
    assert_redirected_to root_path
    assert_equal @alice.id, session[:user_id]
  end

  test "POST /login with invalid password renders form with 422" do
    post login_path, params: { email: @alice.email, password: "wrong" }
    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
    assert_nil session[:user_id]
  end

  test "POST /login with unknown email renders form with 422" do
    post login_path, params: { email: "nobody@example.com", password: "password123" }
    assert_response :unprocessable_entity
    assert_equal "Invalid email or password", flash[:alert]
  end

  test "DELETE /logout clears the session" do
    sign_in_as(@alice)
    delete logout_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end
end
