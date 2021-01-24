class WeekController < ApplicationController
  def index
  	@activities = Activity.all
  end
end