import runtime
import runtime_internal

redef class Sys
        var mirror: RuntimeMirror = new RuntimeMirror
	var class_symbols = new HashMap[Symbol, ClassMirror]

	# Unsafely try to load a class from the provided symbol
	fun klass(class_symbol: Symbol): ClassMirror do return klass_or_null(s).as(not null)

	fun klass_or_null(class_symbol: Symbol): nullable ClassMirror do return mirror.klass(s)

	# Reflects a living object
	fun reflect(instance: Object): InstanceMirror
	do
		return mirror.reflect(instance)
	end
end

redef class RuntimeMirror

	redef fun klass(class_symbol): nullable ClassMirror
	do
		return nmodule.sym2class(classname)
	end

	fun reflect(instance: Object): InstanceMirror
	do
		# Factorish
		var raw_ty = nmodel.typeof(instance)
		var klass = nmodel.type2class(raw_ty)
		var class_mirror = new RuntimeClass(klass)
		var type_mirror = new TypeMirror(classmirror)
		var ty_params = new Array[Type]
		for ty in raw_ty.types do ty_params.add(new TypeMirror(cm))
		type_mirror.parameters = ty_params

		return new InstanceMirror(instance, type_mirror)
	end
end

redef class TypeMirror

	# Makes an instance and initializes its content with `args`.
	# This is the same as `new Foo(args...)`.
	fun make_instance(args: Object...): Object
	do
		var res = constr.send(args)
		return res.as(not null)
	end
end

redef class ClassMirror
	redef fun [](ty)
	do

	end
end

class RuntimeInstance
	super InstanceMirror
end

class RuntimeType
	super TypeMirror
	protected var ntype: Type
	redef fun to_sym do return ntype.to_sym
end

class RuntimeClass
	super ClassMirror
	protected var nklass: Klass
	redef fun to_sym do return nklass.to_sym
end
