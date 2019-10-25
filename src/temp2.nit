
redef class Object
	fun tata(x: Int): Int
	do
		return x + 1
	end
end

redef class Int
	redef fun tata(x)
	do
		return super + self
	end
end

class Toto
	var y: Int
	fun titi(x: Int)
	do
		print x + y
	end
end

class Tata
	super Toto

	redef fun titi(x)
	do
		print x + y +1
	end
end

var t1 = new Toto(10)
var t2 = new Tata(100)
t1.titi(1)
t2.titi(1)
