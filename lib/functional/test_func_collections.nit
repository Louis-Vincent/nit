module test_func_collections is test

import func_collections

class AddOneRef
        super Proc1[Ref[Int]]
        redef fun call(x)
        do
                x.item += 1
        end
end


fun add_one_ref: AddOneRef
do
        return new AddOneRef
end

# test cases for `Entry` API
class TestHashMap
        test

        fun must_be_vacant is test do
                var map = new HashMap[Int,Int]
                var entry = map.entry(1)
                assert entry isa Vacant[Int,Int]
        end


        fun must_be_occupied is test do
                var map = new HashMap[Int,String]
                map[1] = "one"
                var entry = map.entry(1)
                assert entry isa Occupied[Int,String]
        end


        fun add_one_to_occupied_entry is test do
                var map = new HashMap[Int,Ref[Int]]
                map[1] = new Ref[Int](1)
                var entry = map.entry(1)
                entry.and_do(add_one_ref)
                assert map[1].item == 2
        end


        fun add_one_to_vacant_entry is test do
                var map = new HashMap[Int,Ref[Int]]
                var entry = map.entry(1)
                entry.and_do(add_one_ref)
                assert not map.has_key(1)
        end


        fun insert_ten_if_vacant is test do
                var map = new HashMap[Int,Ref[Int]]
                var entry = map.entry(1)
                entry.or_insert(new Ref[Int](10))
                assert map[1].item == 10
        end

        fun do_nothing_if_occupied is test do
                var map = new HashMap[Int,Ref[Int]]
                map[1] = new Ref[Int](1)
                var entry = map.entry(1)
                entry.or_insert(new Ref[Int](10))
                assert map[1].item == 1
        end
end
