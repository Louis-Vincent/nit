import std_runtime_reflection

class A
	var x: Int
	fun foo do print x + 1
end

var a = new A(1)

var im = reflect(a)
print im.all_attributes
