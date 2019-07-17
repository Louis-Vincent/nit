import functional


class A
        var y = 10
        fun titi(x: Int)
        do
                print "in titi: {x+y}"
        end
end

class B[E]
        fun tete(x: E)
        do
                print "in tete: {x.as(not null)}"
        end
end

var a = new A
var b = new B[Int]
var f = &a.titi
var g = &b.tete
g.call(100)
f.call(10)
