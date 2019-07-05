# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2019-2020 Louis-Vincent Boudreault <lv.boudreault95@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import functional_types
import cartesian

redef interface Iterator[E]

        # Applies a function to every elements
        fun map(f: Fun1[E,Object]): MapIter[E,Object]
        do
                return new MapIter[E,Object](self, f)
        end

        # Iterator that gives the current count and element
        fun enumerate: EnumerateIter[E]
        do
                return new EnumerateIter[E](self)
        end

        # Iterator that filters elements by a predicate
        fun filter(pred: Fun1[E,Bool]): FilterIter[E]
        do
                return new FilterIter[E](self,pred)
        end


        # Checks if one element respects a predicate in the iterator
        fun any(pred: Fun1[E,Bool]): Bool
        do
                for x in self do
                        if pred.call(x) then
                                return true
                        end
                end
                return false
        end

        # Checks if all elements respect a predicate in the iterator
        fun all(pred: Fun1[E,Bool]): Bool
        do
                for x in self do
                        if not pred.call(x) then
                                return false
                        end
                end
                return true
        end


        # Folds an iterator from the left
        fun fold(acc: Object, f: Fun2[Object, E, Object]): Object
        do
                for x in self do
                        acc = f.call(acc, x)
                end
                return acc
        end

        # Folds and apply two element at a time
        #
        # requires at least 2 element in the iterator
        fun fold1(f: Fun2[E,E,E]): E
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
        fun for_each(f: Proc1[E])
        do
                for x in self do
                        f.call(x)
                end
        end

        # Maps every element to a nested structure then flattens it
        fun flat_map(f: Fun1[E, Iterator[Object]]): FlatMapIter[E]
        do
                return new FlatMapIter[E](self, f)
        end

end

# Base class for all iterators using functional types.
private abstract class FunIter[OLD,NEW]
        super Iterator[NEW]
        var my_iter: Iterator[OLD]

        redef fun next
        do
                my_iter.next
        end

        redef fun start
        do
                my_iter.start
        end

        redef fun finish
        do
                my_iter.finish
        end

        redef fun is_ok
        do
                return my_iter.is_ok
        end
end


class MapIter[A,B]
        super FunIter[A,B]
        var f: Fun1[A, B]

        redef fun item
        do
                return f.call(my_iter.item)
        end

end

class EnumerateIter[E]
        super FunIter[E, Pair[Int,E]]

        redef fun item
        do
               return new Pair[Int,E](0, my_iter.item)
        end
end

class FilterIter[E]
        super FunIter[E,nullable E]
        var pred: Fun1[E, Bool]

        redef init
        do
                super
                if is_ok and not pred.call(my_iter.item) then
                        next
                end
        end

        redef fun item
        do
                assert is_ok
                return my_iter.item
        end


        redef fun next
        do
                loop
                        my_iter.next
                        if not is_ok then
                                break
                        end
                        var x = my_iter.item
                        if pred.call(x) then
                                break
                        end
                end
        end
end

class FlatMapIter[E]
        super FunIter[E,Object]
        var f: Fun1[E, Iterator[Object]]
        var buffer: Iterator[Object] is noinit

        redef init
        do
                super
                buffer = f.call(my_iter.item)
        end

        redef fun item
        do
                return buffer.item
        end

        redef fun next
        do
                buffer.next
                if not buffer.is_ok then
                        super
                        if is_ok then
                                buffer = f.call(my_iter.item)
                        end
                end
        end
end
