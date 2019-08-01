# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2019 Louis-Vincent Boudreault <lv.boudreault95@gmail.com>
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

# Lambda modelization (objectifying lambda expressions)
# The main idea : wherever there's a lambda expr, a singleton class
# is created. Each lambda in the same method definition will share the
# same instance. This ensure a unique capture, reduce memory fragmentation
# and is simple to implements.

# At the typing phase, every lambda create a new `MClassDef`. These will be
# fuse together, their name is gonna be mangled and added to the Model.
module lambda

import mmodule
import typing

redef class ToolContext
        var lambda_modelize_phase: Phase = new LambdaModelizePhase(self, [typing_phase])
end

private class LambdaModelizePhase
        super Phase
        redef fun process_npropdef(npropdef) do npropdef.do_lambda_modelize(toolcontext.modelbuilder)
end

private class LambdaBuilder

        # Where the final lambda class will be created.
        # WARNING you must be careful where to create the lambda,
        # because the it will be private visibility.
        var mmodule: MModule

        # In which entity the lambda expr has been created (Scopish).
        # There's only two scenario : inside a classdef or methoddef.
        var mentity: MEntity


        # The class to build
        var mclass: MClass is noinit

        # The associated definition to build
        var mclassdef: MClassDef is noinit
        var name: String is noinit

        init
        do
                var kind = concrete_kind
                var visibility = private_visibility
                # TODO: add name manglin
                name = "{mmodule.name}__{mentity.name}__lambda"
                mclass = new MClass(mmodule, name, mentity.location, ??, kind, visibility)
        end

        # Used for renaming (preventing name-collision in lambda capture)
        protected var variable2name: Map[Variable, String] = new HashMap[Variable, String]

        # Captures and return the new name of the variable, avoiding any name
        # collision of different variable.
        #
        # ~~~~nitish
        # fun toto(x: Int): Proc0
        # do
        #       if x < 10 then
        #               var y = x + 10
        #               return fun() do print "y the Int says: {y}"
        #       else
        #               var y = "I love name collision"
        #               retyrn fun() do print "y the String says: {y}"
        #       end
        # end
        # ~~~~
        # This example will produce the following lambda class:
        #
        # ~~~~nitish
        # class Lambda__toto
        #       var if_true_y: Int
        #       var else_y: String
        #       fun if_proc0 do print "y the Int says: {if_true_y}"
        #       fun else_proc0 do print "y the String says: {else_y}"
        # end
        # ~~~~
        #
        # If the variable has already been mangled the same `String` is returned:
        #
        # ~~~~nitish
        # var x = new Variable(...)
        # var new_name1 = builder.capture_variable(x)
        # var new_name2 = builder.capture_variable(x)
        # assert new_name1 == new_name2
        # ~~~~
        fun capture_variable(variable: Variable): String
        do
        end

        # Produces a new method definition based on the provided signature
        fun add_method(msignature: MSignature): nullable MMethodDef
        do
                return null
        end
end

private class LambdaVisitor
        super Visitor
        var modelbuilder: ModelBuilder

        # The analyzed method definition
        var mmethoddef: MMethodDef

        # Keep the number of lambda expression visited.
        # Used to name each lambda.
        private var lambda_cnt = 0

        redef fun visit(node)
        do
                node.accept_lambda_modelize(self)
                node.visit_all(self)
        end

        fun add_lambda(mclassdef: MClassDef)
        do
                scopes.first.add_lambda(mclassdef)
        end

        # Fuse and create a singleton class containing
        # all the lambda expressions.
        fun fuse
        do
        end
end


redef class APropdef
        fun do_lambda_modelize(modelbuilder: ModelBuilder)
        do
        end
end


redef class AMethPropdef
        redef fun do_lambda_modelize(modelbuilder)
        do
                var v = new LambdaVisitor(modelbuilder, mpropdef)
        end
end


redef class ANode
        protected fun accept_lambda_modelize(v: LambdaVisitor) do end
end

redef class ALambdaClass
        redef fun accept_lambda_modelize(v)
        do
        end
end
