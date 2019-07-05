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

# Code generator for `Routine` type hierarchy

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
                        params.push(g.to_lower + ": " + g)
                end

                var signature = params.join(",")
                if i == 0 then
                        writer.write("\tfun call")
                else
                        writer.write("\tfun call(" + signature + ")")
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

        for i in [0..n[ do
                var funwriter = new FunTypeWriter("Fun", ["Fun"], i)
                funwriter.with_return = true
                funwriter.write(writer)
        end

        for i in [0..n[ do
                var procwriter = new FunTypeWriter("Proc", ["Proc"], i)
                procwriter.write(writer)
        end
end

var fw = new FileWriter.open("functional_types.nit")
generate_functypes(20, fw)
