import runtime_reflection
import runtime_internals

redef class Sys
	super Environment

	private var mirror_repo = new MirrorRepository

	redef fun class_exist(classname)
	do
		return self.rti_repo.get_classinfo(classname) != null
	end

	fun get_type(typename: String): TypeMirror
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

redef class TypeInfo

	# Determines if the type is closed, ie it is not a generic,
	# formal type, or any kind of unresolved type.
	fun is_closed: Bool
	do
		if self.is_formal_type then return false
		var res = true
		for targ in type_arguments do
			res = res and not targ.is_closed
		end
		return res
	end
end

private class MirrorRepository
	fun from_classinfo(classinfo: ClassInfo): StdClass
	do
		return new StdClass(classinfo)
	end

	fun from_typeinfo(typeinfo: TypeInfo): StdType
	is
		expect(typeinfo.is_closed)
	do
		var klass = self.from_classinfo(typeinfo.describee)
		var res = new StdType(typeinfo, klass)
		return res
	end

	fun from_propinfo(propinfo: PropertyInfo, anchor: TypeMirror): StdProperty
	do
		var klass = self.from_classinfo(propinfo.introducer)
		return new StdProperty(propinfo, klass, anchor)
	end
end

private class StdDeclaration
	super DeclarationMirror

	private var propinfo: PropertyInfo
	private var my_klass: ClassMirror

	redef fun is_public do return propinfo.is_public
	redef fun is_private do return propinfo.is_private
	redef fun is_protected do return propinfo.is_protected
	redef fun klass do return my_klass

	redef fun bind(im)
	do
		return new StdPropertyInfo(propinfo, self, im)
	end
end

private class StdMethodDeclaration
	super StdDeclaration
	super MethodDeclaration

	redef fun return_type
	do
		var return_type = self.propinfo.return_type
		if return_type == null then return null
	end
end

private class StdAttributeDeclaration
	super StdDeclaration
	super AttributeDeclaration

	redef fun static_type
	do
		var typeinfo = propinfo.static_type
		return mirror_repo.from_typeinfo(typeinfo)
	end
end

private class StdVirtualTypeDeclaration
	super StdDeclaration
	super VirtualTypeDeclaration
end

private class StdClass
	super ClassMirror
	private var classinfo: ClassInfo
	private var cached_ancestors: nullable SequenceRead[ClassMirror]
	private var cached_type_param: nullable SequenceRead[TypeParameter]

	private fun refresh_cache_type_param: SequenceRead[TypeParameter]
	do
		var res = new Array[TypeParameter]
		var i = 0
		for tvar in self.classinfo.type_parameters do
			# NOTE: If the type system becomes more complexe
			# we would need to support more constraint.
			var bound = mirror_repo.from_typeinfo(tvar.bound)
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
	do
		return self.classinfo.type_param_bounds.length
	end

	redef fun ancestors
	do
		if self.cached_ancestors == null then
			var classes = self.classinfo.ancestors
			var res = new Array[ClassMirror]
			for classinfo in classes do
				var klass = mirror_repo.from_classinfo(classinfo)
				res.push(klass)
			end
			self.cached_ancestors = res
		end
		return self.cached_ancestors
	end

	redef fun type_parameters
	do
		return cached_type_param or else refresh_cache_type_param
	end

	redef fun bound_type
	do
		var types = new Array[TypeMirror]
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

abstract class StdStaticType
	super StaticType
	private var typeinfo: TypeInfo
end

private class StdTypeParameter
	super StdStaticType
	super TypeParameter
	private var belongs_to: ClassMirror
	private var my_constraint: FormalTypeConstraint
	private var my_rank: Int

	redef fun klass do return self.belongs_to
	redef fun constraint do return self.my_constraint
	redef fun my_rank do return self.my_rank
end

redef class FormalTypeConstraint
	# Given the constraint `self`, returns the most basic
	# `TypeMirror` that solves the constraint.
	fun default_solution: TypeMirror is abstract
end

private class SubtypeConstraint
	super FormalTypeConstraint
	private var supertype: TypeMirror

	redef fun is_valid(ty)
	do
		return ty.iza(self.supertype)
	end

	redef fun default_solution do return supertype
end

redef class TypeMirror
	fun is_primitive: Bool is abstract
end

private class StdType
	super TypeMirror
	private var type_info: TypeInfo
	private var my_klass: ClassMirror

	redef fun typed_ancestors
	do
	end

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

private class StdInstance
	super InstanceMirror
	private var instance: Object
	private var my_klass: ClassMirror
	private var cached_properties: nullable Collection[Property]
	private var cached_decl_properties: nullable Set[Property]

	redef fun klass do return self.my_klass

	redef fun unwrap do return self.instance

	redef fun properties
	do
		if cached_decl_properties == null then
			var res = new Array[Property]
			for decl in klass.decls do
				var object_prop = decl.bind(self)
				res.add(res)
			end
			cached_decl_properties = res
		end
		return cached_decl_properties.as(not null)
	end

	redef fun decl_properties
	do
		if cached_properties == null then
			cached_properties = super
		end
		return cached_properties.as(not null)
	end
end

private abstract class StdProperty
	super Property
	type PROPINFO : PropertyInfo

	private var propinfo: PROPINFO
	private var my_decl: DeclarationMirror is noinit
	private var my_recv: InstanceMirror is noinit

	new(propinfo: PropertyInfo, decl: DeclarationMirror, recv: InstanceMirror)
	do
		if propinfo isa AttributeInfo then
			return new StdAttribute(propinfo, decl, recv)
		else if propinfo isa MethodInfo then
			return new StdMethod(propinfo, decl, recv)
		else
			assert propinfo isa VirtualTypeInfo
			return new StdVirtualType(propinfo, decl, recv)
		end
	end

	redef fun recv do return self.my_recv

	# TODO: remove this when cache is ready.
	redef fun ==(o) do return o isa SELF and o.propinfo == propinfo

	redef fun name do return self.propinfo.name
end

private class StdAttribute
	super StdProperty
	super AttributeMirror

	redef type PROPINFO: AttributeInfo

	redef fun name
	do
		var res = super
		return res.substring_from(1)
	end

	redef fun get()
	do
		return self.propinfo.value(recv.unwrap)
	end
end

private class StdMethod
	super StdProperty
	super MethodMirror
	redef type PROPINFO: MethodInfo
end

private class StdVirtualType
	super StdProperty
	super VirtualTypeMirror
	redef type PROPINFO: VirtualTypeInfo
end
