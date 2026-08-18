# Activity Add Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bottom-of-page "Add Activity" form on day, week, and month views with a contextual Bootstrap modal triggered by + buttons, pre-filled from context (date and timeslot on day/week; date only on month). Add an optional inline note field so a first Note can be attached without navigating to the activity's detail page.

**Architecture:** A single shared Bootstrap modal partial is rendered once per view. Each + button carries `data-date` / `data-block` attributes; a `show.bs.modal` event listener copies them into the form's hidden fields before the modal appears. `create` keeps `redirect_back` — Turbo Drive replaces the page and the modal disappears naturally. Nested attributes wire the optional note with zero extra controller actions.

**Tech Stack:** Rails 7.1, Turbo Drive (no Streams/Frames), Bootstrap 5.3, Bootstrap Icons, importmap (no Stimulus), PostgreSQL 15.

**Spec:** `docs/superpowers/specs/2026-08-18-activity-add-modal-design.md`

## Global Constraints

- No Stimulus — all JS is vanilla in `<script>` tags.
- No Turbo Streams or Frames — `redirect_back` is the submit response.
- Bootstrap 5.3 available via CDN (already in layout).
- `@timeslots` must be available in every view that renders the modal partial — the controller change in Task 2 ensures this.
- Run tests via CI only; never run `bin/rails test` inside the staging container.
- Commit after every task.

---

### Task 1: Add nested-attributes support on Activity and model tests

**Files:**
- Modify: `app/models/activity.rb`
- Modify: `test/models/activity_test.rb`

**Interfaces:**
- Produces: `Activity.new(notes_attributes: [{ body: "..." }])` saves a Note; blank body is rejected.

- [ ] **Step 1: Write the two failing model tests**

  Add to the bottom of `test/models/activity_test.rb`:

  ```ruby
  # ---------------------------------------------------------------------------
  # Nested note creation via accepts_nested_attributes_for
  # ---------------------------------------------------------------------------

  test "creates an associated note when notes_attributes body is present" do
    activity = Activity.create!(title: "With Note", date: Date.today, block: 1,
                                notes_attributes: [{ body: "hello" }])
    assert_equal 1, activity.notes.count
    assert_equal "hello", activity.notes.first.body
  end

  test "does not create a note when notes_attributes body is blank" do
    activity = Activity.create!(title: "No Note", date: Date.today, block: 1,
                                notes_attributes: [{ body: "" }])
    assert_equal 0, activity.notes.count
  end
  ```

- [ ] **Step 2: Confirm tests fail**

  Push to GitHub and check the CI run on this branch — both new tests should fail with `unknown attribute 'notes_attributes'`.

- [ ] **Step 3: Add `accepts_nested_attributes_for` to Activity**

  In `app/models/activity.rb`, add one line after `has_many :notes, dependent: :destroy`:

  ```ruby
  class Activity < ApplicationRecord
    has_many :notes, dependent: :destroy
    accepts_nested_attributes_for :notes, reject_if: :all_blank
    belongs_to :timeslot, foreign_key: :block, primary_key: :position, optional: true

    validates :title, :date, :block, presence: true

    default_scope { order(block: :asc, updated_at: :asc) }

    def start_time
      self.date
    end
  end
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add app/models/activity.rb test/models/activity_test.rb
  git commit -m "Add nested note creation to Activity via accepts_nested_attributes_for"
  ```

---

### Task 2: Controller — permit nested params and expose @timeslots on month view

**Files:**
- Modify: `app/controllers/activities_controller.rb`
- Modify: `test/controllers/activities_controller_test.rb`

**Interfaces:**
- Consumes: `accepts_nested_attributes_for :notes, reject_if: :all_blank` from Task 1.
- Produces: `POST /activities` with `notes_attributes: { "0" => { body: "..." } }` creates a Note; blank body does not.
- Produces: `@timeslots` available in `month` action (needed by the modal partial in Task 3).

- [ ] **Step 1: Write the two failing controller tests**

  Add to `test/controllers/activities_controller_test.rb` below the existing create tests:

  ```ruby
  test "POST create with a note body creates both Activity and Note" do
    sign_in_as(@alice)
    assert_difference ["Activity.count", "Note.count"] do
      post activities_path,
        params: { activity: { title: "With Note", date: "2026-05-01", block: 1,
                              notes_attributes: { "0" => { body: "My first note" } } } },
        headers: { "HTTP_REFERER" => week_view_url }
    end
    assert_redirected_to week_view_url
  end

  test "POST create with blank note body creates Activity but no Note" do
    sign_in_as(@alice)
    assert_difference "Activity.count" do
      assert_no_difference "Note.count" do
        post activities_path,
          params: { activity: { title: "No Note", date: "2026-05-01", block: 1,
                                notes_attributes: { "0" => { body: "" } } } },
          headers: { "HTTP_REFERER" => week_view_url }
      end
    end
    assert_redirected_to week_view_url
  end
  ```

- [ ] **Step 2: Confirm tests fail**

  Push and check CI — both tests should fail (`notes_attributes` param is not permitted yet so the note is silently dropped).

- [ ] **Step 3: Update the controller**

  Replace the relevant lines in `app/controllers/activities_controller.rb`:

  ```ruby
  # Change this line — add :month
  before_action :get_timeslots, only: [:day, :week, :month, :edit, :update]

  # Change activity_params to permit nested note body
  def activity_params
    params.require(:activity).permit(:title, :date, :block, notes_attributes: [:body])
  end
  ```

  Full updated file for reference:

  ```ruby
  class ActivitiesController < ApplicationController
    before_action :get_activities, only: [:day, :week, :month]
    before_action :get_timeslots, only: [:day, :week, :month, :edit, :update]
    before_action :find_activity, only: [:show, :edit, :update, :destroy]

    def day
      params[:start_date] ||= next_weekday.to_s
    end

    def week
      params[:start_date] ||= next_weekday.to_s
    end

    def month
      params[:start_date] ||= next_weekday.to_s
    end

    def show
    end

    def create
      @activity = Activity.new(activity_params)

      if @activity.save
        redirect_back fallback_location: root_path, notice: "Activity successfully added!"
      else
        redirect_back fallback_location: root_path, alert: "Something still needs to be filled out..."
      end
    end

    def edit
    end

    def update
      if @activity.update(activity_params)
        redirect_to @activity, notice: "Activity successfully updated!"
      else
        flash.now[:alert] = "Something still needs to be filled out..."
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @week_from = @activity.date
      @activity.destroy
      redirect_to week_view_path(:start_date => @week_from), notice: "Activity successfully destroyed!"
    end

    def get_activities
      @activities = Activity.all
    end

    def get_timeslots
      @timeslots = Timeslot.all
    end

    def find_activity
      @activity = Activity.find(params[:id])
    end

    private
      def activity_params
        params.require(:activity).permit(:title, :date, :block, notes_attributes: [:body])
      end

      def next_weekday
        today = Date.today
        today.wday == 6 ? today + 2 : today.wday == 0 ? today + 1 : today
      end
  end
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add app/controllers/activities_controller.rb test/controllers/activities_controller_test.rb
  git commit -m "Permit nested note params in create; expose @timeslots on month view"
  ```

---

### Task 3: Create the shared modal partial

**Files:**
- Create: `app/views/activities/_add_activity_modal.html.erb`

**Interfaces:**
- Consumes: `@timeslots` (Array of Timeslot, available in all three views after Task 2).
- Consumes: Bootstrap 5.3 modal JS (already in layout).
- Produces: A modal with id `add-activity-modal`. Trigger buttons use `data-bs-target="#add-activity-modal"`.
- Produces: Form field ids `activity_title`, `activity_date`, `activity_block` (Rails-generated from `form_with model: Activity.new`).

- [ ] **Step 1: Create the partial**

  Create `app/views/activities/_add_activity_modal.html.erb` with this content:

  ```erb
  <div class="modal fade" id="add-activity-modal" tabindex="-1"
       aria-labelledby="add-activity-modal-label" aria-hidden="true">
    <div class="modal-dialog">
      <div class="modal-content">
        <div class="modal-header bg-dark text-white">
          <h5 class="modal-title" id="add-activity-modal-label">
            <i class="bi bi-plus-circle me-1"></i>Add Activity
          </h5>
          <button type="button" class="btn-close btn-close-white"
                  data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
          <%= form_with model: Activity.new, url: activities_path do |form| %>
            <%= form.hidden_field :date %>

            <div class="mb-3">
              <%= form.text_field :title,
                    class: "form-control",
                    placeholder: "Description" %>
            </div>

            <div class="mb-3">
              <%= form.select :block,
                    options_for_select(@timeslots.map { |t| [t.label, t.position] }),
                    { prompt: "Select Timeslot" },
                    { class: "form-select" } %>
            </div>

            <div class="mb-3">
              <%= form.fields_for :notes, Note.new do |note_form| %>
                <%= note_form.text_area :body,
                      class: "form-control",
                      placeholder: "Add a note (optional)",
                      rows: 2 %>
              <% end %>
            </div>

            <div class="d-flex justify-content-end gap-2">
              <button type="button" class="btn btn-secondary"
                      data-bs-dismiss="modal">Cancel</button>
              <%= form.submit "Add Activity", class: "btn btn-success border-dark" %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
  </div>

  <script>
    (function() {
      var modal = document.getElementById('add-activity-modal');
      modal.addEventListener('show.bs.modal', function(event) {
        var trigger = event.relatedTarget;
        modal.querySelector('#activity_date').value = trigger.getAttribute('data-date') || '';
        modal.querySelector('#activity_block').value = trigger.getAttribute('data-block') || '';
      });
      modal.addEventListener('shown.bs.modal', function() {
        modal.querySelector('#activity_title').focus();
      });
    })();
  </script>
  ```

  **How the JS works:**
  - `show.bs.modal` fires before the modal is visible. `event.relatedTarget` is the element that triggered it (the + button). The handler copies `data-date` and `data-block` into the hidden date field and the timeslot select. If `data-block` is absent (month view), the select value becomes `''`, which matches the prompt option.
  - `shown.bs.modal` fires after the animation completes and focuses the title field.
  - The IIFE prevents variable leakage onto the global scope.

- [ ] **Step 2: Commit**

  ```bash
  git add app/views/activities/_add_activity_modal.html.erb
  git commit -m "Add shared _add_activity_modal partial with JS pre-fill"
  ```

---

### Task 4: Update day view

**Files:**
- Modify: `app/views/activities/day.html.erb`

**Interfaces:**
- Consumes: `_add_activity_modal` partial from Task 3.
- Consumes: `@timeslots`, `@activities` from controller.

- [ ] **Step 1: Replace `day.html.erb`**

  Full replacement — read the current file first to confirm nothing was added since this plan was written, then write:

  ```erb
  <%# Disable Turbo page caching for this page %>
  <% content_for(:body_attributes) do %>
    data-turbo-cache="false"
  <% end %>

  <div style="max-width: 900px; margin: 0 auto;">

  <%= calendar number_of_days: 1, events: @activities do |date, activities| %>
    <% @timeslots.each do |timeslot| %>
      <% @filtered = activities.select{|a| a.block == timeslot.position} %>
      <% @collapseID = "blockID" + timeslot.label.to_s.sub(/:/, '_') %>
      <div class="list-group mb-3 mx-3">
        <div class="list-group-item list-group-item-active fs-5 fw-bold block-header border-dark d-flex align-items-center justify-content-between <%= block_css_class(timeslot.position) %>">
          <a href="#<%= @collapseID %>" data-bs-toggle="collapse"
             class="link-light text-decoration-none flex-grow-1 text-center"
             aria-expanded="true" aria-controls="<%= @collapseID %>">
            <%= timeslot.label %>
          </a>
          <button type="button" class="btn btn-sm btn-outline-light ms-2"
                  data-bs-toggle="modal" data-bs-target="#add-activity-modal"
                  data-date="<%= date %>" data-block="<%= timeslot.position %>">
            <i class="bi bi-plus"></i>
          </button>
        </div>
        <div id="<%= @collapseID %>" class="collapse show">
          <% @filtered.each do |activity| %>
            <%= link_to activity.title, activity_path(activity, ref: 'day'),
                  class: "list-group-item list-group-item-action list-group-item-secondary block-item border-dark" %>
          <% end %>
        </div>
      </div>
    <% end %>
  <% end %>

  <%= render 'add_activity_modal' %>

  </div><%# end max-width wrapper %>
  ```

  **Key changes from original:**
  - Removed `unless @filtered.empty?` guard — all timeslots now always render.
  - Header changed from `<a>` wrapper to `<div>` with `d-flex justify-content-between`. Inner `<a class="link-light ...">` is the collapse toggle; + button is on the right.
  - Bottom "Add Activity" card removed.
  - `<%= render 'add_activity_modal' %>` added at the bottom.

- [ ] **Step 2: Commit**

  ```bash
  git add app/views/activities/day.html.erb
  git commit -m "Day view: always show all timeslots, add + button per timeslot, modal replaces bottom form"
  ```

---

### Task 5: Update week view

**Files:**
- Modify: `app/views/activities/week.html.erb`

**Interfaces:**
- Consumes: `_add_activity_modal` partial from Task 3.
- Consumes: `@timeslots`, `@activities` from controller.

- [ ] **Step 1: Replace `week.html.erb`**

  Full replacement — read the current file first to confirm nothing changed, then write:

  ```erb
  <%# Disable Turbo page caching for this page %>
  <% content_for(:body_attributes) do %>
    data-turbo-cache="false"
  <% end %>

  <div class="card bg-dark bg-gradient text-white mt-2 mb-3">
    <div class="card-body text-center">
      <%= form_tag root_path, method: :get do %>
        <%= label_tag :start_date, "Go to the week of: ", class: "align-middle fs-5" %>
        <%= date_field_tag :start_date, :start_date, class: "align-middle fs-5" %>
        <%= button_tag(type: "submit", class: "btn btn-info") do %>
          <i class="bi bi-search"></i>
        <% end %>
      <% end %>
    </div>
  </div>

  <%= week_calendar events: @activities do |date, activities| %>
    <%= link_to day_view_path(:start_date => date), {class: "btn btn-secondary mb-2", style: "height: 2.5em;"} do %>
      <b><%= date.strftime("%m/%d") %></b>
    <% end %>
    <% @timeslots.each do |timeslot| %>
      <% @filtered = activities.select{|a| a.block == timeslot.position} %>
      <% @collapseID = "blockID" + timeslot.label.to_s.sub(/:/, '_') + date.to_s %>
      <div class="list-group mb-2">
        <div class="list-group-item list-group-item-active block-header border-dark d-flex align-items-center justify-content-between <%= block_css_class(timeslot.position) %>">
          <a href="#<%= @collapseID %>" data-bs-toggle="collapse"
             class="link-light text-decoration-none flex-grow-1 text-center"
             aria-expanded="true" aria-controls="<%= @collapseID %>">
            <%= timeslot.label %>
          </a>
          <button type="button" class="btn btn-sm btn-outline-light ms-2"
                  data-bs-toggle="modal" data-bs-target="#add-activity-modal"
                  data-date="<%= date %>" data-block="<%= timeslot.position %>">
            <i class="bi bi-plus"></i>
          </button>
        </div>
        <div id="<%= @collapseID %>" class="collapse show">
          <% @filtered.each do |activity| %>
            <%= link_to activity.title.truncate(16), activity,
                  class: "list-group-item list-group-item-action list-group-item-secondary block-item border-dark" %>
          <% end %>
        </div>
      </div>
    <% end %>
  <% end %>

  <%= render 'add_activity_modal' %>
  ```

  **Key changes from original:**
  - Removed `unless @filtered.empty?` guard per day column.
  - Header restructured to `<div>` with inner collapse `<a>` and + button.
  - Bottom "Add Activity" card removed.
  - `<%= render 'add_activity_modal' %>` added at the bottom (rendered once, not inside the calendar block).

- [ ] **Step 2: Commit**

  ```bash
  git add app/views/activities/week.html.erb
  git commit -m "Week view: always show all timeslots, add + button per timeslot, modal replaces bottom form"
  ```

---

### Task 6: Update month view

**Files:**
- Modify: `app/views/activities/month.html.erb`

**Interfaces:**
- Consumes: `_add_activity_modal` partial from Task 3.
- Consumes: `@activities` from controller. `@timeslots` available via Task 2's controller change.

- [ ] **Step 1: Replace `month.html.erb`**

  Full replacement — read the current file first to confirm nothing changed, then write:

  ```erb
  <%# Disable Turbo page caching for this page %>
  <% content_for(:body_attributes) do %>
    data-turbo-cache="false"
  <% end %>

  <div class="card bg-dark bg-gradient text-white mt-2 mb-3">
    <div class="card-body text-center">
      <label for="month-search" class="align-middle fs-5 me-2">Search activities:</label>
      <input type="text" id="month-search" class="form-control d-inline-block w-auto align-middle fs-5" placeholder="Type to filter...">
    </div>
  </div>

  <%= month_calendar events: @activities do |date, activities| %>
    <div class="month-day-cell position-relative"
         data-date="<%= date.to_s %>"
         data-titles="<%= activities.map(&:title).join('|') %>">
      <a href="<%= day_view_path(:start_date => date) %>">
        <div class="date-color fw-bold fs-6 badge">
          <%= date.strftime("%d") %>
        </div>
        <% unless activities.empty? %>
          <div class="activity-dots mt-1">
            <% activities.first(5).each do %>
              <span class="activity-dot"></span>
            <% end %>
            <% if activities.count > 5 %>
              <span class="activity-dot-overflow">+<%= activities.count - 5 %></span>
            <% end %>
          </div>
        <% end %>
      </a>
      <button type="button"
              class="btn btn-sm btn-outline-secondary position-absolute top-0 end-0 add-day-btn"
              data-bs-toggle="modal" data-bs-target="#add-activity-modal"
              data-date="<%= date.to_s %>">
        <i class="bi bi-plus"></i>
      </button>
      <div class="search-matches"></div>
    </div>
  <% end %>

  <%= render 'add_activity_modal' %>

  <script>
    document.getElementById('month-search').addEventListener('input', function() {
      var query = this.value.toLowerCase().trim();
      document.querySelectorAll('.month-day-cell').forEach(function(cell) {
        var matchesDiv = cell.querySelector('.search-matches');
        matchesDiv.innerHTML = '';
        cell.classList.remove('search-highlight');
        if (!query) return;
        var titles = (cell.dataset.titles || '').split('|').filter(Boolean);
        var matched = titles.filter(function(t) { return t.toLowerCase().indexOf(query) !== -1; });
        if (matched.length > 0) {
          cell.classList.add('search-highlight');
          matched.forEach(function(title) {
            var el = document.createElement('div');
            el.className = 'search-match-title';
            el.textContent = title.length > 28 ? title.substring(0, 28) + '…' : title;
            matchesDiv.appendChild(el);
          });
        }
      });
    });
  </script>
  ```

  **Key changes from original:**
  - Added `position-relative` to `.month-day-cell` div.
  - Added `<button ... class="... position-absolute top-0 end-0 ...">` with only `data-date` (no `data-block`) — the modal's timeslot select will start on the prompt.
  - Bottom "Add Activity" card removed.
  - `<%= render 'add_activity_modal' %>` added before the search script.

  **Note on layout:** The existing `td a { display:block; width:100%; height:100%; }` in `simple_calendar.scss` makes the date link fill the cell. The + button is absolutely positioned on top of it. Because the button is a later sibling in the DOM and is positioned, it stacks above the link and intercepts clicks correctly — no z-index override needed.

- [ ] **Step 2: Commit**

  ```bash
  git add app/views/activities/month.html.erb
  git commit -m "Month view: add + button per day cell, modal replaces bottom form"
  ```

---

### Task 7: Build on staging and validate

**Files:** None modified — this is a validation task.

- [ ] **Step 1: Build the staging image**

  From `/home/alec/docker/sped-planner-staging`:

  ```bash
  docker compose up -d --build
  ```

- [ ] **Step 2: Check logs for errors**

  ```bash
  docker compose logs app --since 5m | grep -iE "error|warn|fatal"
  ```

- [ ] **Step 3: Confirm the app responds**

  ```bash
  docker compose exec -T app curl -sI \
    -H "Host: planner-staging.oddbox.tech" \
    -H "X-Forwarded-Proto: https" \
    http://localhost:3000
  ```

  Expect: `HTTP/1.1 302 Found` (redirect to login).

- [ ] **Step 4: Manual browser validation**

  Visit `https://planner-staging.oddbox.tech` and log in. Verify:

  1. **Week view (root):** every timeslot row appears on every day column, even those with no activities. Each row header has a visible + button on the right. The bottom "Add Activity" card is gone.
  2. **+ button on week view:** click a + button on a specific day/timeslot. Modal opens. Title field is focused. Date hidden field is pre-filled (check browser dev tools on the hidden input). Timeslot select shows the correct timeslot pre-selected. Fill in a title and submit. Redirected back; new activity appears in the correct slot.
  3. **+ button with optional note:** open the modal again, fill title and note body. Submit. Navigate to the new activity's show page — a note should be attached.
  4. **+ button without note:** open the modal, fill title only (leave note blank). Submit. Navigate to the activity — no note attached.
  5. **Day view:** same + button behavior as week. Date is pre-filled correctly for that specific day.
  6. **Month view:** each day cell has a + button in the top-right corner. Clicking it opens the modal. The timeslot select starts on the prompt (user must choose). Date is pre-filled from the day cell. Submit creates the activity.
  7. **Collapse still works:** clicking a timeslot label (not the + button) still toggles the collapse on day and week views.
