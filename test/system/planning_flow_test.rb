require "application_system_test_case"

class PlanningFlowTest < ApplicationSystemTestCase
  test "log in, create an activity, view its show page" do
    # Unauthenticated visit redirects to login
    visit root_url
    assert_current_path login_path

    # Log in
    fill_in "Email", with: users(:alice).email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_button "Add Activity"

    # Fill in the create form at the bottom of the week view.
    # Use a weekday — the calendar only renders Mon–Fri, matching the
    # controller's next_weekday default.
    activity_date = Date.current
    activity_date += 2 if activity_date.saturday?
    activity_date += 1 if activity_date.sunday?
    fill_in "Type description here...", with: "Test Activity"
    select timeslots(:morning).label, from: "activity_block"
    find("#activity_date").set(activity_date.to_s)
    click_button "Add Activity"

    # Navigate to the week containing the new activity and confirm it appears
    visit week_view_url(start_date: activity_date)
    assert_text "Test Activity"

    # Click through to the show page
    click_link "Test Activity"
    assert_text "Test Activity"
    assert_text activity_date.strftime("%B %-d, %Y")
  end
end
