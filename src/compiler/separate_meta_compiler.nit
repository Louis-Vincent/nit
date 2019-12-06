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
	private var rta_bak: nullable RapidTypeAnalysis = null
	protected var meta_mclasses: Collection[MClass] is noinit
	init
	do
		mcp = rti.meta_cstruct_provider(self)
		var classinfo = get_mclass("ClassInfo")
		var typeinfo = get_mclass("TypeInfo")
		var attrinfo = get_mclass("AttributeInfo")
		var methodinfo = get_mclass("MethodInfo")
		var vtypeinfo = get_mclass("VirtualTypeInfo")
		self.meta_mclasses = [classinfo, typeinfo, attrinfo, methodinfo, vtypeinfo]
		var rta = self.runtime_type_analysis
		if rta != null then
			for mclass in self.meta_mclasses do
				# NOTE: might be useless or incomplete
				rta.live_classes.add(mclass)
			end
		end
	end

	# Unsafely tries to get a `MClass` by name
	protected fun get_mclass(classname: String): MClass
	do
		var model = self.mainmodule.model
		var mclasses = model.get_mclasses_by_name(classname)
		assert mclasses != null and mclasses.length == 1
		return mclasses.first
	end

	redef fun do_compilation
	do
		self.rta_bak = self.runtime_type_analysis
		self.runtime_type_analysis = null
		super
		# This next line of code may be useless, since
		# after compile_types, self.rta will be back to
		# the original instance since compile_types is the last
		# procedure call in super def.
		self.runtime_type_analysis = self.rta_bak
		var c_name = mainmodule.c_name
		self.new_file("{c_name}.meta")
		var ms = rti.model_saver(self)
		ms.save_model(self.mainmodule.model)
	end

	redef fun compile_types
	do
		# NOTE: temporal dependency
		self.runtime_type_analysis = self.rta_bak
		for mclass in self.meta_mclasses do
			var mtype = mclass.mclass_type
			# Gotta bypass that sweet rta analysis
			runtime_type_analysis.live_types.add(mtype)
			runtime_type_analysis.live_cast_types.add(mtype)
		end
		super
	end

	redef fun compile_header_structs do
		super
		mcp.compile_metainfo_header_structs
	end

	redef fun compile_class_if_universal(ccinfo, v)
	do
		var res = super
		if res then return res

		var mclass = ccinfo.mclass
                var c_name = mclass.c_name
                var mtype = ccinfo.mtype

		res = true

                var metainfo_struct = ""
                var metainfo_field = ""
		if mclass.name == "ClassInfo" then
                        self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct clasinfo_t* classinfo;")
                        self.header.add_decl("\};")
                        metainfo_struct = "classinfo_t"
                        metainfo_field = "classinfo"
		else if mclass.name == "AttributeInfo" then
			self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct attrinfo_t* attrinfo;;")
                        self.header.add_decl("\};")
                        metainfo_struct = "attrinfo_t"
                        metainfo_field = "methodinfo"
		else if mclass.name == "TypeInfo" then
			self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct typeinfo_t* typeinfo;")
                        self.header.add_decl("\};")
                        metainfo_struct = "typeinfo_t"
                        metainfo_field = "typeinfo"
		else if mclass.name == "MethodInfo" then
                        self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct attrinfo_t* attrinfo;;")
                        self.header.add_decl("\};")
                        metainfo_struct = "methodinfo_t"
                        metainfo_field = "methodinfo"
		else if mclass.name == "VirtualTypeInfo" then
			#
		        # This structure is shared by virtual types and parameter types.
		        # In this implementation, any type parameter share the same base
		        # structure as `propinfo_t`. Morever, they are stored inside the
		        # same `props[]` array inside<
		        # `instance_ClassInfo`.
		        #
		        self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct vtypeinfo_t* vtypeinfo;")
                        self.header.add_decl("\};")
                        metainfo_struct = "vtypeinfo_t"
                        metainfo_field = "vtypeinfo"
		else
			res = false
		end

                if res then
                        assert metainfo_struct != ""
                        assert metainfo_field != ""
                        self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const struct {metainfo_struct}* metainfo)")
                        v.require_declaration("type_{c_name}")
                        v.require_declaration("class_{c_name}")

                        v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}(const struct vtypeinfo_t* vtypeinfo)")
			var recv = v.get_name("self")
			v.add_decl("struct instance_{c_name} *{recv};")
			var alloc = v.nit_alloc("sizeof(struct instance_{c_name})", mclass.full_name)
			v.add("{recv} = {alloc};")
                        v.add("{recv}->class = &class_{c_name};")
			v.add("{recv}->type = &type_{c_name};")
                        v.add("{recv}->{metainfo_field} = metainfo;")
			v.add("return (val*){recv};")
			v.add("\}")
                end

		return res
	end
end
