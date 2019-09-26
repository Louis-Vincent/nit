import symbol2

redef class Sys
        var mirror: RuntimeMirror = new RuntimeMirror

        fun get_class(s: Symbol): ClassMirror
        do
                return mirror.get_class(s)
        end

        fun reflect(instance: Object): InstanceMirror
        do
        end
end

class RuntimeMirror
        super Environment
end

abstract class Mirror
        var name: String
        var mirror: Mirror
end

abstract class ClassMirror
        super Mirror

        fun method(msym: Symbol): MethodMirror is abstract
        fun field(fsym: Symbol): FieldMirror is abstract
end

class Signature
        var args: Sequence[ClassMirror]
        var return_type: nullable ClassMirror
end

abstract class MethodMirror
        super Mirror
        var signature: Signature

        fun arity: Int do return signature.args.length
end

abstract class FieldMirror
        super Mirror
        var type: ClassMirror
end

abstract class Environment
        super Mirror
end

abstract class InstanceMirror
        super Mirror
        var instance: Object

        fun method(msym: Symbol): MethodMirror
        do
                return type.method(msym)
        end
        fun send(mm: MethodMirror, args: Object...): nullable Object is abstract
end

class RTInstance
        super InstanceMirror
end

class RTMethod
end

class RTClass
        super ClassMirror
end

class RTField
        super

end
