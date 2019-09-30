module common
import symbol2

abstract class Mirror
end

# Base class of all environment kinds.
# Currently there's two kind of environment: runtime and compile-time.
# An environment provides implementation for the general `Mirror` interface.
# The implementation of an environment can be choose by refinement.
# Different kind of environment "could" coexist in the same programe, however,
# two implementations of the same environment can't. Here's an example
#
# ~~~~nitish
# import compile_time_env1 # used for macros
# import runtime_time_env1 # ok
# import runtime_time_env2 # ERROR : two runtime implementation
# ~~~~
abstract class Environment
        super Mirror
	fun get_class(s: Symbol): nullable ClassMirror is abstract
end

# A class is always a `Class`, however it could be a `Type`
# Type = no/resolved formal types.
# Class = unresolved formal types.
abstract class ClassMirror
        super Mirror

	# Number of formal parameter
	fun arity: Int is abstract

        fun method(msym: Symbol): MethodMirror is abstract
        fun field(fsym: Symbol): FieldMirror is abstract

	# Returns a constructor for this class parameterized by `types`.
	fun constr(types: Sequence[TypeMirror]): ConstructorMirror is abstract

	# Returns a class parameterized by the type symbol provided
	# in parameter.
	#
	# ~~~nitish
	# class Foo[E]
	# end
	#
	# var foo_class = get_class(sym "Foo"))
	# var tm = foo_class[sym "Int"]
	# var f = tm.make_instance
	# assert f isa Foo[Int]
	# ~~~
	fun [](ty: Symbol): TypeMirror is abstract

end

# A constructor mirror has more information than method mirror.
# On instantiation, a constructor mirror must be informed about
# its argument type. These types are use to ensure the constructor
# is not called with value who has the wrong type.
abstract class ConstructorMirror
	super MethodMirror
	protected var args_type: Sequence[TypeMirror]
end

# Mirror over a type
abstract class TypeMirror
	super Mirror

	# The class bound to that type
	var klass: ClassMirror

	# Resolved formal parameters
	var parameters: Sequence[TypeMirror]

	fun constr: ConstructorMirror do return klass.constr(parameters)
end

# Mirror over a method
abstract class MethodMirror
        super Mirror
end

# Mirror of a class attribute
abstract class FieldMirror
        super Mirror
        var ty: TypeMirror
end
