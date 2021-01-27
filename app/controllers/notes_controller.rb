class NotesController < ApplicationController
  def create
    @activity = Activity.find(params[:activity_id])
    @note = @activity.notes.create(notes_params)

    if @note.valid?
      redirect_to activity_path(@activity), notice: "Note successfully added!"
    else
      redirect_to activity_path(@activity), alert: "Something still needs to be filled out..."
    end
  end

  def edit
    @note = Note.find(params[:id])
  end

  def update
    @note = Note.find(params[:id])

    if @note.update(notes_params)
      redirect_to @note.activity, notice: "Note successfully updated!"
    else
      flash.now[:alert] = "Something still needs to be filled out..."
      render :edit
    end
  end

  def destroy
    @note = Note.find(params[:id])
    @activity = @note.activity
    @note.destroy

    redirect_to activity_path(@activity), notice: "Note successfully deleted!"
  end

  private
    def notes_params
      params.require(:note).permit(:body)
    end
end
