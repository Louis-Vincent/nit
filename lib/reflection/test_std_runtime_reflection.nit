# This file is part of NIT ( http://www.nitlanguage.org ).
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

module test_std_runtime_reflection

import std_runtime_reflection

class CommandParser
	fun parse(input: String, command_type: Type): CLI
	do
		var ty = command_type
		var tBool = get_type("Bool")
		var tInt = get_type("Int")
		var tString = get_type("String")
		var tSeqRead = get_type("SequenceRead")

		var re = "(-[a-zA-Z1-9]+|--[a-zA-Z1-9]+)( *[\.\/\\_\-~a-zA-Z1-9]*)*".to_re

		var map = new HashMap[String, nullable String]
		for match in input.search_all(re) do
			var option = match.subs.first.as(not null).to_s
			var trimed_option = option
			while trimed_option.first == '-' do
				trimed_option = trimed_option.substring_from(1)
			end
			var args = match.to_s.split(option)[1]
			map[trimed_option] = if args == "" then null else args.trim
		end

		var xs = new Array[nullable Object]
		for attr in ty.declared_attributes do
			var my_type = attr.dyn_type
			var is_optional = my_type.is_nullable
			my_type = my_type.as_not_null
			assert my_type.is_primitive
			var name = attr.name
			if map.has_key(name) then
				var value = map[name]
				if my_type == tBool then
					xs.push(true)
				else if my_type == tInt then
					assert value != null
					xs.push(value)
				else if my_type == tString then
					assert value != null
					xs.push(value)
				end
			else
				if my_type == tBool then
					xs.push(false)
				else
					xs.push(null)
				end
			end
		end
		assert ty.can_new_instance(xs)
		return ty.new_instance(xs).as(CLI)
	end
end

abstract class CLI
	fun usage: String is abstract
end

class NitUnitCLI
	super CLI

	var warn: Bool
	var quiet: Bool
	var keep_going: Bool
	var nitc: nullable String
	redef fun usage
	do
		return """
Usage: nitunit [OPTION]... <file.nit>...
Executes the unit tests from Nit source files.
  -W, --warn              Show additional warnings (advices)
  -w, --warning           Show/hide a specific warning
  -q, --quiet             Do not show warnings
  --keep-going            Continue after errors, whatever the consequences
  --nitc                  nitc compiler to use
"""
	end

	redef fun to_s
	do
		return "warn: {warn}, quiet: {quiet}, keep_going: {keep_going}, nitc: {nitc or else "null"}"
	end
end

var input = "--warn --nitc ../src/nitc arg1 arg2 --quiet"
var ty = get_type("NitUnitCLI")
var cmd_parser = new CommandParser
var res = cmd_parser.parse(input, ty).as(NitUnitCLI)
assert res.warn
assert res.quiet
assert not res.keep_going
assert res.nitc == "../src/nitc arg1 arg2"
print res
