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
	fun type_repo: TypeRepo is intern
end

# Base class of all runtime entities exposed by the API
interface RuntimeInfo
end

universal TypeInfo
	super RuntimeInfo
	fun is_generic: Bool is intern
	fun is_interface: Bool is intern
	fun is_abstract: Bool is intern
	fun is_universal: Bool is intern
	fun is_derived: Bool is intern, expect(not is_generic)
	fun is_type_param: Bool is intern
	fun is_stdclass: Bool
	do
		return not is_abstract and not is_universal and not is_interface
	end

	fun supertypes: Iterator[TypeInfo] is intern, expect(not is_type_param)
	fun properties: Iterator[PropertyInfo] is intern, expect(not is_type_param)
	fun is_nullable: Bool is intern
	fun as_nullable: TypeInfo is intern
	fun type_param_bounds: SequenceRead[TypeInfo] is intern, expect(is_generic)
	fun type_arguments: SequenceRead[TypeInfo] is intern, expect(is_derived)
	fun resolve(args: Array[TypeInfo]): TypeInfo is intern, expect(is_generic)
	fun iza(other: TypeInfo): Bool is intern
	fun new_instance(args: Array[Object]): Object is intern, expect(not is_generic)
	redef fun to_s is intern
end

interface PropertyInfo
	super RuntimeInfo
	fun owner: TypeInfo is intern

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
	# linearization order.
	fun get_linearization: Iterator[SELF] is intern

	fun is_valid_recv(object: Object): Bool
	do
		var ty = type_repo.object_type(object)
		return ty.iza(owner)
	end
end

universal AttributeInfo
	super PropertyInfo

	# Returns the "dynamic" type of the current attribute derived by another
	# type (the receiver type most of the time). This function is useful if
	# the attribute is typed by a type parameter. This function ensures the
	# return `TypeInfo` is closed.
	fun dynamic_type(recv_type: TypeInfo): TypeInfo
	is intern, expect(recv_type.iza(self.owner))

	# Returns the static type of the current attribute.
	# This function is less safer than `type_info_wrecv` since it may
	# return type parameter (aka open generic type).
	fun static_type: TypeInfo is intern

	fun value(recv: Object): Object is intern
end

universal MethodInfo
	super PropertyInfo
	fun parameter_types: SequenceRead[TypeInfo] is intern
	fun call(args: Array[nullable Object]): nullable Object is intern
end

universal VirtualTypeInfo
	super PropertyInfo
end

# Entry point of the API.
universal TypeRepo
	fun get_type(typename: String): nullable TypeInfo is intern
	fun object_type(obj: Object): TypeInfo is intern
end

universal RuntimeInfoIterator[E: RuntimeInfo]
	super Iterator[E]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end
