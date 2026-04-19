ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors, with: :threads)
  fixtures :all
end

module SessionTestHelpers
  def sign_in_as(user, password: "password123")
    post login_path, params: { email: user.email, password: password }
  end
end

class ActionDispatch::IntegrationTest
  include SessionTestHelpers
end
