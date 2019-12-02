import std_runtime_reflection

class A
	var x: Int
	var y: String
	var z: nullable Float
	var b1: nullable B = null
	var b2: nullable B = null
end

class B
	var l: Int
	var m: Int
end

class C
	super B
	var test: String
end

fun to_json(object: Object): String
do
	var im = reflect(object)
	var text_ty = t"Text"
	var strings = new Array[String]
	for attr in im.all_attributes do
		var attr_ty = attr.dyn_type
		var value = attr.get
		var entry = "\"{attr.name}\": "
		if value == null then
			entry += "null"
		else if attr_ty.is_primitive then
			if attr_ty <= text_ty then
				entry += "\"{value}\""
			else
				entry += "{value}"
			end
		else
			var subres = to_json(value)
			entry += subres
		end
		strings.add("{entry}")
	end
	var res = strings.join(",\n")
	return "\{\n{res}\n\}"
end

var a1 = new A(1, "1", 1.0)
var b1 = new B(10, 100)
var b2 = new B(1000, 10000)
var a2 = new A(2, "2", null)
var c1 = new C(2, 4, "c1")

a1.b1 = b1
a1.b2 = b2
print to_json(a1)
print to_json(a2)
print to_json(c1)
