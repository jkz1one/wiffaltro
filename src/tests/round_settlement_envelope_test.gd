extends Node
## Wrapper traversal units only. Stub payloads are deliberately not valid saves.
## Native physical settlement remains a separate end-to-end qualification.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	_json_layers()
	_standard_layers()
	for layers: Array in [
		[], [76], [77], [78, 77], [79, 76], [80, 76],
		[81], [81, 76], [81, 78, 76], [81, 77], [81, 82], [81, 78, 82], [83, 80, 76]
	]:
		_check_layers(layers)
	for malformed: Dictionary in [
		{}, {"version": 81}, {"version": 83, "checkpoint": []},
		{"version": 81, "checkpoint": {"version": 78, "checkpoint": null}},
		{"version": 83, "checkpoint": {"version": 80, "checkpoint": {"version": 76}}},
		{"version": 81, "checkpoint": {"version": 82, "checkpoint": {"physical": []}}},
		{"version": 57, "physical": {"pending": []}}
	]:
		check(SeasonRoundSettlement._physical_payload(malformed).is_empty(),
			"missing or mistyped wrapper/physical containers refuse without indexing")
	var extra: Dictionary = _wrapped([81, 81, 78, 82])
	check(SeasonRoundSettlement._physical_payload(extra).is_empty(),
		"arbitrary repeated authority wrappers are not stripped")
	print("Round settlement envelope checks: %d, failures: %d, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _wrapped(layers: Array) -> Dictionary:
	var result: Dictionary = {"version": 57,
		"physical": {"pending": {"human": ["unit-marker"], "reports": []}}}
	for index in range(layers.size() - 1, -1, -1):
		result = {"version": layers[index], "checkpoint": result}
	return result


func _check_layers(layers: Array) -> void:
	var full: Dictionary = _wrapped(layers)
	var before: Dictionary = full.duplicate(true)
	var payload: Dictionary = SeasonRoundSettlement._physical_payload(full)
	check(not payload.is_empty(), "known physical leaf found: " + str(layers))
	if payload.is_empty():
		return
	check(ClubCareer.same(full, before), "leaf lookup itself leaves all layers unchanged")
	var pending: Dictionary = payload.physical.pending.duplicate(true)
	payload.physical.pending = {}
	check(pending.human == ["unit-marker"]
		and SeasonRoundSettlement._physical_payload(full).physical.pending.is_empty(),
		"clearing pending targets the nested payload in the full envelope")
	check(full.version == (57 if layers.is_empty() else layers[0]),
		"full authority envelope is retained for replay")
	check(SeasonSave._decode(full) == null,
		"traversal does not authorize malformed outer career/session or stub season")


func _json_layers() -> void:
	# Structural stubs only. Full envelope replay must still validate real saves.
	for layers: Array in [
		[], [76], [77], [78, 77], [79, 76], [80, 76], [80, 77],
		[81], [81, 76], [81, 78, 76], [81, 77], [81, 82], [81, 78, 82],
		[83, 80, 76], [83, 80, 77], [84, 86], [85, 84, 86],
		[87, 81, 76], [87, 81, 78, 82], [87, 83, 80, 76], [87, 85, 84, 86]
	]:
		var full: Dictionary = JSON.parse_string(JSON.stringify(_wrapped(layers)))
		var before: Dictionary = full.duplicate(true)
		check(full.version is float, "fixture exercises real JSON version type")
		var payload: Dictionary = SeasonRoundSettlement._physical_payload(full)
		check(not payload.is_empty(), "JSON physical leaf found: " + str(layers))
		if payload.is_empty():
			continue
		check(ClubCareer.same(before, full), "JSON lookup never rewrites a header")
		var pending: Dictionary = payload.physical.pending.duplicate(true)
		payload.physical.pending = {}
		check(pending.human == ["unit-marker"]
			and SeasonRoundSettlement._physical_payload(full).physical.pending.is_empty(),
			"JSON leaf retains nested mutation identity")
		check(full.version == (57 if layers.is_empty() else layers[0]),
			"JSON outer authority remains attached")
	for invalid: Variant in [true, false, -1, 0, 81.5, 85.5, 87.5, 88, INF, NAN, null, "87"]:
		var bad: Dictionary = _wrapped([87, 85, 84, 86])
		bad.version = invalid
		check(SeasonRoundSettlement._physical_payload(bad).is_empty(),
			"invalid wrapper version cannot be coerced into a known layer")
	var repeated: Dictionary = JSON.parse_string(JSON.stringify(_wrapped([87, 87, 85, 84, 86])))
	check(SeasonRoundSettlement._physical_payload(repeated).is_empty(),
		"JSON does not permit repeated authority wrappers")


func _standard_layers() -> void:
	for version: int in [88, 89]:
		for mixed: bool in [false, true]:
			var raw: Dictionary = {"version": 74, "physical": {"pending": {"marker": true}}}
			var full: Dictionary = {"version": version, "checkpoint":
				{"version": 81, "checkpoint": raw} if mixed else raw}
			full = JSON.parse_string(JSON.stringify(full))
			check(not SeasonRoundSettlement._physical_payload(full).is_empty(), "explicit Standard physical layer")
			check(SeasonSave._decode(full) == null, "Standard leaf traversal cannot authorize stub")
		for layers: Array in [[version, 87, 85, 84, 86], [version, 85, 84, 86],
			[version, version], [version, 81, 81]]:
			check(SeasonRoundSettlement._physical_payload(_wrapped(layers)).is_empty(),
				"Standard never strips closed or repeated authority layers")
