require "test_helper"

class ActivityTest < ActiveSupport::TestCase
  test "requires title, date, and block" do
    activity = Activity.new
    assert_not activity.valid?
    assert_includes activity.errors[:title], "can't be blank"
    assert_includes activity.errors[:date], "can't be blank"
    assert_includes activity.errors[:block], "can't be blank"
  end

  test "is valid with title, date, and block" do
    activity = Activity.new(title: "Test", date: Date.today, block: 1)
    assert activity.valid?
  end

  test "destroys associated notes when destroyed" do
    activity = activities(:one)
    note_count = activity.notes.count
    assert_operator note_count, :>, 0, "fixture should give activities(:one) at least one note"
    assert_difference -> { Note.count }, -note_count do
      activity.destroy
    end
  end

  # ---------------------------------------------------------------------------
  # Association — non-standard FK (block / position)
  # ---------------------------------------------------------------------------

  test "resolves timeslot via block/position foreign key" do
    assert_equal timeslots(:morning), activities(:one).timeslot
  end

  test "timeslot is optional — valid when block has no matching timeslot" do
    activity = Activity.new(title: "Orphan", date: Date.today, block: 999)
    assert activity.valid?
  end

  # ---------------------------------------------------------------------------
  # default_scope ordering
  # ---------------------------------------------------------------------------

  test "orders by block ascending by default" do
    blocks = Activity.all.map(&:block)
    assert_equal blocks.sort, blocks
  end

  # ---------------------------------------------------------------------------
  # start_time
  # ---------------------------------------------------------------------------

  test "start_time returns the activity date" do
    activity = activities(:one)
    assert_equal activity.date, activity.start_time
  end
end
