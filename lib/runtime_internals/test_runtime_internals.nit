module test_runtime_internals is test

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

class E[T1,T2]
end

class TestTypeInfoQueries
	test

	fun test_A_supertypes is test do
		var a = type_repo.get_type("A").as(not null)
		var object = type_repo.get_type("Object").as(not null)
		var supertypes = a.supertypes.to_a
		assert supertypes == [object]
	end

	fun test_D_supertypes is test do
		var d = type_repo.get_type("D").as(not null)
		var a = type_repo.get_type("A").as(not null)
		var object = type_repo.get_type("Object").as(not null)
		var supertypes = d.supertypes.to_a
		assert supertypes = [a, object]
	end

	fun test_is_interface_query_for_A is test do
		var my_A = type_repo.get_type("A").as(not null)
		assert my_A.is_interface
		assert not my_A.is_abstract
		assert not my_A.is_generic
		assert not my_A.is_universal
	end

	fun test_is_abstract_query_for_B is test do
		var my_B = type_repo.get_type("B").as(not null)
		assert my_B.is_abstract
		assert not my_B.is_interface
		assert not my_B.is_generic
		assert not my_B.is_universal
	end

	fun test_is_universal_query_for_C is test do
		var my_C = type_repo.get_type("C").as(not null)
		assert my_C.is_universal
		assert not my_C.is_interface
		assert not my_C.is_generic
		assert not my_C.is_abstract
	end

	fun test_is_stdclass_query_for_D_and_E is test do
		var d = type_repo.get_type("D").as(not null)
		var e = type_repo.get_type("E").as(not null)
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
		var e = type_repo.get_type("E").as(not null)
		assert e.is_generic
	end
end

class TestPropertyQuery
	test

	var z1: Z1 is noinit
	var z2: Z2 is noinit
	var tZ1: TypeInfo is noinit
	var tZ2: TypeInfo is noinit
	var tZ3: TypeInfo is noinit
	var tZ4: TypeInfo is noinit
	var tZ5: TypeInfo is noinit
	var p1: PropertyInfo is noinit
	var p11: PropertyInfo is noinit
	var p111: PropertyInfo is noinit

	fun set_up is before_all do
		z1 = new Z1(1)
		z2 = new Z2(10)
                tZ1 = type_repo.get_type("Z1").as(not null)
		tZ2 = type_repo.get_type("Z2").as(not null)
		tZ3 = type_repo.get_type("Z3").as(not null)
		tZ5 = type_repo.get_type("Z5").as(not null)
		p1 = get_prop("p1", tZ1)
		p11 = get_prop("p1", tZ2)
		p111 = get_prop("p1", tZ3)
        end

	fun get_prop(name: String, ty: TypeInfo): PropertyInfo
	do
		for p in ty.properties do
			if p.to_s == name then return p
		end
		abort
	end

	fun test_prop_super is test do
		assert p1.parent != p1
		assert p11.parent == p1
		assert p111.parent == p11
	end

	fun test_owner is test do
		assert p1.owner == tZ1
		assert p11.owner == tZ2
		assert p111.owner == tZ3
	end

	fun test_inherited_property_for_Z5 is test do
		var p1 = get_prop("p1", tZ5)
		assert p1 == p111
	end

	fun test_equivalence_property is test do
		var p2 = get_prop("p2", tZ3)
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

	# Properties may be equivalent but not identical
	fun test_identity_property is test do
		assert p1 == p1
		assert p1 != p11
		assert p11 != p111
		assert p1 != p111
	end
end
