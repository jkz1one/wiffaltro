extends RefCounted
## Test-only passthrough observation of already-returned plain setup diagnostics.
## No admission object is received, read, retained or mutated. No await/callback.
static var _records: Array[Dictionary] = []
static var _calls: int = 0
static var _bookkeeping_usec: int = 0


static func capture(slot: String, returned: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	_records.append({"slot": slot, "returned": returned.duplicate(true)})
	_calls += 1
	_bookkeeping_usec += Time.get_ticks_usec() - started
	return returned


static func snapshot() -> Dictionary:
	return {"schema": "AC02-SETUP-RETURN-DIAGNOSTICS-v1", "calls": _calls,
		"bookkeeping_usec": _bookkeeping_usec, "records": _records.duplicate(true)}
