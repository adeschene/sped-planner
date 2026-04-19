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

    # Use a weekday — the calendar only renders Mon–Fri.
    activity_date = Date.current
    activity_date += 2 if activity_date.saturday?
    activity_date += 1 if activity_date.sunday?

    # Navigate to the specific week so params[:start_date] is set.
    # The form's date_placeholder reads params[:start_date] and pre-fills the
    # date field — avoids fighting Chrome's date input format with .set().
    visit week_view_url(start_date: activity_date)

    fill_in "Type description here...", with: "Test Activity"
    select timeslots(:morning).label, from: "activity_block"
    click_button "Add Activity"

    # redirect_back returns to the same week view; activity should appear
    assert_text "Test Activity"

    # Click through to the show page
    click_link "Test Activity"
    assert_text "Test Activity"
    assert_text activity_date.strftime("%B %-d, %Y")
  end
end
