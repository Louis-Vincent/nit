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

module runtime

# Base class of our meta-hierarchy
interface Mirror
end

# Base class of all environment kinds.
# Currently there's two kind of environment: runtime and compile-time.
# An environment provides implementation for the general `Mirror` interface.
# The implementation of an environment can be choose by refinement.
# Different kind of environment "could" coexist in the same programe, however,
# two implementations of the same environment can't. Here's an example
#
# ~~~~nitish
# import compile_time_env1 # used for macros
# import runtime_time_env1 # ok
# import runtime_time_env2 # ERROR : two runtime implementation
# ~~~~
interface Environment
	super Mirror

	type INSPECTABLE: Object

	# Returns the type named `typename`, otherwise `null`.
	fun get_type(typename: String): nullable Interface is abstract

	fun typeof(object: INSPECTABLE): Interface is abstract
end

interface Reflected
	fun name: String is abstract
end

interface Property
	super Reflected

	# The type that introduced this property
	fun introduced_by: Interface is abstract
	fun is_public: Bool is abstract
	fun is_private: Bool is abstract
	fun is_protected: Bool is abstract
	fun is_redef: Bool is abstract
end

interface Method
	super Property
end

interface Attribute
	super Property
end

interface Constructor
	super Method
end

interface Typoid
	super Reflected

	# Subtype testing, returns `true` is `self isa other`,
	# otherwise false.
	fun iza(other: Typoid): Bool is abstract

	fun as_nullable: NullableTypoid
	do
		if self isa NullableTypoid then
			return self
		else
			return new NullableTypoid(self)
		end
	end
end

class NullableTypoid
	super Typoid

	protected var ty: Typoid

	# Returns the underlying non-nullable type
	fun unwrap: Typoid do return ty

	redef fun iza(other)
	do
		if other isa NullableTypoid then
			return unwrap.iza(other.unwrap)
		else
			return unwrap.iza(other)
		end
	end
end

# A type parameter in a generic type
interface TypeParameter
	super Typoid
	fun bound: Typoid is abstract

	redef fun iza(other)
	do
		return other.iza(bound)
	end
end

# A vritual type definition inside a class
interface VirtualType
	super Property
	super TypeParameter
end

# Base interface for all class representing the NIT type system at runtime.
# It provides basic queries for the type system.
interface Interface
	super Typoid

	# All supertypes of this type in linearized order.
	fun supertypes: SequenceRead[Interface] is abstract

	# Returns a set containing all the property (inherited and introduced)
	# of this type.
	fun properties: Set[Property] is abstract

	# Returns a set of property introduced by this type.
	fun declared_properties: Set[Property] is abstract

	# Returns a set of property introduced by this type up to a given root.
	fun collect_properties_up_to(root: Interface): Set[Property] is abstract

	# Returns a `Property` named `property_name` if it exists, otherwise
	# `null`.
	fun property_or_null(property_name: String): nullable Property is abstract

	# Returns `true` if this type has a property named `property_name`,
	# otherwise `false`.
	fun has_property(property_name: String): Bool
	do
		return self.property_or_null(property_name) != null
	end

	# Returns `true` if this type has a method named `method_name`,
	# otherwise `false`.
	fun has_method(method_name: String): Bool
	do
		var prop = self.property_or_null(method_name)
		return prop != null and prop isa Method
	end

	# Returns `true` if this type has an attribute named `attribute_name`,
	# otherwise `false`.
	fun has_attribute(attribute_name: String): Bool
	do
		var prop = self.property_or_null(attribute_name)
		return prop != null and prop isa Attribute
	end

	# Returns a `Property` named `property_name`.
	fun property(property_name: String): Property
	is
		expect(has_property(property_name))
	do
		return self.property_or_null(property_name).as(not null)
	end

	# Returns a `Method` named `method_name`.
	fun method(method_name: String): Method
	is
		expect(has_method(method_name))
	do
		return self.property(method_name).as(Method)
	end

	# Returns a `Attribute` named `attribute_name`.
	fun attribute(attribute_name: String): Attribute
	is
		expect(has_attribute(attribute_name))
	do
		return self.property(attribute_name).as(Attribute)
	end
end

# Represents a closed type (resolved type) at runtime.
# Only closed type can instance new objects at runtime.
interface Type
	super Interface

	# Returns true if current args match the default init signature,
	# otherwise false.
	fun can_new_instance(args: SequenceRead[Object]): Bool is abstract

	# Same as `can_new_instance` but for a specific named init.
	fun can_new_instance2(args: SequenceRead[Object], constr_name: String): Bool is abstract

	# Command to instantiate a new object.
	# `args` : arguments for the constructor.
	fun new_instance(args: SequenceRead[Object]): Object
	is abstract, expect(self.can_new_instance(args))

	# Same as `new_instance` command but for a specific named init.
	fun new_instance2(args: SequenceRead[Object], constr_name: String): Object
	is abstract, expect(self.can_new_instance2(args, constr_name))
end

# Represents a generic type at runtime.
# More precisely, they are open types in NIT. They can instantiate new `DerivedType`
# instances from `[]` operator.
#
# ~~~~nitish
# var array_ty = type_from_name("Array").as(GenericType)
# # instantiate a new `Type`: the `Array[Int]` type.
# var array_of_ints: Type = array_ty[Int]
# # instantiate a new `Type`: the `Array[String]` type.
# var array_of_strings: Type = array_ty[String]
# ~~~~
interface GenericType
	super Interface

	# The number of formal parameter
	fun arity: Int is abstract

	# The bound for each formal parameter
	fun type_parameters: SequenceRead[TypeParameter] is abstract

	fun [](types: Type...): DerivedType
	do
		return resolve_with(types)
	end

	fun resolve_with(types: SequenceRead[Type]): DerivedType
	is abstract, expect(are_valid_type_values(types))

	fun are_valid_type_values(types: SequenceRead[Interface]): Bool
	do
		for i in [0..types.length[ do
			var tp = type_parameters[i]
			var ty = types[i]
			if not ty.iza(tp) then
				return false
			end
		end
		return true
	end

end

# A generic type who had been resolved.
interface DerivedType
	super Type

	# The type constructor who instantiated `self`.
	fun base: GenericType is abstract
end
