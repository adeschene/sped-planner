require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice    = users(:alice)
    @activity = activities(:one)
    @note     = notes(:one)
  end

  # ---------------------------------------------------------------------------
  # Auth guard — unauthenticated requests redirected to login
  # ---------------------------------------------------------------------------

  test "POST create redirects unauthenticated user to login" do
    post activity_notes_path(@activity), params: { note: { body: "Hello" } }
    assert_redirected_to login_path
  end

  test "GET edit redirects unauthenticated user to login" do
    get edit_note_path(@note)
    assert_redirected_to login_path
  end

  test "PATCH update redirects unauthenticated user to login" do
    patch note_path(@note), params: { note: { body: "Hello" } }
    assert_redirected_to login_path
  end

  test "DELETE destroy redirects unauthenticated user to login" do
    delete note_path(@note)
    assert_redirected_to login_path
  end

  # ---------------------------------------------------------------------------
  # create
  # ---------------------------------------------------------------------------

  test "POST create with valid body saves and redirects to activity with notice" do
    sign_in_as(@alice)
    assert_difference "Note.count" do
      post activity_notes_path(@activity), params: { note: { body: "New note body" } }
    end
    assert_redirected_to activity_path(@activity)
    assert_equal "Note successfully added!", flash[:notice]
  end

  test "POST create associates note with the correct activity" do
    sign_in_as(@alice)
    post activity_notes_path(@activity), params: { note: { body: "Linked note" } }
    assert_equal @activity.id, Note.last.activity_id
  end

  test "POST create with blank body does not save and redirects with alert" do
    sign_in_as(@alice)
    assert_no_difference "Note.count" do
      post activity_notes_path(@activity), params: { note: { body: "" } }
    end
    assert_redirected_to activity_path(@activity)
    assert_equal "Something still needs to be filled out...", flash[:alert]
  end

  test "POST create returns 404 for missing activity" do
    sign_in_as(@alice)
    post activity_notes_path(activity_id: 0), params: { note: { body: "X" } }
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # edit
  # ---------------------------------------------------------------------------

  test "GET edit returns 200 for existing note" do
    sign_in_as(@alice)
    get edit_note_path(@note)
    assert_response :success
  end

  test "GET edit returns 404 for missing note" do
    sign_in_as(@alice)
    get edit_note_path(id: 0)
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  test "PATCH update with valid body saves and redirects to activity with notice" do
    sign_in_as(@alice)
    patch note_path(@note), params: { note: { body: "Updated body" } }
    assert_redirected_to activity_path(@note.activity)
    assert_equal "Note successfully updated!", flash[:notice]
    assert_equal "Updated body", @note.reload.body
  end

  test "PATCH update with blank body re-renders edit with 422" do
    sign_in_as(@alice)
    patch note_path(@note), params: { note: { body: "" } }
    assert_response :unprocessable_entity
    assert_equal "MyText", @note.reload.body
  end

  test "PATCH update returns 404 for missing note" do
    sign_in_as(@alice)
    patch note_path(id: 0), params: { note: { body: "X" } }
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # destroy
  # ---------------------------------------------------------------------------

  test "DELETE destroy removes note and redirects to activity with notice" do
    sign_in_as(@alice)
    activity = @note.activity
    assert_difference "Note.count", -1 do
      delete note_path(@note)
    end
    assert_redirected_to activity_path(activity)
    assert_equal "Note successfully deleted!", flash[:notice]
  end

  test "DELETE destroy returns 404 for missing note" do
    sign_in_as(@alice)
    delete note_path(id: 0)
    assert_response :not_found
  end
end
