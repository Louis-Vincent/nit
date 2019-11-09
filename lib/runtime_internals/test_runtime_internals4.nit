import runtime_internals

class A[E]
	var p1: E
end

class B
	var x: Int
	var y: Int
	var z: Int is noinit
	init
	do
		z = x + y
	end
end

abstract class C
	var x: Int
	var y: Int

	new(x: Int, y: Int)
	do
		if x + y > 10 then
			return new C1(x,y)
		else
			return new C2(x,y)
		end
	end
end

class C1
	super C
	var z: Int is noinit
	init
	do
		z = x + y
	end
end

class C2
	super C
end

fun get_prop(name: String, ty: TypeInfo): PropertyInfo
do
	for p in ty.properties do
		if p.name == name then return p
	end
	abort
end

var tA = type_repo.get_type("A").as(not null)
var tB = type_repo.get_type("B").as(not null)
var tC = type_repo.get_type("C").as(not null)
var tC1 = type_repo.get_type("C1").as(not null)
var tInt = type_repo.get_type("Int").as(not null)
var tA_Int = tA.resolve([tInt])
var p1 = get_prop("_p1", tA_Int).as(AttributeInfo)
print p1.dynamic_type(tA_Int)

var b1 = tB.new_instance([1,10]).as(B)
assert b1.z == 11

var c1 = tC.new_instance([1,10])
var c2 = tC.new_instance([1,1])
var c3 = tC1.new_instance([10, 100])
assert c1 isa C1
assert c1.z == 11
assert c2 isa C2
assert c3 isa C1
assert c3.z == 110
