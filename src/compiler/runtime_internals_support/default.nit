
module default

import runtime_internals_base
private import model::model_collect

redef class Sys
	private var null_dependency = new NullDependency
end

class DefaultRuntimeInternals
	super RuntimeInternalsFactory

	redef fun meta_struct_provider(cc)
	do
		return new DefaultStructProvider(cc)
	end

	redef fun model_saver(cc)
	do
		return new DefaultModelSaver(cc)
	end

	redef fun classinfo_impl(v, recv)
	do
		var cc = v.compiler
		var classinfo_mclass = cc.get_mclass("ClassInfo")
		return new DefaultClassInfoImpl(v, classinfo_mclass, recv)
	end

	redef fun typeinfo_impl(v, recv)
	do
		var cc = v.compiler
		var typeinfo_mclass = cc.get_mclass("TypeInfo")
		return new DefaultTypeInfoImpl(v, typeinfo_mclass, recv)
	end

	redef fun rti_repo_impl(v, recv)
	do
		var cc = v.compiler
		var rti_repo_mclass = cc.get_mclass("RuntimeInternalsRepo")
		return new DefaultRtiRepoImpl(v, rti_repo_mclass, recv)
	end

	redef fun rti_iter_impl(v, recv)
	do
		var cc = v.compiler
		var rti_iter_mclass = cc.get_mclass("RuntimeInfoIterator")
		return new DefaultRtiIterImpl(v, rti_iter_mclass, recv)
	end
end

class DefaultStructProvider
	super MetaStructProvider
        protected var cc: AbstractCompiler

	redef fun mclass_to_struct_type(mclass)
	do
		if mclass.name == "ClassInfo" then
			return "struct classinfo_t"
		else if mclass.name == "TypeInfo" then
			return "struct typeinfo_t"
		else if mclass.name == "AttributeInfo" then
			return "struct attrinfo_t"
		else if mclass.name == "MethodInfo" then
			return "struct methodinfo_t"
		else if mclass.name == "VirtualTypeInfo" then
			return "struct vtypeinfo_t"
		end
		abort
	end

	redef fun compile_metainfo_header_structs
	do
		var classinfo = cc.rti_mclasses["ClassInfo"]
		var typeinfo = cc.rti_mclasses["TypeInfo"]
		var attrinfo = cc.rti_mclasses["AttributeInfo"]
		var vtypeinfo = cc.rti_mclasses["VirtualTypeInfo"]
		var methodinfo = cc.rti_mclasses["MethodInfo"]

		cc.header.add_decl("struct metainfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct propinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct formaltypeinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("//const struct typeinfo_t* bound;")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct classtypeinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("const struct type* type_ptr; // NULL if dead or static")
		cc.header.add_decl("const struct typeinfo_t* resolution_table[];")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct classinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("int color;")
		cc.header.add_decl("const struct class* class_ptr;")
		#cc.header.add_decl("/* if `self` is not generic, then `typeinfo_table` points directly to its type*/")
		# TODO: type table
		#cc.header.add_decl("struct classtypeinfo_t** typeinfo_table;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("/* We always store type parameters first if any*/")
		cc.header.add_decl("struct classinfo_t** ancestors;")
		cc.header.add_decl("const struct propinfo_t* props[];")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct typeinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct attrinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("const struct typeinfo_t* static_type;")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct methodinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("const struct typeinfo_t* signature[];")
		cc.header.add_decl("\};")

		cc.header.add_decl("struct vtypeinfo_t \{")
		cc.header.add_decl("const struct type* type;")
		cc.header.add_decl("const struct class* class;")
		cc.header.add_decl("unsigned int metatag;")
		cc.header.add_decl("const struct classinfo_t* classinfo;")
		cc.header.add_decl("const char* name;")
		cc.header.add_decl("const struct formaltypeinfo_t* vtype;")
		cc.header.add_decl("const struct typeinfo_t* bound;")
		cc.header.add_decl("\};")
	end
end

# Each internal structure that represent a metainformation
# must have a `metainfo` tag at the start of their `struct`.
# This class provide a standard way of describing meta entities.
# NOTE: this class is tightly coupled with the runtime internals implementation.

# There are 6 meta structures = 3 bits, called the `meta kind`
#
# - `000` = class
# - `001` = classtype
# - `010` = type parameter
# - `011` = virtual type
# - `100` = attribute
# - `101` = method
#
# 32 bits: 0000 0000 0000 0000 0000 0000 0000 0000
#
# `classinfo_t` meta tag:
# 32 bits: 0000 00pp pppp pppp Avvk kkaa aaaa ammm
# m = meta kind
# a = arity = number of formal parameters (maximum of 128)
# k = kind of class (concrete (0), abstract (1), interface (10),
# enum (11), extern (100), subset (101))
# v = visibility (public (0) or private (10))
# A = direct descendant of Object (1=yes, 0=no)
# p = properties = number of property (maximum of 1024)
# 0 = unused space = could be use to store larger amount of `p`
#
# `classtypeinfo_t` meta tag:
# 32 bits: n000 0000 0000 0000 0000 aaaa aaak kmmm
# m = meta kind
# k = kind of types (closed 0, not_closed = 1, formal_type = 10)
# a = arity (duplicated data from `ClassInfo`, however, it avoids redundant
# memory roundtrip, a.k.a querying the `ClassInfo` each time we want the arity.
# n = nullable or not (not null = 0, null = 1)
#
# `propinfo_t` meta tag:
# 32 bits: 0000 0000 0000 0000 0000 0000 0qqv vmmm
# m = meta kind
# v = visibility (none (0), public (1), protected (10), private (11))
# q = qualifier (none (0), abstract (1), intern (10), extern (11))
#
# `attrinfo_t` meta tag:
# 32 bits: 0000 0000 0000 0000 0000 0000 0xxx xxxx
# x = inherited from `PropertyInfo` meta structure
#
# `methodinfo_t` meta tag:
# 32 bits: 0000 0000 0000 0000 0raa aaaa axxx xxxx
# x = inherited from `PropertyInfo` meta structure
# a = arity (max 127)
# r = has a return value (0=no, 1=yes)
#
# `formaltypeinfo_t` meta tag:
# 32 bits: n000 0000 0000 0000 0000 0rrr rrrr kmmm
# k = kind of formal type (0=type param, 1=virtual type)
# r = rank (if `self` isa type param)
# n = null bit
abstract class SavableMEntity

	fun metatag_value: Int
	do
		# NOTE: is not a good pratice to hardcode `if`s with type
		# and I could use polymorphism. However, at this stage of
		# development, the metakind of each savable entity change
		# too much. By choosing the metakind here, we avoid changing
		# the code everywhere in the file.
		# TODO: replace this with polymorphism (when stable)
		if self isa MClassType then return 1
		if self isa MFormalType then return 2
		if self isa MVirtualTypeDef then return 3
		if self isa MAttributeDef then return 4
		if self isa MMethodDef then return 5
		return 0
	end

	fun dependencies: CompilationDependency do return null_dependency
	fun meta_cstruct_type: String is abstract
	fun metainfo_uid: String is abstract
	fun full_metainfo_decl: String do return "{meta_cstruct_type} {metainfo_uid}"
	fun to_addr: String do return "&{metainfo_uid}"
	var is_saved: Bool = false is protected writable

	fun pre_save(mainmodule: MModule) do end

	fun save(v: SeparateCompilerVisitor)
	is
		expect(not self.is_saved)
	do
		self.requirements(v)
		self.provide_declaration(v)
		self.write_field_values(v)
	end

	# C declaration dependencies.
	fun requirements(v: AbstractCompilerVisitor) do end

	# Writes the savable content of `self`.
	fun write_field_values(v: AbstractCompilerVisitor) is abstract

	# Converts `self` to a dependency.
	fun to_dep: CompilationDependency
	do
		if is_saved then return null_dependency
		return new SimpleDependency(self)
	end

	# Inverse the control of `Visitor::require_declaration`.
	fun require(v: AbstractCompilerVisitor)
	do
		v.require_declaration(metainfo_uid)
	end

	# Provides `self` as a declaration.
	fun provide_declaration(v: AbstractCompilerVisitor)
	do
		v.compiler.provide_declaration(metainfo_uid, "extern {full_metainfo_decl};")
	end

	fun is_alive(cc: AbstractCompiler): Bool
	do
		# TODO: may be removed.
		assert cc isa SeparateCompiler
		var entity = self
		var rta = cc.runtime_type_analysis
		assert rta != null
		var res = true
		if entity isa MClass then
			res = rta.live_classes.has(entity)
		else if entity isa MClassType then
			if entity isa MGenericType then
				res = rta.live_open_types.has(entity)
			else
				res = rta.live_types.has(entity)
			end
		else if entity isa MType then
			res = rta.live_cast_types.has(entity)
			res = res or rta.live_open_cast_types.has(entity)
		else if entity isa MMethodDef then
			res = rta.live_methoddefs.has(entity)
		else if entity isa MMethod then
			res = rta.live_methods.has(entity)
		end
		return res
	end
end

# Base class for all delayed compilation dependency that needs to be handled in
# the future.
abstract class CompilationDependency
	fun is_out_of_date: Bool is abstract
	fun resolve_dependency(cc: SeparateCompiler): nullable CompilationDependency
	is abstract
end

class NullDependency
	super CompilationDependency
	redef fun is_out_of_date do return true
	redef fun resolve_dependency(cc) do return null
end

abstract class DelayedDependency
	super CompilationDependency
end

class SimpleDependency
	super CompilationDependency
	type SAVABLE: SavableMEntity
	protected var savable: SAVABLE

	redef fun is_out_of_date do return self.savable.is_saved

	redef fun resolve_dependency(cc)
	do
		if self.is_out_of_date then return null
		var v = cc.new_visitor
		savable.pre_save(cc.mainmodule)
		savable.save(v)
		var res = savable.dependencies
		savable.is_saved = true
		return res
	end
end

# Composite of multiple `CompilationDependency`.
class AggregateDependencies
	super CompilationDependency
	protected var dependencies = new Array[CompilationDependency]

	redef fun is_out_of_date
	do
		for dep in dependencies do
			if not dep.is_out_of_date then
				return false
			end
		end
		# If there's no dependency then it is out of date.
		return true
	end

	redef fun resolve_dependency(cc)
	do
		if is_out_of_date then return null
		var res = new AggregateDependencies
		for dep in dependencies do
			var new_dep = dep.resolve_dependency(cc)
			if new_dep != null then
				res.add(new_dep)
			end
		end
		return res
	end

	fun add(dep: CompilationDependency)
	do
		dependencies.add(dep)
	end
end

class DefaultModelSaver
	super ModelSaver
	protected var cc: SeparateCompiler

	redef fun save_model(model)
	do
		var deps = (new Array[CompilationDependency]).as_fifo
		var rta = cc.runtime_type_analysis
		assert rta != null
		var mmodule = cc.mainmodule

		var poset = mmodule.flatten_mclass_hierarchy
		var colorer = new POSetColorer[MClass]
		colorer.colorize(poset)
		var colors_mapping = colorer.colors
		for mclass in model.mclasses do
			# NOTE: temporal dependency, this is not the best solution,
			# however it avoid many problem and verbose code if we globally
			# compute the finalized specificiation of a class, a.k.a resolve
			# its entire definition before saving the model.
			# Currently, the real solution seems to be moving class resolution
			# at boot time instead at compile time. This will be done in the next
			# iteration.
			var def = mclass.most_specific_def(mmodule)
			var ancestors = mclass.linearized_ancestors(mmodule)
			var mpropdefs = mclass.most_specific_mpropdefs(mmodule)
			mclass.main_mclassdef = def
			mclass.main_ancestors = ancestors
			mclass.main_mpropdefs = mpropdefs
			mclass.color = colors_mapping[mclass]
		end

		for mtype in rta.live_types do
			var dep = new SimpleDependency(mtype)
			deps.add(dep)
		end

		while not deps.is_empty do
			var dep = deps.take
			var new_dep = dep.resolve_dependency(cc)
			if new_dep != null then deps.add(new_dep)
		end
		build_class_table
		build_type_table
	end

	protected fun build_class_table
	do
		var v = cc.new_visitor
		var mmodule = cc.mainmodule
		var rta = cc.runtime_type_analysis.as(not null)
		var mclasses = rta.live_classes
		cc.provide_declaration("class_table_entry_t", "struct class_table_entry_t \{ const struct class* class; const struct classinfo_t* classinfo; \};")
		cc.provide_declaration("classinfo_table", "extern struct class_table_entry_t classinfo_table[{mclasses.length + 1}];")
		v.require_declaration("class_table_entry_t")
		v.add_decl("struct class_table_entry_t classinfo_table[{mclasses.length + 1}] = \{")
		for mclass in mclasses do
			mclass.require(v)
			v.add_decl("\{&class_{mclass.c_name}, {mclass.to_addr} \},")
		end
		v.add_decl("\{ NULL, NULL \}")
		v.add_decl("\};")
	end

	protected fun build_type_table
	do
		var v = cc.new_visitor
		var mmodule = cc.mainmodule
		var rta = cc.runtime_type_analysis.as(not null)
		var mtypes = rta.live_types
		cc.provide_declaration("type_table_entry_t", "struct type_table_entry_t \{ const struct type* type; const struct classtypeinfo_t* typeinfo; \};")
		cc.provide_declaration("typeinfo_table", "extern struct type_table_entry_t typeinfo_table[{mtypes.length + 1}];")
		v.require_declaration("type_table_entry_t")
		v.add_decl("struct type_table_entry_t typeinfo_table[{mtypes.length + 1}] = \{")
		for mtype in mtypes do
			mtype.require(v)
			v.require_declaration("type_{mtype.c_name}")
			v.add_decl("\{ &type_{mtype.c_name}, {mtype.to_addr} \},")
		end
		v.add_decl("\{ NULL, NULL \}")
		v.add_decl("\};")
	end
end

# Comparator based on class color.
private class ClassComparator
	super Comparator
	redef type COMPARED: MClass

	redef fun compare(a,b)
	do
		return default_comparator.compare(a.color, b.color)
	end

end

redef class MType
	super SavableMEntity

	# write the field values as if the type was nullable.
	fun write_field_values_nullable(v: AbstractCompilerVisitor) is abstract
end

redef class MClassType

	redef fun meta_cstruct_type do return "struct classtypeinfo_t"

	redef fun metainfo_uid do return "classtypeinfo_of_{self.c_name}"

	redef fun metatag_value
	do
		var tag = super
		var is_open = self.need_anchor.to_i
		tag = tag | (is_open << 3)
		tag = tag | (arguments.length << 5)
		return tag
	end

	redef fun requirements(v)
	do
		var cc = v.compiler
		mclass.require(v)
		if not self.need_anchor and self.is_alive(cc) then
			v.require_declaration("type_{self.c_name}")
		end
		for mtype in self.arguments do
			mtype.require(v)
		end
		for targ in self.accessible_type_args do
			targ.require(v)
		end
	end

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		deps.add(mclass.to_dep)
		for targ in self.accessible_type_args do
			deps.add(targ.to_dep)
		end
		return deps
	end

	redef fun pre_save(mainmodule)
	do
		cache_accessible_type_args(mainmodule)
	end

	private var sorted_ancestors_cache: nullable SequenceRead[MClass]

	# Returns ancestors of `self.mclass`, including `self.mclass`, sorted by
	# class color.
	private fun sorted_ancestors: SequenceRead[MClass]
	do
		if sorted_ancestors_cache == null then
			var comparator = new ClassComparator
			# All ancestors including its own class
			var ancestors = new Array[MClass]
			ancestors.add_all(mclass.main_ancestors)
			ancestors.unshift mclass
			print ancestors.length
			comparator.quick_sort(ancestors, 0, ancestors.length - 1)
			sorted_ancestors_cache = ancestors
		end
		return sorted_ancestors_cache.as(not null)
	end

	private var accessible_type_args: SequenceRead[MType]

	# Collects and resolves all accessible type parameter in a class hierarchy.
	# Returns a `SequenceRead` ordered by class color
	private fun cache_accessible_type_args(mmodule: MModule): SequenceRead[MType]
	do
		if not isset _accessible_type_args then
			# NOTE: another temporal dependency since every living
			# types depend on their accessible type arguments.
			# To avoid adding a `MModule` param to `dependencies`
			# method, we precompute the resolved dependency types.
			var accessible_targs = new Array[MType]
			for mclass in self.sorted_ancestors do
				for mparam in mclass.mparameters do
					var closed_type = mclass.mclass_type.anchor_to(mmodule, self)
					for targ in closed_type.arguments do
						accessible_targs.push(targ)
					end
				end
			end
			accessible_type_args = accessible_targs
		end
		return accessible_type_args
	end

	redef fun write_field_values_nullable(v)
	do
		generic_write_field_values(v, self.as_nullable)
	end

	redef fun write_field_values(v)
	do
		generic_write_field_values(v, self)
	end

	private fun write_typeparam_resolution_table(v: AbstractCompilerVisitor)
	do
		if self.need_anchor then return
		var first_color = sorted_ancestors.first.color
		# We always write down the minimal color (offset).
		v.add_decl("(const struct typeinfo_t*){first_color},")

		var len = sorted_ancestors.length
		var j = 0
		for i in [0..len[ do
			var mclass = sorted_ancestors[i]
			var color = mclass.color
			var k = i+1
			var argsize = mclass.mparameters.length
			for l in [j..argsize+j[ do
				var targ = accessible_type_args[l]
				v.add_decl("(const struct typeinfo_t*)&{targ.metainfo_uid},")
			end
			j += argsize
			if i == len - 1 then continue
			# Add some padding
			var next_color = sorted_ancestors[k].color
			var padding_len = next_color - color + argsize
			for x_ in [0..padding_len[ do
				v.add_decl("(const struct typeinfo_t*)-1,")
			end
		end
	end

	private fun generic_write_field_values(v: AbstractCompilerVisitor, this: MType)
	do
		var cc = v.compiler
		var rti_mclass = cc.rti_mclasses["TypeInfo"]
		v.add_decl("{this.full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
		v.add_decl("{this.metatag_value},")
		v.add_decl("{mclass.to_addr},")
		var name_prefix = ""
		if this isa MNullableType then name_prefix = "nullable "
		v.add_decl("\"{name_prefix}{self.name}\",")
		if not this.need_anchor and this.is_alive(cc) then
			v.add_decl("&type_{this.c_name},")
		else
			v.add_decl("NULL, /*{this} is DEAD*/")
		end
		v.add_decl("\{")
		write_typeparam_resolution_table(v)
		v.add_decl("NULL")
		v.add_decl("\}")
		v.add_decl("\};")
	end
end

# This class is only proxying to `MVirtualTypeDef`.
redef class MVirtualType
	redef fun metainfo_uid do return "vtypeinfo_of_{mclass.c_name}_{name}"
	redef fun meta_cstruct_type do return "struct formaltypeinfo_t"
	redef fun metatag_value
	do
		var tag = super
		return tag | (1 << 3) # 3 = m, 4th = kind of formal type
	end

	fun mclass: MClass
	do
		return mproperty.intro_mclassdef.mclass
	end

	redef fun write_field_values(v)
	do
		generic_write_field_values(v, self)
	end

	redef fun write_field_values_nullable(v)
	do
		generic_write_field_values(v, self.as_nullable)
	end

	redef fun dependencies
	do
		return mclass.to_dep
	end

	private fun generic_write_field_values(v: AbstractCompilerVisitor, this: MType)
	do
		var rti_mclass = v.compiler.rti_mclasses["TypeInfo"]

		v.add_decl("{this.full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
		v.add_decl("{this.metatag_value},")
		v.add_decl("{mclass.to_addr},")
		v.add_decl("\"{self.name}\",")
		# TODO: static bound
		v.add_decl("\};")
	end

	redef fun requirements(v)
		#vtypedef.static_bound.require(v)
	do
		mclass.require(v)
	end
end

redef class MParameterType

	redef fun metainfo_uid do return "typeparam_of_{mclass.c_name}_{name}"
	redef fun meta_cstruct_type do return "struct formaltypeinfo_t"

	redef fun requirements(v)
	do
		mclass.require(v)
	end

	redef fun dependencies
	do
		return mclass.to_dep
	end

	private fun generic_write_field_values(v: AbstractCompilerVisitor, this: MType)
	do
		var rti_mclass = v.compiler.rti_mclasses["TypeInfo"]

		v.add_decl("{this.full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
		v.add_decl("{this.metatag_value},")
		v.add_decl("{mclass.to_addr},")
		v.add_decl("\"{self.name}\",")
		# NOTE: resolve static bound
		v.add_decl("\};")
	end

	redef fun write_field_values(v)
	do
		generic_write_field_values(v, self)
	end

	redef fun write_field_values_nullable(v)
	do
		generic_write_field_values(v, self.as_nullable)
	end
end

redef class MNullableType

	redef fun pre_save(mainmodule)
	do
		mtype.pre_save(mainmodule)
	end

	redef fun metainfo_uid
	do
		return "{self.mtype.metainfo_uid}_nullable"
	end

	redef fun metatag_value
	do
		var tag = self.mtype.metatag_value
		var nullble = 1
		# 12 = 3 metakind + 2 type kind + 7 arity
		return tag | (nullble << 31)
	end

	redef fun meta_cstruct_type
	do
		return self.mtype.meta_cstruct_type
	end

	redef fun dependencies do return self.mtype.dependencies

	redef fun write_field_values(v)
	do
		self.mtype.write_field_values_nullable(v)
	end

	redef fun requirements(v)
	do
		var cc = v.compiler
		if self.is_alive(cc) and not self.need_anchor then
			v.require_declaration("type_{self.c_name}")
		end
		#mtype.require(v)
	end
end

redef class MClass
	super SavableMEntity

	private var color: Int is noinit
	private var main_mclassdef: MClassDef is noinit
	private var main_mpropdefs: Collection[MPropDef] is noinit
	private var main_ancestors: SequenceRead[MClass] is noinit

	redef fun metatag_value
	do
		var tag = super
		var arity = self.mparameters.length
		var mproperties = collect_local_mproperties(null)
		var kind = classkind_to_int(self.kind)
		var visibility = visibility_to_int(self.visibility)
		#var object_class = self.mmodule.get_primitive_class("Object")
		#var direct_childs = object_class.in_hierarchy(self.mmodule).direct_smallers
		# TODO
		var is_child_of_object = 0
		#for child in direct_childs do
		#	if child == self.mclass then
		#		is_child_of_object = 1
		#	end
		#end
		tag = tag | (arity << 3) # 7 bits => 3 + 7 = 10
		tag = tag | (kind << 10) # 3 bits => 10 + 3 + 13
		tag = tag | (visibility << 13) # 1 bits => 13 + 2 = 15
		tag = tag | (is_child_of_object << 15) # 1 bits => 15 + 1 = 16
		tag = tag | (mproperties.length << 16)
                return tag
	end

	redef fun metainfo_uid do return "classinfo_of_{self.c_name}"
	redef fun meta_cstruct_type do return "struct classinfo_t"

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		for raw_dep in self.raw_dependencies do
			deps.add(raw_dep.to_dep)
		end
		return deps
	end
	# TODO: check if we can simplify cache, ie if the instance of `MModule`
	# is always the same.
	protected var ancestors_cache = new ArrayMap[MModule, SequenceRead[MClass]]

	redef fun provide_declaration(v)
	do
		super
		var cc = v.compiler
		var classinfo = cc.rti_mclasses["ClassInfo"]

		# We add 1 for NULL end mark
		var ancestors_len = main_ancestors.length + 1
		var ancestor_table = "struct classinfo_t* ancestor_table_{self.c_name}[{ancestors_len}]"
		v.compiler.provide_declaration("ancestor_table_{self.c_name}", "extern {ancestor_table};")
		# TODO: type table
		#var mtypes_len = 2 # mclass_type + NULL = 2
		#if self.arity > 0 then
		#	var mtypes_len = self.get_mtype_cache.values.length + 1
		#end
		#var type_table = "struct classtypeinfo_t* typeinfo_table_{self.c_name}[{mtypes_len}]"
		#v.compiler.provide_declaration("typeinfo_table_{self.c_name}", "extern {type_table};")
	end

	redef fun requirements(v)
	do
		var cc = v.compiler
		var mmodule = cc.mainmodule
		if self.is_alive(cc) then
			v.require_declaration("class_{self.c_name}")
		end
		#if self.arity == 0 then
		#	self.mclass_type.require(v)
		#end
		# TODO: type table
		#var mtypes = self.get_mtype_cache.values
		#v.require_declaration("typeinfo_table_{self.c_name}")
		v.require_declaration("ancestor_table_{self.c_name}")
		for raw_dep in self.raw_dependencies do
			raw_dep.require(v)
		end
	end

	private fun raw_dependencies: SequenceRead[SavableMEntity]
	do
		var mtypes = self.get_mtype_cache.values
		var raw_deps = new Array[SavableMEntity]
		# TODO: type table
		#raw_deps.add_all(mtypes)
		raw_deps.add_all(main_mpropdefs)
		raw_deps.add_all(main_ancestors)
		raw_deps.add_all(mparameters)
		return raw_deps
	end

	redef fun write_field_values(v)
	do
		var cc = v.compiler
		var classinfo = cc.rti_mclasses["ClassInfo"]

		# The instance
		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("&type_{classinfo.mclass_type.c_name},")
		v.add_decl("&class_{classinfo.c_name},")
		v.add_decl("{metatag_value},")
		v.add_decl("{color},")
		if self.is_alive(cc) then
			v.add_decl("&class_{self.c_name},") # pointer to the reflected class
		else
			v.add_decl("NULL, /*{self} is DEAD*/")
		end
		# TODO: type table
		#if self.arity > 0 then
		#	v.add_decl("(struct classtypeinfo_t**)typeinfo_table_{self.c_name},")
		#else
		#	var mtype = self.mclass_type
		#	v.add_decl("(struct classtypeinfo_t**){mtype.to_addr},")
		#end

		v.add_decl("\"{self.name}\",") # name of the reflected class
		v.add_decl("(struct classinfo_t**)ancestor_table_{self.c_name},")

		# Save properties info
		v.add_decl("\{")
		# Type parameters are registered first
		for mparam in self.mparameters do
			v.add_decl("(struct propinfo_t*){mparam.to_addr},")
		end
		# Then we save properties
		for mpropdef in main_mpropdefs do
			# NOTE: the function `most_specific_mpropdefs` always return
			# a sequence where the first element are virtual types
			v.add_decl("(struct propinfo_t*){mpropdef.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\}")
		v.add_decl("\};")
		save_ancestor_table(v)
		# TODO: resolve type table in another way
		#save_type_table(v)
	end

	fun linearized_ancestors(mmodule: MModule): SequenceRead[MClass]
	do
		var ancestors = self.collect_ancestors(mmodule, null).to_a
		mmodule.linearize_mclasses(ancestors)
		return ancestors
	end

	protected fun save_ancestor_table(v: AbstractCompilerVisitor)
	do
		var cc = v.compiler
		var mmodule = cc.mainmodule
		var ancestors = main_ancestors
		var decl = "struct classinfo_t* ancestor_table_{self.c_name}[{ancestors.length + 1}]"
		v.add_decl("{decl} = \{")
		for ancestor in ancestors do
			v.add_decl("{ancestor.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")

	end

	protected fun save_type_table(v: AbstractCompilerVisitor)
	do
		if self.arity == 0 then return
		var mtypes = self.get_mtype_cache.values
		var decl = "struct classtypeinfo_t* typeinfo_table_{c_name}[{mtypes.length + 1}]"
		v.add_decl("{decl} = \{")
		for mtype in mtypes do
			v.add_decl("{mtype.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")
	end

	# Returns the most specific definition of a local mproperty among
	# all refinements. NOTE: the first ensures the first property def are
	# virtual type def if the class has any.
	fun most_specific_mpropdefs(mmodule: MModule): SequenceRead[MPropDef]
	do
		var mprops = self.collect_local_mproperties(null)
		var vtypes = new Array[MPropDef]
		var propdefs = new Array[MPropDef]
		var mtype = self.intro.bound_mtype
		for mprop in mprops do
			var mpropdef = mprop.lookup_first_definition(mmodule, mtype)
			if mpropdef isa MVirtualTypeDef then
				vtypes.push(mpropdef)
			else
				propdefs.push(mpropdef)
			end
		end
		var res = vtypes
		res.add_all(propdefs)
		return res
	end
end

redef class MPropDef
	super SavableMEntity

	fun mclass: MClass do return self.mclassdef.mclass

	redef fun metatag_value
	do
		var tag = super
		var visibility = visibility_to_int(self.visibility)
		var qualifier =  0

		tag = tag | (visibility << 3)
		tag = tag | (qualifier << 5)
		return tag
	end
end

redef class MAttributeDef
	redef fun metainfo_uid do return "attrinfo_of_{c_name}"
	redef fun meta_cstruct_type do return "struct attrinfo_t"

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		var static_mtype = self.static_mtype.as(not null)
		deps.add(mclass.to_dep)
		deps.add(static_mtype.to_dep)
		return deps
	end

	redef fun requirements(v)
	do
		mclass.require(v)
		static_mtype.as(not null).require(v)
	end

	redef fun write_field_values(v)
	do
		var cc = v.compiler
		var rti_mclass = cc.rti_mclasses["AttributeInfo"]
		var typeinfo = cc.rti_mclasses["TypeInfo"]
		var mmodule = cc.mainmodule
		var static_mtype = self.static_mtype.as(not null)

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
                v.add_decl("{metatag_value},")
                v.add_decl("{mclass.to_addr},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("(const struct typeinfo_t*){static_mtype.to_addr}")
                v.add_decl("\};")
	end
end

redef class MMethodDef
	redef fun metainfo_uid do return "methodinfo_of_{c_name}"
	redef fun meta_cstruct_type do return "struct methodinfo_t"

	redef fun metatag_value
	do
		var tag = super
		var qualifier = 0

		if self.is_abstract then qualifier = 1
		if self.is_intern then qualifier = 2
		if self.is_extern then qualifier = 3
		tag = tag | (qualifier << 5)

		var msignature = self.msignature
		var arity = 0
		var has_return = if msignature?.return_mtype != null then 1 else 0
		if msignature != null then
			arity = msignature.mparameters.length
			assert arity <= 127
		end
		tag = tag | (arity << 3)
		tag = tag | (has_return << 10)
                return tag
	end

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		var msignature = self.msignature
		deps.add(mclass.to_dep)
		if msignature != null then
			for mparam in msignature.mparameters do
				var mtype = mparam.mtype
				deps.add(mtype.to_dep)
			end
			var return_mtype = msignature.return_mtype
			if return_mtype != null then
				deps.add(return_mtype.to_dep)
			end
		end
		return deps
	end

	redef fun requirements(v)
	do
		var msignature = self.msignature
		mclass.require(v)
		if msignature != null then
			for mparam in msignature.mparameters do
				var mtype = mparam.mtype
				mtype.require(v)
			end
			var return_mtype = msignature.return_mtype
			if return_mtype != null then
				return_mtype.require(v)
			end
		end
	end

	redef fun write_field_values(v)
	do
		var cc = v.compiler
		var rti_mclass = cc.rti_mclasses["MethodInfo"]
		var typeinfo = cc.rti_mclasses["TypeInfo"]
		var mmodule = cc.mainmodule
		var msignature = self.msignature

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
                v.add_decl("{metatag_value},")
                v.add_decl("&{mclass.metainfo_uid},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("\{")
		# TODO: add signature persistence
		if msignature != null then
			for mparam in msignature.mparameters do
				var mtype = mparam.mtype
				v.add_decl("(const struct typeinfo_t*){mtype.to_addr},")
			end
			var return_mtype = msignature.return_mtype
			if return_mtype != null then
				v.add_decl("(const struct typeinfo_t*){return_mtype.to_addr},")
			end
		end
		v.add_decl("NULL")
		v.add_decl("\}")
                v.add_decl("\};")
	end
end

redef class MVirtualTypeDef
	redef fun metainfo_uid do return "vtypepropinfo_of_{mclass.c_name}_{name}"
	redef fun meta_cstruct_type do return "struct vtypeinfo_t"

	protected fun static_bound: MType do return self.bound.as(not null)

	protected fun mvirtualtype: MVirtualType
	do
		return self.mproperty.mvirtualtype
	end

	redef fun requirements(v)
	do
		mvirtualtype.require(v)
		# TODO: fix generic type alias
		#static_bound.require(v)
		mclass.require(v)
	end

	# NOTE: duplicate from `MVTypeMetaQuery`
	redef fun dependencies
	do
		var deps = new AggregateDependencies
		deps.add(mvirtualtype.to_dep)
		deps.add(mclass.to_dep)
		deps.add(mvirtualtype.to_dep)
		return deps
	end

	redef fun write_field_values(v)
	do
		var cc = v.compiler
		var rti_mclass = cc.rti_mclasses["VirtualTypeInfo"]
		var typeinfo = cc.rti_mclasses["TypeInfo"]
		var mmodule = v.compiler.mainmodule
		var vtype = mvirtualtype

		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("&type_{rti_mclass.mclass_type.c_name},")
		v.add_decl("&class_{rti_mclass.c_name},")
		v.add_decl("{self.metatag_value},")
		v.add_decl("{mclass.to_addr},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("{vtype.to_addr},")
		v.add_decl("NULL")
		# TODO: fix generic type alias
		#v.add_decl("(const struct typeinfo_t*){static_bound.to_addr}")
		v.add_decl("\};")
	end
end

private fun visibility_to_int(visibility: MVisibility): Int
do
	if visibility == none_visibility then return 0
	if visibility == public_visibility then return 1
	if visibility == protected_visibility then return 2
	if visibility == private_visibility then return 3
	abort
end

private fun classkind_to_int(kind: MClassKind): Int
do
	if kind == concrete_kind then return 0
	if kind == abstract_kind then return 1
	if kind == interface_kind then return 2
	if kind == enum_kind then return 3
	if kind == extern_kind then return 4
	if kind == subset_kind then return 5
	abort
end

redef class RuntimeInfoImpl
	redef fun name
	do
		var c_name = self.mclass.c_name
		var cstring_type = v.mmodule.c_string_type
		var string_type = v.mmodule.string_type
		var int_type = v.mmodule.int_type

		var false_val = v.value_instance(false)
		var raw_name = v.new_var(cstring_type)
		var name_len = v.new_var(int_type)
		var res = v.new_var(string_type)
		v.add("{raw_name} = (char*){cast(recv)}->name;")
		v.add("{name_len} = (long)strlen({raw_name});")
		v.add("{res} = {v.send(v.get_property("to_s_with_length", cstring_type), [raw_name, name_len]).as(not null)};")
		v.ret(res)
	end

	private fun cast(recv: RuntimeVariable): String
	do
		var metatype = ""
		if mclass.name == "ClassInfo" then
			metatype = "classinfo_t"
		else if mclass.name == "VirtualTypeInfo" then
			metatype = "vtypeinfo_t"
		else if mclass.name == "AttributeInfo" then
			metatype = "attrinfo_t"
		else if mclass.name == "MethodInfo" then
			metatype = "methodinfo_t"
		else if mclass.name == "TypeInfo" then
			metatype = "typeinfo_t"
		else if mclass.name == "RuntimeInfoIterator" then
			metatype = "instance_{mclass.c_name}"
		else
			abort
		end
		return "((struct {metatype}*){recv})"
	end

	# Generates C code that instantiate a new `RuntimeInfoIterator`
	# paramaterized by `mclass.mclass_type`.
	private fun new_iter(recv: RuntimeVariable, table_addr: String): RuntimeVariable
	do
		var recv2 = cast(recv)
		var iter_mclass = v.compiler.get_mclass("RuntimeInfoIterator")
		var mtype = iter_mclass.get_mtype([mclass.mclass_type])
		var iter_constr = "NEW_{iter_mclass.c_name}"
		v.require_declaration("type_{mtype.c_name}")
		v.require_declaration(iter_constr)

		var iter = v.get_name("iter")
		v.add_decl("val* {iter};")
		v.add("{iter} = {iter_constr}((const struct metainfo_t**){table_addr}, &type_{mtype.c_name});")
		var res = v.new_expr("{iter}", mtype)
		return res
	end
end

class DefaultClassInfoImpl
	super ClassInfoImpl

	redef fun ancestors
	do
		var mclass = self.mclass
		#v.require_declaration("instance_{mclass.c_name}")
		var iter = new_iter(recv, "{cast(recv)}->ancestors")
		v.ret(v.autobox(iter, ret_type))
	end

	private fun arity: RuntimeVariable
	do
		var recv2 = cast(recv)
		return v.new_expr("({recv2}->metatag >> 3) & 7", v.mmodule.int_type)
	end

	redef fun properties
	do
		var recv2 = cast(recv)
		# We need to add arity since we store type param first
		v.ret(v.autobox(self.new_iter(recv, "{recv2}->props+{arity}"), ret_type))
	end

	redef fun type_parameters
	do
		var recv2 = cast(recv)
		var len = arity
		var arrayclass = v.mmodule.array_class
		var typeinfo = v.compiler.rti_mclasses["TypeInfo"].mclass_type
		var arraytype = arrayclass.get_mtype([typeinfo])
		var res = v.init_instance(arraytype)
		var nclass = v.mmodule.native_array_class
		var nat = v.native_array_instance(mclass.mclass_type, len)
		var i = v.get_name("i")

		v.add_decl("int {i};")
		v.add("for({i}=0; {i} < {len}; {i}++) \{")
		# Type parameters are registered first in the props table
		var ith_mparamtype = "(val*)({recv2}->props[{i}])"
		v.add("((struct instance_{nclass.c_name}*){nat})->values[{i}] = {ith_mparamtype};")
		v.add("\}")
		v.send(v.get_property("with_native", arraytype), [res, nat, len])
		v.ret(v.autobox(res, ret_type))
	end

	private fun get_class_kind: RuntimeVariable
	do
		var recv2 = cast(recv)
		var class_kind = v.get_name("class_kind")
		v.add_decl("int {class_kind};")
		v.add("{class_kind} = ({recv2}->metatag >> 10) & 3;")
		return v.new_expr("{class_kind}", v.mmodule.int_type)
	end

	redef fun is_interface
	do
		var class_kind = get_class_kind
		v.ret(v.new_expr("{class_kind} == 2", ret_type))
	end

	redef fun is_abstract
	do
		var class_kind = get_class_kind
		v.ret(v.new_expr("{class_kind} == 1", ret_type))
	end

	redef fun is_universal
	do
		var class_kind = get_class_kind
		v.ret(v.new_expr("{class_kind} == 3", ret_type))
	end
end

class DefaultRtiIterImpl
	super RtiIterImpl

	redef fun next
	do
		v.add("{cast(recv)}->table++;")
		v.add("goto {self.v.frame.returnlabel.as(not null)};")
	end

	redef fun is_ok
	do
		v.ret(v.new_expr("*{cast(recv)}->table != NULL", ret_type))
	end

	redef fun item
	do
		v.ret(v.new_expr("(val*)*{cast(recv)}->table", ret_type))
	end
end

class DefaultRtiRepoImpl
	super RtiRepoImpl

	redef fun object_type(target)
	do
		var cc = v.compiler
		var entry = v.get_name("entry")
		v.require_declaration("type_table_entry_t")
		v.require_declaration("typeinfo_table")
		v.add("struct type_table_entry_t* {entry} = typeinfo_table;")
		v.add("for(; {entry}->type != NULL; {entry}++) \{")
		v.add("if({entry}->type == ({target}->type)) \{ break; \} ")
		v.add("\}")
		v.add("if({entry}->type != NULL) \{")
		v.ret(v.new_expr("(val*){entry}->typeinfo", ret_type))
		v.add("\}")
		v.add_abort("type not found")
	end

	redef fun classof(target)
	do
		var cc = v.compiler
		var entry = v.get_name("entry")
		v.require_declaration("class_table_entry_t")
		v.require_declaration("classinfo_table")
		v.add("struct class_table_entry_t* {entry} = classinfo_table;")
		v.add("for(; {entry}->class != NULL; {entry}++) \{")
		v.add("if({entry}->class == ({target}->class)) \{ break; \} ")
		v.add("\}")
		v.add("if({entry}->class != NULL) \{")
		v.ret(v.new_expr("(val*){entry}->classinfo", ret_type))
		v.add("\}")
		v.add_abort("class not found")
	end
end

class DefaultTypeInfoImpl
	super TypeInfoImpl

	redef fun klass
	do
		var cc = v.compiler
		var recv2 = cast(recv)
		v.ret(v.new_expr("(val*){recv2}->classinfo", ret_type))
	end

	redef fun is_formal_type
	do
		var recv2 = cast(recv)
		var res = v.new_expr("({recv2}->metatag & 3) == 2", ret_type)
		v.ret(res)
	end

	redef fun native_equal(other)
	do
		var recv2 = cast(recv)
		var other2 = cast(other)
		# TODO: remove this code if useless
		var res = v.new_expr("{recv2} == {other2}", ret_type)
		v.ret(res)
	end

	redef fun iza(other)
	do
		var recv2 = cast(recv)
		var other2 = cast(other)
		v.add("if(({recv2}->metatag & 3) == 1 && ({other2}->metatag & 3) == 1) \{")
		var classtype1 = v.get_name("classtypeinfo")
		var classtype2 = v.get_name("classtypeinfo")
		v.add_decl("const struct type* {classtype1};")
		v.add("{classtype1} = ((const struct classtypeinfo_t*){recv2})->type;")
		v.add_decl("const struct type* {classtype2};")
		v.add("{classtype2} = ((const struct classtypeinfo_t*){other2})->type;")
		var res = v.isa_test(classtype1, classtype2)
		v.ret(v.autobox(res, ret_type))
		v.add("\} else \{")
		v.add_abort("subtype testing works only for living types")
		v.add("\}")
	end

	redef fun type_arguments
	do
		var recv2 = "((struct classtypeinfo_t*){cast(recv)})"
		# TODO
		# v.ret(v.autobox(self.new_iter(recv, "{recv2}->targs"), ret_type))
	end

	redef fun bound
	do
		var recv2 = cast(recv)
		v.add_abort("TODO")
		# FIXME : persist bound of formaltype
		# If its a formal type
		#v.add("if({recv2}->metatag == 2) \{")
		#var res = v.new_expr("(val*)((struct formaltypeinfo_t*){recv2})->bound", ret_type)
		#v.ret(res)
		#v.add("\}")
		#v.add_abort("only formal types have a bound")
	end
end

