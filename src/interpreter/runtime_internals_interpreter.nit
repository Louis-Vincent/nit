import universal_instance
import native_array_tools
import model::model_collect

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var cname = mpropdef.mclassdef.mclass.name
		var pname = mpropdef.mproperty.name
		if cname == "Sys" and pname == "rti_repo" then
			return v.runtime_rti_repo
		else
			return super
		end
	end
end

redef class Model

	# Returns true if there's 0 or 1 `MClass` whose name is `classname`,
	# otherwise false.
	fun is_unique(classname: String): Bool
	is
		expect(self.has_mclass(classname))
	do
		var mclasses = self.get_mclasses_by_name(classname).as(not null)
		return mclasses.length == 1
	end

	fun has_mclass(classname: String): Bool
	do
		var mclasses = self.get_mclasses_by_name(classname)
		return mclasses != null
	end

	# Tries to find an instance of `MClass` named `classname`.
	# If it doesn't exist then it returns null. If more than one `MClass` have
	# the same `classname` then it fails.
	fun get_mclass(classname: String): MClass
	is
		expect(self.is_unique(classname))
	do
		var mclasses = self.get_mclasses_by_name(classname).as(not null)
		return mclasses.first
	end

	fun get_mclass_in_mmodule(classname: String, intro_mmodule_name: String): MClass
	is
		expect(self.has_mclass(classname))
	do
		var mclasses = self.get_mclasses_by_name(classname).as(not null)
		for mclass in mclasses do
			if mclass.intro_mmodule.name == intro_mmodule_name then
				return mclass
			end
		end
		abort
	end
end

redef class MType
	# Returns `self` as a closed `MType` instance
	fun close: MType
	do
		var mtype = self
		var res = mtype
		if mtype isa MClassType and mtype.need_anchor then
			res = mtype.mclass.intro.bound_mtype
		end
		if self isa MNullableType then
			res = res.as_nullable
		end
		return res
	end

	# The class where the mtype belongs/links to.
	fun mclass_link : MClass is abstract
end

redef class MClassType
	redef fun mclass_link do return self.mclass
end

redef class MProxyType
	redef fun mclass_link do return mtype.mclass_link
end

redef class NaiveInterpreter

	var rti_repo: RuntimeInternalsRepo is noinit

	# There's only one instance of `RuntimeInternalsRepo` at runtime
	var runtime_rti_repo: RuntimeInternalsRepoImpl is noinit
	var property_factory: PropertyFactory is noinit

	# Runtime meta types
	var type_type: MClassType is noinit
	var class_iterator_type: MClassType is noinit
	var type_iterator_type: MClassType is noinit
	var prop_iterator_type: MClassType is noinit

	init
	do
		var model = self.mainmodule.model
		var mmodule_name = "runtime_internals"
		if model.has_mclass("RuntimeInternalsRepo") then
			self.rti_repo = new RuntimeInternalsRepo(model)
			self.property_factory = new PropertyFactory(model)

			var runtime_rti_repo_type = model.get_mclass_in_mmodule("RuntimeInternalsRepo", mmodule_name).mclass_type
			runtime_rti_repo = new RuntimeInternalsRepoImpl(runtime_rti_repo_type, self.rti_repo)

			self.type_type = model.get_mclass_in_mmodule("TypeInfo", mmodule_name).mclass_type
			var prop_type = model.get_mclass_in_mmodule("PropertyInfo", mmodule_name).mclass_type
			var class_type = model.get_mclass_in_mmodule("ClassInfo", mmodule_name).mclass_type

			var rt_iterator_class = model.get_mclass_in_mmodule("RuntimeInfoIterator", mmodule_name)
			self.type_iterator_type = rt_iterator_class.get_mtype([self.type_type])
			self.prop_iterator_type = rt_iterator_class.get_mtype([prop_type])
			self.class_iterator_type = rt_iterator_class.get_mtype([class_type])
		end
	end

	fun isa_array(instance: Instance): Bool
	do
		var mtype = instance.mtype
		return mtype isa MClassType and self.mainmodule.array_class == mtype.mclass
	end

	# Transfers a runtime instance whose `mtype` is Array to an actual
	# Array in the interpreter world.
	fun runtime_array_to_native(array_instance: Instance): nullable Array[Instance]
	is
		expect(isa_array(array_instance))
	do
		assert array_instance isa MutableInstance
		var mtype = array_instance.mtype
		var native_instance = self.send(self.force_get_primitive_method("items", mtype), [array_instance])
		if native_instance == null then return null

		if not native_instance isa PrimitiveInstance[Array[Instance]] then
			return null
		else
			#debug "native array: {native_instance}, inner: {native_instance.inner}"
			var i = self.send(self.force_get_primitive_method("length", mtype), [array_instance]).to_i
			var j = self.send(self.force_get_primitive_method("length", native_instance.mtype), [native_instance]).to_i
			return native_instance.val
		end
	end

	# Converts a runtime `String` to an actual String in the interpreter
	# context.
	fun instance_to_s(object: Instance): String
	do
		assert object isa MutableInstance
		var res = self.send(self.force_get_primitive_method("to_cstring", object.mtype), [object])
		return res.val.as(CString).to_s
	end
end

class RuntimeInternalsRepo
	protected var model: Model
	protected var cached_type = new HashMap[MType, TypeInfo]
	protected var cached_class = new HashMap[MClass, ClassInfo]

	fun get_class_by_name(classname: String): nullable ClassInfo
	do
		if self.model.has_mclass(classname) then
			var mclass = self.model.get_mclass(classname)
			return self.from_mclass(mclass)
		else
			return null
		end
	end

	# Returns an instance of `TypeInfo` from a `MType`. The argument `mtype`
	# must be a `MClassType` or `MNullableType` whose proxied type is a
	# `MClassType`.
	fun from_mtype(mtype: MType): TypeInfo
	is
		expect(not mtype.undecorate isa MProxyType)
	do
		var mtype2 = mtype.undecorate
		var res = self.from_cache(mtype2)
		if mtype isa MNullableType then
			return as_nullable(res)
		else
			return res
		end
	end

	fun as_nullable(ty: TypeInfo): TypeInfo
	do
		if ty.is_nullable then return ty
		if ty.nullable_self != null then
			return ty.nullable_self.as(not null)
		end
		var type_type = model.get_mclass("TypeInfo").mclass_type
		var res = new TypeInfo(type_type, ty.reflectee)
		res.is_nullable = true
		ty.nullable_self = res
		return res
	end

	fun from_mclass(mclass: MClass): ClassInfo
	do
		if cached_class.has_key(mclass) then
			return cached_class[mclass]
		end
		var class_type = model.get_mclass("ClassInfo").mclass_type
		var res = new ClassInfo(class_type, mclass)
		cached_class[mclass] = res
		return res
	end

	protected fun from_cache(mtype: MType): TypeInfo
	do
		if cached_type.has_key(mtype) then
			return cached_type[mtype]
		end
		var type_type = model.get_mclass("TypeInfo").mclass_type
		var res = new TypeInfo(type_type, mtype)
		cached_type[mtype] = res
		return res
	end
end

# To promote loose coupling between `PropertyInfo` and `NaiveInterpreter`,
# the `PropertyFactory` has the job of instantiating AND caching `PropertyInfo` with
# the proper runtime type.
class PropertyFactory
	var model: Model
	protected var cached_properties = new HashMap[MPropDef, PropertyInfo]
	protected fun get_meta_type(meta_typename: String): MClassType
	do
		var mclasses = self.model.get_mclasses_by_name(meta_typename)
		assert missing_meta_classes: mclasses != null
		assert ambiguous_name: mclasses.length == 1
		return mclasses.first.mclass_type
	end

	fun build(mpropdef: MPropDef): PropertyInfo
	do
		if cached_properties.has_key(mpropdef) then
			return cached_properties[mpropdef]
		end
		var res: PropertyInfo
		var mtype: MType
		if mpropdef isa MMethodDef then
			mtype = get_meta_type("MethodInfo")
			res = new MethodInfo(mtype, mpropdef)
		else if mpropdef isa MAttributeDef then
			mtype = get_meta_type("AttributeInfo")
			res = new AttributeInfo(mtype, mpropdef)
		else if mpropdef isa MVirtualTypeDef then
			mtype = get_meta_type("VirtualTypeInfo")
			res = new VirtualTypeInfo(mtype, mpropdef)
		else
			abort
		end

		cached_properties[mpropdef] = res
		return res
	end
end

# Exposed `RuntimeInternalsRepo` for the interpreter runtime.
class RuntimeInternalsRepoImpl
	super Universal
	var rti_repo: RuntimeInternalsRepo

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "get_classinfo" then
			out.ok = self.get_classinfo(v, args[1])
		else if pname == "object_type" then
			out.ok = self.object_type(v, args[1])
		end
	end

	protected fun get_classinfo(v: NaiveInterpreter, classname: Instance): nullable ClassInfo
	do
		var classname2 = v.instance_to_s(classname)
		return self.rti_repo.get_class_by_name(classname2)
	end

	# Returns the underlying `TypeInfo` from a runtime instance.
	protected fun object_type(v: NaiveInterpreter, object: Instance): TypeInfo
	do
		return rti_repo.from_mtype(object.mtype)
	end
end

private abstract class Constructor
	private var mclass: MClass
	private var mpropdef: MMethodDef

	new(mclass: MClass, mpropdef: MMethodDef)
	do
		var mprop = mpropdef.mproperty
		if mprop.is_new then
			return new NewFactory(mclass, mpropdef)
		else if mprop.is_init then
			var kind = mclass.kind
			if kind == concrete_kind then
				return new GeneralizedInitializers(mclass, mpropdef)
			end
		end
		return new IllegalConstructor(mclass, mpropdef)
	end

	fun new_instance(v: NaiveInterpreter, args: SequenceRead[Instance], mtype: MClassType): Instance is abstract
end

private class NullConstructor
	super Constructor
end

private class IllegalConstructor
	super Constructor
end

private class Constructors
	super Array[Constructor]

	# Folds an array of constructors and return the most dominant
	# constructors.
	private fun fold_constrs : Constructor
	is
		expect(not self.is_empty)
	do
		var constr = self.first
		for c in self do
			if constr isa NewFactory then break
			if not c isa IllegalConstructor then
				constr = c
			end
		end
		return constr
	end
end

private class NewFactory
	super Constructor

	redef fun new_instance(v, args, mtype)
	do
		var msignature = mpropdef.msignature.as(not null)
		var args2 = new Array[Instance]
		args2.add_all(args)
		var temp_recv = new MutableInstance(mtype)
		v.init_instance(temp_recv)
		args2.unshift temp_recv
		var res = v.send(mpropdef.mproperty, args2)
		assert res != null
		return res
	end
end

private class GeneralizedInitializers
	super Constructor

	redef fun new_instance(v, args, mtype)
	do
		var args2 = new Array[Instance]
		args2.add_all(args)
		var mpropdef = self.mpropdef
		var instance = new MutableInstance(mtype)
		v.init_instance(instance)
		args2.unshift instance
		v.invoke_initializers(mpropdef.initializers, args2)
		v.send(mpropdef.mproperty, [instance])
		return instance
	end
end

class ClassInfo
	super Universal
	protected var reflectee: MClass
	protected var cached_properties: nullable SequenceRead[PropertyInfo] = null

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "classid" then
			out.ok = v.int_instance(0)
		else if pname == "properties" then
			out.ok = self.properties(v)
		else if pname == "unbound_type" then
			out.ok = self.unbound_type(v)
		else if pname == "ancestors" then
			out.ok = self.ancestors(v)
		else if pname == "name" then
			out.ok = self.name(v)
		else if pname == "new_type" then
			out.ok = self.new_type(v, args[1])
		else if pname == "type_parameters" then
			out.ok = self.type_parameters(v)
		else if pname == "super_decls" then
			out.ok = self.super_decls(v)
		end
	end

	protected fun super_decls(v: NaiveInterpreter): InstanceIterator[TypeInfo]
	do
		var mclassdefs = self.reflectee.mclassdefs
		var res = new Array[TypeInfo]
		for mclassdef in mclassdefs do
			for ty in mclassdef.supertypes do
				if ty == v.mainmodule.object_type then continue
				var typeinfo = v.rti_repo.from_mtype(ty)
				res.add(typeinfo)
			end
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, res.iterator)
	end

	protected fun new_type(v: NaiveInterpreter, args: Instance): TypeInfo
	do
		var temp = v.native_array_view(args)
		var types = new Array[MType]
		#v.debug "class: {self.reflectee} , arity: {self.reflectee.arity}"
		assert temp.length == self.reflectee.arity
		for ty in temp do
			assert ty isa TypeInfo
			types.push(ty.reflectee)
		end
		var mtype = self.reflectee.get_mtype(types)
		return v.rti_repo.from_mtype(mtype)
	end

	protected fun unbound_type(v: NaiveInterpreter): TypeInfo
	do
		var mtype = self.reflectee.mclass_type
		return v.rti_repo.from_mtype(mtype)
	end

	protected fun name(v: NaiveInterpreter): Instance
	do
		return v.string_instance(self.reflectee.name)
	end

	protected fun properties(v: NaiveInterpreter): InstanceIterator[PropertyInfo]
	do
		if cached_properties == null then
			var mclass = self.reflectee
			var mmodule = v.mainmodule
			var mprops = mclass.collect_accessible_mproperties(mmodule)
			# Cache our properties
			var cached_properties = new Array[PropertyInfo]
			for mprop in mprops do
				# Get the most specific implementation
				var mtype = mclass.mclass_type
				# First, we need to make sure mtype doesn't need an anchor,
				# otherwise we can't call `lookup_first_definition`.
				if mtype.need_anchor then
					mtype = mclass.intro.bound_mtype
				end
				var mpropdef = mprop.lookup_first_definition(mmodule, mtype)
				var propertyinfo = v.property_factory.build(mpropdef)
				cached_properties.push(propertyinfo)
			end
			self.cached_properties = cached_properties
		end
		return new InstanceIterator[PropertyInfo](v.prop_iterator_type, cached_properties.iterator)
	end

	private fun get_constructor(v: NaiveInterpreter): Constructor
	do
		if cached_properties == null then
			# Load the properties
			self.properties(v)
		end
		var constructors = new Constructors
		for propinfo in cached_properties do
			var mpropdef = propinfo.mpropdef
			if mpropdef isa MMethodDef then
				var mprop = mpropdef.mproperty
				if mprop.is_init or mprop.is_new then
					constructors.add(new Constructor(self.reflectee, mpropdef))
				end
			end
		end
		if constructors.is_empty then
			v.fatal("Fatal error: found no constructor for type: `{self.reflectee}`")
			abort
		end
		var constr = constructors.fold_constrs
		if constr isa IllegalConstructor then
			v.fatal("Fatal error: illegal constructor invokation for type: `{self.reflectee}`")
			abort
		else
			return constr
		end
	end

	protected fun ancestors(v: NaiveInterpreter): InstanceIterator[ClassInfo]
	do
		var mmodule = v.mainmodule
		var mclass = self.reflectee
		var ancestors = mclass.collect_ancestors(mmodule, null).to_a
		mmodule.linearize_mclasses(ancestors)
		var ancestors2 = new Array[ClassInfo]
		for a in ancestors do
			var classinfo = v.rti_repo.from_mclass(a)
			ancestors2.push(classinfo)
		end
		return new InstanceIterator[ClassInfo](v.class_iterator_type, ancestors2.reverse_iterator)

	end

	protected fun type_parameters(v: NaiveInterpreter): Instance
	do
		var mparameters = self.reflectee.mparameters
		var res = new Array[TypeInfo]
		for mparam in mparameters do
			var ty = v.rti_repo.from_mtype(mparam)
			res.push(ty)
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, res.iterator)
	end
end

redef class MFormalType
	fun static_bound(mmodule: MModule): MType is abstract
end

redef class MParameterType
	redef fun close
	do
		var bound = mclass.intro.bound_mtype.arguments[self.rank]
		return bound
	end
	redef fun static_bound(mmodule)
	do
		var mclass_type = mclass.most_specific_def(mmodule)
		var bound_mtype = mclass_type.bound_mtype
		return bound_mtype.arguments[rank]
	end
	redef fun mclass_link do return self.mclass
end

redef class MVirtualType
	redef fun static_bound(mmodule)
	do
		var propdefs = self.mproperty.collect_linearization(mmodule)
		var most_specific = propdefs.last.as(MVirtualTypeDef)
		assert most_specific.bound != null
		return most_specific.bound.as(not null)
	end

	redef fun mclass_link
	do
		return self.mproperty.intro_mclassdef.mclass
	end
end

class TypeInfo
	super Universal
	var reflectee: MType

	protected var is_nullable = false

	# To prevent too much duplication of type info, we cache its nullable
	# equivalent
	private var nullable_self: nullable TypeInfo = null

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "name" then
			out.ok = self.name(v)
		else if pname == "is_generic" then
			out.ok = self.is_generic(v)
		else if pname == "is_interface" then
			out.ok = self.is_interface(v)
		else if pname == "is_abstract" then
			out.ok = self.is_abstract(v)
		else if pname == "is_universal" then
			out.ok = self.is_universal(v)
		else if pname == "is_derived" then
			out.ok = self.is_derived(v)
		else if pname == "is_formal_type" then
			out.ok = self.is_formal_type(v)
		else if pname == "resolve" then
			out.ok = self.resolve(v, args)
		else if pname == "as_not_null" then
			out.ok = self.as_not_null(v)
		else if pname == "as_nullable" then
			out.ok = self.as_nullable(v)
		else if pname == "type_arguments" then
			out.ok = self.type_arguments(v)
		else if pname == "iza" then
			out.ok = self.iza(v, args[1].as(TypeInfo))
		else if pname == "klass" then
			out.ok = self.klass(v)
		else if pname == "new_instance" then
			out.ok = self.new_instance(v, args[1])
		else if pname == "bound" then
			out.ok = self.bound(v)
		else if pname == "native_equal" then
			out.ok = self.native_equal(v, args[1])
		end
	end

	# Native equal is necessary due to generic type.
	# Generic type cause the identity equality test to fail, since the cache
	# can't reuse previously cached formal type from the origina class the
	# generic type might extends.
	protected fun native_equal(v: NaiveInterpreter, o: Instance): Instance
	do
		assert o isa TypeInfo
		var res = reflectee == o.reflectee and is_nullable == o.is_nullable
		return v.bool_instance(res)
	end

	protected fun bound(v: NaiveInterpreter): TypeInfo
	is
		expect(self.reflectee isa MFormalType)
	do
		var reflectee = self.reflectee.as(MFormalType)
		var mmodule = v.mainmodule
		var bound = reflectee.static_bound(mmodule)
		return v.rti_repo.from_mtype(bound)
	end

	protected fun klass(v: NaiveInterpreter): ClassInfo
	do
		var mclass = self.reflectee.mclass_link
		return v.rti_repo.from_mclass(mclass)
	end

	protected fun new_instance(v: NaiveInterpreter, arg: Instance): Instance
	is
		expect(not self.reflectee.need_anchor,
			self.reflectee.undecorate isa MClassType)
	do
		var init_args = v.native_array_view(arg)
		var mmodule = v.mainmodule
		var mtype = self.reflectee.undecorate.as(MClassType)
		var classinfo = v.rti_repo.from_mclass(mtype.mclass)
		var constructor = classinfo.get_constructor(v)
		return constructor.new_instance(v, init_args, mtype)
	end

	protected fun iza(v: NaiveInterpreter, other: TypeInfo): Instance
	do
		var sub = self.reflectee.close
		var sup = other.reflectee.close
		var res = sub.is_subtype(v.mainmodule, null, sup)
		return v.bool_instance(res)
	end

	protected fun resolve(v: NaiveInterpreter, args: SequenceRead[Instance]): TypeInfo
	is
		expect(args.length == 2, self.reflectee isa MGenericType)
	do
		# NOTE: no need to cache derived type inside a table since
		# `MClass::get_mtype` already does it for us.
		var args2 = v.native_array_view(args[1])

		var reflectee = self.reflectee.as(MGenericType)
		# Maps args2 to an array of `MClassType`
		var args3 = new Array[MClassType]
		for arg in args2 do
			assert param_must_be_type_infos: arg isa TypeInfo
			assert type_info_must_reference_class_type: arg.reflectee isa MClassType
			args3.push(arg.reflectee.as(MClassType))
		end

		var derived_type = reflectee.mclass.get_mtype(args3)
		var res = v.rti_repo.from_mtype(derived_type)
		return res
	end

	protected fun type_arguments(v: NaiveInterpreter): Instance
	do
		# NOTE: Should we look through the inheritance hierarchy?
		var mtype = self.reflectee.undecorate.as(MClassType)
		var types = new Array[TypeInfo]
		var rti_repo = v.rti_repo
		for arg in mtype.arguments do
			var ty = rti_repo.from_mtype(arg)
			types.push(ty)
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, types.iterator)
	end

	protected fun as_not_null(v: NaiveInterpreter): TypeInfo
	do
		if not self.is_nullable then return self
		return v.rti_repo.from_mtype(self.reflectee)
	end

	protected fun as_nullable(v: NaiveInterpreter): TypeInfo
	do
		return v.rti_repo.as_nullable(self)
	end

	protected fun name(v: NaiveInterpreter): Instance
	do
		var res: Instance
		if self.is_nullable then
			res = v.string_instance("nullable {self.reflectee.name}")
		else
			res = v.string_instance(self.reflectee.name)
		end
		return res
	end

	protected fun is_generic(v: NaiveInterpreter): Instance
	do
		var res = self.reflectee isa MGenericType and self.reflectee.need_anchor
		return v.bool_instance(res)
	end

	protected fun is_interface(v: NaiveInterpreter): Instance
	do
		var res = false
		var reflectee = self.reflectee
		if reflectee isa MClassType then
			res = reflectee.mclass.is_interface
		end
		return v.bool_instance(res)
	end

	protected fun is_abstract(v: NaiveInterpreter): Instance
	do
		var res = false
		var reflectee = self.reflectee
		if reflectee isa MClassType then
			res = reflectee.mclass.is_abstract
		end
		return v.bool_instance(res)
	end

	protected fun is_universal(v: NaiveInterpreter): Instance
	do
		var res = false
		var reflectee = self.reflectee
		if reflectee isa MClassType then
			res = reflectee.mclass.is_enum
		end
		return v.bool_instance(res)
	end

	protected fun is_derived(v: NaiveInterpreter): Instance
	do
		# NOTE: Should we look through the inheritance hierarchy?
		var res = self.reflectee isa MGenericType and not self.reflectee.need_anchor
		return v.bool_instance(res)
	end

	protected fun is_formal_type(v: NaiveInterpreter): Instance
	do
		var res = self.reflectee isa MFormalType
		return v.bool_instance(res)
	end
end

abstract class PropertyInfo
	super Universal

	protected type MPROPDEF: MPropDef
	protected var mpropdef: MPROPDEF
	protected var cached_linearization: Array[PropertyInfo] is noinit

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "name" then
			out.ok = self.name(v)
		else if pname == "get_linearization" then
			out.ok = self.get_linearization(v)
		else if pname == "is_public" then
			out.ok = self.is_public(v)
		else if pname == "is_private" then
			out.ok = self.is_private(v)
		else if pname == "is_protected" then
			out.ok = self.is_protected(v)
		else if pname == "is_abstract" then
			out.ok = self.is_abstract(v)
		else if pname == "is_intern" then
			out.ok = self.is_intern(v)
		else if pname == "is_extern" then
			out.ok = self.is_extern(v)
		else if pname == "klass" then
			out.ok = self.klass(v)
		end
	end

	protected fun is_public(v: NaiveInterpreter): Instance
	do
		var res = self.mpropdef.visibility == public_visibility
		return v.bool_instance(res)
	end

	protected fun is_private(v: NaiveInterpreter): Instance
	do
		var res = self.mpropdef.visibility == private_visibility
		return v.bool_instance(res)
	end

	protected fun is_protected(v: NaiveInterpreter): Instance
	do
		var res = self.mpropdef.visibility == protected_visibility
		return v.bool_instance(res)
	end

	protected fun is_abstract(v: NaiveInterpreter): Instance
	do
		var mpropdef = self.mpropdef
		var res = mpropdef isa MMethodDef and mpropdef.is_abstract
		return v.bool_instance(res)
	end

	protected fun is_intern(v: NaiveInterpreter): Instance
	do
		var mpropdef = self.mpropdef
		var res = mpropdef isa MMethodDef and mpropdef.is_intern
		return v.bool_instance(res)
	end

	protected fun is_extern(v: NaiveInterpreter): Instance
	do
		var mpropdef = self.mpropdef
		var res = mpropdef isa MMethodDef and mpropdef.is_extern
		return v.bool_instance(res)
	end

	protected fun name(v: NaiveInterpreter): Instance
	do
		return v.string_instance(self.mpropdef.name)
	end

	protected fun get_linearization(v: NaiveInterpreter): InstanceIterator[PropertyInfo]
	do
		if not isset _cached_linearization then
			var mpropdef = self.mpropdef
			var mmodule = v.mainmodule
			var mclassdef = mpropdef.mclassdef
			# We need an anchored type to call lookup_next_definition
			var bound_mtype = mclassdef.bound_mtype
			var linearized_mpropdefs = mpropdef.mproperty.lookup_all_definitions(mmodule, bound_mtype)
			self.cached_linearization = new Array[PropertyInfo]
			for propdef in linearized_mpropdefs do
				self.cached_linearization.add(v.property_factory.build(propdef))
			end
		end

		return new InstanceIterator[PropertyInfo](v.prop_iterator_type, cached_linearization.iterator)
	end

	protected fun klass(v: NaiveInterpreter): ClassInfo
	do
		var mclass = self.mpropdef.mclassdef.mclass
		return v.rti_repo.from_mclass(mclass)
	end
end

class MethodInfo
	super PropertyInfo

	redef type MPROPDEF: MMethodDef

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "call" then
			out.ok = self.call(v, args)
		else if pname == "parameter_types" then
			out.ok = self.parameter_types(v)
		else if pname == "return_type" then
			out.ok = self.return_type(v)
		else if pname == "dyn_return_type" then
			out.ok = self.dyn_return_type(v, args[1])
		else if pname == "dyn_parameter_types" then
			out.ok = self.dyn_parameter_types(v, args[1])
		else
			super
		end
	end

	protected fun dyn_parameter_types(v: NaiveInterpreter, recv_type: Instance): Instance
	do
		assert recv_type isa TypeInfo
		var mmodule = v.mainmodule
		var msignature = mpropdef.new_msignature or else mpropdef.msignature
		var msignature2 = msignature.resolve_for(recv_type.reflectee, null, mmodule, true)
		var res = new Array[TypeInfo]
		for mparam in msignature2.mparameters do
			var mtype = mparam.mtype
			res.push(v.rti_repo.from_mtype(mtype))
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, res.iterator)
	end

	protected fun dyn_return_type(v: NaiveInterpreter, recv_type: Instance): nullable Instance
	do
		assert recv_type isa TypeInfo
		var mmodule = v.mainmodule
		var msignature = mpropdef.new_msignature or else mpropdef.msignature
		var msignature2 = msignature.resolve_for(recv_type.reflectee, null, mmodule, true)
		var ret = msignature2.return_mtype
		if ret != null then
			return v.rti_repo.from_mtype(ret)
		else
			return null
		end
	end

	protected fun return_type(v: NaiveInterpreter): nullable Instance
	do
		var msignature = mpropdef.new_msignature or else mpropdef.msignature
		var return_mtype = msignature.return_mtype
		var res: nullable Instance = null
		if return_mtype != null then
			res = v.rti_repo.from_mtype(return_mtype)
		end
		return res
	end

	fun parameter_types(v: NaiveInterpreter): Instance
	do
		var msignature = mpropdef.new_msignature or else mpropdef.msignature
		var res = new Array[TypeInfo]
		for mparam in msignature.mparameters do
			var mtype = mparam.mtype
			# NOTE: we purposely don't anchor the param type since we
			# want the static type.
			#if mtype.need_anchor then
			#	mtype = mtype.anchor_to(mmodule, mclass_type)
			#end
			var ty = v.rti_repo.from_mtype(mtype)
			res.push(ty)
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, res.iterator)
	end

	fun call(v: NaiveInterpreter, args: SequenceRead[Instance]): nullable Instance
	is
		expect(args.length == 2)
	do
		# Polymorphic send, since `MethodInfo` instance can be called
		# between mixed implementation.
		var runtime_array = args[1]
		var args2 = v.native_array_view(runtime_array)
		var args3 = new Array[Instance]
		args2.copy_to(0, args2.length, args3, 0)
		return v.send(self.mpropdef.mproperty, args3)
	end
end

class AttributeInfo
	super PropertyInfo
	redef type MPROPDEF: MAttributeDef

	protected var static_type: TypeInfo is noinit

	redef fun dispatch(v, pname, args, out)
	do
		if pname == "static_type" then
			out.ok = self.get_static_type(v)
		else if pname == "dyn_type" then
			out.ok = self.dyn_type(v, args[1])
		else if pname == "value" then
			out.ok = self.value(v, args[1])
		else
			super
		end
	end

	protected fun value(v: NaiveInterpreter, recv: Instance): Instance
	do
		return v.read_attribute(self.mpropdef.mproperty, recv)
	end

	protected fun dyn_type(v: NaiveInterpreter, recv: Instance): TypeInfo
	is
		expect(recv isa TypeInfo)
	do
		var typeinfo = recv.as(TypeInfo)
		var anchor = typeinfo.reflectee.undecorate.as(MClassType)
		assert not anchor.need_anchor
		var static_type = self.get_static_type(v).reflectee
		var anchored_mtype = static_type.anchor_to(v.mainmodule, anchor)
		return v.rti_repo.from_mtype(anchored_mtype)
	end

	protected fun get_static_type(v: NaiveInterpreter): TypeInfo
	do
		if isset _static_type then
			return static_type
		end
		var intro = self.mpropdef.mproperty.intro
		var mtype = intro.static_mtype
		assert mtype != null
		static_type = v.rti_repo.from_mtype(mtype)
		return static_type
	end
end

class VirtualTypeInfo
	super PropertyInfo
	redef type MPROPDEF: MVirtualTypeDef
	redef fun dispatch(v, pname, args, out)
	do
		if pname == "static_bound" then
			out.ok = self.static_bound(v)
		else if pname == "dyn_bound" then
			out.ok = self.dyn_bound(v, args[1])
		else
			super
		end
	end

	protected fun dyn_bound(v: NaiveInterpreter, anchor: Instance): TypeInfo
	do
		assert anchor isa TypeInfo
		var mclass_type = anchor.reflectee.undecorate.as(MClassType)
		var mtype = self.mpropdef.mproperty.mvirtualtype
		var static_bound = mtype.static_bound(v.mainmodule)
		var mtype2 = static_bound.anchor_to(v.mainmodule, mclass_type)
		return v.rti_repo.from_mtype(mtype2)
	end

	protected fun static_bound(v: NaiveInterpreter): TypeInfo
	do
		# NOTE: In this current module, `MVirtualType` is refined to
		# find the most specific static bound. This is why we don't
		# use `MVirtualTypeDef::bound`.
		var mtype = self.mpropdef.mproperty.mvirtualtype
		var static_bound = mtype.static_bound(v.mainmodule)
		return v.rti_repo.from_mtype(static_bound)
	end
end

# Wrapper class
class InstanceIterator[INSTANCE: Instance]
	super Universal
	protected var inner: Iterator[INSTANCE]

	redef fun dispatch(v, pname, args, out)
	do
		#v.debug "ENTERING InstanceIterator::dispatch for {pname}"
		if pname == "next" then
			self.next
			out.ok = null
		else if pname == "item" then
			out.ok = self.item
		else if pname == "is_ok" then
			out.ok = self.is_ok(v)
		end
	end

	fun next
	do
		inner.next
	end

	fun item: INSTANCE
	do
		return inner.item
	end

	fun is_ok(v: NaiveInterpreter): Instance
	do
		return v.bool_instance(inner.is_ok)
	end
end

redef class MClass
	fun most_specific_def(mmodule: MModule): MClassDef
	do
		return collect_linearization(mmodule).last.as(MClassDef)
	end
end
