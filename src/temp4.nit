
interface Tata
end

redef class Int
	super Tata
end

interface Foo
	init
	do
		print "in Foo:default init"
	end

	init foo
	do
		print "in Foo::foo init"
	end

	new(x: Int)
	do
		return new Toto(x)
	end
end

abstract class Temp[E]

	new(x: Int)
	do
		if x == 0 then
			return new Temp1[Int]
		end
		if x == 2 then
			return new Temp2[String]
		end
		return new Temp1[Temp[Int]]
	end
end

class Temp1[E]
	super Temp[E]
end
class Temp2[E]
	super Temp[E]
end

class Toto
	super Foo
	var x: Int
	init
	do
		print "In Toto::default init"
	end

	fun create: Toto
	do
		return new Toto(100)
	end
end

var t = new Toto(10)
var t2 = new Temp[Int](0)
var t3 = new Foo(100)

print "t4 instance"
var t4 = new Toto.foo
print t4.x

print "t5 instance"

