# This module tests subtype testing between reflected types.
module test_runtime1_4 is test

import runtime

class A
end

class B
	super A
end

class C
	super A
end

class D
	super B
	super C
end

class G[T1: A, T2: B, T3: C, T4: D]
end

class H[T1: nullable A, T2: nullable B, T3: nullable C, T4: nullable D]
end

class TestRuntimeSubtypeTest
	test

	fun test_G_lowest_bound is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"A", t"B", t"C", t"D")
	end

	fun test_G_T1_bound_1 is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"B", t"B", t"C", t"D")
	end

	fun test_G_T1_bound_2 is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"C", t"B", t"C", t"D")
	end

	fun test_G_T1_bound_3 is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"D", t"B", t"C", t"D")
	end

	fun test_G_T2_bound is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"A", t"D", t"C", t"D")
	end

	fun test_G_T3_bound is test do
		var g = t"G"
		assert g isa GenericType
		assert g.are_valid_type_values(t"A", t"B", t"D", t"D")
	end

	fun test_G_T4_invalid_bound is test do
		var g = t"G"
		assert g isa GenericType
		assert not g.are_valid_type_values(t"A", t"B", t"C", t"B")
	end

	fun test_G_invalid_nullable_bound is test do
		var g = t"G"
		assert g isa GenericType
		assert not g.are_valid_type_values((t"A").as_nullable, t"B", t"C", t"D")
	end

	fun test_H_lowest_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", t"B", t"C", t"D")
	end

	fun test_H_lowest_nullable_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values((t"A").as_nullable,
			(t"B").as_nullable,
			(t"C").as_nullable,
			(t"D").as_nullable)
	end

	fun test_H_T1_bound_1 is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"B", t"B", t"C", t"D")
	end

	fun test_H_T1_bound_2 is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"C", t"B", t"C", t"D")
	end

	fun test_H_T1_bound_3 is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"D", t"B", t"C", t"D")
	end

	fun test_H_T2_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", t"D", t"C", t"D")
	end

	fun test_H_T3_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", t"B", t"D", t"D")
	end

	fun test_H_T4_invalid_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert not h.are_valid_type_values(t"A", t"B", t"C", t"B")
	end

	fun test_H_T1_nullable_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values((t"A").as_nullable, t"B", t"C", t"D")
	end

	fun test_H_T2_nullable_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", (t"B").as_nullable, t"C", t"D")
	end

	fun test_H_T3_nullable_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", t"B", (t"C").as_nullable, t"D")
	end

	fun test_H_T4_nullable_bound is test do
		var h = t"H"
		assert h isa GenericType
		assert h.are_valid_type_values(t"A", t"B", t"D", (t"D").as_nullable)
	end
end

class TestGenericTypeResolution

	fun test_G_resolution_1 is test do
		var g = t"G[A,B,C,D]"
		assert g isa DerivedType
		var g1 = g.new_instance(new Array[Object])
		assert g1 isa G[A,B,C,D]
	end

	fun test_G_resolution_2 is test do
		var g = t"G[A,D,D,D]"
		assert g isa DerivedType
		var g1 = g.new_instance(new Array[Object])
		assert g1 isa G[A,D,D,D]
	end

	fun test_H_resolution_1 is test do
		var h = t"H[nullable A,D,nullable D,D]"
		assert h isa DerivedType
		var h1 = h.new_instance(new Array[Object])
		assert h1 isa H[nullable A,D, nullable D,D]
	end
end
