module class_macro

import model
import auto_super_init
import parser_util
intrude import parser

redef class ToolContext
        var class_macro_phase: Phase = new ClassMacroPhase(self, [typing_phase])
end

private class ClassMacroPhase
        super Phase
        redef fun process_nclassdef(nclassdef)
        do
                var mclassdef = nclassdef.mclassdef
                assert mclassdef != null
                if mclassdef.name == "Point" then
                        print "{nclassdef.mclassdef.as(not null)}"
                        #var logger = new Logger(mclassdef, toolcontext)
                        #logger.transform
                        #var builder = new TypeBuilder(toolcontext.modelbuilder)
                        #var mc = builder.build_metatype(mclassdef)
                end
        end
end

abstract class MetaObject
end

class Attribute
        super MetaObject
        var name: String
        var klass: MetaClass
end

class Method
        super MetaObject

        protected var mpropdef: MMethodDef
        protected var npropdef: AMethPropdef

        fun body: nullable AExpr
        do
                return npropdef.n_block
        end

        fun body=(aexpr: AExpr)
        do
                npropdef.n_block = aexpr
        end

        fun is_abstract: Bool
        do
                return false
        end
end

class MetaClass
        super MetaObject
        protected var mclassdef: MClassDef
        protected var toolcontext: ToolContext
        protected var methods: Array[Method] is noinit
        protected var attributes: Array[Attribute] is noinit
        protected var supers: Array[MetaClass] is noinit
        protected var modelbuilder: ModelBuilder is noinit

        init
        do
                modelbuilder = toolcontext.modelbuilder
                for mpropdef in mclassdef.mpropdefs do
                        if mpropdef isa MMethodDef then
                                var npropdef = modelbuilder.mpropdef2node(mpropdef)
                                assert npropdef != null
                                # TODO: Case where AAttrproddef
                                if not npropdef isa AMethPropdef then continue
                                var method = new Method(mpropdef, npropdef)
                                methods.push(method)
                        else if mpropdef isa MAttributeDef then
                                print "mattrdef: {mpropdef}"
                        end
                end
                supers = new Array[MetaClass]
        end

        fun add_attribute(attr: Attribute)
        do
        end

        fun add_method(method: Method)
        do
        end

        fun transform
        do
        end

        protected fun parse(source: String): ANode
        do
                return toolcontext.parse_something(source)
        end

end

#class TypeBuilder
#        protected var mb: ModelBuilder
#        fun build_metatype(mclassdef: MClassDef): Type
#        do
#                var nattrdefs = mb.collect_attr_propdef(mclassdef)
#                var nmethdefs = new Array[AMethPropdef]
#                for mpropdef in mclassdef.mpropdefs do
#                        var node = mb.mpropdef2node(mpropdef)
#                        assert node != null and node isa AMethPropdef
#                        nmethdefs.push(node)
#                end
#                return new Type(mclassdef, new Array[Attribute], new Array[Method])
#        end
#
#        protected fun build_meta_method(npropdef: AMethPropdef)
#        do
#                var mpropdef = npropdef.mpropdef
#                var params = new Array[Parameter]
#                if mpropdef.msignature != null then
#                        var msignature = mpropdef.msignature.as(not null)
#                        msignature.mparameter
#                end
#        end
#
#        protected fun build_meta_attr(npropdef: AAttrPropdef)
#        do
#        end
#end
#
#abstract class Property
#end
#
#class Attribute
#        super Property
#        protected var mpropdef: MAttributeDef
#end
#
#class Method
#        super Property
#        protected var mpropdef: MMethodDef
#        var body: nullable AExpr = null
#        var is_redef: Bool = false
#        #var return_type: nullable Type = null
#        #var is_redef: Bool = false
#        redef init
#        do
#        end
#end
#
#class Type
#        protected var mclassdef: MClassDef
#        protected var attributes: SequenceRead[Attribute]
#        protected var methods: SequenceRead[Method]
#end
