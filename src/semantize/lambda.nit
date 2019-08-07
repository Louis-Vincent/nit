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
# same instance to ensure a unique capture.

# A new lambda class should be created when:
#       1. A lambda expression in an attribute definition (not implemented)
#       2. A lambda expression inside a method definition (half implemented)
#       3. A lambda inside another lambda (half implemented)
#       4. A for loop with a lambda in its body (not implemented)
#
# ~~~~nitish
# class A
#       var f = fun(x: Int) do return x end     # case 1
#
#       fun my_method
#       do
#               var g = fun(x: Int) do return x + 1 end # case 2
#
#               var h = fun(x: Int) do
#                       var t = fun(y: Int) do x += y end # case 3
#                       t(4)
#               end
#               for i in [0..10[ do
#                       var w = fun(x: Int) do return x + i end # case 4
#               end
#       end
# end
# ~~~~
module lambda

import model_base
import mmodule
import typing
import astbuilder
intrude import modelize

redef class ToolContext
        var lambda_modelize_phase: Phase = new LambdaModelizePhase(self, [typing_phase])
end

private class LambdaModelizePhase
        super Phase
        var lambda_name_gen = new LambdaNameGen
        var lambda_classes = new Array[AStdClassdef]
        redef fun process_npropdef(npropdef)
        do
                var res = npropdef.do_lambda_modelize(toolcontext.modelbuilder, lambda_name_gen)
                lambda_classes.add_all(res)
        end

        redef fun process_nmodule_after(nmodule)
        do
                var unsafe = new UnsafeModelBuilder(toolcontext.modelbuilder, nmodule)
                for nclassdef in lambda_classes do
                        unsafe.build_a_mclassdef_inheritance(nclassdef)
                        nclassdef.mclassdef.add_in_hierarchy
                        var mclass = nclassdef.mclassdef.mclass
                        var mclassdef = nclassdef.mclassdef.as(not null)
                        unsafe.mclassdef2nclassdef(mclassdef, nclassdef)
                        unsafe.mclass2nclassdef(mclass, nclassdef)
                        for obj in nclassdef.n_propdefs do
                                var nmethdef = obj.as(AMethPropdef)
                                var mpropdef = nmethdef.mpropdef.as(not null)
                                unsafe.mpropdef2npropdef(mpropdef, nmethdef)
                        end
                        unsafe.process_default_constructors(nclassdef)
                end

                lambda_classes.clear
        end
end

class LambdaNameGen
        protected var count = 0
        fun next: String
        do
                return "Lambda__Object__<>__{count}"
        end
end

class LambdaBuilder

        # Where the final lambda class will be created.
        # WARNING you must be careful where to create the lambda,
        # because the it will be private visibility.
        var mmodule: MModule

        # Where the lambda is requested
        var location: Location

        var name: String

        # The class to build
        var mclass: MClass is protected writable, noinit

        # The associated definition to build
        var mclassdef: MClassDef is protected writable, noinit

        protected var ast_builder: ASTBuilder is noinit
        protected var mpropdef2node: Map[MPropDef, APropdef] = new HashMap[MPropDef, APropdef]
        protected var variable_count = 0
        protected var method_count = 0

        # Used for renaming (preventing name-collision in lambda capture)
        protected var variable2name: Map[Variable, MAttributeDef] = new HashMap[Variable, MAttributeDef]

        # This function is equivalent to a real init, except it should be done
        # lazely. Otherwise, we would create a lambda each time we enter a `AMethPropdef`.
        protected fun init_class
        do
                var kind = concrete_kind
                var visibility = public_visibility
                # TODO: add name manglin
                mclass = new MClass(mmodule, name, location, null, kind, visibility)
                mclassdef = new MClassDef(mmodule, mclass.mclass_type, location)
                ast_builder = new ASTBuilder(mmodule, mclass.mclass_type)
        end

        # Captures and return the attribute of the variable, avoiding any name
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
        # This example will produce the following lambda(ish) class:
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
        # If the variable has already been added to the class model the same
        # attribute is returned:
        #
        # ~~~~nitish
        # var x = new Variable(...)
        # var attr1 = builder.capture_variable(x)
        # var attr2 = builder.capture_variable(x)
        # assert attr1.is_same_instance(attr2)
        # ~~~~
        #fun capture_variable(variable: Variable): MAttributeDef
        #do
        #        # TODO: free variable capture isn't complete
        #        # Currently, this function is never called since scope phase
        #        # prevents from capturing free variables.
        #        if variable2name.has_key(variable) then
        #                return variable2name[variable]
        #        end
        #        var new_name = "instance__<>__var{variable_count}"
        #        var mprop = new MAttribute(mclassdef, "_" + new_name, location, private_visibility)
        #        var mpropdef = new MAttributeDef(mclassdef, mprop, location)
        #        mpropdef.static_mtype = variable.declared_type
        #        var mreadprop = new MMethod(mclassdef, new_name, location, public_visibility)
        #        var mwriteprop = new MMethod(mclassdef, new_name + "=", location, public_visibility)
        #        var mreadpropdef = new MMethodDef(mclassdef, mreadprop, location)
        #        var mwritepropdef = new MMethodDef(mclassdef, mwriteprop, location)
        #        mreadprop.getter_for = mprop
        #        mwriteprop.setter_for = mprop
        #        variable_count += 1
        #        variable.lambda_mattributedef = mpropdef
        #        return mpropdef
        #end

        # Produces a new method definition
        fun add_method(body: AExpr, nsignature: ASignature, msignature: MSignature): AMethPropdef
        do
                # Lazily build mclass and mclassdef iff client request to add a method.
                if not isset _mclass then init_class
                var mprop = new MMethod(mclassdef, "routine_<>_{method_count}", location, public_visibility)
                var mpropdef = new MMethodDef(mclassdef, mprop, location)
                mpropdef.msignature = msignature
                var nmethdef = ast_builder.make_method(null, null, mpropdef, nsignature, null, null, null, body)
                mpropdef2node[mpropdef] = nmethdef
                return nmethdef
        end


        fun finish: nullable AStdClassdef
        do
                if not isset _mclass then return null
                var propdefs = mpropdef2node.values
                var res = ast_builder.make_stdclass(mclassdef, null, null, null, null, new Array[Object], null, propdefs)
                res.location = location
                return res
        end
end

class NullableANode
        super ANode
end

class LambdaVisitor
        super Visitor
        var modelbuilder: ModelBuilder

        # The module where to create lambda classes
        var mmodule: MModule

        # The analyzed method definition
        var mentity: MEntity

        var name_gen: LambdaNameGen

        # The abstract node who needs a closure
        var node: ANode = new NullableANode

        # All class definition generated by visited nodes.
        var nclassdefs = new Array[AStdClassdef] is protected writable

        # The lambda class builder
        protected var lambda_builder_cache: nullable LambdaBuilder is noinit

        protected var scopes = new Array[LambdaBuilder]

        fun lambda_builder: LambdaBuilder
        do
                return scopes.last
        end

        redef fun visit(node)
        do
                node.accept_lambda_modelize(self)
        end

        fun enter_visit_block(caller: ANode, node_to_visit: ANode)
        do
                var saved = self.node
                self.node = caller
                var lb = new LambdaBuilder(mmodule, node_to_visit.location, name_gen.next)
                scopes.unshift lb
                enter_visit(node_to_visit)
                shift_scope
                self.node = saved
        end

        protected fun shift_scope
        do
                var lb = scopes.shift
                var res = lb.finish
                if res != null then
                        nclassdefs.add(res)
                end
        end
end


redef class APropdef
        fun do_lambda_modelize(modelbuilder: ModelBuilder, name_gen: LambdaNameGen): Array[AStdClassdef]
        do
                return new Array[AStdClassdef]
        end
end


redef class AMethPropdef
        redef fun do_lambda_modelize(modelbuilder, name_gen)
        do
                var mpropdef = self.mpropdef
                var n_block = self.n_block
                if n_block == null then return super
                assert mpropdef != null
                var v = new LambdaVisitor(modelbuilder, mpropdef.mclassdef.mmodule, mpropdef, name_gen)
                v.enter_visit_block(self, n_block)
                return v.nclassdefs
        end
end


redef class ANode
        protected fun accept_lambda_modelize(v: LambdaVisitor)
        do
                visit_all(v)
        end
end

redef class ALambdaExpr
        var invoker: ANode is noinit
        var nmethoddef: AMethPropdef is noinit
        redef fun accept_lambda_modelize(v)
        do
                print "ENTER ALambdaExpr::accept_lambda_modelize"
                var n_expr = self.n_expr
                if n_expr == null then return
                nmethoddef = v.lambda_builder.add_method(n_expr, n_signature, msignature)
                invoker = v.node
                for free_var in free_variables do
                        #v.lambda_builder.capture_variable(free_var)
                end
                v.enter_visit_block(self, n_expr)
        end
end


redef class Variable
        # not null if this variable is used by a lambda function.
        # The associate lambda class attribute
        var lambda_mattributedef: nullable MAttributeDef
end
