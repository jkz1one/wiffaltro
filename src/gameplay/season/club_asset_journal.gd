extends RefCounted
## Shared journal contracts. Domain authority and mixed-state mutation remain in the ledger.
const ValueContract = preload("res://src/gameplay/season/club_value_contract.gd")


static func keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key: String in allowed:
		if not value.has(key):
			return false
	return true


static func same(a: Variant, b: Variant) -> bool:
	return (
		JSON.parse_string(JSON.stringify(a, "", true, true))
		== JSON.parse_string(JSON.stringify(b, "", true, true))
	)


static func valid_credits(value: Variant) -> bool:
	if not value is Array or value.size() > 1024:
		return false
	for credit: Variant in value:
		if not ValueContract.whole(credit, 0, 1000000):
			return false
	return true


static func income(credits: Array, through: int) -> int:
	var total: int = 0
	for index in range(through):
		total += credits[index]
	return total


static func normalize_request(command: Dictionary, fields: Array, maximum: int) -> Dictionary:
	if (
		not keys(command, fields)
		or not command.id is String
		or command.id.is_empty()
		or command.id.length() > 120
		or not ValueContract.whole(command.rev, 0, maximum)
	):
		return error("Invalid permanent-asset request.")
	var event: Dictionary = command.duplicate(true)
	event.rev = int(event.rev)
	return {"ok": true, "event": event}


static func normalize_income(event: Dictionary, credits: Array) -> Dictionary:
	if (
		not ValueContract.whole(event.through, 0, credits.size())
		or not ValueContract.whole(event.price_version, 1, 1000000)
	):
		return error("Invalid earned-income or price version.")
	event.through = int(event.through)
	event.price_version = int(event.price_version)
	return {}


static func request_status(
	event: Dictionary, requests: Dictionary, revision: Callable, maximum: int
) -> Dictionary:
	if requests.has(event.id):
		return (
			{"ok": true, "replayed": true, "error": ""}
			if same(requests[event.id], event)
			else error("Request ID already used differently.")
		)
	if event.rev != revision.call() or revision.call() >= maximum:
		return error("Permanent-asset request is stale or full.")
	return {"ok": true, "replayed": false, "error": ""}


static func append(events: Array, requests: Dictionary, event: Dictionary) -> void:
	events.append(event.duplicate(true))
	requests[event.id] = event.duplicate(true)


static func serialized_events(events: Array) -> Array:
	return events.duplicate(true)


static func valid_header(
	value: Dictionary, fields: Array, seed_value: int, catalog_signature: Callable,
	maximum_version: int, maximum_events: int
) -> bool:
	if not keys(value, fields):
		return false
	return not (
		not ValueContract.whole(value.version, 1, maximum_version)
		or not ValueContract.whole(value.seed, 0, 2147483647)
		or value.seed != seed_value
		or not value.catalog is String
		or value.catalog != catalog_signature.call()
		or not value.events is Array
		or value.events.size() > maximum_events
	)


static func replay(
	events: Array, header: Dictionary, validate_event: Callable, commit: Callable
) -> bool:
	# No default validator: missing domain authority must never become acceptance.
	if not validate_event.is_valid() or not commit.is_valid():
		return false
	for event: Variant in events:
		if not event is Dictionary:
			return false
		if not validate_event.call(header, event):
			return false
		var applied: Dictionary = commit.call(event)
		if not applied.ok or applied.replayed:
			return false
	return true


static func error(message: String) -> Dictionary:
	return {"ok": false, "replayed": false, "error": message}
