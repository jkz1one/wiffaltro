extends Node3D
## Manually invoked interface/overflow negatives; never physical chronology evidence.
# gdlint: disable=max-returns

const INVENTORY_PATH: String = "res://src/tests/helpers/pool_controller_writer_inventory_v17.json"
const FORWARDER: Script = preload("res://src/tests/helpers/pool_controller_shadow_lab.gd")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_values_and_decisions()
	_ancestry_cases()
	for label: String in [
		"reentrant", "byte_overflow", "event_overflow", "row_overflow", "wrong_return"
	]:
		await _real_forwarding(label)
	print(
		"POOL_CONTROLLER_WRITER_UNIT checks=%d failures=%d authority=false" % [_checks, _failures]
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _values_and_decisions() -> void:
	var valid: Array = [Vector3(12, 1, 18), Vector3(12.1, 1, 18), Vector3.ZERO, false, 0.0]
	_check(PoolControllerWriterLedger.numeric_domain(valid), "finite admitted mirror tuple")
	for component: int in range(3):
		for value: float in [NAN, INF, -INF, 65.0, -65.0]:
			var bad: Array = valid.duplicate()
			var point: Vector3 = bad[component]
			point.x = value
			bad[component] = point
			_check(not PoolControllerWriterLedger.numeric_domain(bad), "numeric position negative")
	for scalar: float in [NAN, INF, -INF, 1048577.0, -1048577.0]:
		var bad: Array = valid.duplicate()
		bad[4] = scalar
		_check(not PoolControllerWriterLedger.numeric_domain(bad), "fresh cooldown negative")
	for value: Variant in [null, 0, "false", Vector3.ZERO]:
		var bad: Array = valid.duplicate()
		bad[3] = value
		_check(not PoolControllerWriterLedger.numeric_domain(bad), "gate must be boolean")
	_check(PoolControllerWriterLedger.bounded_value("a".repeat(64)), "exact text limit")
	_check(not PoolControllerWriterLedger.bounded_value("a".repeat(65)), "text over limit")
	_check(not PoolControllerWriterLedger.bounded_value("é".repeat(33)), "UTF8 byte limit")
	_check(not PoolControllerWriterLedger.bounded_value({"arbitrary": true}), "no extension maps")
	var oversized: Array = []
	oversized.resize(65)
	_check(not PoolControllerWriterLedger.bounded_value(oversized), "array count quota")
	var state: Array = []
	state.resize(44)
	state[2] = false
	state[9] = false
	var wet: String = PoolControllerWriterLedger.decision(
		true, true, true, true, true, false, "", state, state
	)
	_check(wet == "CURRENT_WET_HELPER_EXCLUDED_OBSERVED", "conditional observation only")
	var cases: Array[Array] = [
		[false, true, true, true, true, false, "", state, "MIRROR_SEAL_CHANGED"],
		[true, false, true, true, true, false, "", state, "NUMERIC_DOMAIN_UNPROVEN"],
		[true, true, true, true, true, true, "", state, "PRIOR_TERMINAL"],
		[
			true,
			true,
			true,
			true,
			true,
			false,
			"SOLID_PATH_CHRONOLOGY_UNPROVEN",
			state,
			"SOLID_PATH_CHRONOLOGY_UNPROVEN"
		],
		[true, true, true, true, true, false, "", [], "EARLY_SAMPLE_MISSING"],
		[true, true, true, false, true, false, "", state, "HISTORICAL_PITCHER_ORDER_UNPROVEN"],
		[true, true, true, true, false, false, "", state, "CURRENT_DRY_NO_WATER_DECISION"]
	]
	for row: Array in cases:
		_check(
			(
				PoolControllerWriterLedger.decision(
					row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], state
				)
				== row[8]
			),
			"decision refusal"
		)
	var grounded: Array = state.duplicate()
	grounded[2] = true
	_check(
		(
			PoolControllerWriterLedger.decision(
				true, true, true, true, true, false, "", state, grounded
			)
			== "EARLIER_GROUND_OR_TERMINAL"
		),
		"new ground before water refuses"
	)
	_check(
		(
			PoolControllerWriterLedger.decision(
				true, true, false, false, true, false, "", state, state
			)
			== wet
		),
		"closed ordinary gate does not claim helper invocation"
	)
	var ledger: PoolControllerWriterLedger = PoolControllerWriterLedger.new()
	ledger._fail("FIRST")
	ledger._fail("SECOND")
	_check(ledger.failure == "FIRST", "one bounded first-failure slot")
	_check(ledger.events.is_empty(), "failure never invents trace")
	var packet: Dictionary = ledger.packet("baseline", "NO_POOL", "0".repeat(64))
	for key: String in [
		"early_award_authority",
		"phase_closure_qualified",
		"active_awards_enabled",
		"production_qualified",
		"ordinary_controller_qualified",
		"persistent_session_qualified",
		"direct_internal_return_observed",
		"dry_to_dry_completeness_qualified",
		"reflected_path_reconstructed",
		"earlier_segment_terminal_exclusion_qualified"
	]:
		_check(packet[key] == false, "all authority flags false")


func _ancestry_cases() -> void:
	var parent: Node = Node.new()
	var child: Node = Node.new()
	parent.add_child(child)
	_check(PoolControllerWriterLedger.main_thread_ancestry(child), "inherited main group")
	parent.process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD
	_check(
		not PoolControllerWriterLedger.main_thread_ancestry(child), "inherited subthread refuses"
	)
	child.process_thread_group = Node.PROCESS_THREAD_GROUP_MAIN_THREAD
	_check(
		not PoolControllerWriterLedger.main_thread_ancestry(child),
		"explicit child does not hide ancestor"
	)
	parent.free()


func _real_forwarding(label: String) -> void:
	var lab: PitchBatLab = FORWARDER.new()
	lab._match_mode = false
	add_child(lab)
	lab._match_mode = false
	lab.set_process(false)
	var shadow: StadiumPoolControllerShadow = StadiumPoolControllerShadow.new()
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var plain: bool = not lab._match_mode and lab._configured_match == null
	_check(plain, "explicit plain-lab fixture setup")
	if not plain:
		await _abort_fixture(lab, shadow)
		return
	var physics: bool = (
		lab.is_physics_processing()
		and is_instance_valid(lab._primary_fielder)
		and lab._primary_fielder.is_physics_processing()
	)
	_check(physics, "ordinary controller and primary physics stay enabled")
	if not physics:
		await _abort_fixture(lab, shadow)
		return
	var prepared: bool = shadow.prepare(lab, null, "NO_POOL", source)
	_check(prepared, "actual plain model preparation")
	if not prepared:
		await _abort_fixture(lab, shadow)
		return
	var installed: bool = shadow.install(lab, null, "NO_POOL", source)
	_check(installed, "real observer install")
	if not installed:
		await _abort_fixture(lab, shadow)
		return
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(12, 1, 18)
	launch.velocity = Vector3(0, 0, 3)
	lab._start_ball_in_play(launch)
	var writer: PoolControllerWriterLedger = shadow.writer
	var armed: bool = writer.armed and writer.failure == ""
	_print_launch_diagnostic(label, shadow, writer)
	_check(armed, "real launch seal arms writer")
	if not armed:
		await _abort_fixture(lab, shadow)
		return
	var owned: bool = writer.ownership()
	_check(owned, "source and effective owner bound")
	if not owned:
		await _abort_fixture(lab, shadow)
		return
	var inventory_ok: bool = _inventory_witness(writer, label == "reentrant")
	_check(inventory_ok, "complete runtime script inventory matches source-pinned manifest")
	if not inventory_ok:
		await _abort_fixture(lab, shadow)
		return
	var generation: int = shadow.generation
	shadow.generation += 1
	_check(not writer.ownership(), "stale generation rejected")
	shadow.generation = generation
	lab.process_physics_priority = 1
	_check(not writer.ownership(), "priority mutation rejected")
	lab.process_physics_priority = 0
	lab.set_meta(&"stadium_property", {"unsupported": true})
	_check(lab.has_meta(&"stadium_property"), "non-null route negative exists")
	_check(not writer.ownership(), "property route rejected")
	lab.remove_meta(&"stadium_property")
	var restored: bool = writer.ownership()
	_check(restored, "manual fixtures restored before ordinary call")
	if not restored:
		await _abort_fixture(lab, shadow)
		return
	if label == "reentrant":
		_inventory_negatives(writer)
		_capture_negatives(lab, writer)
		_maximal_rows(writer.snapshot())
		var call_id: int = writer.begin(lab, "controller", [0.0])
		_check(call_id > 0, "owned manual controller entry")
		_check(writer.begin(lab, "controller", [0.0]) == 0, "reentrant entry rejected")
		_check(writer.failure == "CALL_NESTING_OR_REENTRANCY", "reentrancy failure exact")
	elif label == "byte_overflow":
		var before_count: int = writer.events.size()
		writer._event_bytes = writer.MAX_TYPED_BYTES - writer.METADATA_RESERVE
		writer.begin(lab, "controller", [0.0])
		_check(writer.failure == "EVENT_BUDGET", "byte overflow rejected")
		_check(writer.events.size() == before_count, "oversized row not appended")
	elif label == "event_overflow":
		writer.events.resize(writer.MAX_EVENTS)
		writer.begin(lab, "controller", [0.0])
		_check(writer.failure == "EVENT_BUDGET", "count overflow rejected")
		_check(writer.events.size() == writer.MAX_EVENTS, "event overflow does not grow")
	elif label == "row_overflow":
		var before_count: int = writer.events.size()
		writer.begin(lab, "controller", ["x".repeat(65)])
		_check(writer.failure == "VALUE_GRAMMAR_LIMIT", "row text overflow rejected")
		_check(writer.events.size() == before_count, "invalid row not appended")
	else:
		var call_id: int = writer.begin(lab, "controller", [0.0])
		writer.end(lab, "pitcher", call_id)
		_check(writer.failure == "RETURN_ORDER", "wrong return rejected")
	_check(not writer.failure.is_empty(), "negative fixture has a real latched failure")
	# Observation is already failed. The real superclass must still ground the play.
	_check(not lab._ball_play_resolver.state.has_grounded, "pre-forward state dry")
	lab._on_batted_surface_contact(&"ground", launch.position)
	_check(
		lab._ball_play_resolver.state.has_grounded, "failed observer preserves ordinary callback"
	)
	_check(
		lab._ball_play_resolver.state.first_ground_position == launch.position, "exact arguments"
	)
	var before: float = lab._ball_play_resolver.state.elapsed_seconds
	lab._physics_process(0.01)
	_check(
		lab._ball_play_resolver.state.elapsed_seconds == before + 0.01,
		"failed observer still forwards exact delta once"
	)
	shadow.detach()
	lab.queue_free()
	await get_tree().process_frame


func _inventory_equal(rows: Array, sources: Array, scripts: Array, expected: Array) -> bool:
	# A set comparison on copies only. Never reorder producer arrays or scene indices.
	if rows.size() != 36 or sources.size() != 36 or scripts.size() != 36 or expected.size() != 36:
		return false
	var wanted: Dictionary = {}
	for value: Variant in expected:
		if not value is Dictionary:
			return false
		var entry: Dictionary = value
		if entry.keys().size() != 3 or not entry.has_all(["path", "sha256", "bytes"]):
			return false
		if not entry.path is String or not entry.sha256 is String:
			return false
		if not (entry.bytes is float or entry.bytes is int):
			return false
		if not is_finite(float(entry.bytes)) or entry.bytes <= 0 or int(entry.bytes) != entry.bytes:
			return false
		if wanted.has(entry.path):
			return false
		wanted[entry.path] = entry
	var seen: Dictionary = {}
	var resources: Array = []
	for index: int in range(36):
		if not rows[index] is Array or rows[index].size() != 2:
			return false
		var row: Array = rows[index]
		if not row[0] is String or not row[1] is String or not sources[index] is String:
			return false
		if not scripts[index] is Script or scripts[index] in resources:
			return false
		if seen.has(row[0]) or not wanted.has(row[0]):
			return false
		var entry: Dictionary = wanted[row[0]]
		var source: String = sources[index]
		var script: Script = scripts[index]
		if (
			row[1] != entry.sha256
			or source.sha256_text() != row[1]
			or source.to_utf8_buffer().size() != entry.bytes
			or script.resource_path != row[0]
			or script.source_code != source
		):
			return false
		seen[row[0]] = true
		resources.append(script)
	return seen.size() == wanted.size()


func _expected_inventory() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	if not parsed is Dictionary or parsed.get("schema") != "POOL-WRITER-INVENTORY-v1":
		return []
	var sets: Variant = parsed.get("sets")
	if not sets is Dictionary or not sets.get("unit") is Dictionary:
		return []
	var unit: Dictionary = sets.unit
	if unit.get("count") != 36 or unit.get("path_hash_table_bytes") != 5048:
		return []
	var rows: Variant = unit.get("rows")
	return rows if rows is Array else []


func _inventory_witness(writer: PoolControllerWriterLedger, emit: bool) -> bool:
	var expected: Array = _expected_inventory()
	var equal: bool = _inventory_equal(
		writer._script_rows, writer._script_sources, writer._scripts, expected
	)
	if (
		writer._script_rows.size() > 36
		or writer._script_rows.size() != writer._script_sources.size()
	):
		return false
	var scripted_nodes: int = 0
	var scene_indices: Dictionary = {}
	for row: Array in writer._scope_rows:
		if row[2] >= 0:
			scripted_nodes += 1
			scene_indices[row[2]] = true

	var full_bytes: int = var_to_bytes(writer._script_rows).size()
	var prefix_bytes: int = var_to_bytes(writer._script_rows.slice(0, 32)).size()

	var metadata_bytes: int = (
		var_to_bytes(writer.packet("shadow", "NO_POOL", writer._shadow._source)).size()
	)

	if emit:
		var observed: Array = []
		for index: int in range(writer._script_rows.size()):
			observed.append(
				{
					"path": writer._script_rows[index][0],
					"sha256": writer._script_rows[index][1],
					"bytes": writer._script_sources[index].to_utf8_buffer().size()
				}
			)
		var encoded: String = JSON.stringify(
			{
				"schema": "POOL-WRITER-INVENTORY-WITNESS-v1",
				"manifest_sha256": FileAccess.get_sha256(INVENTORY_PATH),
				"rows": observed,
				"count": writer._script_rows.size(),
				"exact_set_equal": equal,
				"scripted_nodes": scripted_nodes,
				"scene_scripts": scene_indices.size(),
				"table_bytes": full_bytes,
				"prefix_bytes": prefix_bytes,
				"increment_bytes": full_bytes - prefix_bytes,
				"metadata_bytes": metadata_bytes,
				"metadata_quota": writer.METADATA_RESERVE - 4096
			}
		)
		if encoded.to_utf8_buffer().size() > 16384:
			return false
		print("POOL_WRITER_INVENTORY " + encoded)
	return (
		equal
		and scripted_nodes == 27
		and scene_indices.size() == 23
		and full_bytes == 5048
		and prefix_bytes == 4472
		and full_bytes - prefix_bytes == 576
		and metadata_bytes <= writer.METADATA_RESERVE - 4096
	)


func _inventory_negatives(writer: PoolControllerWriterLedger) -> void:
	var expected: Array = _expected_inventory()
	var rows: Array = writer._script_rows.duplicate(true)
	var sources: Array = writer._script_sources.duplicate()
	var scripts: Array = writer._scripts.duplicate()
	var before: PackedByteArray = var_to_bytes(writer._script_rows)
	_check(
		_inventory_equal(rows, sources, scripts, expected), "exact 36 distinct resources accepted"
	)
	rows.reverse()
	sources.reverse()
	scripts.reverse()
	_check(_inventory_equal(rows, sources, scripts, expected), "copied row order is immaterial")
	_check(before == var_to_bytes(writer._script_rows), "producer order and indices untouched")
	rows = writer._script_rows.duplicate(true)
	sources = writer._script_sources.duplicate()
	scripts = writer._scripts.duplicate()
	for label: String in [
		"under",
		"over",
		"duplicate_row",
		"duplicate_resource",
		"path",
		"hash",
		"source_bytes",
		"manifest_bytes",
		"manifest_path",
		"manifest_hash",
		"manifest_duplicate"
	]:
		var bad_rows: Array = rows.duplicate(true)
		var bad_sources: Array = sources.duplicate()
		var bad_scripts: Array = scripts.duplicate()
		var bad_expected: Array = expected.duplicate(true)
		match label:
			"under":
				bad_rows.pop_back()
			"over":
				bad_rows.append(rows[0])
			"duplicate_row":
				bad_rows[0] = bad_rows[1]
			"duplicate_resource":
				bad_scripts[0] = bad_scripts[1]
			"path":
				bad_rows[0][0] = "res://not-the-bound-script.gd"
			"hash":
				bad_rows[0][1] = "0".repeat(64)
			"source_bytes":
				bad_sources[0] += " "
			"manifest_bytes":
				bad_expected[0].bytes += 1
			"manifest_path":
				bad_expected[0].path = "res://stale-epoch.gd"
			"manifest_hash":
				bad_expected[0].sha256 = "0".repeat(64)
			"manifest_duplicate":
				bad_expected[0] = bad_expected[1]
		_check(
			not _inventory_equal(bad_rows, bad_sources, bad_scripts, bad_expected),
			"inventory negative " + label
		)
	# Local path metadata only: never take over or reload a shared cached Script.
	var duplicate: GDScript = GDScript.new()
	duplicate.source_code = sources[1]
	duplicate.set_path_cache(scripts[1].resource_path)
	_check(
		duplicate != scripts[1] and duplicate.resource_path == scripts[1].resource_path,
		"negative has distinct Script resources sharing one path"
	)
	var duplicate_rows: Array = rows.duplicate(true)
	var duplicate_sources: Array = sources.duplicate()
	var duplicate_scripts: Array = scripts.duplicate()
	duplicate_rows[0] = rows[1].duplicate()
	duplicate_sources[0] = sources[1]
	duplicate_scripts[0] = duplicate
	_check(
		not _inventory_equal(duplicate_rows, duplicate_sources, duplicate_scripts, expected),
		"distinct resources sharing one path rejected"
	)
	duplicate.set_path_cache("")


func _capture_negatives(lab: PitchBatLab, writer: PoolControllerWriterLedger) -> void:
	# Isolated ledger instances only; never rebind or mutate the live writer/source resources.
	var limit: PoolControllerWriterLedger = PoolControllerWriterLedger.new()
	limit._lab = lab
	limit._scripts.assign(writer._scripts)
	var extra: GDScript = GDScript.new()
	extra.source_code = "extends Node\n"
	var reloaded: Error = extra.reload()
	_check(reloaded == OK, "over-limit fixture script compiles")
	var node: Node = Node.new()
	node.set_script(extra)
	lab.add_child(node)
	_check(
		limit._scripts.size() == 36 and extra not in limit._scripts,
		"capture fixture has 37 distinct resources"
	)
	limit._capture_scope()
	_check(limit.failure == "SCRIPT_SCOPE_LIMIT", "actual capture rejects 37th resource")
	_check(limit._scripts.size() == 36, "over-limit capture never appends 37th resource")
	node.free()
	for drift: String in ["path", "content"]:
		var isolated: PoolControllerWriterLedger = PoolControllerWriterLedger.new()
		isolated._lab = lab
		isolated._scripts.assign(writer._scripts.slice(0, 35))
		var path: String = "res://" + "x".repeat(193)
		var reason: String = "SCRIPT_SCOPE_LIMIT"
		if drift == "content":
			path = writer._script_rows[0][0]
			reason = "LOADED_SCRIPT_SOURCE_MISMATCH"
		extra.set_path_cache(path)
		var drift_node: Node = Node.new()
		drift_node.set_script(extra)
		lab.add_child(drift_node)
		_check(
			(
				isolated._scripts.size() == 35
				and extra.resource_path == path
				and extra not in writer._scripts
			),
			"capture drift uses an isolated resource " + drift
		)
		isolated._capture_scope()
		_check(
			isolated.failure == reason and isolated._scripts.size() == 35,
			"actual capture rejects " + drift + " drift"
		)
		drift_node.free()
		extra.set_path_cache("")
	var old: String = writer._script_sources[0]
	writer._script_sources[0] = old + " "
	_check(not writer.ownership(), "captured source content drift rejected")
	writer._script_sources[0] = old
	_check(writer.ownership(), "isolated negative restores exact source ownership")


func _print_launch_diagnostic(
	label: String, shadow: StadiumPoolControllerShadow, writer: PoolControllerWriterLedger
) -> void:
	# Read only already-latched fields. Do not rerun bind, ownership, snapshot or callbacks.
	var errors: Array[String] = []
	var events: Array[String] = []
	var clipped: bool = shadow.errors.size() > 8 or shadow.records.size() > 8
	for index: int in range(mini(shadow.errors.size(), 8)):
		var reason: String = shadow.errors[index]
		clipped = clipped or reason.length() > 64
		errors.append(reason.left(64))
	for index: int in range(mini(shadow.records.size(), 8)):
		var event: Variant = shadow.records[index].get("event", null)
		if event is String:
			clipped = clipped or event.length() > 64
			events.append(event.left(64))
		else:
			clipped = true
			events.append("<NON_STRING_EVENT>")
	clipped = clipped or writer.failure.length() > 64 or String(shadow.phase).length() > 64
	var metadata: Dictionary = {
		"schema": "POOL-WRITER-LAUNCH-DIAGNOSTIC-v1",
		"epoch": "V17",
		"fixture": label.left(64),
		"role": "NO_POOL",
		"shadow_phase": String(shadow.phase).left(64),
		"shadow_generation": shadow.generation,
		"shadow_errors": errors,
		"shadow_error_count": shadow.errors.size(),
		"shadow_events": events,
		"shadow_record_count": shadow.records.size(),
		"writer_armed": writer.armed,
		"writer_failure": writer.failure.left(64),
		"writer_generation": writer._generation,
		"scope_nodes": writer._scope.size(),
		"scope_rows": writer._scope_rows.size(),
		"scripts": writer._scripts.size(),
		"callbacks": writer._signal_rows.size(),
		"ancestors": writer._ancestor_rows.size(),
		"registry": writer._registry.size(),
		"writer_events": writer.events.size(),
		"writer_event_bytes": writer._event_bytes,
		"checks_before_assertion": _checks,
		"failures_before_assertion": _failures,
		"metadata_clipped": clipped or label.length() > 64
	}
	var encoded: String = JSON.stringify(metadata)
	if encoded.to_utf8_buffer().size() > 8192:
		encoded = JSON.stringify(
			{"epoch": "V17", "fixture": label.left(64), "output_overflow": true}
		)
	print("POOL_WRITER_LAUNCH_DIAGNOSTIC " + encoded)


func _abort_fixture(lab: PitchBatLab, shadow: StadiumPoolControllerShadow) -> void:
	# The primary failed assertion remains counted. Skip only dependent fixture work.
	shadow.detach()
	lab.queue_free()
	await get_tree().process_frame


func _maximal_rows(state: Array) -> void:
	# Local encoding fixtures only. No gameplay object or physical value is changed.
	var wide: float = 0.123456789012345
	for index: int in [4, 5, 35, 36, 37]:
		state[index] = "x".repeat(64)
	for index: int in [12, 13, 29, 30, 33, 39]:
		state[index] = wide
	var inputs: Array = state[40]
	inputs[3] = "x".repeat(64)
	inputs[2] = 4611686018427387904
	inputs[4] = 4611686018427387904
	inputs[11] = 4611686018427387904
	for index: int in [1, 5, 6, 7, 8, 9, 10, 12, 13, 14, 15, 17]:
		inputs[index] = wide
	var identities: Array = state[41]
	for index: int in range(8):
		identities[index] = 4611686018427387904 + index
	identities[0] = identities[5]
	state[43] = [wide, wide, wide, wide, wide]
	var point: Vector3 = Vector3(64, 16, 64)
	var contacts: Array = []
	for index: int in range(8):
		contacts.append([4611686018427387904, 255, point])
	var ambiguities: Array[String] = [
		"UNREGISTERED_ROUTER_CONTACT",
		"SOLID_PATH_CHRONOLOGY_UNPROVEN",
		"ROUTER_CAPACITY_UNPROVEN",
		"GROUND_HISTORY_CHRONOLOGY_UNPROVEN"
	]
	var shapes: Dictionary = {
		"seal": [],
		"early": contacts,
		"controller.enter": [wide],
		"controller.return": [],
		"pitcher.enter": [point, point],
		"pitcher.return": [],
		"primary.enter": [],
		"primary.return": [],
		"surface.enter": ["x".repeat(64), point],
		"surface.return": [],
		"fielding.enter": ["primary_fielder", point, 2, Vector3.INF],
		"fielding.return": [],
		"resolved.enter": [4611686018427387904, 5, "x".repeat(64), true, point],
		"resolved.return": [4611686018427387904, 5, "x".repeat(64), true, point],
		"pitcher.seal":
		[
			[point, point, point, Vector3.INF, false, wide],
			[point, point, point, false, wide],
			true,
			true,
			true,
			true,
			"x".repeat(64),
			false,
			false,
			ambiguities
		]
	}
	var maximum: int = 0
	for kind: String in shapes:
		var row: Array = [1599, kind, 180, 180, 900, 899, 4, 1000, shapes[kind], state]
		var size: int = var_to_bytes(row).size()
		_check(
			PoolControllerWriterLedger.bounded_value(shapes[kind]), "all argument shapes bounded"
		)
		_check(size <= 2048, "every maximal encoding fits event quota")
		maximum = maxi(maximum, size)
	_check(var_to_bytes(state).size() == 1448, "exact maximal snapshot encoding")
	_check(maximum == 1992, "maximal argument row agrees with offline byte proof")
	print(
		(
			"POOL_WRITER_MAX_ROW snapshot=1448 maximum=%d quota=2048 shapes=%d"
			% [maximum, shapes.size()]
		)
	)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(label)
