require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice    = users(:alice)
    @activity = activities(:one)
  end

  # ---------------------------------------------------------------------------
  # Auth guard — unauthenticated requests redirected to login
  # ---------------------------------------------------------------------------

  test "GET day redirects unauthenticated user to login" do
    get day_view_path
    assert_redirected_to login_path
  end

  test "GET week redirects unauthenticated user to login" do
    get week_view_path
    assert_redirected_to login_path
  end

  test "GET month redirects unauthenticated user to login" do
    get month_view_path
    assert_redirected_to login_path
  end

  test "GET show redirects unauthenticated user to login" do
    get activity_path(@activity)
    assert_redirected_to login_path
  end

  test "GET edit redirects unauthenticated user to login" do
    get edit_activity_path(@activity)
    assert_redirected_to login_path
  end

  test "POST create redirects unauthenticated user to login" do
    post activities_path, params: { activity: { title: "X", date: Date.today, block: 1 } }
    assert_redirected_to login_path
  end

  test "PATCH update redirects unauthenticated user to login" do
    patch activity_path(@activity), params: { activity: { title: "Y" } }
    assert_redirected_to login_path
  end

  test "DELETE destroy redirects unauthenticated user to login" do
    delete activity_path(@activity)
    assert_redirected_to login_path
  end

  # ---------------------------------------------------------------------------
  # day / week / month — calendar views
  # ---------------------------------------------------------------------------

  test "GET day returns 200 for authenticated user" do
    sign_in_as(@alice)
    get day_view_path
    assert_response :success
  end

  test "GET week returns 200 for authenticated user" do
    sign_in_as(@alice)
    get week_view_path
    assert_response :success
  end

  test "GET month returns 200 for authenticated user" do
    sign_in_as(@alice)
    get month_view_path
    assert_response :success
  end

  test "GET week uses provided start_date param" do
    sign_in_as(@alice)
    get week_view_path, params: { start_date: "2026-05-05" }
    assert_response :success
    assert_equal "2026-05-05", controller.params[:start_date]
  end

  # ---------------------------------------------------------------------------
  # show
  # ---------------------------------------------------------------------------

  test "GET show returns 200 for existing activity" do
    sign_in_as(@alice)
    get activity_path(@activity)
    assert_response :success
  end

  test "GET show returns 404 for missing activity" do
    sign_in_as(@alice)
    get activity_path(id: 0)
    assert_response :not_found
  end

  # ---------------------------------------------------------------------------
  # edit
  # ---------------------------------------------------------------------------

  test "GET edit returns 200 for existing activity" do
    sign_in_as(@alice)
    get edit_activity_path(@activity)
    assert_response :success
  end

  # ---------------------------------------------------------------------------
  # create
  # ---------------------------------------------------------------------------

  test "POST create with valid params saves and redirects" do
    sign_in_as(@alice)
    assert_difference "Activity.count" do
      post activities_path,
        params: { activity: { title: "New Activity", date: "2026-05-01", block: 1 } },
        headers: { "HTTP_REFERER" => week_view_url }
    end
    assert_redirected_to week_view_url
    assert_equal "Activity successfully added!", flash[:notice]
  end

  test "POST create with missing title redirects with alert" do
    sign_in_as(@alice)
    assert_no_difference "Activity.count" do
      post activities_path,
        params: { activity: { title: "", date: "2026-05-01", block: 1 } },
        headers: { "HTTP_REFERER" => week_view_url }
    end
    assert_redirected_to week_view_url
    assert_equal "Something still needs to be filled out...", flash[:alert]
  end

  # ---------------------------------------------------------------------------
  # update
  # ---------------------------------------------------------------------------

  test "PATCH update with valid params redirects to activity" do
    sign_in_as(@alice)
    patch activity_path(@activity),
      params: { activity: { title: "Updated Title", date: @activity.date, block: @activity.block } }
    assert_redirected_to activity_path(@activity)
    assert_equal "Activity successfully updated!", flash[:notice]
    assert_equal "Updated Title", @activity.reload.title
  end

  test "PATCH update with missing title re-renders edit with 422" do
    sign_in_as(@alice)
    patch activity_path(@activity),
      params: { activity: { title: "", date: @activity.date, block: @activity.block } }
    assert_response :unprocessable_entity
    assert_equal "Morning Math Review", @activity.reload.title
  end

  # ---------------------------------------------------------------------------
  # destroy
  # ---------------------------------------------------------------------------

  test "DELETE destroy removes the activity and redirects to week view" do
    sign_in_as(@alice)
    activity_date = @activity.date
    assert_difference "Activity.count", -1 do
      delete activity_path(@activity)
    end
    assert_redirected_to week_view_path(start_date: activity_date)
    assert_equal "Activity successfully destroyed!", flash[:notice]
  end
end
