# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# Seed the default timeslots (positions 0-6 match existing activity.block values)
["9:30AM", "10:30AM", "11:30AM", "Lunch", "1:00PM", "2:00PM", "3:00PM"].each_with_index do |label, pos|
  Timeslot.find_or_create_by!(position: pos) { |t| t.label = label }
end
