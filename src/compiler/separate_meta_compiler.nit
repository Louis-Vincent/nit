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
		var rti_factory = new DefaultRuntimeInternals
		modelbuilder.run_separate_meta_compiler(mainmodule, analysis, rti_factory)
	end
end

# NOTE: duplicate for `separate_compiler`
redef class ModelBuilder
	fun run_separate_meta_compiler(mainmodule: MModule, runtime_type_analysis: nullable RapidTypeAnalysis, rti_factory: RuntimeInternalsFactory)
	do
		var time0 = get_time
		self.toolcontext.info("*** GENERATING C ***", 1)

		var compiler = new SeparateMetaCompiler(mainmodule, self, runtime_type_analysis, rti_factory)
		compiler.do_compilation
		compiler.display_stats

		var time1 = get_time
		self.toolcontext.info("*** END GENERATING C: {time1-time0} ***", 2)
		write_and_make(compiler)
	end
end

redef class AbstractCompilerVisitor
	fun rti_repo_def(pname: String, ret_type: nullable MType, arguments: Array[RuntimeVariable]): Bool do return false
	fun classinfo_def(pname: String, ret_type: nullable MType, arguments: Array[RuntimeVariable]): Bool do return false

	fun rti_iter_def(pname: String, ret_type: nullable MType, arguments: Array[RuntimeVariable]): Bool do return false

	fun typeinfo_def(pname: String, ret_type: nullable MType, arguments: Array[RuntimeVariable]): Bool do return false
end

class SeparateMetaCompilerVisitor
	super SeparateCompilerVisitor
	redef type COMPILER: SeparateMetaCompiler

	private fun rti_factory: RuntimeInternalsFactory
	do
		return compiler.rti_factory
	end

	redef fun rti_repo_def(pname, ret_type, arguments)
	do
		var v = rti_factory.rti_repo_impl(self, arguments[0])
		if ret_type != null then
			v.ret_type = ret_type
		end
		var res = true
		if pname == "classof" then
			v.classof(arguments[1])
		else if pname == "object_type" then
			v.object_type(arguments[1])
		else
			res = false
		end
		return res
	end

	redef fun classinfo_def(pname, ret_type, arguments)
	do
		var v = rti_factory.classinfo_impl(self, arguments[0])
		if ret_type != null then
			v.ret_type = ret_type
		end
		var res = true
		if pname == "name" then
			v.name
		else if pname == "ancestors" then
			v.ancestors
		else if pname == "properties" then
			v.properties
		else if pname == "type_parameters" then
			v.type_parameters
		else if pname == "is_interface" then
			v.is_interface
		else if pname == "is_abstract" then
			v.is_abstract
		else if pname == "is_universal" then
			v.is_universal
		else
			res = false
		end
		return res
	end

	redef fun rti_iter_def(pname, ret_type, arguments)
	do
		var v = rti_factory.rti_iter_impl(self, arguments[0])
		if ret_type != null then
			v.ret_type = ret_type
		end
		var res = true
		if pname == "next" then
			v.next
		else if pname == "is_ok" then
			v.is_ok
		else if pname == "item" then
			v.item
		else
			res = false
		end
		return res
	end

	redef fun typeinfo_def(pname, ret_type, arguments)
	do
		var v = rti_factory.typeinfo_impl(self, arguments[0])
		if ret_type != null then
			v.ret_type = ret_type
		end
		var res = true
		if pname == "name" then
			v.name
		else if pname == "klass" then
			v.klass
		else if pname == "iza" then
			v.iza(arguments[1])
		else if pname == "bound" then
			v.bound
		else if pname == "type_arguments" then
			v.type_arguments
		else if pname == "native_equal" then
			v.native_equal(arguments[1])
		else if pname == "is_formal_type" then
			v.is_formal_type
		else
			res = false
		end
		return res
	end
end

class SeparateMetaCompiler
	super SeparateCompiler

	private var rti_factory: RuntimeInternalsFactory
	private var msp: MetaStructProvider is noinit
	private var rta_bak: nullable RapidTypeAnalysis = null
	#protected var runtime_internals_mclasses: Collection[MClass] is noinit

	init
	do
		msp = rti_factory.meta_struct_provider(self)
		var iterator_class = get_mclass("RuntimeInfoIterator")
		var rta = self.runtime_type_analysis
		if rta != null then
			rta.live_classes.add(iterator_class)
			# Build every iterator types
			for mclass in self.rti_mclasses.values do
				var mclass_type = mclass.mclass_type
				rta.live_classes.add(mclass)
				rta.live_types.add(mclass_type)
				rta.live_cast_types.add(mclass_type)
				var itertype = iterator_class.get_mtype([mclass_type])
				rta.live_types.add(itertype)
				rta.live_cast_types.add(itertype)
			end
		end

		# Add `Array[TypeInfo]` since `ClassInfo::type_parameters` requires it.
		var typeinfo = self.rti_mclasses["TypeInfo"].mclass_type
		var arrayclass = mainmodule.array_class
		var arraytype = arrayclass.get_mtype([typeinfo])
		var nattype = mainmodule.native_array_type(typeinfo)
		rta.live_classes.add(mainmodule.native_array_class)
		rta.live_types.add(nattype)
		rta.live_classes.add(arrayclass)
		rta.live_types.add(arraytype)
	end

	redef fun new_visitor do return new SeparateMetaCompilerVisitor(self)

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
		var ms = rti_factory.model_saver(self)
		ms.save_model(self.mainmodule.model)
	end

	redef fun compile_types
	do
		# NOTE: temporal dependency
		self.runtime_type_analysis = self.rta_bak
		super
	end

	redef fun compile_header_structs do
		super
		msp.compile_metainfo_header_structs
	end

	redef fun compile_class_if_universal(ccinfo, v)
	do
		var res = super
		if res then return res

		var mclass = ccinfo.mclass
                var c_name = mclass.c_name
                var mtype = ccinfo.mtype

		res = true

                var struct_type = ""
                var field_name = ""
		if mclass.name == "RuntimeInternalsRepo" then
			self.header.add_decl("struct instance_{c_name} \{")
                        self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("\};")
			self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}();")
			v.require_declaration("type_{c_name}")
			v.require_declaration("class_{c_name}")
			v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}() \{")
			var recv = v.get_name("self")
			v.add_decl("struct instance_{c_name} *{recv};")
			var alloc = v.nit_alloc("sizeof(struct instance_{c_name})", mclass.full_name)
			v.add("{recv} = {alloc};")
                        v.add("{recv}->class = &class_{c_name};")
			v.add("{recv}->type = &type_{c_name};")
			v.add("return (val*){recv};")
			v.add("\}")
			return true
			#else if self.rti_mclasses.has_key(mclass.name) then
			#else if struct_type = msp.mclass_to_struct_type(mclass)
                        #else if field_name = mclass.name.to_lower
			#else if self.provide_declaration("instance_{c_name}", "struct instance_{c_name};")
                        #else if self.header.add_decl("struct instance_{c_name} \{")
                        #else if self.header.add_decl("const struct type* type;")
                        #else if self.header.add_decl("const struct class* class;")
			#else if self.header.add_decl("const {struct_type}* {field_name};")
                        #else if self.header.add_decl("\};")
		else if mclass.name == "RuntimeInfoIterator" then
			# `RuntimeInfoIterator` must have its own way of
			# generating its allocator.
			self.header.add_decl("struct instance_{c_name} \{")
			self.header.add_decl("const struct type* type;")
                        self.header.add_decl("const struct class* class;")
                        self.header.add_decl("const struct metainfo_t** table;")
                        self.header.add_decl("\};")
			self.provide_declaration("instance_{c_name}", "struct instance_{c_name};")
			self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const struct metainfo_t** table, const struct type* type);")
                        v.require_declaration("class_{c_name}")

                        v.add_decl("/* allocate {mtype} */")
			v.add_decl("{mtype.ctype} NEW_{c_name}(const struct metainfo_t** table, const struct type* type) \{")
			var recv = v.get_name("self")
			v.add_decl("struct instance_{c_name} *{recv};")
			var alloc = v.nit_alloc("sizeof(struct instance_{c_name})", mclass.full_name)
			v.add("{recv} = {alloc};")
                        v.add("{recv}->class = &class_{c_name};")
			v.add("{recv}->type = type;")
			hardening_live_type(v, "type")
                        v.add("{recv}->table = table;")
			v.add("return (val*){recv};")
			v.add("\}")
			return true

		else
			res = false
		end

		#if res then
                #        assert struct_type != ""
                #        assert field_name != ""
                #        self.provide_declaration("NEW_{c_name}", "{mtype.ctype} NEW_{c_name}(const {struct_type}* metainfo);")
                #        v.require_declaration("type_{c_name}")
                #        v.require_declaration("class_{c_name}")

                #        v.add_decl("/* allocate {mtype} */")
		#	v.add_decl("{mtype.ctype} NEW_{c_name}(const {struct_type}* metainfo) \{")
		#	var recv = v.get_name("self")
		#	v.add_decl("struct instance_{c_name} *{recv};")
		#	var alloc = v.nit_alloc("sizeof(struct instance_{c_name})", mclass.full_name)
		#	v.add("{recv} = {alloc};")
                #        v.add("{recv}->class = &class_{c_name};")
		#	v.add("{recv}->type = &type_{c_name};")
                #        v.add("{recv}->{field_name} = metainfo;")
		#	v.add("return (val*){recv};")
		#	v.add("\}")
                #end

		return res
	end
end

redef class AMethPropdef
	redef fun compile_intern_to_c(v, mpropdef, arguments)
	do
		var pname = mpropdef.mproperty.name
		var cname = mpropdef.mclassdef.mclass.name
		var ret = mpropdef.msignature.return_mtype
		var cc = v.compiler

		if not cc isa SeparateMetaCompiler then
			return super
		end

		if cname == "Sys" and pname == "rti_repo" then
			var mclass = cc.get_mclass("RuntimeInternalsRepo")
			v.require_declaration("NEW_{mclass.c_name}")
			v.ret(v.new_expr("NEW_{mclass.c_name}()", ret.as(not null)))
			return true
		else if cname == "RuntimeInternalsRepo" then
			v.rti_repo_def(pname, ret, arguments)
		else if cname == "ClassInfo" then
			v.classinfo_def(pname, ret, arguments)
		else if cname == "RuntimeInfoIterator" then
			v.rti_iter_def(pname, ret, arguments)
		else if cname == "TypeInfo" then
			v.typeinfo_def(pname, ret, arguments)
		end

		return super
	end
end
