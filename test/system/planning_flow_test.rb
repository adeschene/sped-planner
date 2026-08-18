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

    # Verify the week view loaded and timeslots are present
    assert_text timeslots(:morning).label

    # Click any + button to open the modal (first available timeslot on the page)
    first("button[data-bs-target='#add-activity-modal']").click

    # Modal appears — fill in the title and submit
    find("#activity_title", visible: true).fill_in with: "Test Activity"
    click_button "Add Activity"

    # redirect_back returns to the same week view; activity should appear
    assert_text "Test Activity"

    # Click through to the show page
    click_link "Test Activity"
    assert_text "Test Activity"
    assert_text activity_date.strftime("%B %-d, %Y")
  end
end
