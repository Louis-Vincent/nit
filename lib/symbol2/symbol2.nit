
redef class Sys

        protected var sym_table = new HashMap[String, Symbol]

        fun sym(str: String): Symbol
        do
                return sym_table.get_or_default(str, new Symbol(str))
        end
end

class Symbol
	super Symbolic
        protected var name: String # String representation

        redef fun to_s do return name
	redef fun to_sym do return self
end

# Base class for all object who can represented by a `Symbol`.
abstract class Symbolic
	fun to_sym: Symbol is abstract
end
