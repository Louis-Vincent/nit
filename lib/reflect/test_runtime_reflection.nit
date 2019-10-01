import runtime1

redef class Object

        # Ultimate to_s
        redef fun to_s
        do
                var m = new RuntimeMirror
                var im = m.reflect(self)
                var res = new Array[String]
                # attr: AttributeMirror
                for attr in im.attrs do
                        res.push("({attr.to_sym}: {attr.ty} = {attr.value.as(not null)})")
                end
                return "{im.klass.to_sym}'s fields = [{res.join(", ")}]"
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
var toto_class: ClassMirror = klass(sym("Toto"))

var t = new Toto(1)
var im: InstanceMirror = reflect(t)
var mm_incr1: MethodMirror = im[sym("incr")]
var mm_incr2 = toto_class.method(sym("incr"))
var mm_toto = im[sym("toto")]

# send :: Symbol -> [Object] -> nullable Object
# Send retourne null si la méthode est void, c'est ambigue avec une méthode qui
# retourne réellement un nullable Object.
# Une solution serait de retourner un objet `Some[nullable Object]`. Or, ça
# serait très verbeux. C'est pas fou non plus de délégué la tâche au programmeur
# de s'assurer du type de retour. La nature de la réflection doit sacrifier de
# la sûreté pour avoir des comportements dynamiques.
var res1: nullable Object = im.send(mm_toto.to_sym, t, 10)

assert res1 != null
assert res1.as(Int) == 11
assert t.x == 1

im[sym("incr")].send(t, 10)
assert t.x == 11

mm_incr1.send(t, 100)
assert t.x == 111

mm_incr2.send(t, 1000)
assert t.x == 1111
