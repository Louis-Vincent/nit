intrude import naive_interpreter

class StringInstance
	super MutableInstance
	private var inner: MutableInstance
	private var str_val: String

	init
	do
		attributes = inner.attributes
	end

	redef fun hash do return str_val.hash
	redef fun ==(o): Bool do return o isa StringInstance and o.str_val == str_val
end

redef class AStringExpr
	redef fun expr(v)
	do
		var res = super
		if res isa MutableInstance then
			return new StringInstance(res.mtype, res, value)
		else
			return res
		end
	end
end

redef class NaiveInterpreter
	protected var symbol_table = new HashMap[StringInstance, Instance]

	fun get_or_new_sym(symbol_name: StringInstance): Instance
	do
		if symbol_table.has_key(symbol_name) then
			return symbol_table[symbol_name]
		else
			var model = mainmodule.model
			var symbol_classes = model.get_mclasses_by_name("Symbol")
			assert symbol_classes != null
			var mclass = symbol_classes.first
			var mclass_type = mclass.mclass_type
			var mclassdef = mclass.intro

			var res = new MutableInstance(mclass_type)
			self.init_instance(res)
			var name_setter= mainmodule.try_get_primitive_method("name=", mclass)
			assert name_setter != null
			self.send(name_setter, [res, symbol_name])
			symbol_table[symbol_name] = res
			return res
		end
	end
end

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var pname = mpropdef.mproperty.name
		if pname == "sym" then
			var mut = args[1]
			if mut isa StringInstance then
				return v.get_or_new_sym(mut)
			end
			return null
		else
			return super
		end
	end
end
