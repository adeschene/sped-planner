class TimeslotsController < ApplicationController
  before_action :find_timeslot, only: [:update, :destroy]

  def index
    @timeslots = Timeslot.all
    @new_timeslot = Timeslot.new
  end

  def create
    next_position = Timeslot.maximum(:position).to_i + 1
    @timeslot = Timeslot.new(timeslot_params.merge(position: next_position))

    if @timeslot.save
      redirect_to timeslots_path, notice: "Timeslot added!"
    else
      redirect_to timeslots_path, alert: "Label can't be blank."
    end
  end

  def update
    if @timeslot.update(timeslot_params)
      redirect_to timeslots_path, notice: "Timeslot updated!"
    else
      redirect_to timeslots_path, alert: "Label can't be blank."
    end
  end

  def destroy
    if Activity.where(block: @timeslot.position).exists?
      redirect_to timeslots_path, alert: "Can't delete \"#{@timeslot.label}\" — it still has activities assigned to it."
    else
      @timeslot.destroy
      redirect_to timeslots_path, notice: "Timeslot deleted."
    end
  end

  private

  def find_timeslot
    @timeslot = Timeslot.find(params[:id])
  end

  def timeslot_params
    params.require(:timeslot).permit(:label)
  end
end
