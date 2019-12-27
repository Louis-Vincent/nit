import runtime_internals

class A
	var x: Int

	fun toto is abstract
end

class B[T1,T2]
end

var m = rti_repo

var a1 = new A(1)
var b1 = new B[Int, String]

print m.classof(a1)

var b_class = m.classof(b1)
for tp in b_class.type_parameters do
	print tp.name
	print tp.bound.name
end

var t1 = m.object_type(b1)
var t2 = m.object_type(a1)
print t1.name
print t2.name

for ta in t1.type_arguments do
	print ta.name
end

for ta in t2.type_arguments do
	# Not supposed to have any
	print ta.name
end

for prop in m.classof(a1).properties do
	print prop.name
	print "public?: {prop.is_public}, private?: {prop.is_private}, abstract?: {prop.is_abstract}, intern?: {prop.is_intern}, extern?: {prop.is_extern}"
end
