
module default

import runtime_internals_base
private import model::model_collect

redef class Sys
	private var null_dependency = new NullDependency
end

class DefaultRuntimeInternals
	super RuntimeInternalsFactory
	redef fun meta_cstruct_provider(cc)
	do
		return new DefaultCStructProvider(cc)
	end

	redef fun model_saver(cc)
	do
		return new DefaultModelSaver(cc)
	end
end

class DefaultCStructProvider
	super MetaCStructProvider
        protected var cc: AbstractCompiler
	redef fun compile_metainfo_header_structs
	do
		cc.header.add_decl("""
struct metainfo_t {
unsigned int metatag;
};

struct typeinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
};

struct propinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
const char* name;
};

struct attrinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
const char* name;
const int color;
const struct typeinfo_t* static_type;
};

struct methodinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
const char* name;
const int color;
//const struct typeinfo_t* signature[];
};

/*
This structure is shared by virtual types and parameter types.
mix: typeinfo_t + propinfo_t
*/
struct formaltypeinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
const char* name;
const struct typeinfo_t* bound;
};

struct classtypeinfo_t {
unsigned int metatag;
const struct classinfo_t* classinfo;
const struct type* type; // NULL if dead or static
//const struct typeinfo_t* targs[];
};

struct classinfo_t {
unsigned int metatag;
const struct class* class_ptr;
/* if `self` is not generic, then `typeinfo_table` points directly to its type*/
struct classtypeinfo_t** typeinfo_table;
const char* name;
/* We always store type parameters first if any*/
struct classinfo_t** ancestors;
const struct propinfo_t* props[];
};
""")
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
# `clasinfo_t` meta tag:
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
# 32 bits: 0000 0000 0000 0000 0rrr rrrr kxxx xxxx
# x = inherited from `PropertyInfo` meta structure
# k = kind of formal type (0=type param, 1=virtual type)
# r = rank (if `self` isa type param)
abstract class SavableMEntity
	var is_saved: Bool = false is protected writable

	fun save(v: SeparateCompilerVisitor)
	is
		expect(not self.is_saved)
	do
		self.requirements(v)
		self.provide_declaration(v)
		self.write_info(v)
	end

	fun requirements(v: AbstractCompilerVisitor) do end

	fun write_info(v: AbstractCompilerVisitor) is abstract

	fun to_dep: CompilationDependency
	do
		if is_saved then return null_dependency
		return new SimpleDependency(self)
	end

	fun require(v: AbstractCompilerVisitor)
	do
		var mq = to_meta_query(v.compiler.mainmodule)
		v.require_declaration(mq.metainfo_uid)
	end

	fun provide_declaration(v: AbstractCompilerVisitor)
	do
		var mq = self.to_meta_query(v.compiler.mainmodule)
		v.compiler.provide_declaration(mq.metainfo_uid, "{mq.full_metainfo_decl};")
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

	fun to_meta_query(mmodule: MModule): MetaQuery is abstract
end

interface MetaQuery
	fun metatag_value: Int
	do
		# NOTE: is not a good pratice to hardcode `if`s with type
		# and I could use polymorphism. However, at this stage of
		# development, the metakind of each savable entity change
		# too much. By choosing the metakind here, we avoid changing
		# the code everywhere in the file.
		# TODO: replace this with polymorphism (when stable)
		if self isa MClassType then return 1
		if self isa MParameterType then return 2
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
end

redef class SeparateCompiler
	fun has_color_for(entity: MEntity): Bool
	do
		return color_consts_done.has(entity)
	end
end

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

class SimpleDependency
	super CompilationDependency
	protected var savable: SavableMEntity

	redef fun is_out_of_date do return self.savable.is_saved

	redef fun resolve_dependency(cc)
	do
		if self.is_out_of_date then return null
		var v = cc.new_visitor
		#print "before is_saved: {savable}, {savable.is_saved}"
		savable.save(v)
		var metaquery = savable.to_meta_query(cc.mainmodule)
		var res = metaquery.dependencies
		#print "after"
		savable.is_saved = true
		return res
	end
end

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
		for mclass in model.mclasses do
			if not mclass.is_alive(cc) then continue
			var dep = new SimpleDependency(mclass)
			deps.add(dep)
		end

		while not deps.is_empty do
			var dep = deps.take
			var new_dep = dep.resolve_dependency(cc)
			if new_dep != null then deps.add(new_dep)
		end
	end
end

abstract class MTypeMetaQuery
	super MetaQuery
	type MTYPE: MType
	protected var mmodule: MModule
	protected var mtype: MTYPE
end

redef class MType
	super SavableMEntity
end

redef class MClassType
	super MetaQuery

	redef fun to_meta_query(mmodule) do return self

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
	end

	redef fun dependencies do return mclass.to_dep

	redef fun write_info(v)
	do
		var mmodule = v.compiler.mainmodule
		var cc = v.compiler
		var mclassquery = mclass.to_meta_query(mmodule)
		v.add_decl("{self.full_metainfo_decl} = \{")
		v.add_decl("{self.metatag_value},")
		v.add_decl("{mclassquery.to_addr},")
		if not self.need_anchor and self.is_alive(cc) then
			v.add_decl("&type_{self.mclass.c_name}")
		else
			v.add_decl("NULL /*{self} is DEAD*/")
		end
		v.add_decl("\};")
	end
end

class MVTypeMetaQuery
	super MTypeMetaQuery
	redef type MTYPE: MVirtualType

	protected var vtypedef: MVirtualTypeDef is noinit

	init
	do
		vtypedef = self.mtype.most_specific_def(mmodule)
	end

	redef fun metainfo_uid
	do
		return self.vtypedef.metainfo_uid
	end

	redef fun meta_cstruct_type
	do
		return self.vtypedef.meta_cstruct_type
	end

	redef fun dependencies
	do
		return self.vtypedef.dependencies
	end
end

# This class is only proxying to `MVirtualTypeDef`.
redef class MVirtualType

	redef fun to_meta_query(mmodule)
	do
		return new MVTypeMetaQuery(mmodule, self)
	end

	private fun most_specific_def(mmodule: MModule): MVirtualTypeDef
	do
		var mclass = mproperty.intro_mclassdef.mclass
		var mclassdef = mclass.most_specific_def(mmodule)
		var vtypedef = lookup_single_definition(mmodule, mclassdef.bound_mtype)
		return vtypedef
	end

	redef fun save(v)
	do
		var cc = v.compiler
		var mmodule = cc.mainmodule
		var vtypedef = most_specific_def(mmodule)
		# proxy
		if not vtypedef.is_saved then
			vtypedef.save(v)
			vtypedef.is_saved = true
		end
	end

	redef fun require(v)
	do
		var vtypedef = most_specific_def(v.compiler.mainmodule)
		# proxy
		vtypedef.require(v)
	end
end

class MParamMetaQuery
	super MTypeMetaQuery
	redef type MTYPE: MParameterType

	redef fun meta_cstruct_type do return "struct formaltypeinfo_t"
	redef fun metainfo_uid
	do
		return "typeparam_of_{mtype.mclass.c_name}_{mtype.name}"
	end

	redef fun metatag_value
	do
		var tag = super
		return tag | (mtype.rank << 9)
	end

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		deps.add(mtype.mclass.to_dep)
		deps.add(mtype.static_bound(self.mmodule).to_dep)
		return deps
	end
end

redef class MParameterType

	redef fun to_meta_query(mmodule)
	do
		return new MParamMetaQuery(mmodule, self)
	end

	fun static_bound(mmodule: MModule): MType
	do
		var mclassdef = mclass.most_specific_def(mmodule)
		return mclassdef.bound_mtype.arguments[self.rank]
	end

	redef fun requirements(v)
	do
		mclass.require(v)
		static_bound(v.compiler.mainmodule).require(v)
	end

	redef fun write_info(v)
	do
		var mmodule = v.compiler.mainmodule
		var static_bound = static_bound(mmodule)
		var selfquery = to_meta_query(mmodule)
		var mclassquery = mclass.to_meta_query(mmodule)
		var staticquery = static_bound.to_meta_query(mmodule)

		v.add_decl("{selfquery.full_metainfo_decl} = \{")
		v.add_decl("{selfquery.metatag_value},")
		v.add_decl("{mclassquery.to_addr},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("(struct typeinfo_t*){staticquery.to_addr}")
		v.add_decl("\};")
	end
end

class MNullableMetaQuery
	super MTypeMetaQuery

	redef type MTYPE: MNullableType

	protected var proxied: MetaQuery is noinit

	init
	do
		self.proxied = mtype.mtype.to_meta_query(self.mmodule)
	end

	redef fun metainfo_uid
	do
		return "{self.proxied.metainfo_uid}_nullable"
	end

	redef fun metatag_value
	do
		var tag = self.proxied.metatag_value
		var nullble = 1
		# 12 = 3 metakind + 2 type kind + 7 arity
		return tag | (nullble << 31)
	end

	redef fun meta_cstruct_type
	do
		return self.proxied.meta_cstruct_type
	end

	redef fun dependencies do return self.proxied.dependencies
end
redef class MNullableType
	redef fun to_meta_query(mmodule)
	do
		return new MNullableMetaQuery(mmodule, self)
	end
	redef fun save(v)
	do
		self.provide_declaration(v)
		self.requirements(v)
		if not mtype.is_saved then
			mtype.save(v)
			mtype.is_saved = true
		end
	end

	redef fun requirements(v)
	do
		mtype.require(v)
	end
end

class MClassMetaQuery
	super MetaQuery

	protected var mmodule: MModule
	protected var mclass: MClass

	redef fun metatag_value
	do
		var tag = super
		var arity = self.mclass.mparameters.length
		var mproperties = self.mclass.collect_local_mproperties(null)
		var kind = classkind_to_int(self.mclass.kind)
		var visibility = visibility_to_int(self.mclass.visibility)
		var object_class = self.mmodule.get_primitive_class("Object")
		var direct_childs_of_object = object_class.collect_children(self.mmodule, null)
		var is_child_of_object = direct_childs_of_object.has(self).to_i
		tag = tag | (arity << 3) # 7 bits => 3 + 7 = 10
		tag = tag | (kind << 10) # 3 bits => 10 + 3 + 13
		tag = tag | (visibility << 13) # 1 bits => 13 + 2 = 15
		tag = tag | (is_child_of_object << 15) # 1 bits => 15 + 1 = 16
		tag = tag | (mproperties.length << 16)
                return tag
	end

	redef fun metainfo_uid do return "classinfo_of_{mclass.c_name}"
	redef fun meta_cstruct_type do return "struct classinfo_t"

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		if self.mclass.arity == 0 then
			deps.add(mclass.mclass_type.to_dep)
		end
		for raw_dep in mclass.raw_dependencies(self.mmodule) do
			deps.add(raw_dep.to_dep)
		end
		return deps
	end
end

redef class MClass
	super SavableMEntity

	redef fun to_meta_query(mmodule: MModule): MClassMetaQuery
	do
		return new MClassMetaQuery(mmodule, self)
	end

	redef fun provide_declaration(v)
	do
		super
		var ancestor_table = "struct classinfo_t* ancestor_table_{self.c_name}[]"
		v.compiler.provide_declaration("ancestor_table_{self.c_name}", "extern {ancestor_table};")
		if self.arity > 0 then
			var type_table = "struct classtypeinfo_t* typeinfo_table_{self.c_name}[]"
			v.compiler.provide_declaration("typeinfo_table_{c_name}", "extern {type_table};")
		end
	end

	redef fun requirements(v)
	do
		var cc = v.compiler
		var mmodule = cc.mainmodule
		if self.is_alive(cc) then
			v.require_declaration("class_{self.c_name}")
		end
		if self.arity > 0 then
			var mtypes = self.get_mtype_cache.values
			v.require_declaration("typeinfo_table_{self.c_name}")
		else
			self.mclass_type.require(v)
		end

		v.require_declaration("ancestor_table_{self.c_name}")
		for raw_dep in self.raw_dependencies(mmodule) do
			raw_dep.require(v)
		end
	end

	private fun raw_dependencies(mmodule: MModule): SequenceRead[SavableMEntity]
	do
		var ancestors = self.collect_ancestors(mmodule, null)
		var mtypes = self.get_mtype_cache.values
		var mpropdefs = most_specific_mpropdefs(mmodule)
		var raw_deps = new Array[SavableMEntity]
		raw_deps.add_all(mtypes)
		raw_deps.add_all(mpropdefs)
		raw_deps.add_all(ancestors)
		raw_deps.add_all(mparameters)
		return raw_deps
	end

	redef fun write_info(v)
	do
		var cc = v.compiler
		var mmodule = cc.mainmodule
		var mpropdefs = most_specific_mpropdefs(mmodule)
		var metaquery = self.to_meta_query(mmodule)
		# The instance
		v.add_decl("{metaquery.full_metainfo_decl} = \{")
		v.add_decl("{metaquery.metatag_value},")
		if self.is_alive(cc) then
			v.add_decl("&class_{self.c_name},") # pointer to the reflected class
		else
			v.add_decl("NULL, /*{self} is DEAD*/")
		end
		if self.arity > 0 then
			v.add_decl("(struct classtypeinfo_t**)typeinfo_table_{self.c_name},")
		else
			var mtype = self.mclass_type
			v.add_decl("(struct classtypeinfo_t**){mtype.to_addr},")
		end

		v.add_decl("\"{self.name}\",") # name of the reflected class
		v.add_decl("(struct classinfo_t**)ancestor_table_{self.c_name},")

		# Save properties info
		v.add_decl("\{")
		# Type parameters are registered first
		for mparam in self.mparameters do
			var mq = mparam.to_meta_query(mmodule)
			v.add_decl("(struct propinfo_t*){mq.to_addr},")
		end
		# Then we save properties
		for mpropdef in mpropdefs do
			v.add_decl("(struct propinfo_t*){mpropdef.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\}")
		v.add_decl("\};")

		save_ancestor_table(v)
		save_type_table(v)
	end

	protected fun save_ancestor_table(v: AbstractCompilerVisitor)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var ancestors = self.collect_ancestors(mmodule, null)
		var decl = "struct classinfo_t* ancestor_table_{self.c_name}[]"
		v.add_decl("{decl} = \{")
		for ancestor in ancestors do
			var mq = ancestor.to_meta_query(mmodule)
			v.add_decl("{mq.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")

	end

	protected fun save_type_table(v: AbstractCompilerVisitor)
	do
		if self.arity == 0 then return
		var mtypes = self.get_mtype_cache.values
		var decl = "struct classtypeinfo_t* typeinfo_table_{c_name}[]"
		v.add_decl("{decl} = \{")
		for mtype in mtypes do
			var metaquery = mtype.to_meta_query(v.compiler.mainmodule)
			v.add_decl("{metaquery.to_addr},")
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")
	end

	fun most_specific_mpropdefs(mmodule: MModule): Collection[MPropDef]
	do
		var mprops = self.collect_local_mproperties(null)
		var res = new Array[MPropDef]
		var mtype = self.intro.bound_mtype
		for mprop in mprops do
			var mpropdef = mprop.lookup_first_definition(mmodule, mtype)
			res.push(mpropdef)
		end
		return res
	end
end

redef class MPropDef
	super SavableMEntity
	super MetaQuery

	redef fun to_meta_query(mmodule) do return self

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

	redef fun write_info(v)
	do
		var compiler = v.compiler
		assert compiler isa SeparateCompiler
		var mmodule = compiler.mainmodule
		var static_mtype = self.static_mtype.as(not null)
		var mclassquery = mclass.to_meta_query(mmodule)
		var stquery = static_mtype.to_meta_query(mmodule)
		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
                v.add_decl("{metatag_value},")
                v.add_decl("{mclassquery.to_addr},")
		v.add_decl("\"{self.name}\",")
		# NOTE: for debug
		if compiler.has_color_for(self) then
			v.add_decl("-1, // TODO")
		else
			v.add_decl("-2, /*{self} has no color */")
		end
		# NOTE: don't forget to put back `,` at `const_color`
		# TODO: v.add_decl("&typeinfo_of_{static_mtype.c_name}")
		v.add_decl("(const struct typeinfo_t*){stquery.to_addr}")
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

	redef fun dependencies do return mclass.to_dep

	redef fun requirements(v) do mclass.require(v)

	redef fun write_info(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var mclassquery = mclass.to_meta_query(mmodule)

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
                v.add_decl("{metatag_value},")
                v.add_decl("&{mclassquery.metainfo_uid},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("-1 /* {self} is dead */")

		# TODO: add signature persistence
                v.add_decl("\};")
	end
end

redef class MVirtualTypeDef
	redef fun metainfo_uid do return "vtypeinfo_of_{mclass.c_name}_{name}"
	redef fun meta_cstruct_type do return "struct formaltypeinfo_t"

	protected fun static_bound: MType do return self.bound.as(not null)

	redef fun requirements(v)
	do
		mclass.require(v)
		static_bound.require(v)
	end

	redef fun dependencies
	do
		var deps = new AggregateDependencies
		deps.add(mclass.to_dep)
		deps.add(static_bound.to_dep)
		return deps
	end

	redef fun write_info(v)
	do
		var mmodule = v.compiler.mainmodule
		var staticboundquery = static_bound.to_meta_query(mmodule)
		var mclassquery = mclass.to_meta_query(mmodule)
		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("{metatag_value},")
		v.add_decl("{mclassquery.to_addr},")
		v.add_decl("\"{self.name}\",")
		v.add_decl("(struct typeinfo_t*){staticboundquery.to_addr}")
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
