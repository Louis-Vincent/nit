import reflection::runtime

var m = new RuntimeMirror
var array_klass = m.klass("Array")

#alt1# var constr = array.constr # Array isn't a type on its own. Must be parameterized
var constr = array_klass[Int].constr
var my_array = constr.invoke.as(Array[Int])
my_array.add(1)
assert my_array == [1]
