
redef class Sys

        protected var sym_table = new HashMap[Int, Symbol]

        fun sym(str: String): Symbol
        do
                var hstr = str.hash
                var maybe_sym = sym_table.get_or_null(hstr)
                if maybe_sym == null then
                        var res = new Symbol(str)
                        sym_table[hstr] = res
                        return res
                else
                        return maybe_sym
                end
        end
end

class Symbol
        protected var name: String # String representation

        redef fun to_s
        do
                return name
        end
end
