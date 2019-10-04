# Cache who is aware of how to build its own value.
abstract class Cache[K,V]
	super HashMap[K,V]

	# Produces a new entry for the new key `new_key`.
	protected fun new_default_entry(new_key: K): V is abstract

	fun get_or_build(key: K): V
	do
		if self.has_key(key) then
			return self[key]
		else
			var res = new_default_entry(key)
			self[key] = res
			return res
		end
	end
end


