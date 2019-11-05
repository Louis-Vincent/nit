import runtime_internals

abstract class CLI
	init
	do
		type_repo.object_type(self)
	end
end

class NitUnitCLI
	super CLI

	var warn: nullable Bool
	var quiet: nullable Bool
	var keep_going: nullable Bool
	var nitc: nullable String
	var usage = """
Usage: nitunit [OPTION]... <file.nit>...
Executes the unit tests from Nit source files.
  -W, --warn              Show additional warnings (advices)
  -w, --warning           Show/hide a specific warning
  -q, --quiet             Do not show warnings
  --keep-going            Continue after errors, whatever the consequences
  --nitc                  nitc compiler to use
"""
end
