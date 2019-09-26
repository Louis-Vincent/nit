import runtime1

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

var m = new RuntimeMirror
var toto_class: ClassMirror = get_class(sym("Toto"))

var t = new Toto(1)
var im: InstanceMirror = reflect(t)
var mm_incr1: MethodMirror = im.method(sym("incr"))
var mm_incr2 = toto_class.method(sym("incr"))
var mm_toto = im.method(sym("toto"))

assert mm_toto1 == mm_toto2

# send :: Symbol -> [Object] -> nullable Object
# Send retourne null si la méthode est void, c'est ambigue avec une méthode qui
# retourne réellement un nullable Object.
# Une solution serait de retourner un objet `Some[nullable Object]`. Or, ça
# serait très verbeux. C'est pas fou non plus de délégué la tâche au programmeur
# de s'assurer du type de retour. La nature de la réflection doit sacrifier de
# la sûreté pour avoir des comportements dynamiques.
var res1: nullable Object = im.send(mm_toto, 10)

assert res1 != null
assert res1.as(Int) == 11
assert t.x == 1

im.send(incr2, 10)
assert t.x == 11

mm_incr1.invoke(t, 100)
assert t.x == 111

mm_incr2.invoke(t, 1000)
assert t.x == 1111
