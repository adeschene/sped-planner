require "application_system_test_case"

class PlanningFlowTest < ApplicationSystemTestCase
  test "log in, create an activity via modal, view its show page" do
    # Unauthenticated visit redirects to login
    visit root_url
    assert_current_path login_path

    # Log in
    fill_in "Email", with: users(:alice).email
    fill_in "Password", with: "password123"
    click_button "Log In"

    # Use a weekday — the calendar only renders Mon–Fri.
    activity_date = Date.current
    activity_date += 2 if activity_date.saturday?
    activity_date += 1 if activity_date.sunday?

    # Navigate to the specific week so the + buttons have the right data-date.
    visit week_view_url(start_date: activity_date)

    # Click the + button for the morning timeslot on the target date.
    find("button[data-date='#{activity_date}'][data-block='#{timeslots(:morning).position}']").click

    # Modal should now be visible.
    within "#add-activity-modal" do
      fill_in "activity_title", with: "Test Activity"
      click_button "Add Activity"
    end

    # redirect_back returns to the same week view; activity should appear
    assert_text "Test Activity"

    # Click through to the show page
    click_link "Test Activity"
    assert_text "Test Activity"
    assert_text activity_date.strftime("%B %-d, %Y")
  end
end
