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
end

universal ClassInfo
	super RuntimeInfo
	fun ancestors: Iterator[ClassInfo] is intern
	fun properties: Iterator[PropertyInfo] is intern
	fun new_type(args: Array[TypeInfo]): TypeInfo is intern
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
	fun type_parameters: SequenceRead[TypeInfo] is intern
	fun is_stdclass: Bool
	do
		return not is_abstract and not is_universal and not is_interface
	end
	redef fun to_s is intern
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

	fun type_arguments: SequenceRead[TypeInfo] is intern
	fun iza(other: TypeInfo): Bool is intern
	fun new_instance(args: Array[nullable Object]): Object is intern
	redef fun to_s is intern
end

interface PropertyInfo
	super RuntimeInfo
	# The class where the property has been introduced or redefined
	fun klass: ClassInfo is intern

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

	fun name: String is intern

	# Returns an iterator that yields the next super property in the
	# linearizatdyn_typeion order.
	fun get_linearization: Iterator[SELF] is intern
end

universal AttributeInfo
	super PropertyInfo

	# Returns the "dynamic" type of the current attribute derived by another
	# type (the receiver type most of the time). This function is useful if
	# the attribute is typed by a type parameter. This function ensures the
	# return `TypeInfo` is closed.
	fun dynamic_type(recv_type: TypeInfo): TypeInfo
	is intern, expect(recv_type.iza(klass.bound_type))

	# Returns the static type of the current attribute.
	# This function is less safer than `type_info_wrecv` since it may
	# return type parameter (aka open generic type).
	fun static_type: TypeInfo is intern

	fun value(object: Object): nullable Object is intern
end

universal MethodInfo
	super PropertyInfo
	# If `MethodInfo` is a function, then it returns the return static type,
	# otherwise null.
	fun return_type: nullable TypeInfo is intern
	# Returns the static type of each parameters
	fun parameter_types: SequenceRead[TypeInfo] is intern
	fun call(args: Array[nullable Object]): nullable Object is intern
end

universal VirtualTypeInfo
	super PropertyInfo
end

# Entry point of the API.
universal RuntimeInternalsRepo
	fun object_type(obj: Object): TypeInfo is intern
	fun get_classinfo(classname: String): nullable ClassInfo is intern
end

universal RuntimeInfoIterator[E: RuntimeInfo]
	super Iterator[E]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end
