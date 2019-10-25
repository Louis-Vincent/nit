
interface Descriptor
end

universal PropertyIterator
	super Iterator[PropertyDescriptor]
end

universal ParentIterator
	super Iterator[TypeDescriptor]
end

universal TypeDescriptor
	super Descriptor

	fun properties: PropertyIterator is intern
	fun supers:
end

interface PropertyDescriptor
	super Descriptor

	fun owner: TypeDescriptor is intern
end

universal MethodDescriptor
	super PropertyDescriptor
end

universal AttributeDescriptor
	super PropertyDescriptor
end

universal VirtualTypeDescriptor
	super PropertyDescriptor
end

universal ModelRepository
end
