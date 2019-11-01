import runtime_internals
#import test_runtime_internals1
#import test_runtime_internals2

class A
	fun p1: Int do return 1
end

class B[E]
	super A
	redef fun p1: Int do return 10
end

class C
	super B[Int]
end

class D[E]
	super B[E]
end

var a = type_repo.get_type("A")
var b = type_repo.get_type("B")
var c = type_repo.get_type("C")
var d = type_repo.get_type("D")
var int = type_repo.get_type("Int")

print a
print b
print c.supertypes.to_a
print d.supertypes.to_a
print a.properties.to_a

var p1_prop: nullable PropertyInfo = null

for prop in b.properties.to_a do
	if prop.to_s == "p1" then
		p1_prop = prop
	end
end
assert p1_prop != null

print p1_prop
print p1_prop != p1_prop.parent
print p1_prop.parent == p1_prop.parent.parent.parent
print p1_prop.owner
assert p1_prop isa MethodInfo
var b1 = new B[Int]
print p1_prop.call([b1]).as(not null)

var b_int = b.resolve([int])
print b_int
print b.type_param_bounds
