extends PlayRecord
## Test-only serialization callback. Never creates a successful play or issued authority.
var serialize_calls: int = 0
var on_serialize: Callable


func to_dict() -> Dictionary:
	serialize_calls += 1
	if on_serialize.is_valid():
		var once: Callable = on_serialize
		on_serialize = Callable()
		once.call()
	return super.to_dict()
