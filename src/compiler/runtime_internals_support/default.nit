
module default

import runtime_internals_base
private import model::model_collect

class DefaultRuntimeInternals
	super RuntimeInternalsFactory
	redef fun model_saver(compiler)
	do
		return new DefaultModelSaver(compiler)
	end
end

class DefaultModelSaver
	super ModelSaver
	protected var compiler: SeparateCompiler
	protected var metatag_resolver = new MetaTagResolver

	redef fun save_model
	do
		var model = mmodule.model
		var c_name = mmodule.c_name
		compile_metainfo_header_structs
		self.compiler.new_file("{c_name}.metadata")
		for mclass in model.mclasses do
			save_class(mclass)
		end
	end

	protected fun mmodule: MModule do return compiler.mainmodule

	protected fun compile_metainfo_header_structs
	do
		compiler.header.add_decl("""
struct metainfo_t {
const struct type *type;
const struct class *class;
unsigned int metainfo;
};

struct propinfo_t {
const struct type *type;
const struct class *class;
unsigned int metainfo;
const char* name;
const struct instance_ClassInfo* classinfo;
};

struct instance_AttributeInfo {
const struct type *type;
const struct class *class;
unsigned int metainfo;
int color;
const char* name;
const struct instance_ClassInfo* classinfo;
const struct instance_TypeInfo* static_type;
};

struct instance_MethodInfo {
const struct type *type;
const struct class *class;
unsigned int metainfo;
int color;
const char* name;
const struct instance_ClassInfo* classinfo;
const struct instance_TypeInfo* signature[];
};

/*
This structure is shared by virtual types and parameter types.
In this implementation, any type parameter share the same base structure as
`propinfo_t`. Morever, they are stored inside the same `props[]` array inside<
`instance_ClassInfo`.
*/
struct instance_VirtualTypeInfo {
const struct type *type;
const struct class *class;
unsigned int metainfo;
const char* name;
const struct instance_ClassInfo* classinfo;
const struct instance_TypeInfo* static_type;
};

struct instance_ClassInfo {
const struct type *type;
const struct class *class;
unsigned int metainfo;
/* if this `ClassInfo` isn't a generic class, then `typeinfo_table point to its
unique `TypeInfo` instance.*/
struct instance_TypeInfo* typeinfo_table;
const struct class* class_ptr;
const char* name;
/* We always store type parameters first */
const struct propinfo_t props[];
};

struct instance_TypeInfo {
const struct type *type;
const struct class *class;
unsigned int metainfo;
struct type* type_ptr; /* This type_ptr might be null if instance_TypeInfo is a static type */
const struct instance_ClassInfo* classinfo;
const struct instance_TypeInfo* type_arguments[];
};
""")
	end

	protected fun save_class(mclass: MClass)
	do
		var v = compiler.new_visitor
		var c_name = mclass.c_name
		var decl = "const struct instance_ClassInfo class_info_{c_name}"
		v.provide_declaration("class_info_{c_name}", "{decl};")
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
	fun c_meta_declaration: String is abstract
	fun compile_metatag_to_c(: AbstractCompilerVisitor) is abstract
	fun save(v: AbstractCompilerVisitor): nullable CompilationDependency is abstract
end

abstract class CompilationDependency
	fun is_out_of_date: Bool is abstract
	fun resolve_dependency(v: AbstractCompiler): nullable CompilationDependency is abstract
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
		return true
	end

	redef fun resolve_dependency(v)
	do
		if is_out_of_date then return null
		var new_deps = new Array[CompilationDependency]
		for dep in dependencies do
			if dep.is_out_of_date then continue
			var new_dep = dep.resolve_dependency(v)
			if new_dep != null then
				new_deps.push(new_dep)
			end
		end
		if new_deps.is_empty then
			return null
		else
			return new_deps
		end
	end
end

redef class MType
	super SavableMEntity
	redef fun commun_metatag: Int
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

	redef fun c_meta_declaration
	do
		return "struct instance_ClassInfo instance_ClassInfo_{c_name}"
	end

	redef fun save(v)
	do
		var mmodule = v.compiler.mainmodule
		var model = v.compiler.modelbuilder.model
		var classinfo = model.get_mclasses_by_name("ClassInfo")?.first
		assert classinfo != null
		var c_name = classinfo.c_name
		var mprops = mclass.collect_accessible_mproperties(mmodule, null)
		var mtypes = self.get_mtype_cache.values

		# Some prerequisite
		# We require the class and type  of `ClassInfo` to be declared
		v.require_declaration("class_{c_name}")
		v.require_declaration("type_{c_name}")

		# We require the declaration of the class we want to save
		v.require_declaration("class_{self.c_name}")

		if self.arity > 0 then
			v.require_declaration("type_table_{self.c_name}")
		else
			# TODO: maybe not the good code
			v.require_declaration("type_{self.c_name}")
		end

		# Then new declaration
		v.provide_declaration("instance_ClassInfo_{c_name}", "{c_meta_declaration};")

		# The instance
		v.add_decl("{c_meta_declaration} \{")
		## Commun metainfo structure
		v.add_decl("&type_{c_name},")
		v.add_decl("&class_{c_name},")
		compile_metatag_to_c(v)

		if self.arity > 0 then
			v.add_decl("&type_table_{self.c_name},")
		else
			# TODO: maybe not the good code
			v.add_decl("&type_{self.c_name},")
		end
		## `ClassInfo` specific
		v.add_decl("&class_{self.c_name};") # pointer to the reflected class
		v.add_decl("{c_name}") # name of the reflected class

		for mprop in mprops do
			var mprop_decl = mprop.c_meta_declaration
			v.require_declaration("{mprop_decl},")
			v.add_decl("(propinfo_t*)&{mprop_decl},")
		end
		v.add_decl("\}")
		self.is_saved = true
	end

	redef fun compile_metatag_to_c(v: AbstractCompilerVisitor)
	do
		var tag = 0x00000000
		var metakind = 0 # it's a class kind, nothing to do
		var mmodule = v.compiler.mainmodule
		var arity = mclass.mparameters.length
		var mproperties = mclass.collect_accessible_mproperties(mmodule, null)
		var kind = classkind_to_int(mclass.kind)
		var visibility = visiblity_to_int(mclass.visibility)
		tag = tag | metakind # 3 bits
		tag = tag | (arity << 3) # 7 bits => 3 + 7 = 10
		tag = tag | (kind << 10) # 3 bits => 10 + 3 + 13
		tag = tag | (visibility << 13) # 1 bits => 13 + 2 = 15
		tag = tag | (mproperties.length << 15)
		v.add_decl("{tag};")
	end
end

redef class MProperty
	super SavableMEntity

	fun commun_metatag: Int
	do
		var tag = 0x00000000
		var metakind = 0 # we don't know yet
		var visibility = visibility_to_int(mproperty.visibility)
		var qualifier =  0
		if mproperty.is_abstract then qualifier = 1
		if mproperty.is_intern then qualifier = 2
		if mproperty.is_extern the qualifier = 3

		tag = tag | metakind
		tag = tag | (visiblity << 3)
		tag = tag | (qualifier << 5)
		return tag
	end
end

redef class MAttribute

	fun mclass do return self.intro_mclassdef.mclass

	redef fun save(v)
	do
		v.require_declaration(mclass.c_meta_declaration)
		v.provide_declaration(c_meta_declaration)
	end

	redef fun c_meta_declaration
	do
		# FIXME: check for better naming convention
		return "instance_AttributeInfo_{mclass.c_name}_{self.name}"
	end

	redef fun compile_metatag_to_c(v)
	do
		var tag = self.commun_metatag
		var metakind = 2
		tag = tag | metakind
		v.add_decl("{tag};")
	end
end

redef class MMethod

	redef fun c_meta_declaration
	do
		var mclass = self.intro_mclassdef.mclass
		# FIXME: check for better naming convention
		return "instance_MethodInfo_{mclass.c_name}_{self.name}"
	end

	redef fun compile_metatag_to_c(v)
	do
		var tag = self.commun_metatag
		var metakind = 3
		var intro = mmethod.mpropdefs.first
		var msignature = intro.msignature
		var arity = 0
		var has_return = if msignature?.return_mtype != null then 1 else 0
		if msignature != null then
			arity = msignature.mparameters.length
			assert arity <= 127
		end
		tag = tag | metakind
		tag = tag | (arity << 3)
		tag = tag | (has_return << 10)
		v.add_decl("{tag};")
	end
end

redef class MVirtualTypeProp

	redef fun c_meta_declaration
	do
		var mclass = self.intro_mclassdef.mclass
		# FIXME: check for better naming convention
		return "instance_VirtualTypeInfo_{mclass.c_name}_{self.name}"
	end

	redef fun compile_metatag_to_c(v)
	do
		var tag = self.commun_metatag
		var metakind = 4
		tag = tag | metakind
		v.add_decl("{tag};")
	end
end

private fun visibility_to_int(visibility: MVisibility): Int
do
	if visibility == public_visibility return 0
	if visibility == protected_visibility return 1
	if visibility == private_visibility return 2
end

private fun classkind_to_int(kind: MClassKind): Int
do
	if kind == concrete_kind return 0
	if kind == abstract_kind return 1
	if kind == interface_kind return 2
	if kind == enum_kind return 3
	if kind == extern_kind return 4
	if kind == subset_kind return 5
end
