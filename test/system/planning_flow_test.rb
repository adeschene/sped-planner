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

    # Wait for the login POST to land before navigating on. Without this
    # synchronization point the visit below races the redirect and we end up
    # back on /login unauthenticated.
    assert_text "Welcome back!"

    # Use a weekday — the calendar only renders Mon–Fri.
    activity_date = Date.current
    activity_date += 2 if activity_date.saturday?
    activity_date += 1 if activity_date.sunday?

    # Navigate to the specific week so the + buttons carry the right data-date.
    visit week_view_url(start_date: activity_date)

    # The modal is the first feature in this app to depend on Bootstrap's JS.
    # Assert it actually executed, so a CDN or SRI problem fails with a readable
    # message instead of a mystery invisible-element error further down.
    assert_not_equal "undefined", page.evaluate_script("typeof window.bootstrap"),
      "Bootstrap JS did not execute — check the CDN script tag's integrity hash and reachability"

    # Open the modal from the morning timeslot's + button on the target date.
    find("button[data-date='#{activity_date}'][data-block='#{timeslots(:morning).position}']").click

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
