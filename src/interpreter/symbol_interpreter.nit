intrude import naive_interpreter

class SymbolInstance
	super MutableInstance

	var str_instance: StringInstance

	redef fun to_s do return str_instance.str_val
end

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
	protected var symbol_table = new HashMap[String, SymbolInstance]

	fun get_or_new_sym(symbol_name: StringInstance): SymbolInstance
	do
		if symbol_table.has_key(symbol_name.str_val) then
			return symbol_table[symbol_name.str_val]
		else
			var model = mainmodule.model
			var symbol_classes = model.get_mclasses_by_name("Symbol")
			assert symbol_classes != null
			var mclass = symbol_classes.first
			var mclass_type = mclass.mclass_type
			var mclassdef = mclass.intro

			var res = new SymbolInstance(mclass_type, symbol_name)
			self.init_instance(res)
			var name_setter= mainmodule.try_get_primitive_method("name=", mclass)
			assert name_setter != null
			var args = new Array[Instance]
			args.push(res)
			args.push(symbol_name)
			self.send(name_setter, args)
			symbol_table[symbol_name.str_val] = res
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
