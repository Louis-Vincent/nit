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

# Base module for all Mirror API and environments.
# Provides a common meta-hierarchy for every type of environments.
# Mirror API are used to integrate reflection into a language as a pluggable
# module. Thus, it doesn't cost anything if you are not using it. Furthermore,
# mirror based reflection can have multiple implementation per environment,
# eg: remote object, debug objects, current process, etc.
module common

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
	fun get_type(typename: String): nullable AbstractType is abstract

	fun typeof(object: INSPECTABLE): AbstractType is abstract
end

interface Property
	super Mirror

	# The type that introduced this property
	fun introduced_by: AbstractType is abstract

	# The name of this property
	fun name: String is abstract
end

interface Method
	super Property
end

interface Attribute
	super Property
end

interface Constructor
	super Method
	fun arg_types: SequenceRead[Type] is abstract
end

# Base interface for all class representing the NIT type system at runtime.
# It provides basic queries for the type system.
interface AbstractType
	super Mirror

	# The name of the type
	fun name: String is abstract

	# Returns a set containing all the property of this type.
	fun properties: Set[Property] is abstract

	# Subtype testing, returns `true` is `self isa other`,
	# otherwise false.
	fun iza(other: AbstractType): Bool is abstract

	# Returns a `Property` named `property_name` if it exists, otherwise
	# `null`.
	fun get_property_or_null(property_name: String): nullable Property is abstract

	# Returns `true` if this type has a property named `property_name`,
	# otherwise `false`.
	fun has_property(property_name: String): Bool
	do
		return self.get_property_or_null(property_name) != null
	end

	# Returns `true` if this type has a method named `method_name`,
	# otherwise `false`.
	fun has_method(method_name: String): Bool
	do
		var prop = self.get_property_or_null(method_name)
		return prop != null and prop isa Method
	end

	# Returns `true` if this type has an attribute named `attribute_name`,
	# otherwise `false`.
	fun has_attribute(attribute_name: String): Bool
	do
		var prop = self.get_property_or_null(attribute_name)
		return prop != null and prop isa Attribute
	end

	# Returns a `Property` named `property_name`.
	fun get_property(property_name: String): Property
	is
		expect(has_property(property_name))
	do
		return self.get_property_or_null(property_name).as(not null)
	end

	# Returns a `Method` named `method_name`.
	fun get_method(method_name: String): Method
	is
		expect(has_method(method_name))
	do
		return self.get_property(method_name).as(Method)
	end

	# Returns a `Attribute` named `attribute_name`.
	fun get_attribute(attribute_name: String): Attribute
	is
		expect(has_attribute(attribute_name))
	do
		return self.get_property(attribute_name).as(Attribute)
	end
end

# Represents a resolved type at runtime.
# Resolved types can instantiate constructors.
interface Type
	super AbstractType
	fun constr(ts: SequenceRead[Type]): Constructor is abstract
end

# Represents a generic type at runtime.
# More precisely, they are open types in NIT. They can instantiate new `Type`
# instances from `[]` operator.
#
# ~~~~nitish
# var array_ty = type_from_name("Array").as(GenericType)
# # instantiate a new `Type`: the `Array[Int]` type.
# var array_of_ints: Type = array_ty[Int]
# # instantiate a new `Type`: the `Array[String]` type.
# var array_of_strings: Type = array_ty[String]
# ~~~~
abstract class GenericType
	super AbstractType

	# The number of formal parameter
	var arity: Int

	# The bound for each formal parameter
	var bounds: SequenceRead[AbstractType]

	fun [](types: Type...): ResolvedGenericType
	do
		return resolve_with(types)
	end

	fun resolve_with(types: SequenceRead[Type]): ResolvedGenericType
	is abstract, expect(are_valid_type_parameter(types))

	fun are_valid_type_parameter(types: SequenceRead[Type]): Bool
	is abstract, expect(self.arity == types.length)

end

# A generic type who had been resolved.
abstract class ResolvedGenericType
	super Type
	super GenericType
end
