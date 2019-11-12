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

module test_runtime_internals2

import runtime_internals

fun get_prop(name: String, ty: TypeInfo): PropertyInfo
do
	for p in ty.properties do
		if p.name == name then return p
	end
	abort
end

var tF = type_repo.get_type("F").as(not null)
var tG = type_repo.get_type("G").as(not null)
var tH = type_repo.get_type("H").as(not null)
var tI = type_repo.get_type("I").as(not null)

var p1 = get_prop("p1", tI)
var p11 = get_prop("p1", tH)
var p111 = get_prop("p1", tG)
var p1111 = get_prop("p1", tF)
print "{[p1, p11, p111, p1111]}"

for sup in p1.get_linearization do
	print "{sup.name}: {sup}"
end
