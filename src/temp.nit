import runtime_internals
class A[E]
	var p1: E
	var p2: Int
end

var a = new A[Int](1, 10)

var tA = type_repo.object_type(a)
var declared_props = new Array[AttributeInfo]
for prop in tA.properties do
	if prop isa AttributeInfo and tA.iza(prop.owner) then# and prop.owner.iza(tA) then
		declared_props.add(prop)
	end
end

print declared_props
var x = declared_props.first
print x.static_type_wrecv(a)
print x.value(a)
