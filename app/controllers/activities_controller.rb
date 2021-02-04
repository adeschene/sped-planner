class ActivitiesController < ApplicationController
  before_action :get_activities, only: [:day, :week, :month]
  before_action :find_activity, only: [:show, :edit, :update, :destroy]

  def day
  end

  def week
  end

  def month
  end

  def show
  end

  def create
    @activity = Activity.new(activity_params)
    
    if @activity.save
      redirect_back fallback_location: root_path, notice: "Activity successfully added!"
    else
      redirect_back fallback_location: root_path, alert: "Something still needs to be filled out..."
    end
  end

  def edit
  end

  def update
    if @activity.update(activity_params)
      redirect_to @activity, notice: "Activity successfully updated!"
    else
      flash.now[:alert] = "Something still needs to be filled out..."
      render :edit
    end
  end

  def destroy
    @week_from = @activity.date

    @activity.destroy

    redirect_to week_view_path(:start_date => @week_from), notice: "Activity successfully destroyed!"
  end

  def get_activities
    @activities = Activity.all
  end

  def find_activity
    @activity = Activity.find(params[:id])
  end

  private
    def activity_params
      params.require(:activity).permit(:title, :date, :block)
    end
end
