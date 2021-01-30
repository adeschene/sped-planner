module ActivityHelper
	BLOCKS = [:"9:30AM",:"10:30AM",:"11:30AM",:"Lunch",:"1:00PM",:"2:00PM",:"3:00PM"]

	def isToday(dateToCheck)
  		return dateToCheck == Date.current ? "today" : ""
	end

	GETBLOCKCLASS = {
		"9:30AM"  => "nine_thirty_block",
		"10:30AM" => "ten_thirty_block",
		"11:30AM" => "eleven_thirty_block",
		"Lunch"   => "lunch_block",
		"1:00PM"  => "one_block",
		"2:00PM"  => "two_block",
		"3:00PM"  => "three_block"
	}
end
