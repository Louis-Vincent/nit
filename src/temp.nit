import runtime_internal
import symbol2

class Toto
end

var s1 = sym("test")
var s2 = sym("test")

var test = "test"
print s1.to_s == s2.to_s	# true
var s3 = sym(test)
var s4 = sym("Test")

print s1 # test
print s1.is_same_instance(s2)	# true
print s2.is_same_instance(s3)	# true
print s1 == s2	# true
print s2 == s3	# true
print s4 == s3  # false

var toto_klass = nmodel.sym2class(sym("Toto"))
print toto_klass.to_sym
print toto_klass.to_sym == sym("Toto")

var toto_type = nmodel.sym2type(sym("Toto"))
print toto_type != null		# true
print toto_type != toto_klass	# true

#var array_int = nmodel.sym2type(sym("Array[Int]"))
#var mapints = nmodel.sym2type(sym("HashMap[Int,Int]"))
#print array_int != null
#print array_int.to_sym
#print mapints != null
#print mapints.to_sym

var c1 = nmodel.classof(new Toto)
var c2 = nmodel.classof(new Array[String])
print nmodel.ith_bound(0, c2)
var t1 = nmodel.typeof(new Array[Int])

