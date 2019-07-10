import functional

fun toto(x: Int): Int
do 
       return x + 1
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


print f.call(100)
