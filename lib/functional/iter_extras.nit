import functional



redef interface Iterator[E]
        fun map(f: Func1[E,Object]): MapIter[E,Object]
        do
                return new MapIter[E,Object](self, f)
        end
end

private abstract class FuncIter[E]
        super Iterator[E]
        var iter: Iterator[E]
        var curr: E is noinit

        redef fun item: E
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
        super FuncIter[A]
        var f: Func1[A, B]
        redef init
        do
                super
                curr = f.call(iter.item)
        end
        
        redef fun next
        do
                super
                curr = f.call(iter.item)
        end
        
end


class FilterIter[E]
        super FuncIter[E]
        var sat: Func1[E, Bool]
        
        redef init
        do
                super
                var x = iter.item
                if sat.call(x) then
                        curr = x
                else
                        next
                end
        end

        redef fun item: E
        do
                return curr
        end
        
        redef fun next
        do
                loop
                        iter.next
                        var x = iter.item
                        if sat.call(x) then
                                curr = x
                                break
                        end
                end
        end
end

