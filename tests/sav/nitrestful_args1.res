# This file is generated by nitrestful
# Do not modify, instead refine the generated services.
module restful_annot_rest is
	no_warning("parentheses")
end

import restful_annot

redef class MyAction
	redef fun prepare_respond_and_close(request, truncated_uri, http_server)
	do
		var resources = truncated_uri.split("/")
		if resources.not_empty and resources.first.is_empty then resources.shift

		if resources.length != 1 then
			super
			return
		end
		var resource = resources.first

		if (resource == "foo") then
			var in_s = request.string_arg("s")
			var out_s = in_s

			var in_i = request.string_arg("i")
			var out_i = deserialize_arg(in_i, "Int")

			var in_b = request.string_arg("b")
			var out_b = deserialize_arg(in_b, "Bool")

			if out_s isa String and out_i isa Int and out_b isa Bool then
				var response = foo(out_s, out_i, out_b)
				http_server.respond response
				http_server.close
				return
			end
		end
		if (resource == "api_name" or resource == "alt_name") and (request.method == "GET" or request.method == "PUT") then
			var in_s = request.string_arg("s")
			var out_s = in_s

			var in_i = request.string_arg("i")
			var out_i = deserialize_arg(in_i, "nullable Int")

			var in_b = request.string_arg("b")
			var out_b = deserialize_arg(in_b, "nullable Bool")

			if out_i isa nullable Int and out_b isa nullable Bool then
				var response = bar(out_s, out_i, out_b)
				http_server.respond response
				http_server.close
				return
			end
		end
		if (resource == "async_service") then
			var in_str = request.string_arg("str")
			var out_str = in_str

			if out_str isa String then
				var task = new Task_MyAction_async_service(self, request, http_server, out_str)
				self.thread_pool.execute task
				return
			end
		end
		if (resource == "complex_args") then
			var in_array = request.string_arg("array")
			var out_array = deserialize_arg(in_array, "Array[String]")

			var in_data = request.string_arg("data")
			var out_data = deserialize_arg(in_data, "MyData")

			if out_array isa Array[String] and out_data isa MyData then
				var response = complex_args(out_array, out_data)
				http_server.respond response
				http_server.close
				return
			end
		end
		super
	end
end

# Generated task to execute MyAction::async_service
class Task_MyAction_async_service
	super RestfulTask

	redef type A: MyAction

	private var out_str: String

	redef fun indirect_restful_method
	do
		return action.async_service(out_str)
	end
end

