module test_runtime1 is test

import runtime1

class A
	var x: Int
	var y: String

	init default
	do
		init(0, "0")
	end

	fun foo(z: nullable Int): Int
	do
		if z == null then
			return self.x
		else
			return self.x + z
		end
	end

	redef fun to_s do return "A::to_s"
end

class B
	var a: A
	private var private1 = 1
	private var private2 = 2
	private var private3 = 3
	redef fun to_s do return "B::to_s"
end

class C1
	var p1: Object
	var p2: Object
end

class C2
	var p3: Object
	var p4: Object
	var p5: Object
end

class C3
	var p6: Object
end

class D[T1, T2: Object, T3: C2, T4: C1, T5: C3, T6: nullable C2]
end

interface C
end

class TestRuntime1
	test

	var a: A is noinit
	var b: B is noinit

	fun set_up is before_all do
		a = new A(10, "10")
		b = new B(new A(100, "100"))
	end

	fun test_find_attribute is test do
		var ty_A = typeof(self.a)
		var x_prop = ty_A.property("x")
		assert x_prop isa Attribute
	end

	fun test_set_attribute is test do
		var ty_A = typeof(self.a)
		var x_prop = ty_A.property("x").as(Attribute)
		x_prop.set(1000)
		assert self.a.x == 1000
	end

	fun test_attribute is test do
		var ty_A = typeof(self.a)
		var x_prop = ty_A.property("x").as(Attribute)
		assert self.a.x == x_prop.get
	end

	fun test_find_method is test do
		var ty_A = typeof(self.a)
		var to_s_prop = ty_A.property("to_s")
		assert x_prop isa Method
	end

	fun test_method_identity is test do
		# A `Method` instance should be shared by classes from the same
		# hierarchy.
		var ty_A = typeof(self.a)
		var ty_B = typeof(self.b)
		var to_s_prop1 = ty_A.property("to_s").as(Method)
		var to_s_prop2 = ty_B.property("to_s").as(Method)
		assert to_s_prop1 == to_s_prop2
	end

	fun test_method_impl_sameness is test do
		# A `Method` instance who is shared by different classes may
		# differ in implementation
		var ty_A = typeof(self.a)
		var ty_B = typeof(self.b)
		var to_s_prop = ty_A.property("to_s").as(Method)
		assert not to_s_prop.is_same_impl(ty_A, ty_B)
	end

	fun test_method_call is test do
		# A `Method` instance who is shared by different classes may
		# differ in implementation
		var ty_A = typeof(self.a)
		var ty_B = typeof(self.b)
		var to_s_prop = ty_A.property("to_s").as(Method)
		var actual = [to_s_prop.call(self.a), to_s_prop.call(self.b)]
		var expected = ["A::to_s", "B::to_s"]
		assert actual == expected
	end

	fun test_constructor_list_for_A is test do
		var ty_A = typeof(self.a)
		var cs = ty_A.constructors
		assert cs.length == 2
		assert cs.get_or_null("default") != null
		assert cs.get_or_null("") != null
	end

	fun test_named_init_for_A is test do
		var ty_A = typeof(self.a)
		var constr = ty_A.constructor("default").as(not null)
		assert constr.argument_types.length == 0
		var new_a = constr.call
		assert new_a.x == 0 and new_a.y == "0"
	end

	fun test_no_constr_for_C is test do
		var ty_C = type_for_name("C")
		assert not ty_C.has_any_constr
	end

	fun test_declared_property_count_for_B is test do
		var ty_B = typeof(self.b)
		assert ty_B.declared_properties.length == 5
	end

	fun test_property_count_for_B is test do
		var ty_B = typeof(self.b)
		var object_ty = type_for_name("Object")
		var nb_object_properties = object_ty.properties.length
		var nb_declared_prop_in_B = ty_B.declared_properties.length
		assert ty_B.properties.length == nb_object_properties + nb_declared_prop_in_B
	end

	fun test_can_new_instance_for_B is test do
		var ty_B = type_for_name("B")
		assert ty_B.can_new_instance(self.a)
		assert not ty_B.can_new_instance(null)
		assert not ty_B.can_new_instance("a")
	end

	fun test_nullable_param_validation_for_A_foo is test do
		var ty_A = typeof(self.a)
		var foo_prop = ty_A.property("foo").as(Method)
		assert foo_prop.are_valid_arguments([self.a, null])
	end

	fun test_call_A_foo is test do
		var ty_A = typeof(self.a)
		var foo_prop = ty_A.property("foo").as(Method)
		assert foo_prop.call([self.a, null]) == 10
	end

	fun test_array_instanciation is test do
		var array_ty = type_for_name("Array")
		assert array_ty isa GenericType
		var array = array_ty[type_for_name("Int")].new_instance0
		assert array isa Array[Int]
	end

	fun test_collect_prop_for_C3_to_C2 is test do
		var ty_C3 = t"C3"
		var ty_C2 = t"C2"
		var cnt1 = ty_C3.declared_properties.length
		var cnt2 = ty_C2.declared_properties.length
		var props = ty_C3.collect_properties_up_to(ty_C2)
		assert props.length == cnt1 + cnt2
	end

	fun test_arity_for_D is test do
		var ty_D = t"D"
		assert ty_D isa GenericType
		assert ty_D.arity == 5
	end
	fun test_valid_type_valid_for_D is test do
		var ty_D = t"D"
		assert ty_D isa GenericType
		assert ty_D.are_valid_type_values(t"C", t"Int", t"C3", t"C1", t"C3", t"C2")
		assert ty_D.are_valid_type_values(t"C", t"Int", t"C3", t"C1", t"C3", t"nullable C2")
	end

	fun test_valid_type_valid_for_D is test do
		var ty_D = t"D"
		assert ty_D isa GenericType
		assert not ty_D.are_valid_type_values(t"C", t"Int", t"C1", t"C1", t"C3", t"C2")
		assert not ty_D.are_valid_type_values(t"C", t"Int", t"C3", t"C1", t"C3", t"nullable C1")
	end

	fun test_D_type_instantiation is test do
		var ty_D = t"D"
		assert ty_D isa GenericType
		assert ty_D[t"C", t"Int", t"C3", t"C1", t"C3", t"nullable C2"] isa DerivedType
	end
end
