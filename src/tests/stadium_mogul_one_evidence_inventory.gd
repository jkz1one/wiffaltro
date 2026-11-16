extends RefCounted
## Exact dynamic readback inventory; no physics/camera/sample-selection authority.

const Evidence = preload("res://src/tests/stadium_mogul_one_evidence.gd")
const EXTENTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(700, 393)]
const RATES: Array[int] = [30, 60, 120]

var controller_only: bool = false
var expected: Dictionary = {}
var actual: Dictionary = {}
var events: Dictionary = {}
var surfaces: Dictionary = {}
var controllers: Dictionary = {}
var errors: Array[String] = []


func expect(label: String, context: Dictionary) -> void:
	for extent: Vector2i in EXTENTS:
		var key: String = pair_key(label, extent)
		if expected.has(key):
			errors.append("duplicate expected pair: " + key)
		expected[key] = context.duplicate(true)


func note_events(
	source: int, fps: int, ticks: Array, launch: String, left: bool, defense: bool
) -> void:
	var key: String = "%d:%d" % [source, fps]
	if events.has(key) or source not in range(20) or fps not in RATES:
		errors.append("duplicate or unsupported source/rate inventory: " + key)
	var unique: Array = []
	for tick: int in ticks:
		if unique.has(tick):
			errors.append("duplicate source critical tick: " + key)
		unique.append(tick)
	events[key] = {"ticks": unique, "launch": launch, "left": left, "defense": defense}


func note_surfaces(fps: int, names: Array) -> void:
	if surfaces.has(fps) or fps not in RATES:
		errors.append("duplicate or unsupported collider-rate inventory")
	surfaces[fps] = names.duplicate()


func note_controller(left: bool, defense: bool, indices: Array) -> void:
	var key: String = role_key(left, defense)
	if controllers.has(key) or indices.size() != 3 or indices[0] != 0 or indices[1] != 1:
		errors.append("invalid controller source inventory: " + key)
	controllers[key] = indices.duplicate()


func record_pair(owner: Node, images: Array[Image], label: String, context: Dictionary) -> void:
	if owner._capture_dir.is_empty():
		errors.append("native image evidence destination missing")
		owner._check(false, "native image evidence destination is required")
		return
	var extent: Vector2i = images[0].get_size()
	var key: String = pair_key(label, extent)
	if (
		actual.has(key)
		or not expected.has(key)
		or context.get("source_context") != expected.get(key)
	):
		errors.append("duplicate or undeclared actual pair: " + key)
		owner._check(false, "every actual readback has one declared identity: " + key)
		return
	var receipt: Dictionary = Evidence.save_triplet(
		images, owner._capture_dir.path_join(key), context, controller_only
	)
	actual[key] = receipt
	owner._check(
		receipt.get("ok", false), "all three native images and hash receipt retained: " + key
	)


func finish(owner: Node) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if owner._capture_dir.is_empty():
		return false
	var required: Dictionary = required_pairs()
	var complete: bool = (
		errors.is_empty() and same_keys(required, expected) and same_keys(expected, actual)
	)
	for key: String in actual:
		complete = complete and bool(actual[key].get("ok", false))
	var verified: Dictionary = Evidence.verify_inventory(
		Evidence.budget_root(owner._capture_dir.path_join("inventory")), controller_only
	)
	complete = complete and bool(verified.get("ok", false)) and _verified_keys(owner, verified)
	var verified_summary: Dictionary = verified.duplicate(true)
	for key: String in ["images", "triplet_keys", "readback_keys"]:
		verified_summary.erase(key)
	var receipt: Dictionary = {
		"kind": "AM01_EXACT_NATIVE_PAIR_INVENTORY",
		"controller_only": controller_only,
		"complete": complete,
		"errors": errors,
		"required_keys": required.keys(),
		"expected_keys": expected.keys(),
		"actual_keys": actual.keys(),
		"source_rate_events": events,
		"colliders_by_fps": surfaces,
		"controller_source_states": controllers,
		"actual_pair_count": actual.size(),
		"required_pair_count": required.size(),
		"png_formula": "3*actual_pair_count plus4 tracking-entry,8 assembly,8 lab witnesses",
		"verified_image_inventory": verified_summary
	}
	var saved: bool = Evidence.record_receipt(
		receipt, owner._capture_dir.path_join("inventory"), controller_only
	)
	print(
		"MOGUL_ONE_NATIVE_INVENTORY actual_pairs=",
		actual.size(),
		" required_pairs=",
		required.size(),
		" complete=",
		complete,
		" pngs=",
		verified.get("png_count", -1),
		" bytes=",
		verified.get("used_bytes", -1),
		" journal=",
		verified.get("journal_path", "")
	)
	return complete and saved


func _verified_keys(owner: Node, verified: Dictionary) -> bool:
	var declared: Dictionary = {}
	for key: String in actual:
		declared["triplet:" + Evidence._absolute(owner._capture_dir.path_join(key))] = true
	var journal_pairs: Array = verified.get("triplet_keys", [])
	if (
		not unique_exact(declared, journal_pairs)
		or int(verified.get("triplet_count", -1)) != actual.size()
	):
		return false
	var readbacks: Dictionary = {}
	var standalone: Dictionary = {}
	for left: bool in [false, true]:
		for extent: Vector2i in EXTENTS:
			var hand: String = "left" if left else "right"
			standalone["mogul-one-authored-entry-%s-%dx%d.png" % [hand, extent.x, extent.y]] = true
			for subject: String in ["strike_zone", "batter", "pitcher"]:
				var path: String = owner._capture_dir.path_join(
					"entry-witness-%s-%s-%dx%d" % [str(left), subject, extent.x, extent.y]
				)
				readbacks["readbacks:" + Evidence._absolute(path)] = true
	if controller_only:
		standalone.clear()
		readbacks.clear()
	var actual_standalone: Array = []
	for path: String in verified.get("standalone_paths", []):
		actual_standalone.append(path.get_file())
	if not controller_only:
		for group: Array in _optional_venue_groups():
			var found: int = 0
			for name_value: String in group:
				found += int(actual_standalone.has(name_value))
			if found not in [0, group.size()]:
				return false
			if found > 0:
				for name_value: String in group:
					standalone[name_value] = true
	return (
		unique_exact(standalone, actual_standalone)
		and unique_exact(readbacks, verified.get("readback_keys", []))
		and int(verified.get("png_count", -1)) == 3 * actual.size() + standalone.size()
	)


static func _optional_venue_groups() -> Array:
	var assembly: Array[String] = []
	var lab: Array[String] = []
	for extent: Vector2i in EXTENTS:
		for view: String in ["whole-layout", "bowl-context", "board-context", "board-detail"]:
			assembly.append("AM-01-%s-%dx%d.png" % [view, extent.x, extent.y])
		for hand: String in ["left", "right"]:
			for role: String in ["batting", "pitching"]:
				lab.append("mogul-one-field-%s-%s-%dx%d.png" % [hand, role, extent.x, extent.y])
	return [assembly, lab]


static func unique_exact(expected_keys: Dictionary, keys: Array) -> bool:
	var observed: Dictionary = {}
	for key: Variant in keys:
		if observed.has(key):
			return false
		observed[key] = true
	return same_keys(expected_keys, observed)


func required_pairs() -> Dictionary:
	var labels: Array[String] = []
	for left: bool in [false, true]:
		for defense: bool in [false, true]:
			var role: String = role_key(left, defense)
			if not controllers.has(role):
				errors.append("missing actual controller source: " + role)
				continue
			for index: int in controllers[role]:
				labels.append("mogul-one-controller-source-%s-%d" % [role, index])
	if not controller_only:
		_full_labels(labels)
	var result: Dictionary = {}
	for label: String in labels:
		for extent: Vector2i in EXTENTS:
			var key: String = pair_key(label, extent)
			if result.has(key):
				errors.append("duplicate required key: " + key)
			result[key] = true
	return result


func _full_labels(labels: Array[String]) -> void:
	for hand: String in ["left", "right"]:
		labels.append("mogul-one-static-entry-zone-" + hand)
	for source: int in range(20):
		var prior: Array = []
		for fps: int in RATES:
			var key: String = "%d:%d" % [source, fps]
			if not events.has(key):
				errors.append("missing actual source/rate events: " + key)
				continue
			var row: Dictionary = events[key]
			if row.ticks.is_empty() or (not prior.is_empty() and prior != row.ticks):
				errors.append("source critical events disagree across rates: " + key)
			prior = row.ticks
			for tick: int in row.ticks:
				labels.append(
					(
						"mogul-one-history-%s-%d-%s-%d"
						% [row.launch, fps, role_key(row.left, row.defense), tick]
					)
				)
	for fps: int in RATES:
		if not surfaces.has(fps):
			errors.append("missing actual collider inventory at%d" % fps)
		else:
			for collider: String in surfaces[fps]:
				labels.append("mogul-one-synthetic-live-faded-%d-%s" % [fps, collider])
		for control: String in ["historical-actor", "actor-only"]:
			for phase: String in ["contact", "follow-through", "settled"]:
				labels.append("mogul-one-synthetic-%s-%d-%s" % [control, fps, phase])
		for actor: String in ["batter", "bat", "pitcher", "fielder"]:
			labels.append("mogul-one-synthetic-authentic-%s-%d" % [actor, fps])


static func pair_key(label: String, extent: Vector2i) -> String:
	return "%s-%dx%d" % [label, extent.x, extent.y]


static func role_key(left: bool, defense: bool) -> String:
	return "%s-%s" % ["left" if left else "right", "defense" if defense else "offense"]


static func same_keys(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for key: Variant in a:
		if not b.has(key):
			return false
	return true


static func guards(owner: Node) -> void:
	var script: Script = load("res://src/tests/stadium_mogul_one_evidence_inventory.gd")
	var sample: RefCounted = script.new()
	sample.controller_only = true
	for left: bool in [false, true]:
		for defense: bool in [false, true]:
			sample.note_controller(left, defense, [0, 1, 15])
	var keys: Dictionary = sample.required_pairs()
	owner._check(
		keys.size() == 24 and sample.errors.is_empty(), "bounded required identities are exact"
	)
	var missing: Dictionary = keys.duplicate()
	missing.erase(missing.keys()[0])
	owner._check(not same_keys(keys, missing), "missing native pair is refused")
	var duplicate: Array = keys.keys()
	duplicate.append(duplicate[0])
	owner._check(not unique_exact(keys, duplicate), "duplicate saved path or receipt is refused")
	var extra: Dictionary = keys.duplicate()
	extra["unexpected"] = true
	owner._check(not same_keys(keys, extra), "undeclared native pair is refused")
	sample.note_controller(false, false, [0, 1, 15])
	owner._check(not sample.errors.is_empty(), "duplicate source declaration fails permanently")
	var full: RefCounted = script.new()
	for left: bool in [false, true]:
		for defense: bool in [false, true]:
			full.note_controller(left, defense, [0, 1, 15])
	for source: int in range(20):
		for fps: int in RATES:
			full.note_events(source, fps, [source * 2 + 2], "fixture%d" % source, false, false)
	for fps: int in RATES:
		full.note_surfaces(fps, ["a", "b", "c", "d", "e", "f"])
	owner._check(
		full.required_pairs().size() == 244 and full.errors.is_empty(),
		"baseline count derives from actual event and collider inventories"
	)
	for fps: int in RATES:
		full.events["0:%d" % fps].ticks.append(100)
	full.surfaces[30].append("new-collider")
	owner._check(
		full.required_pairs().size() == 252 and full.errors.is_empty(),
		"extra genuine event and collider require all8 extra pairs, never fixed244 admission"
	)
