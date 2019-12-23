import runtime_internals

class A
	var x: Int
end

class B[T1,T2]
end

var m = rti_repo

var a1 = new A(1)
var b1 = new B[Int, String]

print m.classof(a1)

var b_class = m.classof(b1)
for tp in b_class.type_parameters do
	print tp.name
	print tp.bound.name
end

var t1 = m.object_type(b1)
print t1.name

for ta in t1.type_arguments do
	print ta.name
end
