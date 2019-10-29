import naive_interpreter
import model::model_collect

redef class NaiveInterpreter
	# There's only one instance of `TypeRepo`
	var type_repo: TypeRepoImpl

	# Runtime type for `TypeInfoImpl` instance
	var typeinfo_type: MClassType is noinit
	var typeinfo_iterator_type: MClassType is noinit

	init
	do
		# NOTE: If we were to have multiple implementation
		# we should remove the `autoinit` and code against an
		# abstraction instead a concrete type
		var type_repo_def = self.get_classdefs("TypeRepo").as(not null).last
		type_repo = new TypeRepoImpl(type_repo_def.bound_mtype, self)

		# Retrieve `TypeInfo` type
		var typeinfo_defs = self.get_classdefs("TypeInfo")
		assert typeinfo_defs != null
		self.typeinfo_type = typeinfo_defs.last.bound_mtype

		var typeinfo_iterator_def = self.get_classdefs("TypeInfoIterator")?.last
		assert typeinfo_iterator_def != null
		self.typeinfo_iterator_type = typeinfo_iterator_def.bound_mtype
	end

	# Converts a runtime `String` to an actual String in the interpreter
	# context.
	fun instance_to_s(object: Instance): String
	do
		assert object isa MutableInstance
		var res = self.send(self.force_get_primitive_method("to_cstring", object.mtype), [object])
		return res.val.as(CString).to_s
	end

	fun get_mclasses(classname: String): nullable Sequence[MClass]
	do
		return self.mainmodule.model.get_mclasses_by_name(classname)
	end

	# Given a `classname`, it returns an array of class definition sorted
	# by the linearization rules. It returns null if no class definition can
	# be found.
	fun get_classdefs(classname: String): nullable Sequence[MClassDef]
	do
		var mclasses = self.get_mclasses(classname)
		if mclasses == null or mclasses.length == 0 then
			return null
		end
		var mclassdefs = mclasses.first.mclassdefs
		self.mainmodule.linearize_mclassdefs(mclassdefs)
		return mclassdefs
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
			if res.err != null then
				return super
			else
				return res.ok
			end
		else
			return super
		end
	end
end

interface Universal
	fun resolve_intern_call(v: NaiveInterpreter, mpropdef: MMethodDef, args: SequenceRead[Instance]): InternCallResult
	is abstract
end

# Interpreter's implementation of `TypeRepo`, see `runtime_internals` for more
# informations.
class TypeRepoImpl
	super MutableInstance
	super Universal
	var interpreter: NaiveInterpreter
	protected var cached_type = new HashMap[String, TypeInfoImpl]

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		if pname == "get_type" then
			res = get_type(args[1])
		else
			# Throw exception
			return new InternCallResult(null, new UnsupportedMethod("unkown method named: `{pname}` for `TypeRepo`"))
		end
		return new InternCallResult(res, null)
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
		var mclass_type = interpreter.get_mclasses(typename)?.first.mclass_type
		assert mclass_type != null
		var res = new TypeInfoImpl(interpreter.typeinfo_type, mclass_type)
		cached_type[typename] = res
		return res
	end
end

class TypeInfoImpl
	super MutableInstance
	super Universal
	var mclass_type: MClassType

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
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
		else
			# Throw exception
			return new InternCallResult(null, new UnsupportedMethod("unkown method named: `{pname}` for `TypeInfo`"))
		end
		return new InternCallResult(res, null)
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

	protected fun supertypes(v: NaiveInterpreter): TypeIterator
	do
		var mmodule = v.mainmodule
		var ancestors = self.mclass_type.mclass.collect_ancestors(mmodule, null).to_a
		mmodule.linearize_mclasses(ancestors)
		var ancestors2 = new Array[MClassType]
		for a in ancestors do
			var mtype = a.intro.bound_mtype
			# Check if we can anchor the intro type
			if mtype.need_anchor and not self.mclass_type.need_anchor then
				mtype = mtype.anchor_to(mmodule, self.mclass_type)
			end
			ancestors2.push(mtype)
		end
		return new TypeIterator(v.typeinfo_iterator_type, ancestors2.iterator)
	end
end

class PropertyInfoImpl
end

class PropertyIterator
end

class TypeIterator
	super Universal
	super MutableInstance

	protected var inner: Iterator[MClassType]
	protected var current_item: nullable TypeInfoImpl = null

	redef fun resolve_intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		var res: nullable Instance = null
		if pname == "next" then
			self.next
		else if pname == "item" then
			res = self.item(v)
		else if pname == "is_ok" then
			res = self.is_ok(v)
		else
			# Throw exception
			return new InternCallResult(null, new UnsupportedMethod("unkown method named: `{pname}` for `TypeIterator`"))
		end

		return new InternCallResult(res, null)
	end

	fun item(v: NaiveInterpreter): TypeInfoImpl
	do
		if current_item == null then
			assert inner.is_ok
			current_item = new TypeInfoImpl(v.typeinfo_type, inner.item)
		end
		return current_item.as(not null)
	end

	fun next
	do
		inner.next
		current_item = null
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
	var message: String
end

class UnsupportedMethod
	super InternCallError

	redef fun to_s
	do
		return "UnsupportedMethodError: {message}"
	end
end

class InternCallResult
	super Result[Instance, InternCallError]
end
