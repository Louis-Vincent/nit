# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Base module for all Mirror API and environments.
# Provides a common meta-hierarchy for every type of environments.
# Mirror API are used to integrate reflection into a language as a pluggable
# module. Thus, it doesn't cost anything if you are not using it. Furthermore,
# mirror based reflection can have multiple implementation per environment,
# eg: remote object, debug objects, current process, etc.
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

# Base class for every entities who is owned/belongs to a class
abstract class ClassOwned
	super Mirror

	# The `ClassMirror` where `self` belongs.
	var klass: ClassMirror is protected writable
end

# Base class of every class properties : Method, Attributes, Annotations, Supers
# A class property must symbolic and belong to a target class.
abstract class Property
	super ClassOwned
	super Symbolic
end

abstract class ClassMirror
	super Mirror
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
	fun constr: ConstructorMirror
	is
		expects(self.arity == 0)
	do
		# See `TypeMirror::constr` for more information about this
		# inversion of role.
		return as_type.constr
	end

	# See `resolve` for more informations
	fun [](ss: Symbolic...): TypeMirror do return resolve(ss)

	# If this is not a generic class, returns its type, otherwise error.
	fun as_type: TypeMirror is expects(arity == 0), abstract

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
	is expects(are_valid_parameters(ss)), abstract

	# Checks if each symbolic type provided in argument respects each formal type
	# bound. Any extra parameters are ignored.
	# This method support heterogenous data inside the sequence.
	# However, each element in the sequence must be of type `Symbol` or `TypeMirror`
	# and in the case of `Symbol` they must symbolized a runtime type.
	fun are_valid_parameters(ss: SequenceRead[Symbolic]): Bool
	is expects(self.arity == ss.length), abstract
end

# A constructor is a special kind of method. Compared to `MethodMirror`,
# a constructor can not be symbolized and must know its arguments type.
# In other words, it provides a safer/stricter API than `MethodMirror`,
# since it prevents from invoking a constructor with invalid typed value.
abstract class ConstructorMirror
	super MethodMirror
	protected var args_type: SequenceRead[TypeMirror]

	redef fun to_sym
	do
		# This method breaks the segregation principal of GRASP.
		# However, this is the only exception in the meta hierarchy. Morever,
		# `ConstructorMirror` takes advantage of being a `MethodMirror`
		# since it's essentially a function. Finally we don't want any user
		# to access a constructor in a symbolic way. By forcing the user
		# to use this API, it reduces the chance of building a malformed
		# constructor.
		abort
	end
end

# Mirror over a type
abstract class TypeMirror
	super ClassOwned
	super Symbolic

	# Resolved formal parameters
	var parameters: nullable SequenceRead[TypeMirror] = null is writable

	# Checks if self is subtype of `other`
	fun iza(other: TypeMirror): Bool is abstract

	# Returns a constructor that produce instance of `self` type.
	#
	# **NOTE**: intuitively the class `ClassMirror` should be the one
	# who instantiate a constructor. However, generic classes must be
	# parameterized (resolved) before calling `constr` on it. Therefore, it
	# makes sense to have another method named `constr` in `TypeMirror`.
	# Since generic classes are a minority in a program, leaving the
	# method `ClassMirror::constr` without any arguments (for non-generic class)
	# makes the API less verbose, eventhough if we were to reflect a perfect
	# representation of a Nit model, `ClassMirror::constr` should have the following
	# signature `constr(ty: SequenceRead[TypeMirror])`. Instead,
	# `ClassMirror::constr` calls `TypeMirror::class` with resolved parameters if any.
	fun constr: ConstructorMirror is abstract
end

# Mirror over a method.
# `MethodMirror` is used to mirror constructor, getter, setter and methods.
abstract class MethodMirror
        super Property

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
        super Property
end
