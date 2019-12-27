# Base module for all `runtime_internals` implementation
module runtime_internals_base

import separate_compiler

redef class AbstractCompiler
	var rti_mclasses: Map[String, MClass] = new ArrayMap[String, MClass]

	init
	do
		var classinfo = get_mclass("ClassInfo")
		var typeinfo = get_mclass("TypeInfo")
		var attrinfo = get_mclass("AttributeInfo")
		var methodinfo = get_mclass("MethodInfo")
		var vtypeinfo = get_mclass("VirtualTypeInfo")
		var rt_repo = get_mclass("RuntimeInternalsRepo")
		self.rti_mclasses["ClassInfo"] = classinfo
		self.rti_mclasses["TypeInfo"] = typeinfo
		self.rti_mclasses["AttributeInfo"] = attrinfo
		self.rti_mclasses["MethodInfo"] = methodinfo
		self.rti_mclasses["VirtualTypeInfo"] = vtypeinfo
		self.rti_mclasses["RuntimeInternalsRepo"] = rt_repo
	end

	# NOTE: duplicate TODO: put it in `AbstractCompiler`
	# Unsafely tries to get a `MClass` by name
	fun get_mclass(classname: String): MClass
	do
		var model = self.mainmodule.model
		var mclasses = model.get_mclasses_by_name(classname)
		assert mclasses != null and mclasses.length == 1
		return mclasses.first
	end
end

# Abstract factory that produces a family of object to compile a specific
# implementation of `runtime_internals` module. This feature is only supported
# by the separate compiler.
abstract class RuntimeInternalsFactory
	# Every class in runtime internals to compile.
	# protected var ri_mclasses: SequenceRead[MClass]

	fun meta_struct_provider(cc: AbstractCompiler): MetaStructProvider
	is abstract

	fun model_saver(cc: SeparateCompiler): ModelSaver is abstract

	fun classinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): ClassInfoImpl is abstract

	fun typeinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): TypeInfoImpl is abstract

	fun propinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): PropertyInfoImpl is abstract

	fun attrinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): AttributeInfoImpl is abstract

	fun methodinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): MethodInfoImpl is abstract

	fun vtypeinfo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): VirtualTypeInfoImpl is abstract

	fun rti_repo_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): RtiRepoImpl is abstract

	fun rti_iter_impl(v: AbstractCompilerVisitor, recv: RuntimeVariable): RtiIterImpl is abstract
end

abstract class RuntimeInfoImpl

	protected var v: AbstractCompilerVisitor

	# The causally connected `runtime_internals` class of `self`, ie
	# every implementation is associated to a class in `runtime_internals`
	# library.
	var mclass: MClass is protected writable

	# The receiver of the message
	var recv: RuntimeVariable

	# The return type of the method to compile if any.
	# NOTE: unsafe field, may be not initialized.
	var ret_type: MType is noinit, writable

	# Compiles the method `name` of `RuntimeInfo` interface.
	fun name is abstract
end

# Commun class for `MethodInfoImpl`, `AttributeInfoImpl` and `VirtualTypeInfoImpl`.
# Provides commun implementation for all `runtime_internals::PropertyInfo` classes.
abstract class PropertyInfoImpl
	super RuntimeInfoImpl

	# Compiles the method `PropertyInfo::klass`.
	fun klass is abstract

	# Compiles the method `PropertyInfo::is_public`.
	fun is_public is abstract

	# Compiles the method `PropertyInfo::is_private`.
	fun is_private is abstract

	# Compiles the method `PropertyInfo::is_protected`.
	fun is_protected is abstract

	# Compiles the method `PropertyInfo::is_abstract`.
	fun is_abstract is abstract

	# Compiles the method `PropertyInfo::is_intern`.
	fun is_intern is abstract

	# Compiles the method `PropertyInfo::is_extern`
	fun is_extern is abstract
end

# Base class for all implementations of `runtime_internals::AttributeInfo` class.
abstract class AttributeInfoImpl
	super RuntimeInfoImpl
	# Compiles the interned method `AttributeInfo::dyn_type`.
	fun dyn_type is abstract

	# Compiles the interned method `AttributeInfo::static_type`.
	fun static_type is abstract

	# Compiles the interned method `AttributeInfo::value`.
	fun value is abstract
end

# Base class for all implementations of `runtime_internals::MethodInfo` class.
abstract class MethodInfoImpl
	super RuntimeInfoImpl

	# Compiles the interned method `MethodInfo::return_type`.
	fun return_type is abstract

	# Compiles the interned method `Merth::parameter_types`.
	fun parameter_types is abstract

	# Compiles the interned method `MethodInfo::dyn_return_type`.
	fun dyn_return_type is abstract

	# Compiles the interned method `MethodInfo::dyn_parameter_types`.
	fun dyn_parameter_types is abstract

	# Compiles the interned method `MethodInfo::call`.
	fun call is abstract
end

# Base class for all implementations of `runtime_internals::VirtualTypeInfo` class.
abstract class VirtualTypeInfoImpl
	super RuntimeInfoImpl

	# Compiles the interned method `VirtualTypeInfo::static_bound`
	fun static_bound is abstract

	# Compiles the interned method `VirtualTypeInfo::dyn_type`
	fun dyn_bound is abstract
end

# Base class for all implementations of `runtime_internals::ClassInfo` class.
abstract class ClassInfoImpl
	super RuntimeInfoImpl

	# Compiles the interned method `ClassInfo::ancestors`.
	fun ancestors is abstract

	# Compiles the interned method `ClassInfo::properties`.
	fun properties is abstract

	# Compiles the interned method `ClassInfo::type_parameters`.
	fun type_parameters is abstract

	# Compiles the interned method `ClassInfo::is_interface`.
	fun is_interface is abstract

	# Compiles the interned method `ClassInfo::is_abstract`.
	fun is_abstract is abstract

	# Compiles the interned method `ClassInfo::is_universal`.
	fun is_universal is abstract
end

# Base class for all implementations of `runtime_internals::TypeInfo` class.
abstract class TypeInfoImpl
	super RuntimeInfoImpl
	# Compiles the interned method `TypeInfo::klass`.
	fun klass is abstract

	# Compiles the interned method `TypeInfo::is_formal_type`.
	fun is_formal_type is abstract

	# Compiles the interned method `TypeInfo::bound`.
	fun bound is abstract

	# Compiles the interned method `TypeInfo::type_arguments`.
	fun type_arguments is abstract

	# Compiles the interned method `TypeInfo::iza`.
	fun iza(other: RuntimeVariable) is abstract

	# Compiles the interned method `TypeInfo::native_equal`.
	fun native_equal(other: RuntimeVariable) is abstract
end

# Base class for all implementations of `runtime_internals::RtiRepo` class.
abstract class RtiRepoImpl
	super RuntimeInfoImpl

	# Compiles the interned method `RuntimeInternalsRepo::classof`.
	fun classof(target: RuntimeVariable) is abstract

	# Compiles the interned method `RuntimeInternalsRepo::object_type`.
	#
	# `target` : Represents the runtime object to extract the type
	# information of.
	fun object_type(target: RuntimeVariable)
	is abstract

end

# Base class for all implementations of `runtime_internals::RuntimeInfoIterator` class.
abstract class RtiIterImpl
	super RuntimeInfoImpl

	# Compiles the interned method `RuntimeInfoIterator::next`.
	fun next is abstract

	# Compiles the interned method `RuntimeInfoIterator::is_ok`.
	fun is_ok is abstract

	# Compiles the interned method `RuntimeInfoIterator::item`.
	fun item is abstract
end

# Base class for all meta info C struct provider.
# This should be a wrapper over an instance of `AbstractCompiler`
interface MetaStructProvider
	fun mclass_to_struct_type(mclass: MClass): String is abstract
	fun compile_metainfo_header_structs is abstract
end

interface ModelSaver
	fun save_model(model: Model) is abstract
end
