import runtime_reflection
import runtime_internals
private import pthreads

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

	redef fun is_primitive
	do
		var tInt = get_type("Int")
		var tString = get_type("String")
		var tFloat = get_type("Float")
		var tChar = get_type("Char")
		return self == tInt or self == tInt or self == tFloat or self == tChar
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
end

class MethodImpl
	super Method
	super PropertyImpl
	redef type INFO: MethodInfo
end

class AttributeImpl
	super Attribute
	super PropertyImpl
	redef type INFO: AttributeInfo
end

class VirtualTypeImpl
	super VirtualType
	super PropertyImpl
	redef type INFO: VirtualTypeInfo
end
