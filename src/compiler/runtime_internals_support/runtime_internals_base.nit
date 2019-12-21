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

	# Compile the method `name` of `RuntimeInfo` interface.
	fun name is abstract
end

abstract class ClassInfoImpl
	super RuntimeInfoImpl

	# Compile the interned method `ClassInfo::ancestors`.
	fun ancestors is abstract

	# Compile the interned method `ClassInfo::properties`.
	fun properties is abstract

	# Compile the interned method `ClassInfo::type_parameters`.
	fun type_parameters is abstract

	# Compile the interned method `ClassInfo::is_interface`.
	fun is_interface is abstract

	# Compile the interned method `ClassInfo::is_abstract`.
	fun is_abstract is abstract

	# Compile the interned method `ClassInfo::is_universal`.
	fun is_universal is abstract
end

abstract class TypeInfoImpl
	super RuntimeInfoImpl
	# Compile the interned method `TypeInfo::klass`.
	fun klass is abstract

	# Compile the interned method `TypeInfo::is_formal_type`.
	fun is_formal_type is abstract

	# Compile the interned method `TypeInfo::bound`.
	fun bound is abstract

	# Compile the interned method `TypeInfo::type_arguments`.
	fun type_arguments is abstract

	# Compile the interned method `TypeInfo::iza`.
	fun iza(other: RuntimeVariable) is abstract

	# Compile the interned method `TypeInfo::native_equal`.
	fun native_equal(other: RuntimeVariable) is abstract
end

abstract class RtiRepoImpl
	super RuntimeInfoImpl

	# Compile the interned method `RuntimeInternalsRepo::classof`.
	fun classof(target: RuntimeVariable) is abstract

	# Compile the interned method `RuntimeInternalsRepo::object_type`.
	#
	# `target` : Represents the runtime object to extract the type
	# information of.
	fun object_type(target: RuntimeVariable)
	is abstract

end

abstract class RtiIterImpl
	super RuntimeInfoImpl
	fun next is abstract
	fun is_ok is abstract
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
