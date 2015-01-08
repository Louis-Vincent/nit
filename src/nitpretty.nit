# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# `nitpretty` is a tool able to pretty print Nit files.
#
# See `man nitpretty` for more infos.
import pretty

redef class ToolContext
	# The working directory used to store temp files.
	var opt_dir = new OptionString("Working directory (default is '.nitpretty')", "--dir")

	# Output pretty printed code with this filename.
	var opt_output = new OptionString("Output name (default is pretty.nit)", "-o",
	   "--output")

	# Show diff between source and pretty printed code.
	var opt_diff = new OptionBool("Show diff between source and output", "--diff")

	# Show diff between source and pretty printed code using meld.
	var opt_meld = new OptionBool("Show diff between source and output using meld",
	   "--meld")

	# Check formatting instead of pretty printing.
	#
	# This option create a tempory pretty printed file then check if
	# the output of the diff command on the source file and the pretty
	# printed one is empty.
	var opt_check = new OptionBool("Check format of Nit source files", "--check")
end

# Return result from diff between `file1` and `file2`.
private fun diff(file1, file2: String): String do
	var p = new IProcess("diff", "-u", file1, file2)
	var res = p.read_all
	p.wait
	p.close
	return res
end

# process options
var toolcontext = new ToolContext

toolcontext.option_context.
   add_option(toolcontext.opt_dir, toolcontext.opt_output, toolcontext.opt_diff,
   toolcontext.opt_meld, toolcontext.opt_check)

toolcontext.tooldescription = "Usage: nitpretty [OPTION]... <file.nit>\n" +
	"Pretty print Nit code from Nit source files."

toolcontext.process_options args
var arguments = toolcontext.option_context.rest
# build model
var model = new Model
var mbuilder = new ModelBuilder(model, toolcontext)
var mmodules = mbuilder.parse(arguments)
mbuilder.run_phases

if mmodules.is_empty then
	print "Error: no module to pretty print"
	return
end

if not toolcontext.opt_check.value and mmodules.length > 1 then
	print "Error: only --check option allow multiple modules"
	return
end

var dir = toolcontext.opt_dir.value or else ".nitpretty"
if not dir.file_exists then dir.mkdir
var v = new PrettyPrinterVisitor

for mmodule in mmodules do
	var nmodule = mbuilder.mmodule2node(mmodule)
	if nmodule == null then
		print " Error: no source file for module {mmodule}"
		return
	end
	var file = "{dir}/{mmodule.name}.nit"
	var tpl = v.pretty_nmodule(nmodule)
	tpl.write_to_file file

	if toolcontext.opt_check.value then
		var res = diff(nmodule.location.file.filename, file)

		if not res.is_empty then
			print "Wrong formating for module {nmodule.location.file.filename}"
			toolcontext.info(res, 1)

			if toolcontext.opt_meld.value then
				sys.system "meld {nmodule.location.file.filename} {file}"
			end
		else
			toolcontext.info("[OK] {nmodule.location.file.filename}", 1)
		end
	else
		# write to file
		var out = toolcontext.opt_output.value
		if out != null then sys.system "cp {file} {out}"

		# open in meld
		if toolcontext.opt_meld.value then
			sys.system "meld {arguments.first} {file}"
			return
		end

		# show diff
		if toolcontext.opt_diff.value then
			var res = diff(arguments.first, file)
			if not res.is_empty then print res
			return
		end

		# show pretty
		if not toolcontext.opt_quiet.value then tpl.write_to sys.stdout
	end
end
