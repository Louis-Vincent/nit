
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
	fun supertypes: Iterator[TypeInfo] is intern
	fun properties: Iterator[PropertyInfo] is intern
	redef fun to_s is intern
end

interface PropertyInfo
	super RuntimeInfo
	fun parent: SELF is intern
	fun owner: TypeInfo is intern
	fun equiv(other: SELF): Bool
	do
		if self == other then return true
		var my = parent
		var his = other.parent
		while my != my or his != his do
			my = my.parent
			his = his.parent
		end
		return my == his
	end
	fun lequiv(other: SELF): Bool
	do
		return false
	end

	redef fun to_s is intern
end

universal AttributeInfo
	super PropertyInfo
end

universal MethodInfo
	super PropertyInfo
	fun call(args: Array[nullable Object]): nullable Object is intern
end

universal VirtualTypeInfo
	super PropertyInfo
end

universal TypeRepo
	fun get_type(typename: String): TypeInfo is intern
	fun typeof(obj: Object): TypeInfo is intern
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
