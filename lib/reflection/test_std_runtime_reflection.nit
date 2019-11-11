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
		assert not ty isa GenericType
		var tBool = get_type("Bool")
		var tInt = get_type("Int")
		var tString = get_type("String")
		var tSeqRead = get_type("SequenceRead").as(not null)

		var re = "(-[a-zA-Z1-9]+|--[a-zA-Z1-9]+)( *[\.\/\\_\-~a-zA-Z1-9]*)*".to_re

		var map = new HashMap[String, nullable String]
		for match in input.search_all(re) do
			var option = match.subs.first.as(not null)
			var args = match.to_s.split(option.to_s)[1]
			map[option.to_s] = if args == "" then null else args
		end

		var xs = new Array[nullable Object]
		for attr in ty.declared_attributes do
			var sty = attr.static_type
			if sty.iza(tSeqRead) and sty isa DerivedType then
				assert sty.type_arguments.first.is_primitive
			else
				assert sty.is_primitive
			end
			if map.has_key(sty.name) then
				var value = map[sty.name]
				if sty == tBool then
					xs.push(true)
				else if sty == tInt then
					assert value != null
					xs.push(value)
				else if sty == tString then
					assert value != null
					xs.push(value)
				end
			else
				if sty == tBool then
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
end

var input = "--warn --nitc ../src/nitc arg1 arg2 --quiet"
var ty = get_type("NitUnitCLI").as(not null)
var cmd_parser = new CommandParser
var res = cmd_parser.parse(input, ty).as(NitUnitCLI)
print res
