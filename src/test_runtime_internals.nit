import runtime_internals
#import test_runtime_internals1
#import test_runtime_internals2

class A
end

class B[E]
	super A
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

print a
print b
print c.supertypes.to_a
print d.supertypes.to_a

print a.properties.to_a

