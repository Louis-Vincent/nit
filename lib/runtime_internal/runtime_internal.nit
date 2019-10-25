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

# Expose low level information of the current program.
# This module enables the user to manipulate runtime entities such as class or
# type but in a really opaque/symbolic way. This module is not for metaprogramming,
# however, it provides an entry point to build more complex librairies like a
# reflection API.
module runtime_internal
import symbol2
import functional

redef class Sys
	fun nmodel: NativeModel is intern
end

# Represents a runtime Type
universal Type
	fun to_sym: Symbol is intern
	fun types: nullable SequenceRead[Type] is intern
	redef fun ==(o) do return o isa Type and to_sym == o.to_sym
end

# Represents a runtime Class
universal Klass
	fun to_sym: Symbol is intern
	redef fun ==(o) do return o isa Type and to_sym == o.to_sym
end

# Represents a runtime Method
universal Method
	fun to_sym: Symbol is intern
	fun ref: Routine is intern
end

# Facade to access model information during runtime.
# This interface is rudimentary and is used for building richer
# API.
universal NativeModel
	# Returns the class of the corresponding symbol `s`
	fun sym2class(s: Symbol): nullable Klass is intern

	# Returns the type of the corresponding symbol `ty`
	fun sym2type(ty: Symbol): nullable Type is intern

	# Returns true if `sym` symbolized a runtime type otherwise false.
	fun isa_type(sym: Symbolic): Bool is intern do
		return sym2type(sym.to_sym) != null
	end

	# Returns true if `sym` symbolized a runtime class otherwise false.
	fun isa_class(sym: Symbolic): Bool is intern do
		return sym2class(sym.to_sym) != null
	end

	# Subtype test between two `Type`.
	fun t1_isa_t2(t1: Type, t2: Type): Bool is intern

	# Returns the class of a type
	fun type2class(ty: Type): Klass is intern

	# Returns the class of a living object.
	fun classof(object: Object): Klass is intern

	# Returns the type of a living object.
	fun typeof(object: Object): Type is intern

	# Returns the method symbolized by `sym` in the class `klass`.
	fun method(sym: Symbol, klass: Klass): nullable Method is intern

	# Returns the number of formal parameters for the class `klass`.
	fun arity_of(klass: Klass): Int is intern

	# Returns the ith class parameter bound.
	# Class parameters are indexed from 0 to n-1.
	#
	# ~~~nitish
	# class Foo[A,B,C,D]
	# end
	# var foo_class = klass(sym "Foo")
	# print nmodel.ith_bound(0, foo_class).to_sym # output "Object"
	# print nmodel.ith_bound(1, foo_class).to_sym # output "Object"
	# print nmodel.ith_bound(2, foo_class).to_sym # output "Object"
	# ~~~
	fun ith_bound(i: Int, klass: Klass): Type
	is expect(i >= 0 and i < arity_of(klass)), intern

	# Instantiate a new type from a class `Klass` and its
	# formal parameters `ts`.
	fun resolve(klass: Klass, ts: SequenceRead[Type]): Type
	is expect(ts.length == arity_of(klass)), intern
end
