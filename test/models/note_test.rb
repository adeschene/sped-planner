require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "is valid with body and activity" do
    note = Note.new(body: "Great session", activity: activities(:one))
    assert note.valid?
  end

  test "requires body" do
    note = Note.new(activity: activities(:one))
    assert_not note.valid?
    assert_includes note.errors[:body], "can't be blank"
  end

  test "requires activity" do
    note = Note.new(body: "Great session")
    assert_not note.valid?
    assert_includes note.errors[:activity], "must exist"
  end

  test "belongs to its activity" do
    assert_equal activities(:one), notes(:one).activity
  end
end
