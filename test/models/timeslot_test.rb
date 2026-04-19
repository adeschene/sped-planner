require "test_helper"

class TimeslotTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  test "is valid with label and position" do
    timeslot = Timeslot.new(label: "Late Block", position: 3)
    assert timeslot.valid?
  end

  test "requires label" do
    timeslot = Timeslot.new(position: 3)
    assert_not timeslot.valid?
    assert_includes timeslot.errors[:label], "can't be blank"
  end

  test "requires position" do
    timeslot = Timeslot.new(label: "Late Block")
    assert_not timeslot.valid?
    assert_includes timeslot.errors[:position], "can't be blank"
  end

  test "requires position to be unique" do
    timeslot = Timeslot.new(label: "Duplicate", position: timeslots(:morning).position)
    assert_not timeslot.valid?
    assert_includes timeslot.errors[:position], "has already been taken"
  end

  test "requires position to be an integer" do
    timeslot = Timeslot.new(label: "Bad", position: 1.5)
    assert_not timeslot.valid?
    assert_includes timeslot.errors[:position], "must be an integer"
  end

  test "requires position to be zero or greater" do
    timeslot = Timeslot.new(label: "Bad", position: -1)
    assert_not timeslot.valid?
    assert_includes timeslot.errors[:position], "must be greater than or equal to 0"
  end

  # ---------------------------------------------------------------------------
  # Association — non-standard FK (block / position)
  # ---------------------------------------------------------------------------

  test "resolves activities via block/position foreign key" do
    assert_includes timeslots(:morning).activities, activities(:one)
  end

  test "does not include activities from a different block" do
    assert_not_includes timeslots(:morning).activities, activities(:two)
  end

  # ---------------------------------------------------------------------------
  # dependent: :nullify
  # ---------------------------------------------------------------------------

  test "destroying a timeslot nullifies block on its activities rather than deleting them" do
    morning = timeslots(:morning)
    activity = activities(:one)
    assert_equal morning.position, activity.block

    assert_no_difference "Activity.count" do
      morning.destroy
    end

    assert_nil activity.reload.block
  end

  # ---------------------------------------------------------------------------
  # default_scope ordering
  # ---------------------------------------------------------------------------

  test "orders by position ascending by default" do
    positions = Timeslot.all.map(&:position)
    assert_equal positions.sort, positions
  end
end
