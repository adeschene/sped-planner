class UsersController < ApplicationController
  VALID_THEMES = %w[default garden citrus ocean wildflower].freeze

  def update_theme
    theme = params[:theme].to_s
    current_user.update!(theme: theme) if VALID_THEMES.include?(theme)
    redirect_back fallback_location: root_path
  end
end
