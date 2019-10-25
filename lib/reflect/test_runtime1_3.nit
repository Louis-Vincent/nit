# This module test instance creation service
module test_runtime1_3 is test

import runtime

class Point
	var x: Float
	var y: Float

	init origin
	do
		init(0.0, 0.0)
	end

	init polar(r, phi: Float)
	do
		var x = r * phi.cos
		var y = r * phi.sin
		init(x, y)
	end

	redef fun to_s do return "({x},{y})"
end
class TestPointClassInstanciations
	test

	fun test_default_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		var p1 = t_point.new_instance(10,20).as(Point)
		assert p1.x == 10
		assert p1.y == 20
	end

	fun test_polar_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		var p1 = t_point.new_instance2(1.41, 45.0, "origin")
		assert p1.x < 1.001 and p1.x > 0.990
		assert p1.y < 1.001 and p1.y > 0.990
	end

	fun test_origin_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		var p1 = t_point.new_instance2(new Array[Object], "origin")
		assert p1.x == 0
		assert p1.y == 0
	end

	fun test_invalid_origin_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		assert not t_point.can_new_instance2(["1", 2], "origin")
	end

	fun test_invalid_polar_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		assert not t_point.can_new_instance2(["1", 2], "polar")
	end

	fun test_invalid_polar_init2 is test do
		var t_point = t"Point"
		assert t_point isa Type
		assert not t_point.can_new_instance2(new Array[Object], "polar")
	end

	fun test_valid_origin_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		assert t_point.can_new_instance2(new Array[Object], "origin")
	end

	fun test_valid_polar_init is test do
		var t_point = t"Point"
		assert t_point isa Type
		assert t_point.can_new_instance2([1,1], "origin")
	end
end

