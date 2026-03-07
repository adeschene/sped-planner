module ActivityHelper
	BLOCK_CSS_CLASSES = [
		"nine_thirty_block",
		"ten_thirty_block",
		"eleven_thirty_block",
		"lunch_block",
		"one_block",
		"two_block",
		"three_block"
	]

	def isToday(dateToCheck)
  		return dateToCheck == Date.current ? "today" : ""
	end

	def block_css_class(position)
		BLOCK_CSS_CLASSES[position % BLOCK_CSS_CLASSES.length]
	end
end
