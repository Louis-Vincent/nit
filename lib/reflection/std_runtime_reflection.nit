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

module std_runtime_reflection

import runtime_reflection
import runtime_internals
private import pthreads

redef class TypeInfo
	fun is_nullable: Bool
	do
		return self == self.as_nullable
	end
end

redef class Sys
	super Environment

	private var mirror_repo: MirrorRepository

	init
	do
		var prop_factory = new PropertyFactory
		var type_factory = new TypeFactory
		mirror_repo = new MirrorRepository(type_factory, prop_factory)
	end

	redef fun get_type(typename)
	do
		var tinfo = self.type_repo.get_type(typename)
		if tinfo == null then return null
		return mirror_repo.from_type_info(tinfo)
	end

	redef fun typeof(object)
	do
		var tinfo = self.type_repo.object_type(object)
		return mirror_repo.from_type_info(tinfo)
	end
end

redef class Type
	fun is_primitive: Bool is abstract
end

private class PropertyFactory
	private var cache = new HashMap[PropertyInfo, PropertyImpl]
	private var mutex = new Mutex

	fun build(property_info: PropertyInfo, repo: MirrorRepository): PropertyImpl
	do
		mutex.lock
		if cache.has_key(property_info) then
			mutex.unlock
			return cache[property_info]
		end
		var res: PropertyImpl
		if property_info isa AttributeInfo then
			res = new AttributeImpl(property_info, repo)
		else if property_info isa MethodInfo then
			res = new MethodImpl(property_info, repo)
		else
			assert property_info isa VirtualTypeInfo
			res = new VirtualTypeImpl(property_info, repo)
		end
		cache[property_info] = res
		mutex.unlock
		return res
	end
end

private class TypeFactory
	private var cache = new HashMap[TypeInfo, TypeImpl]
	private var mutex = new Mutex

	fun build(type_info: TypeInfo, repo: MirrorRepository): TypeImpl
	do
		mutex.lock
		if cache.has_key(type_info) then
			mutex.unlock
			return cache[type_info]
		end
		var res: TypeImpl
		if type_info.is_generic then
			res = new GenericTypeImpl(type_info, repo)
		else if type_info.is_derived then
			res = new DerivedTypeImpl(type_info, repo)
		else
			res = new TypeImpl(type_info, repo)
		end
		cache[type_info] = res
		mutex.unlock
		return res
	end
end

# Mirrored runtime entities repository.
# Serves as a facade for data retrieval.
private class MirrorRepository
	# There's a really strong coupling between `MirroRepository`
	# and the factories. It's better to have this high coupling here,
	# otherwise it would be inside `PropertyImpl` and `TypeImpl`.
	# This is due to `Type` and `Property` are interdependent and
	# we provide service through data objects. To remove the coupling
	# we would have to do a composition dominant API where
	# services are separated from their data, like so :
	#
	# ~~~~nitish
	# var a = new A()
	# var ty = type_service.typeof(ty)
	# var props = type_service.properties(ty)
	# var declared_props = type_service.declared_props(ty)
	# ~~~~
	#
	# This example follows the "mirror" philosophy. However,
	# it makes the code really verbose.
	private var type_factory: TypeFactory
	private var prop_factory: PropertyFactory

	fun from_type_info(type_info: TypeInfo): TypeImpl
	do
		return type_factory.build(type_info, self)
	end

	fun from_prop_info(prop_info: PropertyInfo): PropertyImpl
	do
		var prop_impl = self.prop_factory.build(prop_info, self)
		return prop_impl
	end
end

class TypeImpl
	super Type
	protected var type_info: TypeInfo
	private var mirror_repo: MirrorRepository

	private var cached_supertypes: nullable SequenceRead[TypeImpl] = null
	private var cached_properties: nullable Set[Property] = null

	redef fun properties: Set[PropertyImpl]
	do
		var set = new HashSet[PropertyImpl]
		for property_info in type_info.properties do
			var impl = self.mirror_repo.from_prop_info(property_info)
			set.add(impl)
		end
		if self.cached_properties == null then
			self.cached_properties = set
		end
		return set
	end

	redef fun supertypes
	do
		if self.cached_supertypes != null then
			return self.cached_supertypes.as(not null)
		end
		var res = new Array[TypeImpl]
		for st in self.type_info.supertypes do
			res.add(self.mirror_repo.from_type_info(st))
		end
		self.cached_supertypes = res
		return res
	end

	redef fun iza(other)

	do
		if not other isa SELF then
			return false
		end
		var my = self.type_info
		var his = other.type_info
		return my.iza(his)
	end

	redef fun declared_properties
	do
		var res = new HashSet[Property]
		for prop in self.properties do
			if prop.introducer == self then
				res.add(prop)
			end

		end
		return res
	end

	redef fun declared_attributes
	do
		var props = self.declared_properties
		var res = new Array[Attribute]
		for prop in props do
			if prop isa Attribute then
				res.push(prop)
			end
		end
		return res
	end

	redef fun property_or_null(property_name)
	do
		var properties = self.cached_properties or else self.properties
		for prop in properties do
			if prop.name == property_name then
				return prop
			end
		end
		return null
	end

	redef fun as_nullable
	do
		var nullabl = self.type_info.as_nullable
		var res = self.mirror_repo.from_type_info(nullabl)
		return res
	end

	redef fun as_not_null: TypeImpl
	do
		if not is_nullable then return self
		var notnull = self.type_info.as_not_null
		var res = self.mirror_repo.from_type_info(notnull)
		return res
	end

	redef fun is_primitive
	do
		var tInt = get_type("Int")
		var tString = get_type("String")
		var tFloat = get_type("Float")
		var tChar = get_type("Char")
		var tBool = get_type("Bool")
		var primitives = [tInt, tString, tFloat, tChar, tBool]
		var res = false
		for p in primitives do res = res or self == p
		return remais c'es
	end

	redef fun can_new_instance(args)
	do
		#for dp in declared_properties do
		#		print dp.name
		#end
		return true
	end

	redef fun new_instance(args)
	do
		var args2 = new Array[nullable Object]
		for a in args do args2.push(a)
		return self.type_info.new_instance(args2)
	end

	redef fun name
	do
		return self.type_info.to_s
	end
end

class GenericTypeImpl
	super GenericType
	super TypeImpl

	redef var arity is noinit

	init
	do
		self.arity = self.type_info.type_param_bounds.length
	end
end

class DerivedTypeImpl
	super DerivedType
	super TypeImpl

	redef fun declared_properties
	do
		var res = super
		res.add_all(base.declared_properties)
		return res
	end
end

abstract class PropertyImpl
	super Property
	protected type INFO: PropertyInfo
	protected var property_info: INFO
	private var mirror_repo: MirrorRepository

	redef fun introducer
	do
		var type_info = self.property_info.owner
		return self.mirror_repo.from_type_info(type_info)
	end

	redef fun name
	do
		return self.property_info.name
	end
end

class MethodImpl
	super Method
	super PropertyImpl
	redef type INFO: MethodInfo

	redef fun parameter_types
	do
		var type_infos = self.property_info.parameter_types
		var res = new Array[Type]
		for ti in type_infos do
			var ty = self.mirror_repo.from_type_info(ti)
			res.push(ty)
		end
		return res
	end
end

class AttributeImpl
	super Attribute
	super PropertyImpl
	redef type INFO: AttributeInfo

	redef fun static_type
	do
		var static_type = self.property_info.static_type
		var res = self.mirror_repo.from_type_info(static_type)
		return res
	end

	redef fun name
	do
		var res = super
		return res.substring_from(1)
	end
end

class VirtualTypeImpl
	super VirtualType
	super PropertyImpl
	redef type INFO: VirtualTypeInfo
end
