import functional

fun toto(x: Int): Int
do
       return x + 1
end

fun tata(p: Proc0)
do
        p.call
end

fun tutu
do
        print "tutu"
end

class A
        var y = 10
        fun titi(x: Int): Int
        do
                return x + 1 + y
        end
end

var a = new A
var f = &a.titi
var g = &tutu

tata g
print f.call(100)
