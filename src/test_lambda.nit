import functional

class A
        var x: Int

        #fun toto: Proc2[A, Int]
        #do
        #        var f = fun(a: A, amount: Int) do
        #                a.x += amount
        #        end
        #        return f
        #end

        fun titi(f: Fun1[Int, Int])
        do
                x += f.call(x)
        end


        fun tutu: Fun0[Int]
        do
                var f = fun: Int do
                        return 10
                end
                return f
        end

end

var f = fun(x: Int): Int
do
        return x + 1
end

var f2: Fun1[Int, Int] = f
#
assert f.call(1) == 2
assert f.call(0) == 1
assert f.call(-1) == 0
assert f2.call(1) == 2
#
#var a = new A(10)
#assert a.tutu.call == 10
#var g = a.toto
#g.call(a, 100)
#g.call(a, 1000)
#assert a.x == 1110
#
#a.titi(f)
#assert a.x == 1111


