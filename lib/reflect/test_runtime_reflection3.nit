import reflection::runtime

class Bataille
        var nom: String
        var annee: String
        var decisive: Bool

        redef fun to_s
        do
                return "{nom}, {annee}, {decisive}"
        end
end

fun csvinit2(ClassMirror klazz, String csv): Array[Bataille]
do
        var constr = klazz.constr
        var m = klazz.mirror
        var res = new Array[Bataille]
        for line in csv.split("\n") do
                var cols = line.split(",")
                # from_literals :: String... -> [Object]
                var args = m.from_literals(cols)
                var bataille = constr.invoke(args).as(Bataille)
                res.add(bataille)
        end
        return res
end

var csv = """
Massacre à Durlieu, 302 AC, true
Bataille de Chateau Noir, 301 AC, true
Bataille de Qohor, 100 BC, true
Bataille de Ironrath, 301 AC, false
"""

var m = new RuntimeMirror
var klazz = m.klass("Bataille")
var bs = csvinit(klazz, csv)

for b in bs do
        print b
end
