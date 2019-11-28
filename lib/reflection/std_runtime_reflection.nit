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

	redef fun reflect(object)
	do
		return new StdInstance(object)
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
			res = res and targ.is_closed
		end
		return res
	end

	fun is_nullable: Bool
	do
		return self.as_nullable == self
	end
end

private class MirrorRepository
	fun from_classinfo(classinfo: ClassInfo): ClassMirror
	do
		return new StdClass(classinfo)
	end

	fun from_typeinfo(typeinfo: TypeInfo): TypeMirror
	is
		expect(typeinfo.is_closed)
	do
		var klass = self.from_classinfo(typeinfo.klass)
		var res = new StdType(typeinfo, klass)
		if typeinfo.is_nullable then
			return res.as_nullable
		end
		return res
	end
end

private abstract class StdDeclaration
	super DeclarationMirror

	private type PROPINFO: PropertyInfo
	private var propinfo: PROPINFO
	private var my_klass: ClassMirror

	redef fun is_public do abort #return propinfo.is_public
	redef fun is_private do abort #return propinfo.is_private
	redef fun is_protected do abort #return propinfo.is_protected
	redef fun klass do return my_klass

	new(propinfo: PROPINFO, klass: ClassMirror)
	do
		if propinfo isa AttributeInfo then
			return new StdAttributeDeclaration(propinfo, klass)
		else if propinfo isa MethodInfo then
			return new StdMethodDeclaration(propinfo, klass)
		else
			assert propinfo isa VirtualTypeInfo
			return new StdVirtualTypeDeclaration(propinfo, klass)
		end
	end

	redef fun into_property(class_itf)
	do
		var res = new StdProperty(propinfo, self, class_itf)
		return res
	end

	redef fun name do return propinfo.name

end

private class StdMethodDeclaration
	super StdDeclaration
	super MethodDeclaration

	redef type PROPINFO: MethodInfo

	redef fun return_type
	do
		var return_type = self.propinfo.return_type
		if return_type == null then return null
		return new StdStaticType(return_type)
	end
end

private class StdAttributeDeclaration
	super StdDeclaration
	super AttributeDeclaration

	redef type PROPINFO: AttributeInfo

	redef fun static_type
	do
		var typeinfo = propinfo.static_type
		return new StdStaticType(typeinfo)
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
	private var cached_supertypes: nullable Collection[SuperTypeAttributeMirror]
	private var cached_type_param: nullable SequenceRead[TypeParameter]
	private var cached_declarations: nullable Collection[DeclarationMirror]

	private fun refresh_cache_type_param: SequenceRead[TypeParameter]
	do
		var res = new Array[TypeParameter]
		var i = 0
		for tvar in self.classinfo.type_parameters do
			# NOTE: If the type system becomes more complexe
			# we would need to support more constraint.
			var bound = mirror_repo.from_typeinfo(tvar.bound)
			var constraint = new SubtypeConstraint(bound)
			var typeparam = new StdTypeParameter(tvar, self, constraint, i)
			res.push(typeparam)
			i += 1
		end
		self.cached_type_param = res
		return res
	end

	redef fun declarations
	do
		if self.cached_declarations == null then
			var res = new Array[DeclarationMirror]
			for prop in self.classinfo.properties do
				var wrapped = new StdDeclaration(prop, self)
				res.push(wrapped)
			end
			self.cached_declarations = res
		end
		return self.cached_declarations.as(not null)
	end

	redef fun name do return classinfo.to_s

	redef fun arity
	do
		return self.type_parameters.length
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
		return self.cached_ancestors.as(not null)
	end

	redef fun type_parameters
	do
		return cached_type_param or else refresh_cache_type_param
	end

	redef fun supertypes
	do
		if cached_supertypes == null then
			var supertypes = self.classinfo.super_decls
			var res = new Array[SuperTypeAttributeMirror]
			for st in supertypes do
				var st2 = new StdSuperType(st, self)
				res.add(st2)
			end
			cached_supertypes = res
		end
		return cached_supertypes.as(not null)
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

private class StdSuperType
	super SuperTypeAttributeMirror

	private var typeinfo: TypeInfo
	private var belongs_to: ClassMirror

	redef fun name do return typeinfo.to_s

	redef fun klass do return self.belongs_to

	# TODO
	redef fun static_type do abort
end

private class StdStaticType
	super StaticType
	private var typeinfo: TypeInfo

	redef fun name do return typeinfo.to_s

	redef fun ==(o) do return o isa SELF and o.typeinfo == typeinfo
end

private class StdTypeParameter
	super TypeParameter
	super StdStaticType

	private var belongs_to: ClassMirror
	private var my_constraint: FormalTypeConstraint
	private var my_rank: Int

	redef fun klass do return self.belongs_to
	redef fun constraint do return self.my_constraint
	redef fun rank do return self.my_rank

	# TODO
	redef fun to_dyn(recv_type) do abort
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

	redef fun klass do return self.my_klass

	redef fun as_nullable
	do
		if type_info.is_nullable then return self
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

	redef fun name
	do
		return type_info.to_s
	end
end

private class StdInstance
	super InstanceMirror
	private var instance: Object
	private var tm: TypeMirror is noinit
	private var cached_properties: nullable Collection[PropertyMirror] = null
	private var cached_decl_properties: nullable Collection[PropertyMirror] = null

	init
	do
		self.tm = typeof(instance)
	end

	redef fun to_s do return instance.to_s

	redef fun klass do return self.tm.klass
	redef fun dyn_type do return self.tm

	redef fun unwrap do return self.instance

	redef fun properties
	do
		if cached_decl_properties == null then
			cached_decl_properties = super
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
	super PropertyMirror
	type PROPINFO : PropertyInfo

	private var propinfo: PROPINFO
	private var my_decl: DECLARATION
	private var class_itf: ClassInterfaceMirror

	new(propinfo: PropertyInfo, decl: DeclarationMirror, itf: ClassInterfaceMirror)
	do
		if propinfo isa AttributeInfo then
			assert decl isa AttributeDeclaration
			return new StdAttribute(propinfo, decl, itf)
		else if propinfo isa MethodInfo then
			assert decl isa MethodDeclaration
			return new StdMethod(propinfo, decl, itf)
		else
			assert decl isa VirtualTypeDeclaration
			assert propinfo isa VirtualTypeInfo
			return new StdVirtualType(propinfo, decl, itf)
		end
	end

	redef fun decl do return self.my_decl

	redef fun recv
	do
		return self.class_itf.as(InstanceMirror)
	end

	redef fun class_interface do return self.class_itf

	# TODO: remove this when cache is ready.
	redef fun ==(o) do return o isa SELF and o.propinfo == propinfo

	redef fun name do return self.propinfo.name
end

private class StdAttribute
	super StdProperty
	super AttributeMirror

	redef type PROPINFO: AttributeInfo
	private var cached_dyn_type: nullable TypeMirror = null

	redef fun name
	do
		var res = super
		return res.substring_from(1)
	end

	redef fun get
	do
		return self.propinfo.value(recv.unwrap)
	end

	redef fun dyn_type
	do
		if self.cached_dyn_type == null then
			var recv_type = class_itf.dyn_type
			assert recv_type isa StdType
			var dyntype = propinfo.dynamic_type(recv_type.type_info)
			var res = mirror_repo.from_typeinfo(dyntype)
			self.cached_dyn_type = res
		end
		return self.cached_dyn_type.as(not null)
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
