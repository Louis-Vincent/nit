
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
	fun owner: TypeInfo is intern

	# Return true if `self` and `other` come from the same introduction.
	fun equiv(other: SELF): Bool is intern do
		var my = self.get_linearization
		var his = other.get_linearization
		var last1 = self
		var last2 = other
		while my.is_ok or his.is_ok do
			if my.is_ok then
				last1 = my.item
				my.next
			end
			if his.is_ok then
				last2 = his.item
				his.next
			end
		end
		return last1 == last2
	end

	fun name: String is intern

	# Returns an iterator that yields the next super property in the
	# linearization order.
	fun get_linearization: Iterator[SELF] is intern

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

universal RuntimeInfoIterator[E: RuntimeInfo]
	super Iterator[E]
	redef fun is_ok is intern
	redef fun next is intern
	redef fun item is intern
end