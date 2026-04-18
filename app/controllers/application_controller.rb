class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  def authenticate_user!
    if session[:user_id].nil?
      respond_to do |format|
        format.html { redirect_to login_path, alert: "Please log in." }
        format.any  { head :unauthorized } # This prevents the 406 for non-HTML requests
      end
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user
end
