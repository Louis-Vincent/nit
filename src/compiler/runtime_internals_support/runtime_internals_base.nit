# Base module for all `runtime_internals` implementation
module runtime_internals_base

import separate_compiler

redef class AbstractCompiler
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

	fun classinfo_impl(v: AbstractCompilerVisitor): ClassInfoImpl is abstract

	fun rti_repo_impl(v: AbstractCompilerVisitor): RtiRepoImpl is abstract

	fun rti_iter_impl(v: AbstractCompilerVisitor): RtiIterImpl is abstract
end

abstract class RuntimeInfoImpl

	protected var v: AbstractCompilerVisitor

	# The causally connected `runtime_internals` class of `self`, ie
	# every implementation is associated to a class in `runtime_internals`
	# library.
	var mclass: MClass is protected writable

	# Compile the method `name` of `RuntimeInfo` interface.
	fun name(recv: RuntimeVariable, ret_type: MType) is abstract
end

abstract class ClassInfoImpl
	super RuntimeInfoImpl

	# Compile the interned method `ClassInfo::ancestors`
	fun ancestors(recv: RuntimeVariable, ret_type: MType) is abstract
end

abstract class RtiRepoImpl
	super RuntimeInfoImpl

	# Compile the interned method `RuntimeInternalsRepo::classof`.
	fun classof(target: RuntimeVariable, ret_type: MType) is abstract

	# Compile the interned method `RuntimeInternalsRepo::object_type`.
	#
	# `target` : Represents the runtime object to extract the type
	# information of.
	fun object_type(target: RuntimeVariable, ret_type: MType)
	is abstract

end

abstract class RtiIterImpl
	super RuntimeInfoImpl

	fun next(recv: RuntimeVariable) is abstract
	fun is_ok(recv: RuntimeVariable, ret_type: MType) is abstract
	fun item(recv: RuntimeVariable, ret_type: MType) is abstract
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
