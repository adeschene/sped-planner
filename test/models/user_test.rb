require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires an email" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires a unique email" do
    User.create!(email: "dupe@example.com", password: "password123")
    user = User.new(email: "dupe@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "authenticates with the correct password" do
    user = users(:alice)
    assert user.authenticate("password123")
    assert_not user.authenticate("wrong")
  end
end
