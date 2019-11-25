import runtime_reflection
import runtime_internals

redef class Sys
	super Environment

	private var mirror_repo = new MirrorRepository

	redef fun class_exist(classname)
	do
		return self.rti_repo.get_classinfo(classname) != null
	end

	fun get_type(typename: String): Type
	do
		var klass = get_class(typename)
		return klass.bound_type
	end

	redef fun get_class(classname)
	do
		var classinfo = self.rti_repo.get_classinfo(classname)
		assert classinfo != null
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
		#expect(not typeinfo.is_generic and not typeinfo.is_type_param)
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

	fun from_propinfo(propinfo: PropertyInfo, anchor: Type): StdProperty
	do
		var klass = self.from_classinfo(propinfo.introducer)
		return new StdProperty(propinfo, klass, anchor)
	end
end

class StdClass
	super Class
	protected var classinfo: ClassInfo
	protected var cached_type_param: nullable SequenceRead[TypeParameter]

	protected fun refresh_cache_type_param: SequenceRead[TypeParameter]
	do
		var res = new Array[TypeParameter]
		var i = 0
		var tvar_bounds = self.classinfo.type_param_bounds
		for tvar in self.classinfo.type_parameters do
			# NOTE: If the type system becomes more complexe
			# we would need to support more constraint.
			var bound = mirror_repo.from_typeinfo(tvar_bounds[i])
			var constraint = new SubtypeConstraint(bound)
			var typeparam = new StdTypeParameter(self, constraint, i, tvar)
			res.push(typeparam)
			i += 1
		end
		self.cached_type_param = res
		return res
	end

	redef fun name do return classinfo.to_s

	redef fun arity
	is
	#ensure(result >= 0)
	do
		return self.classinfo.type_param_bounds.length
	end

	redef fun ancestors
	do
		var classes = self.classinfo.ancestors
		var res = new Array[Class]
		for classinfo in classes do
			var klass = mirror_repo.from_classinfo(classinfo)
			res.push(klass)
		end
		return res
	end

	redef fun type_parameters
	do
		return cached_type_param or else refresh_cache_type_param
	end

	redef fun bound_type
	do
		var types = new Array[Type]
		for tparam in type_parameters do
			var ty = tparam.constraint.default_solution
			types.push(ty)
		end
		return derive_from(types)
	end

	redef fun derive_from(types)
	do
		var typeinfos = new Array[TypeInfo]
		for ty in types do
			var ty2 = ty.as(StdType)
			typeinfos.push(ty2.type_info)
		end
		var derived_type = self.classinfo.new_type(typeinfos)
		var res = mirror_repo.from_typeinfo(derived_type)
		return res
	end

	# TODO: cache all classinfo to avoid avoid duplicate instance of the
	# same class.
	redef fun ==(o) do return o isa SELF and o.classinfo == classinfo
end

class StdTypeParameter
	super TypeParameter
	protected var typeinfo: TypeInfo
end

redef class FormalTypeConstraint
	# Given the constraint `self`, returns the most basic
	# `Type` that solves the constraint.
	fun default_solution: Type is abstract
end

class SubtypeConstraint
	super FormalTypeConstraint
	protected var supertype: Type

	redef fun is_valid(ty)
	do
		return ty.iza(self.supertype)
	end

	redef fun default_solution do return supertype
end

redef class Type
	fun is_primitive: Bool is abstract
end

class StdType
	super Type
	protected var type_info: TypeInfo
	protected var my_klass: Class
	protected var cached_properties: nullable Set[Property]
	protected var cached_decl_properties: nullable Set[Property]

	redef fun properties
	do
		if cached_decl_properties == null then
			var res = new HashSet[Property]
			var my_klass = self.my_klass.as(StdClass)
			for prop in my_klass.classinfo.properties do
				var prop2 = mirror_repo.from_propinfo(prop, self)
				res.add(prop2)
			end
			cached_decl_properties = res
		end
		return cached_decl_properties.as(not null)
	end

	redef fun declared_properties
	do
		if cached_properties == null then
			cached_properties = super
		end
		return cached_properties.as(not null)
	end

	redef fun klass do return self.my_klass

	redef fun as_nullable
	do
		var nullabl = self.type_info.as_nullable
		var res = mirror_repo.from_typeinfo(nullabl)
		return res
	end

	redef fun as_not_null
	do
		if not is_nullable then return self
		var notnull = self.type_info.as_not_null
		var res = mirror_repo.from_typeinfo(notnull)
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

	redef fun can_new_instance(args)
	do
		return true
	end

	redef fun new_instance(args)
	do
		var args2 = new Array[nullable Object]
		for a in args do args2.push(a)
		return self.type_info.new_instance(args2)
	end

	# TODO : remove this when cache is ready
	redef fun ==(o) do return o isa SELF and o.type_info == type_info
end

class StdDerivedType
	super DerivedType
	super StdType
end

abstract class StdProperty
	super Property

	type PROPINFO : PropertyInfo

	protected var propinfo: PROPINFO
	protected var intro: Class
	protected var anchor: Type

	new(propinfo: PropertyInfo, klass: Class, anchor: Type)
	do
		if propinfo isa AttributeInfo then
			return new StdAttribute(propinfo, klass, anchor)
		else if propinfo isa MethodInfo then
			return new StdMethod(propinfo, klass, anchor)
		else
			assert propinfo isa VirtualTypeInfo
			return new StdVirtualType(propinfo, klass, anchor)
		end
	end

	redef fun introducer do return self.intro

	# TODO: remove this when cache is ready.
	redef fun ==(o) do return o isa SELF and o.propinfo == propinfo

	redef fun name do return self.propinfo.name
end

redef class Attribute
	fun get_for(object: Object): nullable Object is abstract
	fun set_for(object: Object, val: nullable Object) is abstract
end

class StdAttribute
	super StdProperty
	super Attribute

	redef type PROPINFO: AttributeInfo

	redef fun dyn_type
	do
		var anchor = self.anchor.as(StdType)
		var typeinfo = self.propinfo.dynamic_type(anchor.type_info)
		var res = mirror_repo.from_typeinfo(typeinfo)
		return res
	end

	redef fun name
	do
		var res = super
		return res.substring_from(1)
	end

	redef fun get_for(object)
	do
		return self.propinfo.value(object)
	end
end

class StdMethod
	super StdProperty
	super Method

	redef type PROPINFO: MethodInfo
end

class StdVirtualType
	super StdProperty
	super VirtualType

	redef type PROPINFO: VirtualTypeInfo
end
