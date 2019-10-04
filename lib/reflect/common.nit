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
	# Tries to build a class mirror from the provided symbol `s`.
	# If the class doesn't exist at runtime, then returns null.
	fun klass(s: Symbol): nullable ClassMirror is abstract
end

# Base class of every meta entities in the program, eg : Type, Class, Method, etc.
abstract class MetaObject
	super Mirror

	# To respect the Ontological correspondance of a Nit Program,
	# every entities belong to a class. For example:
	# A method belongs to a class, an attribute belongs to a class,
	# A redef belongs to a class, etc.
	# The only exception is `ClassMirror` which doesn't belong to a class.
	# However, for simplicity a `ClassMirror` instance should return self.
	# In other words a class belongs to itself.
	var klass: ClassMirror is protected writable
end

abstract class ClassMirror
	super MetaObject
	super Symbolic

	# Number of formal parameter
	var arity: Int = 0

	# Returns true if this class has a method symbolized by `method_symbol`,
	# otherwise false.
	fun has_method(method_symbol: Symbol): Bool is abstract

	# Returns true if this class has an attribute symbolized by
	# `method_symbol`, otherwise false.
	fun has_attr(attr_symbol: Symbol): Bool is abstract

	# Returns the method symbolized by `method_symbol`.
        fun method(method_symbol: Symbol): MethodMirror
	is expects(has_method(method_symbol)), abstract

	# Returns the attribute symbolized by `attr_symbol`.
        fun attr(attr_symbol: Symbol): AttributeMirror
	is expects(has_attr(attr_symbol)), abstract

	# Returns a constructor for this class parameterized by `types`.
	fun constr(types: nullable Sequence[TypeMirror]): ConstructorMirror is abstract

	# Given a generic class, try to create a resolved type parameterized by type
	# symbols passed in argument.
	# ~~~nitish
	# class Foo[E,T]
	# end
	#
	# var int_mirror = klass(sym Int).as_type
	# var foo_class = get_class(sym Foo)
	# var tm = foo_class.resolve([sym Int, int_mirror])
	# var f = tm.make_instance
	# assert f isa Foo[Int]
	# ~~~
	# This method support heterogenous data inside the sequenceo.
	# However, each element in the sequence must be of type `Symbol` or `TypeMirror`
	# and in the case of `Symbol` they must symbolized a runtime type.
	#
	# NOTE: This method voluntary breaks the polymorphism principle of GRASP for
	# a more flexible API. The "officialer" way to do it, would be to create :
	# `SymbolTypeResolver`, `TypeMirrorTypeResolver` and `TypeResolver`. This hierarchy
	# would implement a method `resolve(symbolic: SYMBOLIC)`, etc. Then the class
	# `ClassMirror` would need two different method.
	fun resolve(ss: SequenceRead[Symbolic]): TypeMirror
	is expects(arity == ss.length,
		are_valid_parameters(ss)), abstract

	# Checks if each symbolic type provided in argument respects each formal type
	# bound. Any extra parameters are ignored.
	# This method support heterogenous data inside the sequence.
	# However, each element in the sequence must be of type `Symbol` or `TypeMirror`
	# and in the case of `Symbol` they must symbolized a runtime type.
	fun are_valid_parameters(ss: SequenceRead[Symbolic]): Bool is abstract

	# Breaks the recursion
	redef fun klass do return self
end

# A constructor mirror has more information than method mirror.
# On instantiation, a constructor mirror must be informed about
# its argument type. These types are use to ensure the constructor
# is not called with value who has the wrong type.
abstract class ConstructorMirror
	super MethodMirror
	protected var args_type: Sequence[TypeMirror]

	redef fun to_sym
	do
		# This method breaks the segregation principal of GRASP.
		# However, it doesn't seem to be so harmful in this case.
		# This is the only exception in the meta hierarchy. Morever,
		# `ConstructorMirror` takes advantage of being a `MethodMirror`
		# since it's essentially a function. Finally we don't want any user
		# to access a constructor in a symbolic way. By forcing the user
		# to use this API, it reduces the chance of building a malformed
		# constructor.
		abort "Constructor can not be symbolized"
		return super
	end
end

# Mirror over a type
abstract class TypeMirror
	super MetaObject
	super Symbolic

	# Resolved formal parameters
	var parameters: nullable Sequence[TypeMirror] = null

	# Checks if self is subtype of `other`
	fun iza(other: TypeMirror): Bool is abstract

	fun constr: ConstructorMirror
	do
		return klass.constr(parameters or else new Array[TypeMirror])
	end
end

# Mirror over a method.
# `MethodMirror` is used to mirror constructor, getter, setter and methods.
abstract class MethodMirror
        super MetaObject
	super Symbolic

	# Unsafely tries to downcast `self` to `AccessorMirror`
	fun as_accessor: AccessorMirror
	do
		assert self isa AccessorMirror
		return self
	end
end

# Mirror over an accessor method (get/set).
abstract class AccessorMirror
	super MethodMirror

	var attr: AttributeMirror
end

# Mirror of a class attribute.
abstract class AttributeMirror
        super MetaObject
	super Symbolic
end
