import common

# Base class of a runtime environment (compile-time, interpreter or vm)
# The implementation of an environment is built by refinement.
class RuntimeMirror
	super Environment

	fun reflect(instance: Object): InstanceMirror is abstract
end

# A mirror that reflects a living object.
# This is the base class for all object mirror
abstract class InstanceMirror
        super Mirror

	# The current instance being reflected on
        var instance: Object

	# The `Class` of `self.instance`
	var klass: ClassMirror

	var ty: TypeMirror

        fun method(msym: Symbol): MethodMirror is abstract
end
