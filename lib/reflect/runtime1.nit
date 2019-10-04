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

# Runtime implementation of the Mirror API. Use `runtime_internal` to provide
# low-level runtime information about living objects to the current program.
module runtime1

import runtime
private import cache
import runtime_internal

redef class Sys
        var mirror: RuntimeMirror = new RuntimeMirror

	# Unsafely try to load a class from the provided symbol
	fun klass(class_symbol: Symbol): ClassMirror
	do
		return klass_or_null(class_symbol).as(not null)
	end

	fun klass_or_null(class_symbol: Symbol): nullable ClassMirror
	do
		return mirror.klass(class_symbol)
	end

	# Reflects a living object
	fun reflect(instance: Object): InstanceMirror
	do
		return mirror.reflect(instance)
	end
end

private class ClassCache
	super Cache[Klass, RuntimeClass]

	redef fun new_default_entry(new_key)
	do
		return new RuntimeClass(new_key)
	end
end

redef class RuntimeMirror
	private var class_cache: ClassCache

	redef fun klass(class_symbol): nullable RuntimeClass
	do
		var nklass = nmodel.sym2class(class_symbol)
		if nklass == null then
			return null
		else
			return class_cache.get_or_build(nklass)
		end
	end

	redef fun reflect(instance: Object): InstanceMirror
	do
		var ty = nmodel.typeof(instance)
		var rttype = build_typemirror(ty)
		return new RuntimeInstance(instance, rttype)
	end

	# Builds a `TypeMirror` over a raw type info.
	private fun build_typemirror(ty: Type): RuntimeType
	do
		var nklass = nmodel.type2class(ty)
		var rtclass = class_cache.get_or_build(nklass)
		var rttype = new RuntimeType(rtclass, ty)
		var ty_params = new Array[RuntimeType]
		for ty2 in ty.types do
			ty_params.add(build_typemirror(ty2))
		end
		rttype.parameters = ty_params
		return rttype
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

	# Cache every instantiated type for this runtime class.
	private var ty_cache: Map[SequenceRead[Symbolic], TypeMirror] is noinit

	init
	do
		if arity > 0 then
			ty_cache = new HashMap[SequenceRead[TypeMirror], TypeMirror]
		end
	end

	redef fun to_sym do return nklass.to_sym

	redef fun has_method(method_symbol)
	do
		return nmodel.method(method_symbol, nklass) != null
	end

	redef fun method(method_symbol) is abstract

	redef fun resolve(ss)
	do
		if ty_cache.has_key(ss) then
			return ty_cache[ss]
		end

		var parameters = new Array[Type]
		for symbolic in ss do
			var ty = nmodel.sym2type(symbolic.to_sym)
			assert ty != null
			parameters.push(ty)
		end

		var ty = nmodel.resolve(nklass, parameters)
		var rttype = mirror.build_typemirror(ty)
		ty_cache[ss] = rttype
		return rttype
	end

	redef fun are_valid_parameters(ss)
	do
		for i in [0..arity[ do
			var sym = ss[i].to_sym
			var ty = nmodel.sym2type(sym)
			if ty == null then return false
			var ty2 = nmodel.ith_bound(i, self.nklass)
			if not nmodel.t1_isa_t2(ty, ty2) then return false
		end

		return true
	end
end
