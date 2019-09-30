import runtime
import common

redef class Sys
        var mirror: RuntimeMirror = new RuntimeMirror
	var class_symbols = new HashMap[Symbol, ClassMirror]

        fun get_class(s: Symbol): nullable ClassMirror do return mirror.get_class(s)
end

redef class RuntimeMirror

	protected var classsym2mirror: Map[Symbol, ClassMirror] = new HashMap[Symbol, ClassMirror]

	redef fun get_class(classname): nullable ClassMirror
	do
		# TODO: check if already loaded, otherwise try load, otherwise null
		return classsym2mirror.get_or_null(classname)
	end

	# TODO
	# redef fun reflect(instance: Object): InstanceMirror is abstract
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

redef class MethodMirror
	# Sends this message to the first argument passed in parameter
	fun send(args: Object...): nullable Object is abstract
end

redef class InstanceMirror
	fun send(mm: MethodMirror, args: Object...): nullable Object do
		return mm.send(instance, args)
	end
end
