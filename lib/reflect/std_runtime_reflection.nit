import runtime_reflection
import runtime_internals
private import pthreads

redef class Sys
	super Environment

	private var type_factory: TypeFactory
	private var prop_factory: PropFactory

	init
	do
		prop_factory = new PropFactory
		type_factory = new TypeFactory(prop_factory)
	end

	redef fun get_type(typename)
	do
		var tinfo = self.type_repo.get_type(typename)
		if tinfo == null then return null
		return type_factory.build(tinfo)
	end

	redef fun typeof(object)
	do
		var tinfo = self.type_repo.object_type(object)
		return type_factory.build(tinfo)
	end
end

interface Factory[K,V]
	fun build(key: K): V is abstract
end

abstract class CachedFactory[K,V]
	super Factory[K,V]
	protected var cache = new HashMap[K,V]
	private var mutex = new Mutex
	redef fun build(key: K): V
	do
		mutex.lock
		if cache_has_key(key) then
			mutex.unlock
			return cache[key]
		end
		var res = new_instance(key)
		mutex.unlock
		cache[key] = res
		return res
	end
	protected fun new_instance(key: K): V is abstract
end

class PropFactory
	super CachedFactory[PropertyInfo, PropertyImpl]
	redef fun new_instance(property_info)
	do
		var res: PropertyImpl
		if property_info isa AttributeInfo then
			res = new AttributeImpl(property_info)
		else if property_info isa MethodInfo then
			res = new MethodImpl(property_info)
		else
			assert property_info isa VirtualTypeInfo
			res = new VirtualTypeImpl(property_info)
		end
		return res
	end
end

class TypeFactory
	super CachedFactory[TypeInfo, TypeImpl]
	protected var prop_factory: CachedFactory[PropertyInfo, PropertyImpl]

	redef fun new_instance(type_info: TypeInfo): TypeImpl
	do
		var res: TypeImpl
		if type_info.is_generic then
			res = new GenericTypeImpl(type_info, self, self.prop_factory)
		else if type_info.is_derived then
			res = new DerivedTypeImpl(type_info, self, self.prop_factory)
		else
			res = new TypeImpl(type_info, self, self.prop_factory)
		end
		return res
	end
end

class TypeImpl
	super Type
	protected var type_info: TypeInfo
	protected var type_factory: Factory[TypeInfo, TypeImpl]
	protected var prop_factory: Factory[PropertyInfo, PropertyImpl]

	private var cached_supertypes: nullable SequenceRead[TypeImpl] = null

	redef fun properties
	do
		var set = new HashSet[PropertyImpl]
		for property_info in type_info.properties do
			var impl = self.prop_factory(property_info)
			set.add(impl)
		end
		return set
	end

	redef fun supertypes
	do
		if self.cached_supertypes != null then
			return self.cached_supertypes
		end
		var res = new Array[Type]
		for st in self.type_info.supertypes do
			res.add(self.type_factory.build(st))
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
end

class GenericTypeImpl
	super TypeImpl
end

class DerivedTypeImpl
	super TypeImpl
end

abstract class PropertyImpl
	super Property
	protected type INFO: PropertyInfo
	protected var property_info: INFO
end

class MethodImpl
	super PropertyImpl
	redef type INFO: MethodInfo
end

class AttributeImpl
	super PropertyImpl
	redef type INFO: AttributeInfo
end

class VirtualTypeImpl
	super PropertyImpl
	redef type INFO: VirtualTypeInfo
end
