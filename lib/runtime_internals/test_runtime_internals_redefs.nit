import test_runtime_internals_base

redef class Z1
	redef fun p1
	do
		return "redef Z:p1"
	end
end

class Z2
	super Z1

	redef fun p1
	do
		return "Z2:p1"
	end
end

class Z3
	super Z2

	redef fun p1
	do
		return "Z3:p1"
	end

	fun p2
	do
		return "Z3:p2"
	end
end

class Z4
	super Z2
end

class Z5
	super Z3
	super Z4
end
