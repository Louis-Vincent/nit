import temp4

class Foo[E]
	type ARR: nullable E
	var x: E
end

redef class Toto

	init
	do
		print "toto module 3 {self}"
	end

	fun foo(y: nullable Int)
	do
		if y == null then
			print "y is null"
		else
			print "y is {y}"
		end
	end
end

var t = new Toto(10)
t.create
t.foo(null)
t.foo(10)
