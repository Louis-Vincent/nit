
interface RuntimeInfo
end

interface TypeInfo
	super RuntimeInfo
	fun supertypes: Iterator[TypeInfo]
	fun properties: Iterator[PropertyInfo]
end

interface PropertyInfo
	super RuntimeInfo

	fun parent: RuntimeProperty is abstract
	fun declared_by: RuntimeType is abstract
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
		return False
	end
end

universal AttributeInfo
	super PropertyInfo
end

universal MethodInfo
	super PropertyInfo
end

universal TypeRepo
	fun get_type(typename: String): TypeInfo is intern
	fun typeof(obj: Object): TypeInfo is intern
end
