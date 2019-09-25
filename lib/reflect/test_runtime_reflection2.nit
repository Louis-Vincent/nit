import reflection
import symbol

redef class Object

        # Ultimate to_s
        redef fun to_s
        do
                var m = new RuntimeMirror
                var im = m.reflect(self)
                var res = new Array[String]
                # fm: FieldMirror
                for fm in im.fields do
                        res.push("({fm.name}: {fm.type} = {fm.value})")
                end
                return "{im.klazz.name}'s fields = [{res.join(", ")}]"
        end
end

class Toto
        var x: Int
        fun titi(y: Int): Int
        do
                return x + y
        end

        fun incr(y: Int)
        do
                self.x += y
        end
end

class Foo
end

var m = new RuntimeMirror
var toto_class: ClassMirror = m.get_class("Toto")

var t = new Toto(1)
var im: InstanceMirror = m.reflect(im)
var mm_incr1: MethodMirror = im.method("incr")
var mm_incr2 = toto_class.method("incr")
assert mm_incr1 == mm_incr2

var mm_toto = im.method("toto")

var mim: MethodInvokerMirror = m.invoker(mm_incr1) # runtime only feature
mim.invoke(t, mm_incr1, 10)
assert t.x == 11
mim.invoke(t, mm_incr2, 100)
assert t.x == 111

var res = mim.invoke(t, mm_toto, 10)
assert res != null and res.as(Int) == 121
assert t.x == 111

var toto_constructor = im.constr
var named_constructors: Sequence[ConstrMirror] = im.named_constr()
assert named_constructors.is_empty

assert toto_constructor isa MethodMirror
assert toto_constructor.arity == 1

# Arguments type
var types: Sequence[TypeMirror] = toto_constructor.types
var int_type = m.type_str("Int")
assert types[0] == int_type

var raw: RawInstance = toto_class.new_instance()

