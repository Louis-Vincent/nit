import semantize::class_macro

class Logger
        super MetaClass

        redef fun transform
        do
                print "in Logger::tranform"
        end
end

class Point
        is meta(Logger)
        var x: Int
        var y: Int

        fun dist_x(p: Point): Int do return (p.x - x).abs
        fun toto: Int
        do
                for i in [0..10[ do return 10
                for i in [0..10[ do
                        var z = 10 + 20
                        var w = 20 + 20

                        if z + w > 1000 then return 100

                        if x + 100 > 2000 then
                                return 11
                        end
                        return 10
                end
                return 1
        end
end

abort
