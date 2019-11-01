import naive_interpreter
import model::model_collect

redef class NaiveInterpreter
	# There's only one instance of `TypeRepo`
	var type_repo: TypeRepoImpl

	var property_factory: PropertyFactory is noinit

	# Runtime meta types
	var type_type: MClassType is noinit
	var type_iterator_type: MClassType is noinit
	var property_type: MClassType is noinit
	var prop_iterator_type: MClassType is noinit

	init
	do
		# NOTE: If we were to have multiple implementation
		# we should remove the `autoinit` and code against an
		# abstraction instead a concrete type
		var type_repo_type = get_mclass("TypeRepo").as(not null).mclass_type
		self.property_factory = new PropertyFactory(self.mainmodule)
		type_repo = new TypeRepoImpl(type_repo_type, self)
		self.type_type = get_mclass("TypeInfo").as(not null).mclass_type
		self.type_iterator_type = get_mclass("TypeInfoIterator").as(not null).mclass_type
		self.prop_iterator_type = get_mclass("PropertyInfoIterator").as(not null).mclass_type
		self.property_type = get_mclass("PropertyInfo").as(not null).mclass_type
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

	# Tries to find a class named `classname`, fails if `classname` is
	# shared by the two or more classes.
	fun get_mclass(classname: String): nullable MClass
	do
		var mclasses = self.mainmodule.model.get_mclasses_by_name(classname)
		if mclasses == null then
			return null
		end
		if mclasses.length > 1 then
			self.fatal("ambiguous class name : `{classname}`")
			return null
		end
		return mclasses.first
	end
end

# To promote loose coupling between `PropertyInfo` and `NaiveInterpreter`,
# the `PropertyFactory` has the job of instantiating new `PropertyInfo` with
# the proper runtime type.
class PropertyFactory
	var mmodule: MModule

	protected fun get_meta_type(meta_typename: String): MClassType
	do
		var mclasses = mmodule.model.get_mclasses_by_name(meta_typename)
		assert missing_meta_classes: mclasses != null
		assert ambiguous_name: mclasses.length == 1
		return mclasses.first.mclass_type
	end

	fun build(mpropdef: MPropDef): PropertyInfo
	do
		var mtype: MType
		if mpropdef isa MMethodDef then
			mtype = get_meta_type("MethodInfo")
			return new MethodInfo(mtype, mpropdef)
		else if mpropdef isa MAttributeDef then
			mtype = get_meta_type("AttributeInfo")
			return new AttributeInfo(mtype, mpropdef)
		else if mpropdef isa MVirtualTypeDef then
			mtype = get_meta_type("VirtualTypeInfo")
			return new VirtualTypeInfo(mtype, mpropdef)
		else
			abort
		end
	end
end

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var cname = mpropdef.mclassdef.mclass.name
		var pname = mpropdef.mproperty.name
		if cname == "Sys" and pname == "type_repo" then
			return v.type_repo
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

# Interpreter's implementation of `TypeRepo`, see `runtime_internals` for more
# informations.
class TypeRepoImpl
	super Universal

	var interpreter: NaiveInterpreter
	protected var cached_type = new HashMap[String, TypeInfo]

	redef fun dispatch(v, mpropdef, args, out)
	do
		var pname = mpropdef.mproperty.name
		if pname == "get_type" then
			out.ok = self.get_type(args[1])
		end
	end

	# Returns the most specific class definition for a given `typename`.
	protected fun get_type(typename_arg: Instance): nullable TypeInfo
	is
		expect(typename_arg isa MutableInstance)
	do
		var typename = interpreter.instance_to_s(typename_arg)
		if cached_type.has_key(typename) then
			return cached_type[typename]
		end
		# TODO: handle fully qualified name: manage ambiguous name
		var mclass_type = interpreter.get_mclass(typename)?.mclass_type
		assert mclass_type != null
		var res = new TypeInfo(interpreter.type_type, mclass_type)
		cached_type[typename] = res
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
		else if pname == "supertypes" then
			out.ok = self.supertypes(v)
		else if pname == "properties" then
			out.ok = self.properties(v)
		else if pname == "resolve" then
			out.ok = self.resolve(v, args)
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
			# TODO: try to find a way to call get_type with a `String`
			var bound_name = v.string_instance(bound.mclass.name)
			var ty = v.type_repo.get_type(bound_name)
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
			ancestors2.push(new TypeInfo(v.type_type, mtype))
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
				# TODO: removed `get_meta_type` since it creates an implicit
				# temporal dependency between `get_meta_type` and the constructor.
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
		var classname = v.string_instance(self.mpropdef.mclassdef.mclass.name)
		return v.type_repo.get_type(classname).as(not null)
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
