# Activity Add Modal — Design Spec
_2026-08-18_

## Goal

Replace the bottom-of-page "Add Activity" form on day, week, and month views with a contextual Bootstrap modal triggered by a + button on each timeslot row (day/week) or each day cell (month). Pre-fill date and timeslot from the button's context. Add an optional inline Note field so users can attach a first note without navigating to the activity's detail page.

---

## What changes

| File | Change |
|---|---|
| `app/views/activities/day.html.erb` | Always render all timeslots; add + button to each header; remove bottom add card |
| `app/views/activities/week.html.erb` | Same as day, applied per day column |
| `app/views/activities/month.html.erb` | Add + button to each day cell; remove bottom add card |
| `app/views/activities/_add_activity_modal.html.erb` | **New** — shared Bootstrap modal rendered once per view |
| `app/views/activities/_form.html.erb` | Unchanged — still used by `edit` |
| `app/models/activity.rb` | Add `accepts_nested_attributes_for :notes, reject_if: :all_blank` |
| `app/controllers/activities_controller.rb` | Add `:month` to `get_timeslots` before_action; permit `notes_attributes: [:body]` in `activity_params` |

---

## Always-show-all-timeslots

Day and week views currently skip timeslot blocks with no activities (`unless @filtered.empty?`). Remove that guard — all timeslots render on every day, whether or not they have activities. Empty timeslots render as a header-only row (collapse body present but empty).

---

## The modal (`_add_activity_modal.html.erb`)

A single Bootstrap modal partial, rendered once at the bottom of each view. `@timeslots` is available in all three views after the controller change above.

### Form fields

- **Title** — required text field, auto-focused on modal open (`autofocus` attribute)
- **Timeslot** — `<select>` for `:block` built from `@timeslots`, always visible. JS pre-selects the correct option when launched from day/week; stays on prompt when launched from month (user must pick).
- **Note** — optional textarea via `fields_for :notes, Note.new`. Placeholder: "Add a note (optional)". Blank = no Note created.
- **Date** — hidden field, always present; JS fills value from the trigger button's `data-date` attribute.

### JS pre-fill (vanilla, ~10 lines, in a `<script>` tag in the partial)

Listens for Bootstrap's `show.bs.modal` event on the modal element. Reads `data-date` and `data-block` from `event.relatedTarget` (the + button). Sets the hidden date field value. Sets the select's value to `data-block` (no-op when absent — select stays on prompt for month view).

### Trigger button shape

**Day / week (timeslot header):**
```html
<button data-bs-toggle="modal" data-bs-target="#add-activity-modal"
        data-date="<%= date %>" data-block="<%= timeslot.position %>">+</button>
```

**Month (day cell):**
```html
<button data-bs-toggle="modal" data-bs-target="#add-activity-modal"
        data-date="<%= date %>">+</button>
```

---

## Timeslot header layout (day + week)

The header becomes a flex row: timeslot label on the left (still the Bootstrap collapse toggle), + button on the right. The collapse toggle wraps just the label text, not the full row, so clicking the + doesn't toggle collapse.

---

## Submission

`ActivitiesController#create` keeps `redirect_back`. Turbo Drive replaces the page; the modal disappears naturally with the navigation. No Turbo Streams or Frames involved.

---

## Model change

```ruby
# app/models/activity.rb
accepts_nested_attributes_for :notes, reject_if: :all_blank
```

If the note textarea is blank, no Note is created. If it has content, the Note is saved atomically with the Activity.

---

## Controller changes

```ruby
# before_action
before_action :get_timeslots, only: [:day, :week, :month, :edit, :update]
# ^^^ add :month (currently missing)

# activity_params
params.require(:activity).permit(:title, :date, :block, notes_attributes: [:body])
```

---

## Testing

### Model — `test/models/activity_test.rb`
- Creating an activity with `notes_attributes: [{ body: "some text" }]` saves a Note associated to it
- Creating an activity with `notes_attributes: [{ body: "" }]` creates no Note

### Controller — `test/controllers/activities_controller_test.rb`
- `POST /activities` with valid params redirects (existing test — verify still passes)
- `POST /activities` with a non-blank note body creates both an Activity and a Note
- `POST /activities` with a blank note body creates the Activity but no Note

### Manual validation
Build and test on staging. Verify:
- + button on each timeslot row (day view, week view) pre-fills date and timeslot correctly
- + button on each day cell (month view) pre-fills date, timeslot select starts on prompt
- Submitting with a note body creates the note; submitting without one does not
- Redirect lands back on the originating view with the new activity visible
