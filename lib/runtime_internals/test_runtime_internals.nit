# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module test_runtime_internals

import runtime_internals
import test_runtime_internals_redefs

redef class TypeInfo
	# For test purposes
	redef fun to_s do return name
end
redef class ClassInfo
	# For test purposes
	redef fun to_s do return name
end

redef class PropertyInfo
	# For test purposes
	redef fun to_s do return name
end

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
	fun foo(x: T1): T2 is abstract
	fun bar(x: Int): Int is abstract
	fun baz(x: T2): D is abstract
	fun bad(x: D): T1 is abstract
end

class F
	# For visibility + qualifier tests
	var fattr1 = 1
	protected var fattr2 = 2
	private var fattr3 = 3

	fun ffun1 do print 1
	protected fun ffun2 do print 2
	private fun ffun3 do print 3
	fun ffun4 is abstract
	private fun ffun5 is intern

	# End of visibility + qualifier tests

	fun p1 do print 1
end

redef class Int
	fun next `{ return recv + 1 `}
end

class G
	super F
	redef fun p1
	do
		super
		print 2
	end
end
class H
	super F
	redef fun p1
	do
		super
		print 3
	end
end

class I
	super H
	super G

	redef fun p1
	do
		super
		print 4
	end
end

class K[E]
	var p1: E
end

class K2[E]
end

redef class Z1
	super K2[Int]
end

class M[E]
	super K[Int]
	super K2[E]
end

class L
	var x: Int
	var y: Int
	var z: Int is noinit
	init
	do
		z = x + y
	end
end

abstract class J
	var x: Int
	var y: Int

	new(x: Int, y: Int)
	do
		if x + y > 10 then
			return new J1(x,y)
		else
			return new J2(x,y)
		end
	end
end

class J1
	super J
	var z: Int is noinit
	init
	do
		z = x + y
	end
end

class J2
	super J
end

class Toto[E]
	type MY_TYPE: E
end

fun get_prop(name: String, klass: ClassInfo): PropertyInfo
do
	for p in klass.properties do
		if p.name == name then return p
	end
	abort
end

var z1: Z1
var z2: Z2
var cZ1: ClassInfo
var cZ2: ClassInfo
var cZ3: ClassInfo
var cZ4: ClassInfo
var cZ5: ClassInfo
var cD: ClassInfo
var cE: ClassInfo
var tZ1: TypeInfo
var tZ2: TypeInfo
var tZ3: TypeInfo
var tZ4: TypeInfo
var tZ5: TypeInfo
var tD: TypeInfo
var tE: TypeInfo
var tInt: TypeInfo
var tString: TypeInfo
var p1: PropertyInfo
var p11: PropertyInfo
var p111: PropertyInfo
var p2: PropertyInfo

z1 = new Z1(1)
z2 = new Z2(10)
cZ1 = rti_repo.get_classinfo("Z1").as(not null)
cZ2 = rti_repo.get_classinfo("Z2").as(not null)
cZ3 = rti_repo.get_classinfo("Z3").as(not null)
cZ4 = rti_repo.get_classinfo("Z4").as(not null)
cZ5 = rti_repo.get_classinfo("Z5").as(not null)
cD = rti_repo.get_classinfo("D").as(not null)
cE = rti_repo.get_classinfo("E").as(not null)

tZ1 = cZ1.unbound_type
assert tZ1 == cZ1.bound_type
tZ2 = cZ2.unbound_type
assert tZ2 == cZ2.bound_type

tZ3 = cZ3.unbound_type
tZ4 = cZ4.unbound_type
tZ5 = cZ5.unbound_type
tD = cD.unbound_type
tE = cE.unbound_type
assert tE != cE.bound_type

tInt = rti_repo.get_classinfo("Int").as(not null).unbound_type
tString = rti_repo.get_classinfo("String").as(not null).unbound_type

p1 = get_prop("p1", cZ1)
p11 = get_prop("p1", cZ2)
p111 = get_prop("p1", cZ3)
p2 = get_prop("p2", cZ3)

assert p1.klass == cZ1
assert p11.klass == cZ2
assert p111.klass == cZ3

var p1111 = get_prop("p1", cZ5)
assert p1111 == p111

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

# Properties may be equivalent but not identical
assert p1 == p1
assert p1 != p11
assert p11 != p111
assert p1 != p111

var tE_Int_String = cE.new_type([tInt, tString])
assert tE_Int_String.name == "E[Int, String]"
assert tE_Int_String.type_arguments.to_a == [tInt, tString]

var d1 = new D(10, 100)
var d1_ty = rti_repo.object_type(d1)
assert d1_ty == tD

var cF = rti_repo.get_classinfo("F").as(not null)
var cG = rti_repo.get_classinfo("G").as(not null)
var cH = rti_repo.get_classinfo("H").as(not null)
var cI = rti_repo.get_classinfo("I").as(not null)
var tF = cF.unbound_type
var tG = cG.unbound_type
var tH = cH.unbound_type
var tI = cI.unbound_type

p1 = get_prop("p1", cI)
p11 = get_prop("p1", cH)
p111 = get_prop("p1", cG)
p1111 = get_prop("p1", cF)
print "{[p1, p11, p111, p1111]}"

for sup in p1.get_linearization do
	print "{sup.name}: {sup}"
end

var cK = rti_repo.get_classinfo("K").as(not null)
var tL = rti_repo.get_classinfo("L").as(not null).unbound_type
var tJ = rti_repo.get_classinfo("J").as(not null).unbound_type
var tJ1 = rti_repo.get_classinfo("J1").as(not null).unbound_type
var tK_Int = cK.new_type([tInt])
print tK_Int.name
var attr_p1 = get_prop("_p1", cK)
assert attr_p1 isa AttributeInfo

var x = rti_repo.get_classinfo("Object").as(not null).unbound_type
var y = x.as_nullable
var z = (cK.type_parameters.to_a)[0].bound
assert y == z
var temp = attr_p1.klass.bound_type
print attr_p1.dyn_type(tK_Int).name

var b1 = tL.new_instance([1,10]).as(L)
assert b1.z == 11

var c1 = tJ.new_instance([1,10])
var c2 = tJ.new_instance([1,1])
var c3 = tJ1.new_instance([10, 100])
assert c1 isa J1
assert c1.z == 11
assert c2 isa J2
assert c3 isa J1
assert c3.z == 110

for tp in cK.type_parameters do
	assert tp.is_formal_type
	print tp.name
end

var ancestors = cI.ancestors.to_a
print "ancestors of I: {ancestors}"

# Tests for `MethodInfo` queries

var method_foo = get_prop("foo", cE).as(MethodInfo)
var method_bar = get_prop("bar", cE).as(MethodInfo)
var method_baz = get_prop("baz", cE).as(MethodInfo)
var method_bad = get_prop("bad", cE).as(MethodInfo)

print method_foo.parameter_types.to_a # [T1]
print method_foo.return_type or else "" # T2
print method_bar.parameter_types.to_a # [Int]
print method_bar.return_type or else "" # Int
print method_baz.parameter_types.to_a # [T2]
print method_baz.return_type or else "" # D
print method_bad.parameter_types.to_a # [D]
print method_bad.return_type or else "" # [T1]

print method_foo.dyn_return_type(tE_Int_String).as(not null) # String
print method_bar.dyn_return_type(tE_Int_String).as(not null) # Int
print method_baz.dyn_return_type(tE_Int_String).as(not null) # D

print method_foo.dyn_parameter_types(tE_Int_String).to_a # [Int]
print method_bar.dyn_parameter_types(tE_Int_String).to_a # [Int]
print method_baz.dyn_parameter_types(tE_Int_String).to_a # [String]

# Tests for super declarations for `ClassInfo`

print cZ1.super_decls.to_a

var cK2 = rti_repo.get_classinfo("K2").as(not null)
var cM = rti_repo.get_classinfo("M").as(not null)

var first_tparam = (cM.type_parameters.to_a)[0] # formal type
assert first_tparam.is_formal_type
var superdecls = cM.super_decls.to_a
assert superdecls.length == 2 # K[Int], K2[E]
var k_super_decl = superdecls[0] # K[Int]
var k2_super_decl = superdecls[1] # K2[E]
# Type parameter must persist through super declarations.
assert (k2_super_decl.type_arguments.to_a)[0] == first_tparam

# Tests for nullable type

print tZ1.as_nullable.name
assert tZ1 != tZ1.as_nullable
assert tZ1.as_nullable == tZ1.as_nullable
assert tZ1.as_nullable.iza(tZ1)

print tE_Int_String.as_nullable.name
assert tE_Int_String.as_nullable != tE_Int_String

# Tests for virtual type property
var cToto = rti_repo.get_classinfo("Toto").as(not null)
var tToto_Int = cToto.new_type([tInt])
var vtype = get_prop("MY_TYPE", cToto).as(VirtualTypeInfo)
print vtype # MY_TYPE
print vtype.static_bound # E
print vtype.dyn_bound(tToto_Int) # Int
print vtype.is_proper_receiver_type(tZ1) # false
print vtype.is_proper_receiver_type(tToto_Int.as_nullable) # true

# Tests for visibility

var fattr1 = get_prop("fattr1", cF)
assert fattr1.is_public
assert not fattr1.is_private
assert not fattr1.is_protected
assert not fattr1.is_abstract

var fattr2 = get_prop("fattr2", cF)
assert fattr2.is_protected
assert not fattr2.is_public

var fattr3 = get_prop("fattr3", cF)
assert fattr3.is_private
assert not fattr3.is_public
assert not fattr3.is_protected

var ffun3 = get_prop("ffun3", cF)
assert ffun3.is_private
assert not ffun3.is_public

# Tests for method qualifier

var ffun4 = get_prop("ffun4", cF)
assert ffun4.is_public
assert ffun4.is_abstract
assert not ffun4.is_extern
assert not ffun4.is_intern

var ffun5 = get_prop("ffun5", cF)
assert ffun5.is_private
assert ffun5.is_intern
assert not ffun5.is_abstract
assert not ffun5.is_extern

var cInt = rti_repo.get_classinfo("Int").as(not null)
var next = get_prop("next", cInt)
assert next.is_public
assert next.is_extern
