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

# Introspection of the program structure at runtime.
module runtime_internals

redef class Sys
	fun rti_repo: RuntimeInternalsRepo is intern
end

# Base class of all runtime entities exposed by the API
interface RuntimeInfo
	fun name: String is abstract
end

universal ClassInfo
	super RuntimeInfo
	# Linearized class hierarchy
	fun ancestors: Iterator[ClassInfo] is intern

	# local properties (intro + refined) of a class
	fun properties: Iterator[PropertyInfo] is intern

	# Instantiate a new type
	fun new_type(args: Array[TypeInfo]): TypeInfo is intern

	# Returns an iterator over the super declaration of a class.
	# The iteration order isn't garantee to be the same as the declaration
	# order due to class refinement.
	fun super_decls: Iterator[TypeInfo] is intern

	fun bound_type: TypeInfo
	do
		var bounds = new Array[TypeInfo]
		# Make a copy
		for tparam in type_parameters do
			var bound = tparam.bound
			assert not bound.is_formal_type
			bounds.push(bound)
		end
		return self.new_type(bounds)
	end

	fun unbound_type: TypeInfo is intern

	fun is_interface: Bool is intern
	fun is_abstract: Bool is intern
	fun is_universal: Bool is intern
	fun type_parameters: Iterator[TypeInfo] is intern

	fun is_stdclass: Bool
	do
		return not is_abstract and not is_universal and not is_interface
	end

	fun is_generic: Bool
	do
		return type_parameters.to_a.length > 0
	end

	redef fun name is intern
end

universal TypeInfo
	super RuntimeInfo
	# A `TypeInfo` is always linked to a class.
	fun klass: ClassInfo is intern

	# Represents a type variable
	fun is_formal_type: Bool is intern

	fun as_not_null: TypeInfo is intern

	fun as_nullable: TypeInfo is intern

	# The bound (might be F-bounded) of a formal type
	fun bound: TypeInfo is intern, expect(is_formal_type)

	fun type_arguments: Iterator[TypeInfo] is intern

	# Determines if `self` isa `other`, ie if `self` is a subtype of `other`.
	#
	# ~~~nitish
	# class A
	# end
	#
	# class B
	#	super B
	# end
	#
	# var a = new A
	# var b = new B
	# var at = object_type(a)
	# var bt = object_type(b)
	#
	# assert bt.iza(at)
	# assert bt.iza(at)
	# ~~~
	fun iza(other: TypeInfo): Bool is intern

	fun new_instance(args: Array[nullable Object]): Object is intern

	redef fun name is intern

	redef fun ==(o) do return o isa SELF and native_equal(o)

	fun native_equal(o: TypeInfo): Bool is intern
end

interface PropertyInfo
	super RuntimeInfo
	# The class where the property has been introduced or redefined
	fun klass: ClassInfo is intern

	# Visibilities
	fun is_public: Bool is intern
	fun is_private: Bool is intern
	fun is_protected: Bool is intern

	# Qualifiers
	fun is_abstract: Bool is intern
	fun is_intern: Bool is intern
	fun is_extern: Bool is intern

	# Return true if `self` and `other` come from the same introduction.
	fun equiv(other: SELF): Bool is intern do
		var my = self.get_linearization
		var his = other.get_linearization
		var last1 = self
		var last2 = other
		while my.is_ok or his.is_ok do
			if my.is_ok then
				last1 = my.item
				my.next
			end
			if his.is_ok then
				last2 = his.item
				his.next
			end
		end
		return last1 == last2
	end

	redef fun name: String is intern

	# Returns an iterator that yields the next super property in the
	# linearizatdyn_typeion order.
	# TODO: might remove this function
	fun get_linearization: Iterator[SELF] is intern

	fun is_proper_receiver(candidate: Object): Bool
	do
		var ty = rti_repo.object_type(candidate)
		return is_proper_receiver_type(ty)
	end

	fun is_proper_receiver_type(candidate: TypeInfo): Bool
	do
		return candidate.iza(klass.bound_type)
	end
end

universal AttributeInfo
	super PropertyInfo

	# Returns the "dynamic" type of the current attribute derived by another
	# type (the receiver type most of the time). This function is useful if
	# the attribute is typed by a type parameter. This function ensures the
	# return `TypeInfo` is closed.
	fun dyn_type(recv_type: TypeInfo): TypeInfo
	is intern, expect(is_proper_receiver_type(recv_type))

	# Returns the static type of the current attribute.
	# This function is less safer than `type_info_wrecv` since it may
	# return type parameter (aka open generic type).
	fun static_type: TypeInfo is intern

	fun value(object: Object): nullable Object
	is intern, expect(is_proper_receiver(object))
end

universal MethodInfo
	super PropertyInfo

	# Returns the static return type of the underlying method. If the method
	# is a procedure, then null is returned instead.
	fun return_type: nullable TypeInfo is intern

	# Returns the static type of each parameters
	fun parameter_types: Iterator[TypeInfo] is intern

	fun dyn_return_type(recv_type: TypeInfo): nullable TypeInfo
	is intern, expect(is_proper_receiver_type(recv_type))

	fun dyn_parameter_types(recv_type: TypeInfo): Iterator[TypeInfo]
	is intern, expect(is_proper_receiver_type(recv_type))

	# Sends the message to `args[0]` (the receiver)
	fun call(args: Array[nullable Object]): nullable Object
	is intern, expect(is_proper_receiver(args[0].as(not null)))
end

universal VirtualTypeInfo
	super PropertyInfo

	# Returns the static type bound.
	fun static_bound: TypeInfo is intern

	# Returns the bound contextualized by a living type.
	fun dyn_bound(recv_type: TypeInfo): TypeInfo
	is intern, expect(is_proper_receiver_type(recv_type))
end

# Entry point of the API.
universal RuntimeInternalsRepo
	fun classof(obj: Object): ClassInfo is intern
	fun object_type(obj: Object): TypeInfo is intern
	fun get_classinfo(classname: String): nullable ClassInfo is intern
end

universal RuntimeInfoIterator[E: RuntimeInfo]
	super Iterator[E]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end
