import separate_compiler

redef class SeparateCompiler
	var type_repo: RuntimeVariable

	init
	do
	end
end

redef class AbstractCompiler
	fun get_mclass(name: String): MClass is abstract
end

redef class AMethPropdef
	redef fun compile_intern_to_c(v, mpropdef, arguments)
	do
		var pname = mpropdef.mproperty.name
		var cname = mpropdef.mclassdef.mclass.name
		var ret = mpropdef.msignature.return_mtype
		var v2 = v.as(SeparateCompilerVisitor)
		if cname == "Sys" and pname == "type_repo" then
			self.ret(v2.type_repo)
			return true
		else if cname == "TypeRepo" then
			var v3 = new TypeRepoCompiler(v2)
			return v3.dispatch(pname, ret, arguments)
		else
			return super
		end
	end
end

class TypeRepoCompiler
	var v: SeparateCompilerVisitor

	fun dispatch(pname: String, ret_type, arguments): Bool
	do
		if pname == "get_type" then
			v.compile_get_type(ret_type, arguments[1])
			return true
		end
	end

	fun compile_get_type(ret_type: MType, type_name: RuntimeVariable)
	do
		v.require_declaration("get_type_by_name")
		var type_info = v.compiler.get_mclass("TypeInfo").mclass_type
		var res = v.new_expr("get_type_by_name({type_name})", type_info)
		v.ret(res)
	end
end
