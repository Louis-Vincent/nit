
redef class Sys

        protected var sym_table = new HashMap[String, Symbol]

        fun sym(str: String): Symbol
        do
                return sym_table.get_or_default(str, new Symbol(str))
        end
end

class Symbol
        protected var name: String # String representation

        redef fun to_s
        do
                return name
        end
end
