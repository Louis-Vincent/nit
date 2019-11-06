import runtime_internals

class A
	fun p1 do print 1
end
class B
	super A
	redef fun p1
	do
		super
		print 2
	end
end
class C
	super A
	redef fun p1
	do
		super
		print 3
	end
end

class D
	super B
	super C

	redef fun p1
	do
		super
		print 4
	end
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
var tD = type_repo.get_type("D").as(not null)

var p1 = get_prop("p1", tD)
var p11 = get_prop("p1", tC)
var p111 = get_prop("p1", tB)
var p1111 = get_prop("p1", tA)
print "{[p1, p11, p111, p1111]}"

for sup in p1.get_linearization do
	print "{sup.name}: {sup}"
end
