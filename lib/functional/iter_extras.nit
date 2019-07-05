import functional
import cartesian

# Remark: a collector corresponds to a fold
interface Collector[E,RESULT]

        # The accumulator function
        fun collect(x: E) is abstract

        # Collapse the accumulated result into RESULT
        fun finish: RESULT is abstract
end

# Collects result inside an array
class ArrayCollector[E]
        super Collector[E, Array[E]]
        protected var acc = new Array[E]

        redef fun collect(x: E)
        do
                acc.push(x)
        end


        redef fun finish: Array[E]
        do
                return acc
        end
end

# Collector for Char iterators
class StringCollector
        super Collector[Char, String]
        private var str = new Buffer

        redef fun collect(c: Char)
        do
                str.add(c)
        end

        redef fun finish: String
        do
                return str.to_s
        end
end

redef interface Iterator[E]

        # Syntax shortcut
        fun iter: Iterator[E]
        do
                return iterator
        end

        # Applies a function to every elements
        fun map(f: Func1[E,Object]): MapIter[E,Object]
        do
                return new MapIter[E,Object](self, f)
        end

        # Iterator that gives the current count and element
        fun enumerate: EnumerateIter[E]
        do
                return new EnumerateIter[E](self)
        end

        # Iterator that filters elements by a predicate
        fun filter(pred: Func1[E,Bool]): FilterIter[E]
        do
                return new FilterIter[E](self,pred)
        end


        # Checks if one element respects a predicate in the iterator
        fun any(pred: Func1[E,Bool]): Bool
        do
                for x in self do
                        if pred.call(x) then
                                return true
                        end
                end
                return false
        end

        # Checks if all elements respect a predicate in the iterator
        fun all(pred: Func1[E,Bool]): Bool
        do
                for x in self do
                        if not pred.call(x) then
                                return false
                        end
                end
                return true
        end


        # Folds an iterator from the left
        fun fold(acc: Object, f: Func2[Object, E, Object]): Object
        do
                for x in self do
                        acc = f.call(acc, x)
                end
                return acc
        end

        # Folds and apply two element at a time
        #
        # requires at least 2 element in the iterator
        fun fold1(f: Func2[E,E,E]): E
        do
                var a1 = item
                next
                var a2 = item
                next
                var res = f.call(a1,a2)
                for x in self do
                        res = f.call(res, x)
                end
                return res
        end

        # Apply a mutation function over all elements
        fun for_each(f: Func1[E, Unit])
        do
                for x in self do
                        f.call(x)
                end
        end

        # Maps every element to a nested structure then flattens it
        fun flat_map(f: Func1[E, Iterator[Object]]): FlatMapIter[E]
        do
                return new FlatMapIter[E](self, f)
        end

        # Folds the iterator using the collector's `collect` function.
        fun collect(collector: Collector[E,Object]): Object
        do
                for x in self do
                        collector.collect(x)
                end
                return collector.finish
        end

        fun to_array: Array[E]
        do
                var res = collect(new ArrayCollector[E])
                assert res isa Array[E] else
                        print "Error: collector used by to_array doesn't return an Array"
                end
                return res
        end
end

# Base class forall iterators using functional types.
private abstract class FuncIter[OLD,NEW]
        super Iterator[NEW]
        var iter: Iterator[OLD]
        var curr: NEW is noinit

        redef fun item: NEW
        do
                return curr
        end

        redef fun next
        do
                iter.next
        end

        redef fun start
        do
                iter.start
        end

        redef fun finish
        do
                iter.finish
        end

        redef fun is_ok: Bool
        do
                return iter.is_ok
        end
end

class MapIter[A,B]
        super FuncIter[A,B]
        var f: Func1[A, B]
        redef init
        do
                super
                curr = f.call(iter.item)
        end

        redef fun next
        do
                super
                if is_ok then
                        curr = f.call(iter.item)
                end
        end
end


class FilterIter[E]
        super FuncIter[E,E]
        var pred: Func1[E, Bool]

        redef init
        do
                super
                var x = iter.item
                if pred.call(x) then
                        curr = x
                else
                        next
                end
        end

        redef fun next
        do
                assert is_ok
                return my_iter.item
        end


        redef fun next
        do
                loop
                        iter.next
                        if not is_ok then
                                break
                        end
                        var x = iter.item
                        if pred.call(x) then
                                curr = x
                                break
                        end
                end
        end
end

class EnumerateIter[E]
        super FuncIter[E, Pair[Int,E]]

        redef init
        do
                super
                curr = new Pair[Int,E](0, iter.item)
        end


        redef fun next
        do
                super
                if is_ok then
                        curr = new Pair[Int,E](curr.e + 1, iter.item)
                end
        end
end


class FlatMapIter[E]
        super FuncIter[E,Object]
        var f: Func1[E, Iterator[Object]]
        var buffer: Iterator[Object] is noinit

        redef init
        do
                super
                buffer = f.call(iter.item)
                curr = buffer.item
        end

        redef fun next
        do
                buffer.next
                if buffer.is_ok then
                        curr = buffer.item
                else
                        super
                        if is_ok then
                                buffer = f.call(iter.item)
                                curr = buffer.item
                        end
                end
        end
end
