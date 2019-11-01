import naive_interpreter
import model::model_collect

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
end

redef class NaiveInterpreter

	var type_repo: TypeRepo is noinit

	# There's only one instance of `TypeRepo` at runtime
	var runtime_type_repo: TypeRepoImpl is noinit
	var property_factory: PropertyFactory is noinit

	# Runtime meta types
	var type_type: MClassType is noinit
	var type_iterator_type: MClassType is noinit
	var prop_iterator_type: MClassType is noinit

	init
	do
		var model = self.mainmodule.model

		# NOTE: If we were to have multiple implementation
		# we should remove the `noinit` and code against an
		# abstraction instead of a concrete type

		self.type_repo = new TypeRepo(model)
		self.property_factory = new PropertyFactory(model)

		var runtime_type_repo_type = model.get_mclass("TypeRepo").mclass_type
		runtime_type_repo = new TypeRepoImpl(runtime_type_repo_type, self.type_repo)

		self.type_type = model.get_mclass("TypeInfo").mclass_type
		self.type_iterator_type = model.get_mclass("TypeInfoIterator").mclass_type
		self.prop_iterator_type = model.get_mclass("PropertyInfoIterator").mclass_type
	end

	fun isa_array(instance: Instance): Bool
	do
		var mtype = instance.mtype
		return mtype isa MClassType and self.mainmodule.array_class == mtype.mclass
	end

	# Transfers a runtime instance whose `mtype` is Array to an actual
	# Array in the interpreter world.
	fun runtime_array_to_native(array_instance: Instance): Array[Instance]
	is
		expect(isa_array(array_instance))
	do
		assert array_instance isa MutableInstance
		var mtype = array_instance.mtype
		var native_instance = self.send(self.force_get_primitive_method("items", mtype), [array_instance])
		assert native_instance isa PrimitiveInstance[Array[Instance]]
		return native_instance.val
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

class TypeRepo
	protected var model: Model
	protected var cached_type = new HashMap[MClassType, TypeInfo]

	fun get_type_by_name(name: String): nullable TypeInfo
	do
		if model.has_mclass(name) then
			assert is_unique_class: model.is_unique(name)
			var mclass_type = model.get_mclass(name).intro.bound_mtype
			return get_type_by_mclass_type(mclass_type)
		else
			return null
		end
	end

	fun get_type_by_mclass_type(mclass_type: MClassType): TypeInfo
	do
		if cached_type.has_key(mclass_type) then
			return cached_type[mclass_type]
		end
		var type_type = model.get_mclass("TypeInfo").mclass_type
		var res = new TypeInfo(type_type, mclass_type)
		cached_type[mclass_type] = res
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

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var cname = mpropdef.mclassdef.mclass.name
		var pname = mpropdef.mproperty.name
		if cname == "Sys" and pname == "type_repo" then
			return v.runtime_type_repo
		else if args.length > 0 and args[0] isa Universal then
			var recv = args[0].as(Universal)
			var res = recv.resolve_intern_call(v, mpropdef, args)
			if res.err != null and res.err isa UnsupportedMethod then
				return super
			else
				return res.ok
			end
		else
			return super
		end
	end
end

abstract class Universal
	super MutableInstance
	fun resolve_intern_call(v: NaiveInterpreter, mpropdef: MMethodDef, args: SequenceRead[Instance]): InternCallResult
	do
		var res = new InternCallResult(null, new UnsupportedMethod(mpropdef.mproperty.name))
		dispatch(v, mpropdef, args, res)
		return res
	end

	protected fun dispatch(v: NaiveInterpreter, mpropdef: MMethodDef, args: SequenceRead[Instance], out: InternCallResult)
	is abstract
end

# Exposed `TypeRepo` for the interpreter runtime.
class TypeRepoImpl
	super Universal
	var type_repo: TypeRepo

	protected var cached_type = new HashMap[String, TypeInfo]
	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
		if pname == "get_type" then
			out.ok = self.get_type(v, args[1])
		end
	end

	# Returns the most specific class definition for a given `typename`.
	protected fun get_type(v: NaiveInterpreter, typename_arg: Instance): nullable TypeInfo
	is
		expect(typename_arg isa MutableInstance)
	do
		var typename = v.instance_to_s(typename_arg)
		var res = self.type_repo.get_type_by_name(typename)
		return res
	end
end

class TypeInfo
	super Universal
	var mclass_type: MClassType

	protected var is_nullable = false
	protected var my_properties: SequenceRead[PropertyInfo] is noinit

	# To prevent too much duplication of type info, we cache its nullable
	# equivalent
	private var nullable_self: TypeInfo is noinit

	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
		if pname == "to_s" then
			out.ok = self.to_string(v)
		else if pname == "is_generic" then
			out.ok = self.is_generic(v)
		else if pname == "is_interface" then
			out.ok = self.is_interface(v)
		else if pname == "is_abstract" then
			out.ok = self.is_abstract(v)
		else if pname == "is_universal" then
			out.ok = self.is_universal(v)
		else if pname == "supertypes" then
			out.ok = self.supertypes(v)
		else if pname == "properties" then
			out.ok = self.properties(v)
		else if pname == "resolve" then
			out.ok = self.resolve(v, args)
		else if pname == "is_nullable" then
			out.ok = v.bool_instance(self.is_nullable)
		else if pname == "as_nullable" then
			out.ok = self.as_nullable
		else if pname == "type_param_bounds" then
			out.ok = self.type_param_bounds(v)
		end
	end

	protected fun resolve(v: NaiveInterpreter, args: SequenceRead[Instance]): TypeInfo
	is
		expect(args.length == 2)
	do
		# NOTE: no need to cache derived type inside a table since
		# `MClass::get_mtype` already does it for us.
		var args2 = v.runtime_array_to_native(args[1])

		# Maps args2 to an array of `MClassType`
		var args3 = new Array[MClassType]
		for arg in args2 do
			assert param_must_be_type_infos: arg isa TypeInfo
			args3.push(arg.mclass_type)
		end

		var derived_type = self.mclass_type.mclass.get_mtype(args3)
		return new TypeInfo(v.type_type, derived_type)
	end

	protected fun type_param_bounds(v: NaiveInterpreter): Instance
	do
		var bound_mtype = self.mclass_type.mclass.intro.bound_mtype
		var type_args = bound_mtype.arguments
		var types = new Array[TypeInfo]
		for t_arg in type_args do
			assert t_arg isa MNullableType or t_arg isa MClassType
			var bound: MClassType
			if t_arg isa MNullableType then
				bound = t_arg.mtype.as(MClassType)
			else
				bound = t_arg.as(MClassType)
			end
			var ty = v.type_repo.get_type_by_name(bound.mclass.name)
			assert ty != null
			if t_arg isa MNullableType then
				ty = ty.as_nullable
			end
			types.push(ty)
		end
		return v.array_instance(types, v.type_type)
	end

	protected fun as_nullable: TypeInfo
	do
		if self.is_nullable then
			return self
		else if not isset _nullable_self then
			var dup = new TypeInfo(self.mtype, self.mclass_type)
			dup.is_nullable = true
			self.nullable_self = dup
		end
		return self.nullable_self
	end

	protected fun to_string(v: NaiveInterpreter): Instance
	do
		if self.is_nullable then
			return v.string_instance("nullable {self.mclass_type.name}")
		end
		return v.string_instance(self.mclass_type.name)
	end

	protected fun is_generic(v: NaiveInterpreter): Instance
	do
		var res = self.mclass_type isa MGenericType
		return v.bool_instance(res)
	end

	protected fun is_interface(v: NaiveInterpreter): Instance
	do
		var res = self.mclass_type.mclass.is_interface
		return v.bool_instance(res)
	end

	protected fun is_abstract(v: NaiveInterpreter): Instance
	do
		var res = self.mclass_type.mclass.is_abstract
		return v.bool_instance(res)
	end

	protected fun is_universal(v: NaiveInterpreter): Instance
	do
		var res = self.mclass_type.mclass.is_enum
		return v.bool_instance(res)
	end

	protected fun supertypes(v: NaiveInterpreter): InstanceIterator[TypeInfo]
	do
		var mmodule = v.mainmodule
		var ancestors = self.mclass_type.mclass.collect_ancestors(mmodule, null).to_a
		mmodule.linearize_mclasses(ancestors)
		var ancestors2 = new Array[TypeInfo]
		for a in ancestors do
			var mtype = a.mclass_type
			# Check if we can anchor
			if mtype.need_anchor and not self.mclass_type.need_anchor then
				mtype = mtype.anchor_to(mmodule, self.mclass_type)
			end
			var typeinfo = v.type_repo.get_type_by_mclass_type(mtype)
			ancestors2.push(typeinfo)
		end
		return new InstanceIterator[TypeInfo](v.type_iterator_type, ancestors2.reverse_iterator)
	end

	protected fun properties(v: NaiveInterpreter): InstanceIterator[PropertyInfo]
	do
		if not isset _my_properties then
			var mclass = self.mclass_type.mclass
			var mmodule = v.mainmodule
			var mprops = mclass.collect_accessible_mproperties(mmodule)
			# Cache our properties
			var my_properties = new Array[PropertyInfo]
			for mprop in mprops do
				# Get the most specific implementation
				var mtype = mclass_type
				# First, we need to make sure mtype doesn't need an anchor,
				# otherwise we can't call `lookup_first_definition`.
				if mtype.need_anchor then
					mtype = mclass.intro.bound_mtype
				end
				var mpropdef = mprop.lookup_first_definition(mmodule, mtype)
				var propertyinfo = v.property_factory.build(mpropdef)
				my_properties.push(propertyinfo)
			end
			self.my_properties = my_properties
		end
		return new InstanceIterator[PropertyInfo](v.prop_iterator_type, my_properties.iterator)
	end
end

abstract class PropertyInfo
	super Universal

	protected type MPROPDEF: MPropDef
	protected var mpropdef: MPROPDEF
	protected var cached_parent: PropertyInfo is noinit

	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
		if pname == "to_s" then
			out.ok = v.string_instance(self.mpropdef.name)
		else if pname == "parent" then
			out.ok = self.parent(v)
		else if pname == "owner" then
			out.ok = self.owner(v)
		end
	end

	protected fun parent(v: NaiveInterpreter): PropertyInfo
	do
		# If mpropdef is already the introduction, we can't ask for next definition.
		# Thus, when mpropdef is intro then parent = self
		if self.mpropdef.is_intro then
			return self
		end
		if not isset _cached_parent then
			var mpropdef = self.mpropdef
			var mmodule = v.mainmodule
			var mclassdef = mpropdef.mclassdef
			# We need an anchored type to call lookup_next_definition
			var bound_mtype = mclassdef.bound_mtype
			var parentdef = mpropdef.lookup_next_definition(mmodule, bound_mtype)
			self.cached_parent = v.property_factory.build(parentdef)
		end
		return self.cached_parent
	end

	protected fun owner(v: NaiveInterpreter): TypeInfo
	do
		var classname = self.mpropdef.mclassdef.mclass.name
		return v.type_repo.get_type_by_name(classname).as(not null)
	end
end

class MethodInfo
	super PropertyInfo

	redef type MPROPDEF: MMethodDef

	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
		if pname == "call" then
			out.ok = self.call(v, args)
		end
		super
	end

	fun call(v: NaiveInterpreter, args: SequenceRead[Instance]): nullable Instance
	is
		expect(args.length == 2)
	do
		# Polymorphic send, since `MethodInfo` instance can be called
		# between mixed implementation.
		var runtime_array = args[1]
		var args2 = v.runtime_array_to_native(runtime_array)
		return v.send(self.mpropdef.mproperty, args2)
	end
end

class AttributeInfo
	super PropertyInfo
end

class VirtualTypeInfo
	super PropertyInfo
end

# Wrapper class
class InstanceIterator[INSTANCE: Instance]
	super Universal
	protected var inner: Iterator[INSTANCE]

	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
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

class Result[TYPE, ERROR]
	var ok: nullable TYPE
	var err: nullable ERROR
end

abstract class InternCallError
	var message: String = ""
end

class UnsupportedMethod
	super InternCallError
	var methodname: String

	redef fun to_s
	do
		return "UnsupportedMethodError: unkown method named `{methodname}`"
	end
end

class InternCallResult
	super Result[Instance, InternCallError]

	redef fun ok=(val)
	do
		_ok = val
		_err = null
	end

	redef fun err=(val)
	do
		_err = val
		_ok = null
	end
end

redef class MClass
	fun most_specific_def(mmodule: MModule): MClassDef
	do
		return collect_linearization(mmodule).last.as(MClassDef)
	end
end
