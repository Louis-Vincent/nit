import naive_interpreter

abstract class Universal
	super MutableInstance

	fun resolve_intern_call(v: NaiveInterpreter, pname: String, args: SequenceRead[Instance]): InternCallResult
	do
		var res = new InternCallResult(null, new UnsupportedMethod(pname))
		dispatch(v, pname, args, res)
		return res
	end

	protected fun dispatch(v: NaiveInterpreter, pname: String, args: SequenceRead[Instance], out: InternCallResult)
	is abstract
end

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		if args.length > 0 and args[0] isa Universal then
			var recv = args[0].as(Universal)
			var res = recv.resolve_intern_call(v, pname, args)
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

class Result[TYPE, ERROR]
	var ok: nullable TYPE is writable
	var err: nullable ERROR is writable
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

