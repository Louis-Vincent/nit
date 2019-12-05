
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
const struct typeinfo_t* static_type;
};

struct methodinfo_t {
unsigned int metatag;
const char* name;
const struct classinfo_t* classinfo;
const int color;
const struct typeinfo_t* signature[];
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
const struct typeinfo_t* static_type;
};

struct classinfo_t {
unsigned int metatag;
const struct class* class_ptr;
/* if `self` is not generic, then `typeinfo_table` points directly to its type*/
struct typeinfo_t* typeinfo_table;
const char* name;
/* We always store type parameters first if any*/
const struct propinfo_t props[];
};

struct typeinfo_t {
unsigned int metatag;
struct type* type_ptr; /* This type_ptr might be null if instance_TypeInfo is a static type */
const struct classinfo_t* classinfo;
const struct typeinfo_t* type_arguments[];
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
# v = visibility (public (0), protected (1), private (10))
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
	fun compile_metatag_to_c(v: AbstractCompilerVisitor) is abstract
	fun save(v: AbstractCompilerVisitor): nullable CompilationDependency do return null
end

abstract class CompilationDependency
	fun is_out_of_date: Bool is abstract
	fun resolve_dependency(cc: AbstractCompiler): nullable CompilationDependency
	is abstract, expect(not is_out_of_date)
end

class SimpleDependency
	super CompilationDependency
	protected var savable: SavableMEntity

	redef fun is_out_of_date do return savable.is_saved

	redef fun resolve_dependency(cc)
	do
		var v = cc.new_visitor
		return savable.save(v)
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
		var aggregate = new AggregateDependencies
		for dep in dependencies do
			if dep.is_out_of_date then continue
			var new_dep = dep.resolve_dependency(cc)
			if new_dep != null then
				aggregate.add(new_dep)
			end
		end
		if aggregate.is_out_of_date then
			return null
		else
			return aggregate
		end
	end

	fun add(dep: CompilationDependency)
	is
		expect(not dep.is_out_of_date)
	do
		dependencies.add(dep)
	end
end

class DefaultModelSaver
	super ModelSaver
	protected var cc: SeparateCompiler

	redef fun save_model(model)
	do
		var dependencies = (new Array[CompilationDependency]).as_fifo
		for mclass in model.mclasses do
			var dep = new SimpleDependency(mclass)
			dependencies.add(dep)
		end

		while not dependencies.is_empty do
			var dep = dependencies.take
			if dep.is_out_of_date then
				continue
			else
				var new_dep = dep.resolve_dependency(cc)
				if new_dep != null then
					dependencies.add(new_dep)
				end
			end
		end
	end
end

redef class MType
	super SavableMEntity
	fun commun_metatag: Int
	do
		var tag = 0
		var metakind = 1
		# NOTE: this is useless a operation and we could return 1, but
		# to be more uniformed with the rest of the code I keep it more
		# verbose.
		tag = tag | metakind
		return tag
	end
	redef fun compile_metatag_to_c(v) do v.add_decl("{commun_metatag};")
end

redef class MClassType

	redef fun commun_metatag
	do
		var tag = super
		var kind = 0
		if self.need_anchor then kind = 1
		tag = tag | (kind << 3)
		tag = tag | (arguments.length << 5)
		return tag
	end
end

redef class MFormalType
	redef fun commun_metatag
	do
		var tag = super
		var is_formal = 1
		return tag | (is_formal << 5)
	end
end

redef class MNullableType
	redef fun commun_metatag
	do
		var tag = mtype.commun_metatag
		var nullble = 1
		# 12 = 3 metakind + 2 type kind + 7 arity
		return tag | (nullble << 12)
	end
end

redef class MClass
	super SavableMEntity

	redef fun save(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule

		var mprops = self.collect_accessible_mproperties(mmodule, null)
		var mtypes = self.get_mtype_cache.values

		# Some prerequisite
		v.require_declaration("const struct classinfo_t")
		v.require_declaration("const struct typeinfo_t")
                v.require_declaration("const struct propinfo_t")

		# We require the declaration of the class we want to save
		v.require_declaration("class_{self.c_name}")

		if self.arity > 0 then
			v.require_declaration("typeinfo_table_{self.c_name}")
		else
			v.require_declaration("typeinfo_of_{self.c_name}")
		end

                var decl = "struct classinfo_t classinfo_of_{c_name}"

		# Then new declaration
                compiler.provide_declaration("classinfo_of_{c_name}", decl)

		# The instance
		v.add_decl("{decl} \{")
		v.add_decl("{metatag_value(mmodule)},")
		v.add_decl("&class_{self.c_name},") # pointer to the reflected class

		if self.arity > 0 then
			v.add_decl("&type_table_{self.c_name},")
		else
			# TODO: maybe not the good code
			v.add_decl("&typeinfo_of_{self.c_name},")
		end
		v.add_decl("\"{self.c_name}\",") # name of the reflected class

		var mpropdefs = most_specific_mpropdefs(mmodule)

		for mpropdef in mpropdefs do
			#var mpropdef_decl = mpropdef.c_meta_declaration
			# TODO: remove the ',' when last item
			#v.add_decl("(propinfo_t*)&{mpropdef_decl},")
		end
		v.add_decl("\}")
		self.is_saved = true

		# TODO: return dependencies
		return null
	end

	fun most_specific_mpropdefs(mmodule: MModule): Collection[MPropDef]
	do
		var mprops = self.collect_accessible_mproperties(mmodule)
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
		var mproperties = self.collect_accessible_mproperties(mmodule, null)
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

	fun mclass: MClass do return mproperty.intro_mclassdef.mclass

	redef fun save(v)
	do
		var compiler = v.compiler
		var mmodule = compiler.mainmodule
		var static_mtype = self.static_mtype.as(not null)

                # Some prerequisite
		v.require_declaration("const struct classinfo_t")
		v.require_declaration("const struct typeinfo_t")
                v.require_declaration("const struct attrinfo_t")
                v.require_declaration("classinfo_of_{mclass.c_name}")
                v.require_declaration("typeinfo_of_{static_mtype.c_name}")

		var decl = "struct attrinfo_t attrinfo_of_{self.c_name}"
		## Then new declaration
		compiler.provide_declaration("attrinfo_of_{c_name}", "{decl}")

		## The instance
		v.add_decl("{decl} \{")
                v.add_decl("{metatag_value(mmodule)},")
                v.add_decl("\"{c_name}\",")
                v.add_decl("&classinfo_of_{mclass.c_name},")
                v.add_decl("{const_color},")
                v.add_decl("&typeinfo_of_{static_mtype.c_name}")
                v.add_decl("\};")

		self.is_saved = true
		# TODO: return dependencies
		return null
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
end

redef class MVirtualTypeDef

	redef fun metatag_value(mmodule)
	do
		var tag = super
		var metakind = 4
		tag = tag | metakind
                return tag
	end
end

private fun visibility_to_int(visibility: MVisibility): Int
do
	if visibility == public_visibility then return 0
	if visibility == protected_visibility then return 1
	if visibility == private_visibility then return 2
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
