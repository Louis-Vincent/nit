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

import test_runtime_internals_base

class Y[E]
end

redef class Z1
	super Y[String]
	redef fun p1
	do
		return "redef Z1:p1"
	end
end

class Z2
	super Z1

	redef fun p1
	do
		return "Z2:p1"
	end
end

class Z3
	super Z2

	redef fun p1
	do
		return "Z3:p1"
	end

	fun p2: String
	do
		return "Z3:p2"
	end
end

class Z4
	super Z2
end

class Z5
	super Z3
	super Z4
end
