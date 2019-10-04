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

# Base module for all runtime implementation of the Mirror API.
module runtime

import common

# Base class of a runtime environment (compile-time, interpreter or vm)
# The implementation of an environment is built by refinement.
class RuntimeMirror
	super Environment

	# Creates a mirror over a living object
	fun reflect(instance: Object): InstanceMirror is abstract

	# Returns the type of an instance
	fun typeof(instance: Object): TypeMirror is abstract

	# Returns the class of an instance
	fun klassof(instaence: Object): ClassMirror is abstract
end

redef class MethodMirror

	# Tries to send a message to the first argument.
	# The first argument must be the receiver and the rest the
	# actual arguments of the method.
	#
	# ~~~~nitish
	# class Foo
	#	fun bar do print "Foo::bar"
	# end
	# var f = new Foo
	# var im = reflect(f)
	# var bar_meth = im.method(sym bar)
	# bar_meth.send(f) # output: "Foo::bar"
	# ~~~~
	fun send(args: Object...): nullable Object is abstract
end

# A mirror that reflects a living object.

# This is the base class for all object mirror
abstract class InstanceMirror
        super Mirror

	# The current instance being reflected on
        var instance: Object

	# The `Type` of `self.instance`
	var ty: TypeMirror

	# The `Class` of `self.instance`.
	fun klass: ClassMirror do return ty.klass

	# Returns true if this instance has a method symbolized by `method_sym`,
	# otherwise false.
	fun has_method(method_sym: Symbol): Bool is abstract

	# Returms the method symbolized by `method_sym`, otherwise null.
        fun method(method_sym: Symbol): nullable MethodMirror is abstract

	fun attrs: Sequence[AttributeMirror] is abstract

	# Creates a mirror of a method whose symbol is equal to `msym`.
	# REQUIRE: method(msym) != null
	fun [](method_sym: Symbol): MethodMirror
	is expects(has_method(method_sym)), abstract

	# Sends the `method_sym` message to the current instance with `args`.
	fun send(method_sym: Symbol, args: Object...): nullable Object
	is
		expects(has_method(method_sym))
	do
		var method = self.method(method_sym).as(not null)
		# TODO: maybe add assertion for the arity?
		return method.send(self.instance, args)
	end
end

# This class reprsesents an attribute for both a `ClassMirror` and an `InstanceMirror`.
# It voluntary breaks the Seggregation Principle (GRASP) for more convenience.
# This is due to the `ty` and `value` methods who should only be used by `InstanceMirror`.
# Since an attribute may not have value, nor a concrete type in its class definition:
#
#
# ~~~~nitish
# class Foo[E]
#	var xs: Array[E]
# end
#
# var f = new Foo[Int]([1,2,3])
# ~~~~
# Here, if we ask the type of `xs` from the `ClassMirror` perspective, then `xs`
# as no type. It has a type constructor which is Array. This is the case for all
# generic types.
#
# However, if we ask the type of `xs` from `f` instance, then the type will be `Array[Int]`.
redef class AttributeMirror
	var anchor: nullable InstanceMirror
	protected var maybe_ty: TypeMirror is noinit
	init
	do
		if anchor != null then
			assert anchor.klass == self.klass
			maybe_ty = self.klass.resolve([anchor.ty.to_sym]) # parameterized ty by the anchor
		end
	end

	# Returns the type of an attribute.
	# This method fails if the attribute isn't bound to any instance.
	# In other words, if you call this directly on a `ClassMirror` a runtime
	# error will be throwed.
	fun ty: TypeMirror
	do
		assert anchor != null
		return maybe_ty
	end

	fun value: nullable Object do return null
end
