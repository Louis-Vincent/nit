module test_runtime_internals is test

import test_runtime_internals_redefs

interface A
	var p1: Int
	var p2: Int
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

class E[T1,T2]
end

class TestTypeDescriptorQueries
	test

	# model_repo comes from `Sys::model_repo`
	var mr = model_repo

	fun test_A_supers is test do
		var a = mr.get_type("A")
		var object = mr.get_type("Object")
		var supers = a.supers.to_a
		assert supers.has_all([a, object])
		assert supers.length == 2
	end

	fun test_D_supers is test do
		var d = mr.get_type("D")
		var a = mr.get_type("A")
		var object = mr.get_type("Object")
		var supers = d.supers.to_a
		assert supers.has_all([a, object, d])
		assert supers.length == 3
	end

	fun test_is_interface_query_for_A is test do
		var my_A = mr.get_type("A")
		assert my_A.is_interface
		assert not my_A.is_abstract
		assert not my_A.is_generic
		assert not my_A.is_universal
	end

	fun test_is_abstract_query_for_B is test do
		var my_B = mr.get_type("B")
		assert my_B.is_abstract
		assert not my_B.is_interface
		assert not my_B.is_generic
		assert not my_B.is_universal
	end

	fun test_is_universal_query_for_C is test do
		var my_C = mr.get_type("C")
		assert my_C.is_universal
		assert not my_C.is_interface
		assert not my_C.is_generic
		assert not my_C.is_abstract
	end

	fun test_is_stdclass_query_for_D_and_E is test do
		var d = mr.get_type("D")
		var e = mr.get_type("E")
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

	fun test_is_generic_query_for_E is test do
		var e = mr.get_type("E")
		assert e.is_generic
	end
end

class TestPropertyQuery
	test

	var mr = model_repo
	var z1 = new Z1(1)
	var z2 = new Z2(2)
	var tZ1: TypeDescriptor is autoinit
	var tZ2: TypeDescriptor is autoinit
	var tZ3: TypeDescriptor is autoinit
	var tZ4: TypeDescriptor is autoinit
	var tZ5: TypeDescriptor is autoinit
	var p1: PropertyDescriptor is autoinit
	var p11: PropertyDescriptor is autoinit
	var p111: PropertyDescriptor is autoinit

	init
	do
		var tZ1 = mr.get_type("Z1")
		var tZ2 = mr.get_type("Z2")
		var tZ3 = mr.get_type("Z3")
		var p1 = get_prop("p1", tZ1).as(not null)
		var p11 = get_prop("p1", tZ2).as(not null)
		var p111 = get_prop("p1", tZ3).as(not null)
	end

	fun get_prop(name: String, ty: TypeDescriptor): PropertyDescriptor
	do
		for p in ty.properties do
			if p.name == name then return p1
		end
		abort
	end

	fun test_prop_super is test do
		assert p1.parent == p1
		assert p11.parent == p1
		assert p111.parent == p11
	end

	fun test_declared_by is test do
		assert p1.declared_by == tZ1
		assert p11.declared_by == tZ2
		assert p111.declared_by == tZ3
	end

	fun test_inherited_property_for_Z5 is test do
		var p1 = get_prop("p1", tZ5)
		assert p1 == p111
	end

	fun test_equivalence_property is test do
		var p2 = get_prop("p2", tZ3).as(not null)
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
	end

	fun test_lequiv_property is test do
		var p2 = get_prop("p2", tZ3).as(not null)
		assert p111.lequiv(p11) and p11.lequiv(p1) and p111.lequiv(p1)
		assert not p111.lequiv(p2) and not p11.lequiv(p2) and not p1.lequiv(p1)
	end

	# Properties may be equivalent but not identical
	fun test_identity_property is test do
		assert p1 == p1
		assert p1 != p11
		assert p11 != p111
		assert p1 != p111
	end
end
