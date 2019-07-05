import functional_types
class SumFn
        super Fun2[Int,Int,Int]

        redef fun call(x: Int, y: Int): Int
        do
                return x + y
        end
end

class MinFn[E: Comparable]
        super Fun2[E,E,E]

        redef fun call(x: E, y: E): E
        do
                if x < y then
                        return x
                end
                return y
        end
end

class InitArrayFn[E]
        super Fun0[Array[E]]

        var initial_val: nullable E

        redef fun call: Array[E]
        do
                var xs = new Array[E]
                if initial_val != null then
                        xs.push(initial_val)
                end
                return xs
        end
end

class SnakeCaseFn
        super Fun1[String,String]

        redef fun call(x: String): String
        do
                return x.to_snake_case
        end
end

class UpperCaseFn
        super Fun1[String, String]

        redef fun call(x: String): String
        do
                return x.to_upper
        end
end

class IsLetterFn
        super Fun1[Char, Bool]

        redef fun call(c: Char): Bool
        do
                return c.is_letter
        end
end

class AddOneFn
        super Fun1[Int,Int]

        redef fun call(x: Int): Int
        do
                return x + 1
        end
end

class CharsFn
        super Fun1[String, Iterator[Char]]

        redef fun call(str): Iterator[Char]
        do
                return str.chars.iterator
        end
end

class LowerThanFn
        super Fun1[Int, Bool]
        var target: Int
        redef fun call(x): Bool
        do
                return x < target
        end
end

fun sum_fn: SumFn
do
        return new SumFn
end

fun min_int_fn: MinFn[Int]
do
        return new MinFn[Int]
end


fun new_int_arr(x: nullable Int): InitArrayFn[Int]
do
        return new InitArrayFn[Int](x)
end

fun snake_case_fn: SnakeCaseFn
do
        return new SnakeCaseFn
end

fun upper_fn: UpperCaseFn
do
        return new UpperCaseFn
end

fun is_letter_fn: IsLetterFn
do
        return new IsLetterFn
end

fun add_one: AddOneFn
do
        return new AddOneFn
end

fun chars_fn: CharsFn
do
        return new CharsFn
end


fun lower_than_fn(x: Int): LowerThanFn
do
        return new LowerThanFn(x)
end
