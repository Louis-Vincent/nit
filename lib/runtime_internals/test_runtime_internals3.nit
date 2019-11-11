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

module test_runtime_internals3

import runtime_internals

class K[E]
	var p1: E
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

fun get_prop(name: String, ty: TypeInfo): PropertyInfo
do
	for p in ty.properties do
		if p.name == name then return p
	end
	abort
end

var tK = type_repo.get_type("K").as(not null)
var tL = type_repo.get_type("L").as(not null)
var tJ = type_repo.get_type("J").as(not null)
var tJ1 = type_repo.get_type("J1").as(not null)
var tInt = type_repo.get_type("Int").as(not null)
var tK_Int = tK.resolve([tInt])
var p1 = get_prop("_p1", tK_Int).as(AttributeInfo)
print p1.dynamic_type(tK_Int)

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
