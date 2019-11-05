
redef class Sys
	fun type_repo: TypeRepo is intern
end

interface RuntimeInfo
end

universal TypeInfo
	super RuntimeInfo
	fun is_generic: Bool is intern
	fun is_interface: Bool is intern
	fun is_abstract: Bool is intern
	fun is_universal: Bool is intern
	fun is_derived: Bool is intern
	fun is_type_param: Bool is intern
	fun is_stdclass: Bool
	do
		return not is_abstract and not is_universal and not is_interface
	end

	fun supertypes: Iterator[TypeInfo] is intern, expect(not is_type_param)
	fun properties: Iterator[PropertyInfo] is intern, expect(not is_type_param)
	fun is_nullable: Bool is intern
	fun as_nullable: TypeInfo is intern
	fun type_param_bounds: SequenceRead[TypeInfo] is intern, expect(is_generic)
	fun type_arguments: SequenceRead[TypeInfo] is intern, expect(is_derived)
	fun resolve(args: Array[TypeInfo]): TypeInfo is intern, expect(is_generic)
	fun iza(other: TypeInfo): Bool is intern
	redef fun to_s is intern
end

interface PropertyInfo
	super RuntimeInfo
	fun parent: SELF is intern
	fun owner: TypeInfo is intern

	# Return true if `self` and `other` come from the same introduction.
	fun equiv(other: SELF): Bool
	do
		if self == other then return true
		var my = parent
		var his = other.parent
		while my != my.parent or his != his.parent do
			my = my.parent
			his = his.parent
		end
		return my == his
	end

	redef fun to_s is intern

	fun is_valid_recv(object: Object): Bool
	do
		var ty = type_repo.object_type(object)
		return ty.iza(owner)
	end
end

universal AttributeInfo
	super PropertyInfo

	# Returns the static type of the current attribute anchored by a receiver.
	# This function is useful if the attribute is typed by a type parameter.
	# This function ensures the return `TypeInfo` is closed.
	fun static_type_wrecv(recv: Object): TypeInfo
	is intern, expect(is_valid_recv(recv))

	# Returns the static type of the current attribute.
	# This function is less safer than `type_info_wrecv` since it may
	# return type parameter (aka open generic type).
	fun static_type: TypeInfo is intern

	fun value(recv: Object): Object is intern
end

universal MethodInfo
	super PropertyInfo
	fun call(args: Array[nullable Object]): nullable Object is intern
end

universal VirtualTypeInfo
	super PropertyInfo
end

universal TypeRepo
	fun get_type(typename: String): nullable TypeInfo is intern
	fun object_type(obj: Object): TypeInfo is intern
end

universal TypeInfoIterator
	super Iterator[TypeInfo]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end

universal PropertyInfoIterator
	super Iterator[PropertyInfo]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end
