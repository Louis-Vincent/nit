import universal_instance

redef class NaiveInterpreter
	fun native_array_view(array_instance: Instance): AbstractArrayRead[Instance]
	do
		return new NativeArrayInstanceWrapper(array_instance, self)
	end
end

# This wrapper provides a safe way to manage native array instance
# since the `length` attribute of a `NativeArray` may be larger than
# its container class `Array`. This is due to the fact that `length`
# attribute is used to represents the `capacity` of an `Array` instance.
# In other words, don't manually unwrap a primitive instance whose inner type is
# `Array[Instance]` use `native_array_view` instead.
private class NativeArrayInstanceWrapper
	super AbstractArrayRead[Instance]
	private var array_instance: Instance
	private var v: NaiveInterpreter
	private var native_array: Array[Instance] is noinit

	init
	do
		var mtype = array_instance.mtype.undecorate
		assert mtype isa MClassType
		var array_class = v.mainmodule.array_class
		assert mtype.mclass == array_class
		var native_instance = v.send(v.force_get_primitive_method("items", mtype), [array_instance])
		if not native_instance isa PrimitiveInstance[Array[Instance]] then
			native_array = new Array[Instance]
		else
			native_array = native_instance.val
		end
	end

	redef fun length: Int
	do
		var mtype = array_instance.mtype
		var res = v.send(v.force_get_primitive_method("length", mtype), [array_instance])
		return res.to_i
	end

	redef fun [](index)
	do
		return native_array[index]
	end

	redef fun iterator
	do
		return new BoundedIndexedIterator[Instance](native_array.iterator, length)
	end
end

private class BoundedIndexedIterator[E]
	super IndexedIterator[E]
	private var wrapped: IndexedIterator[E]
	private var limit: Int
	redef fun is_ok
	do
		return wrapped.index < _limit
	end

	redef fun next do wrapped.next
	redef fun item do return wrapped.item
end
