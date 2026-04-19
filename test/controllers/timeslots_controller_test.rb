require "test_helper"

class TimeslotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice   = users(:alice)
    @morning = timeslots(:morning)
  end

  # ---------------------------------------------------------------------------
  # Auth guard — unauthenticated requests redirected to login
  # ---------------------------------------------------------------------------

  test "GET index redirects unauthenticated user to login" do
    get timeslots_path
    assert_redirected_to login_path
  end

  test "POST create redirects unauthenticated user to login" do
    post timeslots_path, params: { timeslot: { label: "New Block" } }
    assert_redirected_to login_path
  end

  test "PATCH update redirects unauthenticated user to login" do
    patch timeslot_path(@morning), params: { timeslot: { label: "Renamed" } }
    assert_redirected_to login_path
  end

  test "DELETE destroy redirects unauthenticated user to login" do
    delete timeslot_path(@morning)
    assert_redirected_to login_path
  end

  # ---------------------------------------------------------------------------
  # index
  # ---------------------------------------------------------------------------

  test "GET index returns 200" do
    sign_in_as(@alice)
    get timeslots_path
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # create
  # ---------------------------------------------------------------------------

  test "POST create with valid label saves and redirects with notice" do
    sign_in_as(@alice)
    assert_difference "Timeslot.count" do
      post timeslots_path, params: { timeslot: { label: "Late Block" } }
    end
    assert_redirected_to timeslots_path
    assert_equal "Timeslot added!", flash[:notice]
  end

  test "POST create assigns next available position" do
    sign_in_as(@alice)
    max_before = Timeslot.maximum(:position)
    post timeslots_path, params: { timeslot: { label: "Late Block" } }
    assert_equal max_before + 1, Timeslot.last.position
  end

  test "POST create with blank label does not save and redirects with alert" do
    sign_in_as(@alice)
    assert_no_difference "Timeslot.count" do
      post timeslots_path, params: { timeslot: { label: "" } }
    end
    assert_redirected_to timeslots_path
    assert_equal "Label can't be blank.", flash[:alert]
  end

  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  test "PATCH update with valid label saves and redirects with notice" do
    sign_in_as(@alice)
    patch timeslot_path(@morning), params: { timeslot: { label: "Early Morning" } }
    assert_redirected_to timeslots_path
    assert_equal "Timeslot updated!", flash[:notice]
    assert_equal "Early Morning", @morning.reload.label
  end

  test "PATCH update with blank label does not save and redirects with alert" do
    sign_in_as(@alice)
    patch timeslot_path(@morning), params: { timeslot: { label: "" } }
    assert_redirected_to timeslots_path
    assert_equal "Label can't be blank.", flash[:alert]
    assert_equal "Morning Block", @morning.reload.label
  end

  test "PATCH update returns 404 for missing timeslot" do
    sign_in_as(@alice)
    patch timeslot_path(id: 0), params: { timeslot: { label: "X" } }
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # destroy
  # ---------------------------------------------------------------------------

  test "DELETE destroy with no assigned activities removes record and redirects with notice" do
    sign_in_as(@alice)
    empty = Timeslot.create!(label: "Empty Block", position: 99)
    assert_difference "Timeslot.count", -1 do
      delete timeslot_path(empty)
    end
    assert_redirected_to timeslots_path
    assert_equal "Timeslot deleted.", flash[:notice]
  end

  test "DELETE destroy with assigned activities refuses and redirects with alert" do
    sign_in_as(@alice)
    assert_no_difference "Timeslot.count" do
      delete timeslot_path(@morning)
    end
    assert_redirected_to timeslots_path
    assert_match "Can't delete", flash[:alert]
    assert_match @morning.label, flash[:alert]
  end

  test "DELETE destroy returns 404 for missing timeslot" do
    sign_in_as(@alice)
    delete timeslot_path(id: 0)
    assert_response :not_found
  end
end
