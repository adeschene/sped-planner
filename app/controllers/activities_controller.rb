class ActivitiesController < ApplicationController
  def index
    @activities = Activity.all
  end

  def show
    @activity = Activity.find(params[:id])
  end

  def create
    @activity = Activity.new(activity_params)

    if @activity.save
      redirect_to root_path, notice: "Activity successfully added!"
    else
      redirect_to root_path, alert: "Something still needs to be filled out..."
    end
  end

  def edit
    @activity = Activity.find(params[:id])
  end

  def update
    @activity = Activity.find(params[:id])

    if @activity.update(activity_params)
      redirect_to @activity, notice: "Activity successfully updated!"
    else
      flash.now[:alert] = "Something still needs to be filled out..."
      render :edit
    end
  end

  def destroy
    @activity = Activity.find(params[:id])
    @activity.destroy

    redirect_to root_path, notice: "Activity successfully destroyed!"
  end

  private
    def activity_params
      params.require(:activity).permit(:title, :date, :block)
    end
end
