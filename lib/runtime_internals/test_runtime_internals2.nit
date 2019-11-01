module test_runtime_internals2
import runtime_internals
import test_runtime_internals_redefs

interface A
	fun p1: Int is abstract
	fun p2: Int is abstract
end

abstract class B
	var p3: Int
	var p4: Int
end

universal C
end

class D
	super A
	var p5: Int
	var p6: Int
end

fun get_prop(name: String, ty: TypeInfo): PropertyInfo
do
	for p in ty.properties do
		if p.to_s == name then return p
	end
	abort
end

fun test_A_supertypes do
	var a = type_repo.get_type("A")
	var object = type_repo.get_type("Object")
	var supertypes = a.supertypes.to_a
	print supertypes[0] == object
	assert supertypes == [object]
end

fun test_D_supertypes do
	var d = type_repo.get_type("D")
	var a = type_repo.get_type("A")
	var object = type_repo.get_type("Object")
	var supertypes = d.supertypes.to_a
	assert supertypes == [a, object]
end

fun test_is_interface_query_for_A do
	var my_A = type_repo.get_type("A")
	assert my_A.is_interface
	assert not my_A.is_abstract
	assert not my_A.is_generic
	assert not my_A.is_universal
end

fun test_is_abstract_query_for_B do
	var my_B = type_repo.get_type("B")
	assert my_B.is_abstract
	assert not my_B.is_interface
	assert not my_B.is_generic
	assert not my_B.is_universal
end

fun test_is_universal_query_for_C do
	var my_C = type_repo.get_type("C")
	assert my_C.is_universal
	assert not my_C.is_interface
	assert not my_C.is_generic
	assert not my_C.is_abstract
end

fun test_is_stdclass_query_for_D_and_E do
	var d = type_repo.get_type("D")
	var e = type_repo.get_type("E")
	assert d.is_stdclass
	assert e.is_stdclass
	assert not d.is_interface
	assert not e.is_interface
	assert not d.is_abstract
	assert not e.is_abstract
	assert not d.is_universal
	assert not e.is_universal
	assert not d.is_generic
end

fun test_is_generic_query_for_E do
	var e = type_repo.get_type("E")
	assert e.is_generic
end

test_A_supertypes
test_D_supertypes
test_is_interface_query_for_A
test_is_abstract_query_for_B
test_is_universal_query_for_C
test_is_stdclass_query_for_D_and_E
test_is_generic_query_for_E

var z1: Z1
var z2: Z2
var tZ1: TypeInfo
var tZ2: TypeInfo
var tZ3: TypeInfo
var tZ4: TypeInfo
var tZ5: TypeInfo
var p1: PropertyInfo
var p11: PropertyInfo
var p111: PropertyInfo
var p2: PropertyInfo

z1 = new Z1(1)
z2 = new Z2(10)
tZ1 = type_repo.get_type("Z1")
tZ2 = type_repo.get_type("Z2")
tZ3 = type_repo.get_type("Z3")
tZ5 = type_repo.get_type("Z5")
p1 = get_prop("p1", tZ1)
p11 = get_prop("p1", tZ2)
p111 = get_prop("p1", tZ3)
p2 = get_prop("p2", tZ3)

assert p1.parent == p1
assert p11.parent == p1
assert p111.parent == p11

assert p1.owner == tZ1
assert p11.owner == tZ2
assert p111.owner == tZ3

var p1111 = get_prop("p1", tZ5)
assert p1111 == p111

# Symmetry
assert p1.equiv(p11)
assert p11.equiv(p1)

# Reflexivity
assert p1.equiv(p1)
assert p11.equiv(p11)
assert p111.equiv(p111)

# Transitivity
assert p11.equiv(p111)
assert p1.equiv(p111)

# non-related property
assert not p2.equiv(p1)
assert not p2.equiv(p11)
assert not p2.equiv(p111)
assert not p1.equiv(p2)
assert not p11.equiv(p2)
assert not p111.equiv(p2)

assert p111.lequiv(p11) and p11.lequiv(p1) and p111.lequiv(p1)
assert not p111.lequiv(p2) and not p11.lequiv(p2) and not p1.lequiv(p1)

# Properties may be equivalent but not identical
assert p1 == p1
assert p1 != p11
assert p11 != p111
assert p1 != p111
