
module default

import runtime_internals_base
private import model::model_collect

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

struct propinfo_t {
unsigned int metatag;
const char* name;
const struct classinfo_t* classinfo;
};

struct attrinfo_t {
unsigned int metatag;
const char* name;
const struct classinfo_t* classinfo;
const int color;
//const struct typeinfo_t* static_type;
};

struct methodinfo_t {
unsigned int metatag;
const char* name;
const struct classinfo_t* classinfo;
const int color;
//const struct typeinfo_t* signature[];
};

/*
This structure is shared by virtual types and parameter types.
In this implementation, any type parameter share the same base structure as
`propinfo_t`. Morever, they are stored inside the same `props[]` array inside<
`instance_ClassInfo`.
*/
struct vtypeinfo_t {
unsigned int metatag;
const char* name;
const struct classinfo_t* classinfo;
//const struct typeinfo_t* static_type;
};

struct classinfo_t {
unsigned int metatag;
const struct class* class_ptr;
/* if `self` is not generic, then `typeinfo_table` points directly to its type*/
struct typeinfo_t** typeinfo_table;
const char* name;
/* We always store type parameters first if any*/
struct classinfo_t** ancestors;
const struct propinfo_t* props[];
};

struct typeinfo_t {
unsigned int metatag;
/* This type_ptr might be null if it describes a static type or
is an unhardened open type.
*/
const struct type* type_ptr;
const struct classinfo_t* classinfo;
//const struct typeinfo_t* type_arguments[];
};
""")
	end
end

# Each internal structure that represent a metainformation
# must have a `metainfo` tag at the start of their `struct`.
# This class provide a standard way of describing meta entities.
# NOTE: this class is tightly coupled with the runtime internals implementation.

# There are 5 meta structures = 3 bits called the `meta kind`
#
# - `000` = class kind
# - `001` = type kind
# - `010` = attribute kind
# - `011` = method kind
# - `100` = virtual type kind
#
# 32 bits: 0000 0000 0000 0000 0000 0000 0000 0000
#
# `ClassInfo` meta structure :
# 32 bits: 0000 000p pppp pppp pvvk kkaa aaaa ammm
# m = meta kind
# a = arity = number of formal parameters (maximum of 128)
# k = kind of class (concrete (0), abstract (1), interface (10),
# enum (11), extern (100), subset (101))
# v = visibility (public (0) or private (10))
# p = properties = number of property (maximum of 1024)
# 0 = unused space = could be use to store larger amount of `p`
#
# `TypeInfo` meta structure :
# 32 bits: 0000 0000 0000 0000 000n aaaa aaak kmmm
# m = meta kind
# k = kind of types (closed 0, not_closed = 1, formal_type = 10)
# a = arity (duplicated data from `ClassInfo`, however, it avoids redundant
# memory roundtrip, a.k.a querying the `ClassInfo` each time we want the arity.
# n = nullable or not (not null = 0, null = 1)
#
# Shared meta info for `PropertyInfo` :
# 32 bits: 0000 0000 0000 0000 0000 0000 0qqv vmmm
# m = meta kind
# v = visibility (none (0), public (1), protected (10), private (11))
# q = qualifier (none (0), abstract (1), intern (10), extern (11))
#
# `AttributeInfo` meta structure :
# 32 bits: 0000 0000 0000 0000 0000 0000 0xxx xxxx
# x = inherited from `PropertyInfo` meta structure
#
# `MethodInfo` meta structure :
# 32 bits: 0000 0000 0000 0000 0raa aaaa axxx xxxx
# x = inherited from `PropertyInfo` meta structure
# a = arity (max 127)
# r = has a return value (0=no, 1=yes)
#
# `VirtualTypeInfo` meta structure :
# 32 bits: 0000 0000 0000 0000 0000 0000 0xxx xxxx
# x = inherited from `PropertyInfo` meta structure
abstract class SavableMEntity
	var is_saved: Bool is protected writable
	fun metatag_value(mmodule: MModule): Int is abstract
	fun meta_cstruct_type: String is abstract
	fun metainfo_uid: String is abstract
	fun full_metainfo_decl: String do return "{meta_cstruct_type} {metainfo_uid}"
	fun save(v: SeparateCompilerVisitor): nullable CompilationDependency
	is
		expect(not self.is_saved)
	do
		return null
	end

	#fun is_savable(cc: SeparateCompiler): Bool do return cc.is_alive(self)
end

redef class SeparateCompiler

	fun has_color_for(entity: MEntity): Bool
	do
		return color_consts_done.has(entity)
	end

	# TODO: may be removed.
	fun is_alive(entity: MEntity): Bool
	do
		var rta = self.runtime_type_analysis
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

abstract class CompilationDependency
	fun is_out_of_date: Bool is abstract
	fun resolve_dependency(cc: SeparateCompiler): nullable CompilationDependency
	is abstract
end

class SimpleDependency
	super CompilationDependency
	protected var savable: SavableMEntity

	redef fun is_out_of_date do return savable.is_saved

	redef fun resolve_dependency(cc)
	do
		if is_out_of_date then return null
		var v = cc.new_visitor
		var res = savable.save(v)
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
			if dep.is_out_of_date then continue
			var new_dep = dep.resolve_dependency(cc)
			if new_dep != null then
				res.add(new_dep)
			end
		end
		if res.is_out_of_date then
			return null
		else
			return res
		end
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
			if not cc.is_alive(mclass) then continue
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

redef class MType
	super SavableMEntity

	redef fun meta_cstruct_type do return "struct typeinfo_t"

	redef fun metatag_value(mmodule): Int
	do
		var tag = 0
		var metakind = 1
		# NOTE: this is useless a operation and we could return 1, but
		# to be more uniformed with the rest of the code I keep it more
		# verbose.
		tag = tag | metakind
		return tag
	end
end

redef class MClassType
	redef fun metainfo_uid do return "typeinfo_of_{self.c_name}"

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var kind = 0
		if self.need_anchor then kind = 1
		tag = tag | (kind << 3)
		tag = tag | (arguments.length << 5)
		return tag
	end

	redef fun save(v)
	do
		var mmodule = v.compiler.mainmodule
		var compiler = v.compiler
		# Then new declaration
                compiler.provide_declaration("{metainfo_uid}", "{self.full_metainfo_decl};")
		v.require_declaration(mclass.metainfo_uid)
		v.add_decl("{self.full_metainfo_decl} = \{")
		v.add_decl("{self.metatag_value(mmodule)},")

		if not self.need_anchor and compiler.is_alive(self) then
			v.require_declaration("type_{self.c_name}")
			v.add_decl("&type_{self.mclass.c_name},")
		else
			v.add_decl("NULL, /*{self} is DEAD*/")
		end

		v.add_decl("&{mclass.metainfo_uid}")
		# TODO: handle type arguments
		v.add_decl("\};")

		if not mclass.is_saved then
			return new SimpleDependency(self.mclass)
		else
			return null
		end
		# TODO: handle type arguments dependencies
	end
end

redef class MFormalType

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var is_formal = 1
		return tag | (is_formal << 5)
	end
end

redef class MParameterType
	redef fun metainfo_uid do return "typeinfo_of_{mclass.c_name}"
	# TODO
	redef fun meta_cstruct_type do return ""
end

redef class MNullableType
	redef fun metainfo_uid do return "{mtype.metainfo_uid}_nullable"

	redef fun metatag_value(mmodule)
	do
		var tag = mtype.metatag_value(mmodule)
		var nullble = 1
		# 12 = 3 metakind + 2 type kind + 7 arity
		return tag | (nullble << 12)
	end

	redef fun save(v) do return mtype.save(v)
end

redef class MClass
	super SavableMEntity

	redef fun metainfo_uid do return "classinfo_of_{c_name}"
	redef fun meta_cstruct_type do return "struct classinfo_t"

	redef fun save(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var deps = new AggregateDependencies
		var mpropdefs = most_specific_mpropdefs(mmodule)
		# Then new declaration
                compiler.provide_declaration("{metainfo_uid}", "{full_metainfo_decl};")

		# The instance
		v.add_decl("{full_metainfo_decl} = \{")
		v.add_decl("{metatag_value(mmodule)},")
		if compiler.is_alive(self) then
			# We require the declaration of the class we want to save
			v.require_declaration("class_{self.c_name}")
			v.add_decl("&class_{self.c_name},") # pointer to the reflected class
		else
			v.add_decl("NULL, /*{self} is DEAD*/")
		end
		if self.arity > 0 then
			v.require_declaration("typeinfo_table_{self.c_name}")
			v.add_decl("(struct typeinfo_t**)typeinfo_table_{self.c_name},")
		else
			v.require_declaration("typeinfo_of_{self.c_name}")
			# TODO: maybe not the good code
			v.add_decl("(struct typeinfo_t**)&typeinfo_of_{self.c_name},")
			var mtype = self.mclass_type
			deps.add(new SimpleDependency(mtype))
		end
		v.add_decl("\"{self.name}\",") # name of the reflected class
		v.require_declaration("ancestor_table_{self.c_name}")
		v.add_decl("(struct classinfo_t**)ancestor_table_{self.c_name},")

		# Save properties info
		v.add_decl("\{")
		for mpropdef in mpropdefs do
			if mpropdef isa MVirtualTypeDef then continue
			var mpropdef_decl = mpropdef
			v.require_declaration("{mpropdef.metainfo_uid}")
			v.add_decl("(struct propinfo_t*)&{mpropdef.metainfo_uid},")
			if not mpropdef.is_saved then
				deps.add(new SimpleDependency(mpropdef))
			end
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\}")
		v.add_decl("\};")

		var subdep = save_ancestor_table(v)
		deps.add(subdep)
		if arity > 0 then
			var subdep2 = save_type_table(v)
			deps.add(subdep2)
		end

		# TODO: return dependencies
		return deps
	end

	protected fun save_ancestor_table(v: AbstractCompilerVisitor): CompilationDependency
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var ancestors = self.collect_ancestors(mmodule, null)
		var deps = new AggregateDependencies
		var decl = "struct classinfo_t* ancestor_table_{self.c_name}[]"
		v.compiler.provide_declaration("ancestor_table_{self.c_name}", "extern {decl};")
		v.add_decl("{decl} = \{")
		for ancestor in ancestors do
			v.require_declaration("{ancestor.metainfo_uid}")
			v.add_decl("&{ancestor.metainfo_uid},")
			if not ancestor.is_saved then
				deps.add(new SimpleDependency(ancestor))
			end
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")
		return deps

	end

	protected fun save_type_table(v: AbstractCompilerVisitor): CompilationDependency
	do
		var mtypes = self.get_mtype_cache.values
		var deps = new AggregateDependencies
		var decl = "struct typeinfo_t* typeinfo_table_{c_name}[]"
		v.compiler.provide_declaration("typeinfo_table_{c_name}", "extern {decl};")
		v.add_decl("{decl} = \{")
		for mtype in mtypes do
			v.require_declaration("{mtype.metainfo_uid}")
			v.add_decl("&{mtype.metainfo_uid},")
			if not mtype.is_saved then
				deps.add(new SimpleDependency(mtype))
			end
		end
		v.add_decl("NULL") # NULL terminated sequence
		v.add_decl("\};")
		return deps
	end

	fun most_specific_mpropdefs(mmodule: MModule): Collection[MPropDef]
	do
		var mprops = self.collect_local_mproperties(null)
		# Cache our properties
		var res = new Array[MPropDef]
		for mprop in mprops do
			# Get the most specific implementation
			var mtype = self.mclass_type
			# First, we need to make sure mtype doesn't need an anchor,
			# otherwise we can't call `lookup_first_definition`.
			if mtype.need_anchor then
				mtype = self.intro.bound_mtype
			end
			var mpropdef = mprop.lookup_first_definition(mmodule, mtype)
			res.push(mpropdef)
		end
		return res
	end

	redef fun metatag_value(mmodule)
	do
		var tag = 0x00000000
		var metakind = 0 # it's a class kind, nothing to do
		var arity = self.mparameters.length
		var mproperties = self.collect_local_mproperties(null)
		var kind = classkind_to_int(self.kind)
		var visibility = visibility_to_int(self.visibility)
		tag = tag | metakind # 3 bits
		tag = tag | (arity << 3) # 7 bits => 3 + 7 = 10
		tag = tag | (kind << 10) # 3 bits => 10 + 3 + 13
		tag = tag | (visibility << 13) # 1 bits => 13 + 2 = 15
		tag = tag | (mproperties.length << 15)
                return tag
	end
end

redef class MPropDef
	super SavableMEntity

	fun mclass: MClass do return mproperty.intro_mclassdef.mclass

	redef fun metatag_value(mmodule)
	do
		var tag = 0x00000000
		var metakind = 0 # we don't know yet
		var visibility = visibility_to_int(self.visibility)
		var qualifier =  0

		tag = tag | metakind
		tag = tag | (visibility << 3)
		tag = tag | (qualifier << 5)
		return tag
	end
end

redef class MAttributeDef

	redef fun metainfo_uid do return "attrinfo_of_{c_name}"
	redef fun meta_cstruct_type do return "struct attrinfo_t"

	redef fun save(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var static_mtype = self.static_mtype.as(not null)
		compiler.provide_declaration("{metainfo_uid}", "{full_metainfo_decl};")

                # Some prerequisite
                v.require_declaration("classinfo_of_{mclass.c_name}")

		# TODO: v.require_declaration("typeinfo_of_{static_mtype.c_name}")

		## Then new declaration

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
                v.add_decl("{metatag_value(mmodule)},")
                v.add_decl("\"{self.name}\",")
                v.add_decl("&{mclass.metainfo_uid},")
		# NOTE: for debug
		if compiler.has_color_for(self) then
			#v.require_declaration(self.const_color)
			#v.add_decl("{self.const_color}")
			v.add_decl("-1 // TODO")
		else
			v.add_decl("-2 /*{self} has no color */")
		end
		# NOTE: don't forget to put back `,` at `const_color`
		# TODO: v.add_decl("&typeinfo_of_{static_mtype.c_name}")
                v.add_decl("\};")

		if mclass.is_saved then
			return null
		else
			return new SimpleDependency(mclass)
		end

		# TODO: add type static dependency
	end

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var metakind = 2
		tag = tag | metakind
                return tag
	end
end

redef class MMethodDef

	redef fun metainfo_uid do return "methodinfo_of_{c_name}"
	redef fun meta_cstruct_type do return "struct methodinfo_t"

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var qualifier = 0

		if self.is_abstract then qualifier = 1
		if self.is_intern then qualifier = 2
		if self.is_extern then qualifier = 3
		tag = tag | (qualifier << 5)

		var metakind = 3
		var msignature = self.msignature
		var arity = 0
		var has_return = if msignature?.return_mtype != null then 1 else 0
		if msignature != null then
			arity = msignature.mparameters.length
			assert arity <= 127
		end
		tag = tag | metakind
		tag = tag | (arity << 3)
		tag = tag | (has_return << 10)
                return tag
	end

	redef fun save(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		compiler.provide_declaration("{metainfo_uid}", "{full_metainfo_decl};")

                # Some prerequisite
                v.require_declaration("classinfo_of_{mclass.c_name}")

		# TODO: add type signature requirements

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
                v.add_decl("{metatag_value(mmodule)},")
                v.add_decl("\"{self.name}\",")
                v.add_decl("&classinfo_of_{mclass.c_name},")
		#if compiler.has_color_for(self) then
		#		v.require_declaration(self.const_color)
		#	v.add_decl("{self.const_color}")
		#else
		v.add_decl("-1 /* {self} is dead */")
			#end

		# TODO: add signature persistence
                v.add_decl("\};")

		if mclass.is_saved then
			return null
		else
			return new SimpleDependency(mclass)
		end
		# TODO: add type dependencies
	end
end

redef class MVirtualTypeDef

	redef fun meta_cstruct_type do return "struct vtypeinfo_t"
	redef fun metainfo_uid do return "vtypeinfo_of_{mclass.c_name}_{name}"

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var metakind = 4
		tag = tag | metakind
                return tag
	end

	redef fun save(v)
	do
		if is_saved then
			print "saved twice for `{self}`"
			abort
		end
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		compiler.provide_declaration("{metainfo_uid}", "{full_metainfo_decl};")

                # Some prerequisite
                v.require_declaration("classinfo_of_{mclass.c_name}")

		# TODO: add bound requirement

		# The c_name is artificial since virtual type doesn't normally
		# exist at runtime.
		## Then new declaration

		## The instance
		v.add_decl("{full_metainfo_decl} = \{")
                v.add_decl("{metatag_value(mmodule)},")
                v.add_decl("\"{self.name}\",")
                v.add_decl("&classinfo_of_{mclass.c_name}")
		# TODO: add bound persistence
                v.add_decl("\};")

		if mclass.is_saved then
			return null
		else
			return new SimpleDependency(mclass)
		end
		# TODO: add bound dependency
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
