# Base module for all `runtime_internals` implementation
module runtime_internals_base

import separate_compiler

# Abstract factory that produces a family of object to compile a specific
# implementation of `runtime_internals` module. This feature is only supported
# by the separate compiler.
interface RuntimeInternalsFactory
	fun model_saver(compiler: SeparateCompiler): ModelSaver
	is abstract

	# Returns an object capable of compiling a `TypeInfo` enum class.
	fun type_info_def(v: SeparateCompilerVisitor): TypeInfoImpl
	is abstract

	# Returns an object capable of compiling a `ClassInfo` enum class.
	fun class_info_def(v: SeparateCompilerVisitor): ClassInfoImpl
	is abstract

	# Returns an object capable of compiling a `AttributeInfo` enum class.
	fun attr_info_def(v: SeparateCompilerVisitor): AttributeInfoImpl
	is abstract

	# Returns an object capable of compiling a `MethodInfo` enum class.
	fun method_info_def(v: SeparateCompilerVisitor): MethodInfoImpl
	is abstract

	# Returns an object capable of compiling a `VirtualTypeInfo` enum class.
	fun vtype_info_def(v: SeparateCompilerVisitor): VirtualTypeInfoImpl
	is abstract

	# Returns an object capable of compiling a `RuntimeInternalRepo` enum class.
	fun runtime_internals_def(v: SeparateCompilerVisitor): RuntimeInternalsRepoImpl
	is abstract
end

#class NullRuntimeInternals
#	super RuntimeInternalsFactory
#
#	fun model_saver(compiler) do abort
#
#	# Returns an object capable of compiling a `TypeInfo` enum class.
#	fun type_info_def(v) do abort
#
#	# Returns an object capable of compiling a `ClassInfo` enum class.
#	fun class_info_def(v) do abort
#
#	# Returns an object capable of compiling a `AttributeInfo` enum class.
#	fun attr_info_def(v) do abort
#
#	# Returns an object capable of compiling a `MethodInfo` enum class.
#	fun method_info_def(v) do abort
#
#	# Returns an object capable of compiling a `VirtualTypeInfo` enum class.
#	fun vtype_info_def(v) do abort
#
#	# Returns an object capable of compiling a `RuntimeInternalRepo` enum class.
#	fun runtime_internals_def(v) do abort
#end

# Base class for all model persistor.
interface ModelSaver
	fun save_model is abstract
end

# Base class for all `TypeInfo` implementations.
# Wrapper over a compiler visitor.
interface TypeInfoImpl
	fun klass is abstract
	fun bound is abstract
	fun as_not_null is abstract
	fun as_nullable is abstract
	fun is_formal_type is abstract
	fun type_arguments is abstract
	fun name is abstract
	fun native_equal is abstract
	fun iza(other: RuntimeVariable) is abstract
end

# Base class for all `ClassInfo` implementations.
# Wrapper over a compiler visitor.
interface ClassInfoImpl
	fun ancestors is abstract
	fun properties is abstract
	fun new_type(args: SequenceRead[RuntimeVariable]) is abstract
	fun unbound_type is abstract
	fun is_interface is abstract
	fun is_abstract is abstract
	fun is_universal is abstract
	fun name is abstract
end

# Base class for all `PropertyInfo` implementations.
# Wrapper over a compiler visitor.
interface PropertyInfoImpl
	fun klass is abstract

	fun is_public is abstract
	fun is_private is abstract
	fun is_protected is abstract

	fun is_abstract is abstract
	fun is_intern is abstract
	fun is_extern is abstract

	# NOTE: might remove this function
	fun get_linearization is abstract
end

# Base class for all `AttributeInfo` implementations
# Wrapper over a compiler visitor.
interface AttributeInfoImpl
	super PropertyInfoImpl
	fun dyn_type(recv_type: RuntimeVariable) is abstract
	fun static_type is abstract
	fun value(object: RuntimeVariable) is abstract
end

# Base class for all `MethodInfo` implementations
# Wrapper over a compiler visitor.
interface MethodInfoImpl
	super PropertyInfoImpl
	fun return_type is abstract
	fun parameter_types is abstract

	fun dyn_return_type(recv_type: RuntimeVariable) is abstract
	fun dyn_parameter_types(recv_type: RuntimeVariable) is abstract

	fun call(args: SequenceRead[RuntimeVariable]) is abstract
end

# Base class for all `VirtualTypeInfo` implementations
# Wrapper over a compiler visitor.
interface VirtualTypeInfoImpl
	super PropertyInfoImpl
	fun static_bound is abstract
	fun dyn_bound(recv_type: RuntimeVariable) is abstract
end

# Base class for all `RuntimeInternalsRepo` implementations
interface RuntimeInternalsRepoImpl
	fun object_type(obj: RuntimeVariable) is abstract
	fun get_classinfo(classname: RuntimeVariable) is abstract
end
