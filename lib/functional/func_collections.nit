
module func_collections 
import functional

redef class Array[E]                
        fun for_each(f: Func1[E, Unit])
        do
                for x in self do
                        f.call(x)
                end
        end

        fun map(f: Func1[E,Object]) : Array[Object]
        do      
                var res = new Array[Object]
                for x in self do
                        res.push(f.call(x))
                end
                return res 
        end


        fun foldl(f: Func2[Object, E, Object], acc: Object): Object
        do    
                for x in self do
                        acc = f.call(acc,x) 
                end
                return acc
        end

        fun foldl1(f: Func2[E,E,E]): E 
        do
                var x = f.call(self[0], self[1])
                for i in [2..length[ do
                        x = f.call(x,self[i])
                end
                return x
        end



        fun foldr(f: Func2[E, Object, Object], acc: Object): Object
        do
                for x in self.reverse_iterator do
                        acc = f.call(x, acc)
                end
                return acc
        end
end

# In place data manipulation inside an hashmap
# Provides a Monad-like structure to do computation, i.e you can chain the entry
# manipulation to a certain extend.
abstract class Entry[K,V]
        var hmap: HashMap[K,V]
        var key: K

        fun and_modify(f: Func1[V, Unit]): Entry[K,V] do
                return self
        end

        fun or_insert(x: V): V is abstract

        fun or_insert_with(x: ConstFn[V]): V is abstract
end

class Vacant[K,V]
        super Entry[K,V]
        
        redef fun or_insert(x: V): V 
        do
                hmap[key] = x
                return hmap[key]
        end

        redef fun or_insert_with(f: ConstFn[V]): V
        do
                hmap[key] = f.call
                return hmap[key]
        end
end

class Occupied[K,V]
        super Entry[K,V]

        redef fun or_insert(x: V): V
        do
                return hmap[key]
        end
                
        
        redef fun or_insert_with(f: ConstFn[V]): V
        do
                # duplicate from or_insert
                return hmap[key]
        end

        redef fun and_modify(f: Func1[V, Unit]): Entry[K,V] do
                f.call(hmap[key])
                return self
        end
end

redef class HashMap[K,V]
        fun entry(k: K): Entry[K,V] do
                if has_key(k) then
                        return new Occupied[K,V](self, k)
                end
                return new Vacant[K,V](self, k)
        end
end


class InitArrayFn[E]
        super ConstFn[Array[E]]
        
        var initial_val: nullable E

        redef fun call: Array[E]
        do
                var xs = new Array[E]
                if initial_val != null then
                        xs.push(initial_val)
                end
                return xs
        end
end


fun new_int_arr(x: nullable Int): InitArrayFn[Int]
do
        return new InitArrayFn[Int](x)
end

# TODO: delete this part
var hmap = new HashMap[Int, Array[Int]]

var vs = hmap.entry(1).or_insert_with(new_int_arr(1))

print hmap[1]

