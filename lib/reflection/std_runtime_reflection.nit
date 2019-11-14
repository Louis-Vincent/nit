import runtime_reflection
import runtime_internals

redef class Sys
	super Environment

	private var mirror_repo = new MirrorRepository

	redef fun get_class(classname)
	do
		var classinfo = self.rti_repo.get_classinfo(classname)
		if classinfo == null then return null
		return self.mirror_repo.from_classinfo(classinfo)
	end

	redef fun typeof(object)
	do
		var typeinfo = self.rti_repo.object_type(object)
		return self.mirror_repo.from_typeinfo(typeinfo)
	end
end

class MirrorRepository
	fun from_classinfo(classinfo: ClassInfo): StdClass
	do
		return new StdClass(classinfo)
	end
	fun from_typeinfo(typeinfo: TypeInfo): StdType
	is
		expect(not typeinfo.is_generic)
	do
		var klass = self.from_classinfo(typeinfo.describee)
		var res: StdType
		if typeinfo.is_derived then
			res = new StdDerivedType(typeinfo, klass)
		else
			res = new StdType(typeinfo, klass)
		end
		return res
	end
	fun from_propinfo(propinfo: PropertyInfo): StdProperty
	do
		var klass = self.from_classinfo(propinfo.introducer)
		return new StdProperty(propinfo, klass)
	end
end

class StdClass
	super Class
	protected var classinfo: ClassInfo
	protected var cached_properties: nullable Set[Property]

	protected fun refresh_cache_properties: Set[Property]
	do
		var res = new HashSet[Property]
		for prop in classinfo.properties do
			res.add(mirror_repo.from_propinfo(prop))
		end
		self.cached_properties = res
		return res
	end

	redef fun arity
	is
		ensure(result >= 0)
	do
		return self.classinfo.type_param_bounds.length
	end

	redef fun ancestors
	do
		abort
		#var classes = self.classinfo.superclasses
		#var res = new Array[Class]
		#for classinfo in classes do
		#	var klass = mirror_repo.from_classinfo(classinfo)
		#	res.push(klass)
		#end
		#return res
	end

	redef fun properties
	do
		return cached_properties or else refresh_cache_properties
	end

	redef fun type_parameters
	do
		if self.arity == 0 then return new Array[TypeParameter]
		var unbound = self.classinfo.unbound_type
		assert unbound.is_generic
		abort
	end

	# TODO: cache all classinfo to avoid avoid duplicate instance of the
	# same class.
	redef fun ==(o) do return o isa SELF and o.classinfo == classinfo
end

class SubtypeConstraint
	super FormalTypeConstraint
	protected var supertype: Type

	redef fun is_valid(ty)
	do
		return ty.iza(self.supertype)
	end
end

class StdType
	super Type
	protected var typeinfo: TypeInfo
	protected var my_klass: Class

	redef fun klass do return self.my_klass

	# TODO : remove this when cache is ready
	redef fun ==(o) do return o isa SELF and o.typeinfo == typeinfo
end

class StdDerivedType
	super DerivedType
	super StdType
end

abstract class StdProperty
	super Property

	protected var propinfo: PropertyInfo
	protected var intro: Class

	new(propinfo: PropertyInfo, klass: Class)
	do
		if propinfo isa AttributeInfo then
			return new StdAttribute(propinfo, klass)
		else if propinfo isa MethodInfo then
			return new StdMethod(propinfo, klass)
		else
			return new StdVirtualType(propinfo, klass)
		end
	end

	redef fun introducer do return self.intro

	# TODO: remove this when cache is ready
	redef fun ==(o) do return o isa SELF and o.propinfo == propinfo
end

class StdAttribute
	super StdProperty
	super Attribute
end

class StdMethod
	super StdProperty
	super Method
end

class StdVirtualType
	super StdProperty
	super VirtualType
end
