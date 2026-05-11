require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
  end

  test "PATCH update_theme redirects unauthenticated user to login" do
    patch update_theme_path, params: { theme: "garden" }
    assert_redirected_to login_path
  end

  test "PATCH update_theme with valid theme persists and redirects" do
    sign_in_as(@alice)
    patch update_theme_path, params: { theme: "garden" }
    assert_equal "garden", @alice.reload.theme
    assert_redirected_to root_path
  end

  test "PATCH update_theme cycles through all valid themes" do
    sign_in_as(@alice)
    UsersController::VALID_THEMES.each do |theme|
      patch update_theme_path, params: { theme: theme }
      assert_equal theme, @alice.reload.theme
    end
  end

  test "PATCH update_theme with invalid theme is a no-op" do
    sign_in_as(@alice)
    patch update_theme_path, params: { theme: "hacker" }
    assert_equal "default", @alice.reload.theme
    assert_redirected_to root_path
  end

  test "PATCH update_theme with blank theme is a no-op" do
    sign_in_as(@alice)
    patch update_theme_path, params: { theme: "" }
    assert_equal "default", @alice.reload.theme
  end
end
