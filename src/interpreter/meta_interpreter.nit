intrude import symbol_interpreter

class KlassInstance
	super MutableInstance
	var mclass: MClass
	var symbol: SymbolInstance
end

class TypeInstance
	super MutableInstance
	var mclass_type: MClassType
	var parameters: nullable SequenceRead[TypeInstance]
	var symbol: SymbolInstance
end

redef class NaiveInterpreter

	# The `NativeModel` instance
	var native_model: nullable Instance is noinit

	var klass: MClassType is noinit
	var ty: MClassType is noinit

	# Map of [Symbol, Klass]
	protected var klass_cache = new HashMap[SymbolInstance, KlassInstance]

	# Map of [Symbol, Type]
	protected var type_cache = new HashMap[SymbolInstance, TypeInstance]

	init
	do
		var mclass = self.get_mclass_by_name("NativeModel")
		if mclass != null then
			self.native_model = self.new_mut_instance(mclass.mclass_type)
			var klass_mclass = self.get_mclass_by_name("Klass")
			assert klass_mclass != null
			var type_mclass = self.get_mclass_by_name("Type")
			assert type_mclass != null
			self.klass = klass_mclass.mclass_type
			self.ty = type_mclass.mclass_type
		end
	end

	fun new_mut_instance(mtype: MType): MutableInstance
	do
		var res = new MutableInstance(mtype)
		self.init_instance(res)
		return res
	end

	fun get_mclass_by_name(name: String): nullable MClass
	do
		var mclasses = mainmodule.model.get_mclasses_by_name(name)
		if mclasses == null then
			return null
		else
			return mclasses.first
		end
	end

	# Returns the class symbolized by `symbol`, if no class is symbolized by
	# `symbol`, then return null.
	fun get_klass_instance(symbol: SymbolInstance): nullable KlassInstance
	do
		var res = klass_cache.get_or_null(symbol)
		if res == null then
			var mclass = self.get_mclass_by_name(symbol.to_s)
			if mclass == null then return null
			res = new KlassInstance(self.klass, mclass, symbol)
			self.init_instance(res)
			klass_cache[symbol] = res
			return res
		else
			return res
		end
	end

	# Returns the type symbolized by `symbol`, if no type is symbolized by
	# `symbol`, then return null.
	fun get_type_instance(symbol: SymbolInstance): nullable TypeInstance
	do
		var res = type_cache.get_or_null(symbol)
		if res == null then
			var type_name = symbol.to_s
			var obra = type_name.index_of('[')
			var cbra = type_name.length - 1 - obra
			var classname: String
			# Stores formal parameter's `TypeInstance`
			var parameters: nullable SequenceRead[TypeInstance] = null
			# Stores each parameter's `MClassType` of `parameters`
			var parameters2 = new Array[MClassType]
			if obra == -1 then
				classname = type_name
			else
				classname = type_name.substring(0, obra)
			end

			var mclass = self.get_mclass_by_name(classname)
			if mclass == null then
				# the type can't exist if the class doesn't exist.
				return null
			end
			if obra != -1 then
				var temp = type_name.substring(obra+1, cbra-1)
				var params = temp.split(",")
				parameters = new Array[TypeInstance]
				for param in params do

					# Recursively build type parameters
					var param_sym = self.get_sym(param.trim)
					var ty = self.get_type_instance(param_sym)
					# If one of its type parameter is null then
					# we can't make a `TypeInstance`.
					if ty == null then
						# TODO: rollback the symbol_table to remove invalid symbol.
						return null
					end
					parameters.push(ty)
					parameters2.push(ty.mclass_type)
				end
			end
			var mclass_type = mclass.get_mtype(parameters2)
			res = new TypeInstance(self.ty, mclass_type, parameters, symbol)
			return res
		else
			return res
		end
	end
end

redef class AMethPropdef
	redef fun intern_call(v, mpropdef, args)
	do
		var cname = mpropdef.mclassdef.mclass.name
		var pname = mpropdef.mproperty.name
		if cname == "Sys" and pname == "nmodel" then
			return v.native_model
		end
		if cname == "NativeModel" then
			return native_model_def(v, mpropdef, args)
		else if cname == "Klass" then
			return klass_def(v, mpropdef, args)
		else if cname == "Type" then
			return type_def(v, mpropdef, args)
		else
			return super
		end
	end

	protected fun native_model_def(v: NaiveInterpreter, mpropdef: MMethodDef, args: Array[Instance]): nullable Instance
	do
		var nmodel = v.native_model.as(not null)
		var pname = mpropdef.mproperty.name
		if pname == "sym2class" then
			assert args.length == 2
			var sym = args[1]
			assert sym isa SymbolInstance
			return v.get_klass_instance(sym)
		else if pname == "sym2type" then
			assert args.length == 2
			var sym = args[1]
			assert sym isa SymbolInstance
			print sym
			return v.get_type_instance(sym)
		else if pname == "classof" then
			assert args.length == 2
			var object: Instance = args[1]
			var mclass_type = object.mtype.derive_mclass_type
			var classsym = v.get_sym(mclass_type.mclass.name)
			return v.get_klass_instance(classsym)
		else if pname == "typeof" then
			assert args.length == 2
			var object: Instance = args[1]
			var mtype = object.mtype
			var typesym = v.get_sym(mtype.to_s)
			return v.get_type_instance(typesym)
		else if pname == "t1_isa_t2" then
			assert args.length == 3
			var ty1 = args[1]
			var ty2 = args[2]
			assert ty1 isa TypeInstance and ty2 isa TypeInstance
			# TODO: check if `is_subtype` should receives `v.mainmodule`
			return v.bool_instance(ty1.mclass_type.is_subtype(v.mainmodule, null, ty2.mclass_type))
		else if pname == "arity_of" then
			assert args.length == 2
			var klass = args[1]
			assert klass isa KlassInstance
			return v.int_instance(klass.mclass.arity)
		else if pname == "ith_bound" then
			assert args.length == 3
			var i = args[1].to_i
			assert i >= 0
			var klass = args[2]
			assert klass isa KlassInstance
			# `MClassType` whose formal parameters are resolved via their bounds.
			var mtypes = klass.mclass.intro.bound_mtype.arguments
			assert mtypes.length > i
			# TODO: check if we should support nullable type
			print mtypes[i].undecorate
			var typesym = v.get_sym(mtypes[i].undecorate.to_s)
			return v.get_type_instance(typesym)
		end
		return null
	end

	protected fun klass_def(v: NaiveInterpreter, mpropdef: MMethodDef, args: Array[Instance]): nullable Instance
	do
		var pname = mpropdef.mproperty.name
		if pname == "to_sym" then
			return args.first.as(KlassInstance).symbol
		end
		return null
	end

	protected fun type_def(v: NaiveInterpreter, mpropdef: MMethodDef, args: Array[Instance]): nullable Instance
	do
		var pname = mpropdef.mproperty.name
		if pname == "to_sym" then
		end
		return null
	end
end
