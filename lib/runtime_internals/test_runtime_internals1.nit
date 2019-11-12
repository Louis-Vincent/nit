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

module test_runtime_internals1

import runtime_internals
import test_runtime_internals_redefs

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
end

class F
	fun p1 do print 1
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
	super G
	super H

	redef fun p1
	do
		super
		print 4
	end
end

fun get_prop(name: String, klass: ClassInfo): PropertyInfo
do
	for p in klass.properties do
		if p.name == name then return p
	end
	abort
end

fun test_A_supertypes do
	#var a = rti_repo.get_classinfo("A").as(not null).unbound_type
	#var object = rti_repo.get_classinfo("Object").as(not null).unbound_type
	#var supertypes = a.supertypes.to_a
	#assert supertypes == [object]
end

fun test_D_supertypes do
	#var d = rti_repo.get_classinfo("D").as(not null).unbound_type
	#var a = rti_repo.get_classinfo("A").as(not null).unbound_type
	#var object = rti_repo.get_classinfo("Object").as(not null).unbound_type
	#var supertypes = d.supertypes.to_a
	#assert supertypes == [a, object]
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

assert p1.introducer == cZ1
assert p11.introducer == cZ2
assert p111.introducer == cZ3

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
assert tE_Int_String.to_s == "E[Int, String]"
assert tE_Int_String.is_derived
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
