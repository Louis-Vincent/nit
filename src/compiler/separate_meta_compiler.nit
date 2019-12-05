module separate_meta_compiler
intrude import separate_compiler
import runtime_internals_support::default

redef class ToolContext
	var opt_meta = new OptionBool("Saves the program object model", "--meta")

	var meta_compiler_phase = new MetaCompilerPhase(self, null)

	init
	do
		super
		self.option_context.add_option(self.opt_meta)
	end

end

class MetaCompilerPhase
	super Phase
	redef fun process_mainmodule(mainmodule, given_modules)
	do
		if not toolcontext.opt_meta.value then return

		# NOTE: duplicate from `separate_compiler::SeparateCompilerPhase`
		var modelbuilder = toolcontext.modelbuilder
		var analysis = modelbuilder.do_rapid_type_analysis(mainmodule)
		var rti = new DefaultRuntimeInternals
		modelbuilder.run_separate_meta_compiler(mainmodule, analysis, rti)
	end
end

# NOTE: duplicate for `separate_compiler`
redef class ModelBuilder
	fun run_separate_meta_compiler(mainmodule: MModule, runtime_type_analysis: nullable RapidTypeAnalysis, rti: RuntimeInternalsFactory)
	do
		var time0 = get_time
		self.toolcontext.info("*** GENERATING C ***", 1)

		var compiler = new SeparateMetaCompiler(mainmodule, self, runtime_type_analysis, rti)
		compiler.do_compilation
		compiler.display_stats

		var time1 = get_time
		self.toolcontext.info("*** END GENERATING C: {time1-time0} ***", 2)
		write_and_make(compiler)
	end
end

class SeparateMetaCompiler
	super SeparateCompiler
	private var rti: RuntimeInternalsFactory
	private var mcp: MetaCStructProvider is noinit

	init
	do
		mcp = rti.meta_cstruct_provider(self)
	end

	redef fun do_compilation
	do
		super
		var c_name = mainmodule.c_name
		self.new_file("{c_name}.meta")
		var ms = rti.model_saver(self)
		ms.save_model(self.mainmodule.model)
	end

	redef fun compile_header_structs do
		super
		mcp.compile_commun_meta_header_structs
	end

	redef fun compile_class_if_universal(ccinfo, v)
	do
		var res = super
		if res then return res

		var mclass = ccinfo.mclass

		res = true

		if mclass.name == "ClassInfo" then
			mcp.compile_classinfo_header_struct
		else if mclass.name == "TypeInfo" then
			mcp.compile_typeinfo_header_struct
		else if mclass.name == "AttributeInfo" then
			mcp.compile_attributeinfo_header_struct
		else if mclass.name == "MethodInfo" then
			mcp.compile_methodinfo_header_struct
		else if mclass.name == "VirtualTypeInfo" then
			mcp.compile_vtypeinfo_header_struct
		else
			res = false
		end

		return res
	end
end
