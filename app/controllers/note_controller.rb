class NoteController < ApplicationController
  def create
    @activity = Activity.find(params[:activity_id])
    @note = @activity.notes.create(note_params)

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

    if @note.update(note_params)
      redirect_to @note, notice: "Note successfully updated!"
    else
      flash.now[:alert] = "Something still needs to be filled out..."
      render :edit
    end
  end

  def destroy
    @activity = Activity.find(params[:activity_id])
    @note = @activity.notes.find(params[:id])
    @note.destroy

    redirect_to activity_path(@activity), notice: "Note successfully deleted!"
  end

  private
    def note_params
      params.require(:note).permit(:body)
    end
end
