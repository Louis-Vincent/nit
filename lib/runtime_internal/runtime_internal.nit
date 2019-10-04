# Expose low level information of the current program.
# This module enables the user to manipulate runtime entities such as class or
# type but in a really opaque/symbolic way. This module is not for metaprogramming,
# however, it provides an entry point to build more complex librairies like a
# reflection API.
module runtime_internal
import symbol2
import functional

redef class Sys
	var nmodel: NativeModel is noinit
	init
	do
		# TODO: load model + load symbols table
	end
end

# Represents a runtime Type
universal Type
	super Symbolic

	fun types: SequenceRead[Type] is intern

	redef fun symbol is intern
	redef fun ==(o) do return o isa Type and native_equals(o)
	private fun native_equals(o: Type): Bool is intern
end

# Represents a runtime Class
universal Klass
	super Symbolic
	redef fun symbol is intern

	redef fun ==(o) do return o isa Klass and native_equals(o)
	private fun native_equals(o: Klass): Bool is intern
end

# Represents a runtime Method
universal Method
	super Symbolic
	redef fun symbol is intern
	fun ref: Routine is intern
end

# Facade to access model information during runtime.
# This interface is rudimentary and is used for building richer
# API.
universal NativeModel
	# Returns the class of the corresponding symbol `s`
	fun sym2class(s: Symbol): nullable Klass is intern

	# Returns the type of the corresponding symbol `ty`
	fun sym2type(ty: Symbol): nullable Type is intern

	fun isa_type(sym: Symbolic): Bool is intern
	do
		return sym2type(sym.to_sym) != null
	end

	fun isa_class(sym: Symbolic): Bool is intern
	do
		return sym2class(sym.to_sym) != null
	end

	# Subtype test between two `Type`.
	fun t1_isa_t2(t1: Type, t2: Type): Bool is intern

	# Returns the class of a type
	fun type2class(ty: Type): Klass is intern

	# Returns the class of a living object.
	fun classof(object: Object): Klass is intern

	# Returns the type of a living object.
	fun typeof(object: Object): Type is intern

	# Returns the method symbolized by `sym` in the class `klass`
	fun method(sym: Symbol, klass: Klass): nullable Method is intern
end
