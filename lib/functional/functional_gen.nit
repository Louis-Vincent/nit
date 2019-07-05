redef class Writer
        fun writeln(s: Text)
        do
                write(s + "\n")
        end
end

fun gen_generics(nargs: Int): Array[String]
do
        var args = new Array[String]
        for i in [0..nargs[ do
                args.push("A" + i.to_s)
        end
        return args
end


class FunTypeWriter
        var name: String
        var supers: SequenceRead[String]
        var nb_formal_types: Int
        var with_return = false
        var annotation = "is abstract"

        fun write(writer: Writer)
        do
                var i = nb_formal_types
                var generics = gen_generics(i)
                var formal_types = generics.join(",")
                if with_return then
                        generics.push("RESULT")
                end
                writer.write("interface {name}{i}")
                writer.writeln("[" + generics.join(",") + "]")
                for zuper in supers do
                        writer.write("super {zuper}")
                end
                var output = ""
                if with_return then
                        output = generics.pop
                end
                var params = new Array[String]
                for g in generics do
                        params.push(g.to_lower + ": " + g)
                end
                var signature = params.join(",")
                if i == 0 then
                        writer.write("fun call")
                else
                        writer.write("fun call(" + signature + ")")
                end
                if with_return then
                        writer.write(": {output}")
                end
                writer.writeln(" {annotation}")
                writer.writeln("end")
        end

end


fun generate_functypes(n: Int, writer: Writer)
do
        writer.writeln("module functional")

        writer.writeln("interface Fun")
        writer.writeln("end")

        writer.writeln("abstract class Closure")
        writer.writeln("private var native_closure: NativeClosure")
        writer.writeln("end")

        for i in [0..n[ do
                var funwriter = new FunTypeWriter("Fun", ["Fun"], i)
                funwriter.with_return = true
                funwriter.write(writer)

                var procwriter = new FunTypeWriter("Proc", ["Fun"], i)
                procwriter.write(writer)
        end
end

var fw = new FileWriter.open("functional.nit")
generate_functypes(20, fw)
