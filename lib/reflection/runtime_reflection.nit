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

module runtime_reflection

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
# ~~~~nitish
# import compile_time_env1 # used for macros
# import runtime_time_env1 # ok
# import runtime_time_env2 # ERROR : two runtime implementation
# ~~~~
interface Environment
	super Mirror

	type INSPECTABLE: Object

	fun class_exist(classname: String): Bool is abstract

	# Returns the type named `typename`, otherwise `null`.
	fun get_class(classname: String): Class
	is abstract, expect(class_exist(classname))

	fun typeof(object: INSPECTABLE): Type is abstract
end

interface Reflected
	super Mirror
	fun name: String is abstract
end

# Represents local property defined in a class
interface Property
	super Reflected

	# The class who locally introduced this property
	fun introducer: Class is abstract
	fun global_property: Property is abstract
	fun is_public: Bool is abstract
	fun is_private: Bool is abstract
	fun is_protected: Bool is abstract
end

# Represents contextualized properties, ie a property whose receiver type had
# been resolved.
interface Typed
	fun static_type: StaticType is abstract
	fun dyn_type: Type is abstract
end

# A vritual type definition inside a class
interface VirtualType
	super Property
	super Typed
end

interface Method
	super Property
	super Typed
	redef fun dyn_type: MethodType is abstract
end

interface Attribute
	super Property
	super Typed
end

interface FormalTypeConstraint
	fun is_valid(ty: Type): Bool is abstract
end

class NullConstraint
	super FormalTypeConstraint
	redef fun is_valid(ty) do return true
end

# A type parameter in a generic type
abstract class TypeParameter
	super StaticType
	# where the type parameter belongs
	var klass: Class is protected writable
	var constraint: FormalTypeConstraint is protected writable
	var rank: Int is protected writable
end

interface StaticType
	super Reflected
	fun to_dyn(recv_type: Type): Type is abstract
	fun unsafe_to_dyn: Type is abstract
end

interface Class
	super Reflected

	# The number of formal parameter
	fun arity: Int is abstract

	# Returns a type for this class. If `self` is generic then it
	# returns a derived type whose type arguments are the bounds
	# of its type parameters.
	fun bound_type: Type is abstract

	# The bound for each formal parameter
	fun type_parameters: SequenceRead[TypeParameter] is abstract

	fun [](types: Type...): DerivedType
	do
		var res = derive_from(types)
		assert res isa DerivedType
		return res
	end

	# Returns all ancestors including `self` in linearized order.
	fun ancestors: SequenceRead[Class] is abstract

	# Derive a new type from types arguments.
	fun derive_from(types: SequenceRead[Type]): Type
	is abstract, expect(are_valid_type_values(types))

	fun are_valid_type_values(types: SequenceRead[Type]): Bool
	do
		for i in [0..types.length[ do
			var constraint = type_parameters[i].constraint
			var ty = types[i]
			if not constraint.is_valid(ty) then
				return false
			end
		end
		return true
	end
end

# Denotes the absence of type (absurd type)
class NoneType
	super Type
	redef fun properties do return new ArraySet[Property]
	redef fun can_new_instance(args) do return false
	redef fun iza(other) do return other isa NoneType
	redef fun as_nullable do return self
	redef fun is_nullable do return false
	redef fun as_not_null do return self
end

# Base interface for all dynamic type living at runtime. A dynamic type is closed,
# ie it has no static type like: generics, formal type, etc.
interface Type
	super Reflected

	fun klass: Class is abstract

	fun properties: Set[Property] is abstract

	# Returns a set of property introduced by this type and all its
	# refinements
	fun declared_properties: Set[Property]
	do
		var res = new HashSet[Property]
		for prop in self.properties do
			if prop.introducer == klass then
				res.add(prop)
			end
		end
		return res
	end

	fun declared_attributes: SequenceRead[Attribute]
	do
		var res = new Array[Attribute]
		for dprop in self.declared_properties do
			if dprop isa Attribute then
				res.push(dprop)
			end
		end
		return res
	end

	fun declared_methods: SequenceRead[Method]
	do
		var res = new Array[Method]
		for dprop in self.declared_properties do
			if dprop isa Method then
				res.push(dprop)
			end
		end
		return res
	end

	# Returns a `Property` named `property_name` if it exists, otherwise
	# `null`.
	fun property_or_null(property_name: String): nullable Property
	do
		return null
	end

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

	# Subtype testing, returns `true` is `self isa other`,
	# otherwise false.
	fun iza(other: Type): Bool is abstract

	fun as_nullable: Type is abstract

	fun is_nullable: Bool
	do
		return	self == self.as_nullable
	end

	fun as_not_null: Type is abstract

	# Returns true if current args match the default init signature,
	# otherwise false.
	fun can_new_instance(args: SequenceRead[nullable Object]): Bool is abstract

	# Command to instantiate a new object.
	# `args` : arguments for the constructor.
	fun new_instance(args: SequenceRead[nullable Object]): Object
	is abstract, expect(self.can_new_instance(args))
end

# A generic type who had been resolved.
interface DerivedType
	super Type
	fun type_arguments: SequenceRead[Type] is abstract
end

interface MethodType
	super Type
	fun return_type: Type is abstract
	fun parameter_types: SequenceRead[Type] is abstract
end
