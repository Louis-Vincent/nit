module class_macro

import model
import auto_super_init
import parser_util
intrude import parser

redef class ToolContext
        var metafactory: MetaClassFactory is lazy do
                return new MetaClassFactory(modelbuilder)
        end
        var meta_class_hierarchy = new POSet[MetaClass]
        var meta_class_probing_phase: Phase = new MetaProbingPhase(self, [typing_phase])
        var meta_modeling_phase: Phase = new MetaModelingPhase(self, [meta_class_probing_phase])
end

redef class AClassdef
        var metaclassdefs: SequenceRead[AAnnotPropdef] is lazy do
                var res = new Array[AAnnotPropdef]
                for na in n_propdefs do
                        if na isa AAnnotPropdef and na.name == "meta" then res.add na
                end
                return res
        end
end

private class MetaProbingPhase
        redef fun process_nclassdef(nclassdef)
        do
                var mclassdef = nclasdef.mclassdef
                assert mclassdef != null
                for st in mclassdef.supertypes do
                        if st.name == "MetaClass" and name != "MetaClass" then
                                toolcontext.metafactory.build(mclassdef)
                        end
                end
        end
end

private class MetaModelingPhase
        super Phase

        redef fun process_nclassdef(nclassdef)
        do
                var mclassdef = nclassdef.mclassdef
                assert mclassdef != null
                if mclassdef.name == "Point" then
                        print "{nclassdef.metaclassdefs}"
                        print "{nclassdef.mclassdef.as(not null)}"
                        #var logger = new Logger(mclassdef, toolcontext)
                        #logger.transform
                        #var builder = new TypeBuilder(toolcontext.modelbuilder)
                        #var mc = builder.build_metatype(mclassdef)
                end
        end
end

abstract class MetaObject
        type AST: ANode
        var source: AST is noinit
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
end

class Module
        super MetaObject
end

class MetaClass
        super MetaObject

        redef type AST: AClassdef

        var parent: MetaClass is noinit
        var methods: Array[Method] is noinit

        fun transform
        do
        end
end

class NullMetaClass
        super MetaClass
end

class MetaClassFactory
        protected var modelbuilder: ModelBuilder
        protected var root: MetaClass is noinit
        protected var hierarchy = new POSet[MetaClass]
        init
        do
                root = new MetaClass
                root.parent = root
                hierarchy.add_node(root)
        end

        fun build(mclassdef: MClassDef): MetaClass
        do
                var methods = new Array[Method]
                for mpropdef in mclassdef.mpropdefs do
                        if mpropdef isa MMethodDef then
                                var npropdef = modelbuilder.mpropdef2node(mpropdef)
                                assert npropdef != null
                                # TODO: Case where AAttrproddef
                                if not npropdef isa AMethPropdef then continue
                                var method = new Method(mpropdef, npropdef)
                                methods.push(method)
                        end
                end
                var metaclass = new MetaClass
                metaclass.methods = methods
                metaclass.parent = self.root
                return metaclass
        end
end
