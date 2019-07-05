module func_collections
import iter_extras


# In place data manipulation inside an hashmap
# Provides a Monad-like structure to do computation over hashmap entries.
abstract class Entry[K,V]
        var map: Map[K,V]
        var key: K


        # If the entry is occupied, then it applies the function
        # to the underlying element. Otherwise, nothing is done.
        fun and_do(f: Proc1[V]): Entry[K,V] do
                return self
        end

        # If the entry is vacant, assign the value `x` as the default
        # value in the `Map`.
        fun or_insert(x: V): V is abstract

        # Same as `Entry::or_insert` except the value is provided by a function.
        fun or_insert_with(x: Fun0[V]): V is abstract
end

# The entry (key) in the hashmap doesn't exist
class Vacant[K,V]
        super Entry[K,V]

        redef fun or_insert(x)
        do
                map[key] = x
                return map[key]
        end

        redef fun or_insert_with(f)
        do
                return or_insert(f.call)
        end
end

# The entry (key) in the hashmap exists
class Occupied[K,V]
        super Entry[K,V]

        redef fun or_insert(x)
        do
                return map[key]
        end


        redef fun or_insert_with(f)
        do
                # duplicate from or_insert
                return map[key]
        end

        redef fun and_do(f)
        do
                f.call(map[key])
                return self
        end
end

redef interface Map[K,V]

        # A view over a key-value pair.
        fun entry(k: K): Entry[K,V] do
                if has_key(k) then
                        return new Occupied[K,V](self, k)
                end
                return new Vacant[K,V](self, k)
        end
end
