import naive_interpreter
import model::model_collect

redef class NaiveInterpreter
	# There's only one instance of `TypeRepo`
	var type_repo: TypeRepoImpl

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
		type_repo = new TypeRepoImpl(type_repo_type, self)

		# Retrieve `TypeInfo` type
		self.type_type = get_mclass("TypeInfo").as(not null).mclass_type

		self.type_iterator_type = get_mclass("TypeInfoIterator").as(not null).mclass_type

		self.prop_iterator_type = get_mclass("PropertyInfoIterator").as(not null).mclass_type
		self.property_type = get_mclass("PropertyInfo").as(not null).mclass_type
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
	is abstract
end

# Interpreter's implementation of `TypeRepo`, see `runtime_internals` for more
# informations.
class TypeRepoImpl
	super Universal

	var interpreter: NaiveInterpreter
	protected var cached_type = new HashMap[String, TypeInfoImpl]

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		var err: nullable InternCallError = null
		if pname == "get_type" then
			res = get_type(args[1])
		else
			err = new UnsupportedMethod("TypeRepo", pname)
		end
		return new InternCallResult(res, err)
	end

	# Returns the most specific class definition for a given `typename`.
	protected fun get_type(typename_arg: Instance): nullable TypeInfoImpl
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
		var res = new TypeInfoImpl(interpreter.type_type, mclass_type)
		cached_type[typename] = res
		return res
	end
end

class TypeInfoImpl
	super Universal
	var mclass_type: MClassType

	protected var my_properties: SequenceRead[PropertyInfoImpl] is noinit

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		var err: nullable InternCallError = null
		if pname == "to_s" then
			res = self.to_string(v)
		else if pname == "is_generic" then
			res = self.is_generic(v)
		else if pname == "is_interface" then
			res = self.is_interface(v)
		else if pname == "is_abstract" then
			res = self.is_abstract(v)
		else if pname == "supertypes" then
			res = self.supertypes(v)
		else if pname == "properties" then
			res = self.properties(v)
		else
			err = new UnsupportedMethod("TypeInfo", pname)
		end
		return new InternCallResult(res, err)
	end

	protected fun to_string(v: NaiveInterpreter): Instance
	do
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

	protected fun supertypes(v: NaiveInterpreter): InstanceIterator[TypeInfoImpl]
	do
		var mmodule = v.mainmodule
		var ancestors = self.mclass_type.mclass.collect_ancestors(mmodule, null).to_a
		mmodule.linearize_mclasses(ancestors)
		var ancestors2 = new Array[TypeInfoImpl]
		for a in ancestors do
			var mtype = a.mclass_type
			# Check if we can anchor
			if mtype.need_anchor and not self.mclass_type.need_anchor then
				mtype = mtype.anchor_to(mmodule, self.mclass_type)
			end
			ancestors2.push(new TypeInfoImpl(v.type_type, mtype))
		end
		return new InstanceIterator[TypeInfoImpl](v.type_iterator_type, ancestors2.reverse_iterator)
	end

	protected fun properties(v: NaiveInterpreter): InstanceIterator[PropertyInfoImpl]
	do
		if not isset _my_properties then
			var mclass = self.mclass_type.mclass
			var mmodule = v.mainmodule
			var mprops = mclass.collect_accessible_mproperties(mmodule)
			# Cache our properties
			var my_properties = new Array[PropertyInfoImpl]
			for mprop in mprops do
				# Get the most specific implementation
				var mpropdef = mprop.lookup_first_definition(mmodule, mclass_type)
				var propertyinfo = new PropertyInfoImpl(v.property_type, mpropdef)
				my_properties.push(propertyinfo)
			end
			self.my_properties = my_properties
		end
		return new InstanceIterator[PropertyInfoImpl](v.prop_iterator_type, my_properties.iterator)
	end
end

class PropertyInfoImpl
	super Universal

	protected var mpropdef: MPropDef
	protected var parent: PropertyInfoImpl is noinit
	protected var declared_by: TypeInfoImpl is noinit

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		var err: nullable InternCallError = null
		if pname == "to_s" then
			res = v.string_instance(self.mpropdef.name)
		else if pname == "parent" then
			#res = parent
		else if pname == "declared_by" then
			#res = declared_by
		else
			err = new UnsupportedMethod("PropertyInfo", pname)
		end
		return new InternCallResult(res, err)
	end
end

# Wrapper class
class InstanceIterator[INSTANCE: Instance]
	super Universal
	protected var inner: Iterator[INSTANCE]

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		var err: nullable InternCallError = null
		if pname == "next" then
			self.next
		else if pname == "item" then
			res = self.item
		else if pname == "is_ok" then
			res = self.is_ok(v)
		else
			err = new UnsupportedMethod("PropertyIterator", pname)
		end
		return new InternCallResult(res, err)
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
	var recv_classname: String
	var methodname: String

	redef fun to_s
	do
		return "UnsupportedMethodError: unkown method named `{methodname}` for class `{recv_classname}`"
	end
end

class InternCallResult
	super Result[Instance, InternCallError]
end

redef class MClass
	fun most_specific_def(mmodule: MModule): MClassDef
	do
		return collect_linearization(mmodule).last.as(MClassDef)
	end
end
