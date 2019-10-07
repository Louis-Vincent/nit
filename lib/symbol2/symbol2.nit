
redef class Sys
        fun sym(str: String): Symbol is intern
end

class Symbol
	super Symbolic
        protected var name: String # String representation

        redef fun to_s do return name
	redef fun to_sym do return self
end

# Base class for all object who can be represented by a `Symbol`.
abstract class Symbolic
	fun to_sym: Symbol is abstract
end
