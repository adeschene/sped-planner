module ActivityHelper
	BLOCKS = [
		"9:30AM",
		"10:30AM",
		"11:30AM",
		"Lunch",
		"1:00PM",
		"2:00PM",
		"3:00PM"
	]

	def isToday(dateToCheck)
  		return dateToCheck == Date.current ? "today" : ""
	end

	GETBLOCKCLASS = [
		"nine_thirty_block",
		"ten_thirty_block",
		"eleven_thirty_block",
		"lunch_block",
		"one_block",
		"two_block",
		"three_block"
	]
end
