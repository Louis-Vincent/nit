# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2019-2020 Louis-Vincent Boudreault <lv.boudreault95@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Code generator for `Routine` type hierarchy, this code is really bad

redef class Writer
        var tabs = 0

        fun writeln(s: Text)
        do
                for t in [0..tabs[ do
                        write("\t")
                end
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
        var class_kind: String
        var name: String
        var supers: SequenceRead[String]
        var nb_formal_types: Int
        var with_return = false
        var is_redef = false
        var annotation = "is abstract"

        fun write(writer: Writer)
        do
                var i = nb_formal_types
                var generics = gen_generics(i)
                if with_return then
                        generics.push("RESULT")
                end
                writer.write("{class_kind} {name}{i}")
                writer.writeln("[" + generics.join(",") + "]")
                writer.tabs += 1
                for zuper in supers do
                        writer.writeln("super {zuper}")
                end
                writer.tabs -= 1
                var output = ""
                if with_return then
                        output = generics.pop
                end
                var params = new Array[String]
                for g in generics do
                        var param = g.to_lower
                        if not is_redef then
                                param += ": {g}"
                        end
                        params.push(param)
                end

                var signature = params.join(",")
                if is_redef then
                        writer.write("\tredef ")
                else
                        writer.write("\t")
                end
                if i == 0 then
                        writer.write("fun call")
                else
                        writer.write("fun call(" + signature + ")")
                end
                if with_return and not is_redef then
                        writer.write(": {output}")
                end
                writer.writeln(" {annotation}")
                writer.writeln("end")
        end

end


fun generate_functypes(n: Int, writer: Writer)
do
        writer.writeln("""
# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2019-2020 Louis-Vincent Boudreault <lv.boudreault95@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file is automatically generated.
""")
        writer.writeln("module functional_types")

        writer.writeln("interface Routine")
        writer.writeln("end")

        writer.writeln("interface Fun")
        writer.tabs += 1
        writer.writeln("super Routine")
        writer.tabs -= 1
        writer.writeln("end")

        writer.writeln("interface Proc")
        writer.tabs += 1
        writer.writeln("super Routine")
        writer.tabs -= 1
        writer.writeln("end")

        writer.writeln("universal RoutineRef")
        writer.writeln("end")

        for i in [0..n[ do
                var funwriter = new FunTypeWriter("interface", "Fun", ["Fun"], i)
                funwriter.with_return = true
                funwriter.write(writer)
        end

        for i in [0..n[ do
                var procwriter = new FunTypeWriter("interface", "Proc", ["Proc"], i)
                procwriter.write(writer)
        end

        # universal `FunRef`
        for i in [0..n[ do
                var generics = gen_generics(i)
                generics.push("RESULT")
                var zuper =  "Fun{i}[{generics.join(",")}]"
                var funrefwriter = new FunTypeWriter("universal", "FunRef", [zuper, "RoutineRef"], i)
                funrefwriter.with_return = true
                funrefwriter.is_redef = true
                funrefwriter.annotation = "is intern"
                funrefwriter.write(writer)
        end

        # universal `ProcRef`
        for i in [0..n[ do
                var zuper = "Proc{i}"
                if i > 0 then
                        zuper =  "Proc{i}[{gen_generics(i).join(",")}]"
                end
                var procrefwriter = new FunTypeWriter("universal", "ProcRef", [zuper, "RoutineRef"], i)
                procrefwriter.annotation = "is intern"
                procrefwriter.is_redef = true
                procrefwriter.write(writer)
        end
end

var fw = new FileWriter.open("functional_types.nit")
generate_functypes(20, fw)
