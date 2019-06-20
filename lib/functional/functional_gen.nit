
fun intercalate(xs: Array[String], e: String): String
do
        var res = ""
        for i in [0..xs.length[ do
                res += xs[i]
                if i != xs.length - 1 then
                        res += e    
                end
        end 
        return res
end


fun gen_generics(nargs: Int): Array[String]
do
        var args = new Array[String]
        for i in [0..nargs[ do
                args.push("A" + i.to_s)
        end
        args.push("RESULT") 
        return args
end


fun generate_functypes(n: Int, writer: Writer) 
do
        writer.write("module functional")
    
        writer.write("\ninterface Func")
        writer.write("\nend")

        writer.write("\nclass Unit")
        writer.write("\nend")     
        for i in [0..n[ do
                # defn
                var generics = gen_generics(i)
                if i == 0 then
                        writer.write("\ninterface ConstFn")
                else
                        writer.write("\ninterface Func" + i.to_s)
                end
                writer.write("[" + intercalate(generics, ",") + "]") 
                writer.write("\n\tsuper Func") 
                # body\
                var output = generics.pop
                for j in [0..generics.length[ do
                        var g = generics[j]
                        g = g.to_lower + ": " + g
                        generics[j] = g
                end
                if i == 0 then
                        writer.write("\n\tfun call: ")
                else
                        writer.write("\n\tfun call(" + intercalate(generics, ",") + "):") 
                end
                writer.write(output + " is abstract")

                # end
                writer.write("\nend")
        end
end

var fw = new FileWriter.open("functional.nit")
generate_functypes(20, fw)

