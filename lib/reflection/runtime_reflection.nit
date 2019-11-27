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
	fun name: String is abstract
end

# Base class for all runtime dependant reflected entities. In other words, this
# class represents objects whose metaqueries must be done at runtime to be
# coherent. Types and instances are good example, they require to be completly
# resolved (contextualised) before being queried or manipulated. This "resolvness"
# implies runtime because they are dynamic.
interface RuntimeEntity
	super Mirror
end

# Base class for all static entites reflected at runtime. Even though, we would
# like to have only one unified meta-hierarchy of things, we must dissociate what
# is dynamic (runtime) and what is static. Finally, some metaprogram requires
# static knowledge during runtime to be useful.
interface StaticEntity
	super Mirror
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
	fun get_class(classname: String): ClassMirror
	is abstract, expect(class_exist(classname))

	fun typeof(object: INSPECTABLE): TypeMirror is abstract

	fun reflect(object: Object): InstanceMirror is abstract
end

# Static declaration info of a class property.
interface DeclarationMirror
	super StaticEntity
	fun is_public: Bool is abstract
	fun is_private: Bool is abstract
	fun is_protected: Bool is abstract
	fun is_abstract: Bool is abstract

	# Returns the associated `PropertyMirror` of an object, ie it returns
	# a runtime version of `self`.
	fun bind(im: InstanceMirror): PropertyMirror is abstract

	# The class where the declaration belongs
	fun klass: ClassMirror is abstract
end

interface TypedDeclaration
	super DeclarationMirror
	fun static_type: StaticType is abstract
end

interface MethodDeclaration
	super DeclarationMirror
	fun parameters_type: SequenceRead[StaticType] is abstract
	fun return_type: nullable StaticType is abstract
end

interface AttributeDeclaration
	super TypedDeclaration
end

interface VirtualTypeDeclaration
	super TypedDeclaration
end

interface PropertyMirror
	super RuntimeEntity
	type DECLARATION: DeclarationMirror
	fun decl: DECLARATION is abstract
	fun recv: InstanceMirror is abstract
end

interface TypedProperty
	super PropertyMirror
	fun dyn_type: TypeMirror is abstract
end

interface MethodMirror
	super PropertyMirror
	redef type DECLARATION: MethodDeclaration
	fun parameter_types: SequenceRead[TypeMirror] is abstract
	fun return_type: nullable TypeMirror is abstract
	fun is_callable_with(args: SequenceRead[nullable Object]): Bool is abstract
	fun call(args: SequenceRead[nullable Object]): nullable Object is abstract
end

interface AttributeMirror
	super TypedProperty
	redef type DECLARATION: AttributeDeclaration
	fun set(value: nullable Object) is abstract
	fun get: nullable Object is abstract
end

interface VirtualTypeMirror
	super TypedProperty
	redef type DECLARATION: VirtualTypeDeclaration
end

interface FormalTypeConstraint
	fun is_valid(ty: TypeMirror): Bool is abstract
end

class NullConstraint
	super FormalTypeConstraint
	redef fun is_valid(ty) do return true
end

# An attribute of a class, like super types, type parameter, etc.
interface ClassAttributeMirror
	super StaticEntity

	# The class where the attribute belongs
	fun klass: ClassMirror is abstract
end

interface SuperTypeAttributeMirror
	super ClassAttributeMirror

	fun static_type: StaticType is abstract
end

interface StaticType
	super StaticEntity
	fun to_dyn(recv_type: TypeMirror): TypeMirror is abstract
end

# A type parameter in a generic type
interface TypeParameter
	super ClassAttributeMirror
	super StaticType
	fun constraint: FormalTypeConstraint is abstract
	fun rank: Int is abstract
end

interface ClassMirror
	super StaticEntity

	# The number of formal parameter
	fun arity: Int is abstract

	# All local declarations.
	fun declarations: Collection[DeclarationMirror] is abstract

	# Returns a type for this class. If `self` is generic then it
	# returns a derived type whose type arguments are the bounds
	# of its type parameters.
	fun bound_type: TypeMirror is abstract

	# The bound for each formal parameter
	fun type_parameters: SequenceRead[TypeParameter] is abstract

	fun [](types: TypeMirror...): TypeMirror
	do
		var res = derive_from(types)
		return res
	end

	#fun class_attributes: Collection[ClassAttributeMirror] is abstract

	fun supertypes: Collection[SuperTypeAttributeMirror] is abstract

	# Returns all ancestors including `self` in linearized order.
	fun ancestors: SequenceRead[ClassMirror] is abstract

	# Derive a new type from types arguments.
	fun derive_from(types: SequenceRead[TypeMirror]): TypeMirror
	is abstract, expect(are_valid_type_values(types))

	fun are_valid_type_values(types: SequenceRead[TypeMirror]): Bool
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

	fun < (other: ClassMirror): Bool
	do
		return ancestors.has(other)
	end

	fun <= (other: ClassMirror): Bool
	do
		return self == other or self < other
	end
end

interface TypeMirror
	super RuntimeEntity

	fun klass: ClassMirror is abstract

	fun typed_ancestors: SequenceRead[TypeMirror] is abstract

	# Subtype testing, returns `true` is `self isa other`,
	# otherwise false.
	fun iza(other: TypeMirror): Bool is abstract

	fun as_nullable: TypeMirror is abstract

	fun is_nullable: Bool
	do
		return	self == self.as_nullable
	end

	fun as_not_null: TypeMirror is abstract

	# Returns true if current args match the default init signature,
	# otherwise false.
	fun can_new_instance(args: SequenceRead[nullable Object]): Bool is abstract

	# Command to instantiate a new object.
	# `args` : arguments for the constructor.
	fun new_instance(args: SequenceRead[nullable Object]): Object
	is abstract, expect(self.can_new_instance(args))

	fun type_arguments: SequenceRead[TypeMirror] is abstract

	fun < (other: TypeMirror): Bool
	do
		return self != other and self.iza(other)
	end

	fun <= (other: TypeMirror): Bool
	do
		return self.iza(other)
	end
end

# Base interface for all dynamic type living at runtime. A dynamic type is closed,
# ie it has no static type like: generics, formal type, etc.
interface InstanceMirror
	super RuntimeEntity

	fun klass: ClassMirror is abstract
	fun dyn_type: TypeMirror is abstract

	fun properties: Collection[PropertyMirror] is abstract

	# Return the underlying reflected object.
	fun unwrap: Object is abstract

	fun all_attributes: SequenceRead[AttributeMirror]
	do
		var res = new Array[AttributeMirror]
		for dprop in self.properties do
			if dprop isa AttributeMirror then
				res.push(dprop)
			end
		end
		return res
	end

	fun all_methods: SequenceRead[MethodMirror]
	do
		var res = new Array[MethodMirror]
		for dprop in self.properties do
			if dprop isa MethodMirror then
				res.push(dprop)
			end
		end
		return res
	end

	# Returns a set of property introduced by this type and all its
	# refinements
	fun decl_properties: Collection[PropertyMirror]
	do
		var res = new HashSet[PropertyMirror]
		for prop in self.properties do
			if prop.decl.klass == klass then
				res.add(prop)
			end
		end
		return res
	end

	fun decl_attributes: SequenceRead[AttributeMirror]
	do
		var res = new Array[AttributeMirror]
		for prop in self.all_attributes do
			if prop.decl.klass == klass then
				res.add(prop)
			end
		end
		return res
	end

	fun decl_methods: SequenceRead[MethodMirror]
	do
		var res = new Array[MethodMirror]
		for prop in self.all_methods do
			if prop.decl.klass == klass then
				res.add(prop)
			end
		end
		return res
	end

	# Returns a `PropertyMirror` named `property_name` if it exists, otherwise
	# `null`.
	fun property_or_null(property_name: String): nullable PropertyMirror
	do
		for prop in properties do
			if prop.name == property_name then
				return prop
			end
		end
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
		return prop != null and prop isa MethodMirror
	end

	# Returns `true` if this type has an attribute named `attribute_name`,
	# otherwise `false`.
	fun has_attribute(attribute_name: String): Bool
	do
		var prop = self.property_or_null(attribute_name)
		return prop != null and prop isa AttributeMirror
	end

	# Returns a `PropertyMirror` named `property_name`.
	fun property(property_name: String): PropertyMirror
	is
		expect(has_property(property_name))
	do
		return self.property_or_null(property_name).as(not null)
	end

	# Returns a `MethodMirror` named `method_name`.
	fun method(method_name: String): MethodMirror
	is
		expect(has_method(method_name))
	do
		return self.property(method_name).as(MethodMirror)
	end

	# Returns a `AttributeMirror` named `attribute_name`.
	fun attribute(attribute_name: String): AttributeMirror
	is
		expect(has_attribute(attribute_name))
	do
		return self.property(attribute_name).as(AttributeMirror)
	end
end
