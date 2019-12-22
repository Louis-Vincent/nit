import runtime_internals

class A
	var x: Int
end

var m = rti_repo

var a1 = new A(1)

print m.classof(a1)

