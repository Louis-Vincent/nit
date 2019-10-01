import runtime
import common

redef class Sys
        var mirror: RuntimeMirror = new RuntimeMirror
	var class_symbols = new HashMap[Symbol, ClassMirror]

	# Unsafely try to load a class from the provided symbol
	fun klass(s: Symbol): ClassMirror do return klass_or_null(s).as(not null)

	fun klass_or_null(s: Symbol): nullable ClassMirror do return mirror.klass(s)

	# Reflects a living object
	fun reflect(instance: Object): InstanceMirror
	do
		return mirror.reflect(instance)
	end
end

redef class RuntimeMirror

	protected var classsym2mirror: Map[Symbol, ClassMirror] = new HashMap[Symbol, ClassMirror]

	redef fun klass(classname): nullable ClassMirror
	do
		# TODO: check if already loaded, otherwise try load, otherwise null
		return classsym2mirror.get_or_null(classname)
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
