import functional


class A
        var y = 10
        fun titi(x: Int)
        do
                print "in titi: {x+y}"
        end
end


class B
        fun tutu
        do
                print "in tutu"
        end

        fun toto(x: String)
        do
                print "in toto: {x}"
        end
end

var a = new A
var b = new B

var f = &a.titi

a.titi(100)
f.call(1000)
