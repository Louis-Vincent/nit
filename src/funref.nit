import functional
class A
        var y = 10
        fun titi(x: Int)
        do
                print "in titi: {x+y}"
        end
end

var a = new A
var f = &a.titi
a.titi(100)
f.call(1000)
