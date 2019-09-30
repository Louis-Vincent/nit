# Expose low level information of the current program.
# This module enables the user to manipulate runtime entities such as class or
# type but in a really opaque/symbolic way. This module is not for metaprogramming,
# however, it provides an entry point to build more complex librairies like a
# reflection API.
module runtime
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
end

# Represents a runtime Class
universal Klass
	redef fun ==(o) do return o isa Klass and native_equals(o)
	private fun native_equals(o: Klass): Bool is intern
end

# Represents a runtime Method
universal Method
	fun ref: Routine is intern
end

# Facade to access model information during runtime.
# This interface is rudimentary and is used for building richer
# API.
universal NativeModel
	# Returns the class of the corresponding symbol `s`
	fun sym2class(s: Symbol): Klass is intern

	# Returns the type of the corresponding symbol `ty`
	fun sym2type(ty: Symbol): Type is intern

	# Returns a pointer to the class of `object`.
	fun classof(object: Object): Klass is intern

	# Returns the type of an object
	fun typeof(object: Object): Type is intern

	# Returns the method named `sym` available in the type `ty`.
	fun method_named(sym: Symbol, ty: Type): Routine is intern

	# Returns the `Int` type
	fun int_type: Type is intern

	# Returns the `Float` type
	fun float_type: Type is intern

	# Returns the `String` type
	fun string_type: Type is intern

	# Returns the `Object`  type
	fun object_type: Type is intern
end
