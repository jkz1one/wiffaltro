extends "res://src/tests/stadium_npc_retained_daylight_test.gd"
## New authority/installation seam only. Every inherited daylight sample and proof is unchanged.
## Inspection layers and capture locks are instrumentation, never accepted installed authority.

const COMMON_FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
const MATCH_SEED: int = 47
const ENVIRONMENT_SEED: int = 76003
var _completed_groups: int = 0


func _ready() -> void:
	_revision = 2
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		elif argument.begins_with("--npc-bound-venue="):
			_selected_venue = argument.trim_prefix("--npc-bound-venue=")
	if DisplayServer.get_name() == "headless" or _capture_dir.is_empty():
		_check(false, "raw-bound daylight requires native rendering and --ui-capture-dir")
		get_tree().quit(1)
		return
	if not _selected_venue.is_empty() and _selected_venue not in IDS:
		_check(false, "raw-bound selector names an exact admitted revision2 park")
		get_tree().quit(1)
		return
	_capture_dir = _capture_dir.path_join("npc-bound-r2")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "raw-bound native startup handshake")
	for id: String in IDS:
		if _selected_venue.is_empty() or id == _selected_venue:
			await _venue(id)
	_check(_native._failures == 0, "raw-bound matrix has no hidden capture handshake failure")
	_check(_completed_groups == (6 if _selected_venue.is_empty() else 2),
		"every requested full 7680-position native group completed without skipped proofs")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		if _selected_venue.is_empty():
			print("Wiffaltro NPC raw bound daylight passed: six native fixture17 groups and visibility.")
		else:
			print("Wiffaltro NPC raw bound daylight selected venue passed: " + _selected_venue + ".")
	get_tree().quit(0 if _failures == 0 else 1)


func _binding(id: String) -> Dictionary:
	# Synthetic caller-owned expectations are independent of MatchState.stadium.
	return {"season_id": "0123456789abcdef0123456789abcdef",
		"assignment_key": "b".repeat(64), "owner_club": 2, "venue_id": id,
		"venue_revision": 2, "fixture": 7, "away": 0, "batting_home": 2,
		"neutral": false, "match_seed": MATCH_SEED, "field": "field.npc_venue"}


func _environment() -> Dictionary:
	return {"version": 1, "seed": ENVIRONMENT_SEED, "fixture": 7, "mode": "day", "profile": ""}


func _venue(id: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	_check(lab._match_state.stadium.is_empty() and not lab.has_meta("stadium_property"),
		"ordinary empty-stadium startup does not dispatch raw NPC authority")
	var fixture: Dictionary = StadiumNpcSnapshot.raw_fixture(
		StadiumNpcSnapshot.raw_entry(id, 2), _binding(id), _environment())
	var parsed: Variant = JSON.parse_string(JSON.stringify(fixture, "", true, true))
	lab._match_state.stadium = StadiumNpcSnapshot.normalize_raw_envelope(parsed)
	_check(not fixture.is_empty() and fixture == lab._match_state.stadium,
		"native context starts from exact full-P raw fixture17 roundtrip")
	var field: FieldDefinition = COMMON_FIELD.duplicate(true) as FieldDefinition
	var context: StadiumNpcQualificationContext = StadiumNpcQualificationContext.create(
		lab._match_state, _binding(id), _environment(), field, MATCH_SEED)
	var original_field: FieldDefinition = lab._field_definition
	var host: Node = lab.get_node("StarterFieldGeometry")
	var original_nodes: Array[Node] = host.get_children()
	var installed: bool = StadiumNpcRuntime.install_bound(lab, context)
	_check(installed, id + " actual raw fixture17 installation without authoring flags")
	if not installed:
		lab.queue_free()
		await get_tree().process_frame
		return
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	_check(StadiumNpcRuntime.installed(lab, context), id + " full bound installation proof")
	_check(property.context == context and property.field == field,
		"native matrix uses the actual independent context and supplied concrete field")
	_check(not StadiumNpcSnapshot.valid(fixture) and not StadiumLayoutSnapshot.valid(fixture)
		and not StadiumNpcAvailability.record(id, 2).production_runtime,
		"native qualification does not open public snapshot or runtime availability")
	_write_context(id, fixture)
	var bodies: Array[Node] = property.find_children("*", "StaticBody3D", true, false)
	var original_colliders: Array = Proof.colliders(property)
	var layers: Array[int] = []
	for body: StaticBody3D in bodies:
		layers.append(body.collision_layer)
		body.collision_layer |= Proof.MASK
	# The strict runtime must refuse the instrumented state; no readiness bypass is used.
	_check(not StadiumNpcRuntime.installed(lab, context),
		"measurement-only collision layers do not masquerade as installed geometry")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var collision_snapshot: Array = Proof.colliders(property)
	for extent: Vector2i in EXTENTS:
		var failures_before: int = _failures
		_check(await _native.resize(extent), "raw-bound native extent acknowledged")
		var content: Vector2i = _native._expected_content_size(extent)
		_check(content == (Vector2i(1280, 720) if extent.x == 1280 else Vector2i(700, 393)),
			"raw-bound requested daylight content resolution")
		print("NPC_BOUND_DAYLIGHT_GROUP_BEGIN venue=", id, " content=", content,
			" fixture_key=", StadiumNpcSnapshot.raw_envelope_key(fixture),
			" public_P=", fixture.manifest_key)
		# These inherited functions retain every original sample, negative control, capture,
		# ray/sphere/triangle, hidden-control equality, contrast and physical freeze assertion.
		await _setup(lab, id, extent)
		await _controls(lab, id, extent)
		await _tracking(lab, id, extent)
		_check(context.validated(lab) and not property.suspended,
			"all native measurements preserve independent binding and current MatchState")
		_check(Proof.colliders(property) == collision_snapshot,
			"native group preserves all instrumented actual colliders")
		if _failures == failures_before:
			_completed_groups += 1
			print("NPC_BOUND_DAYLIGHT_GROUP_COMPLETE venue=", id, " content=", content,
				" samples=7680 fixture_key=", StadiumNpcSnapshot.raw_envelope_key(fixture))
	_check(Proof.colliders(property) == collision_snapshot,
		"full raw-bound camera matrix preserves every actual collider")
	for index in range(bodies.size()):
		bodies[index].collision_layer = layers[index]
	_check(Proof.colliders(property) == original_colliders,
		"measurement mask restoration preserves exact original collider identity and layers")
	_check(StadiumNpcRuntime.installed(lab, context),
		"complete native matrix restores strict installed geometry, callbacks and processing")
	_check(lab._match_state.stadium == fixture,
		"six-group qualification never mutates raw fixture authority")
	_check(StadiumNpcRuntime.teardown(lab), "idle raw-bound native teardown")
	_check(host.get_children() == original_nodes and lab._field_definition == original_field,
		"native teardown restores original live children/order and field resource")
	_check(not StadiumNpcRuntime.installed(lab, context),
		"native teardown revokes installed raw-bound status")
	await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame


func _write_context(id: String, fixture: Dictionary) -> void:
	_check(DirAccess.make_dir_recursive_absolute(_capture_dir) == OK,
		"raw-bound native evidence directory is available")
	var path: String = _capture_dir.path_join("npc-bound-%s-fixture.json" % id.to_lower())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "raw-bound native context evidence opens")
	if file == null:
		return
	var record: Dictionary = {"kind": "RAW_NPC_BOUND_DAYLIGHT_QUALIFICATION_CONTEXT",
		"version": 1, "fixture": fixture,
		"fixture_key": StadiumNpcSnapshot.raw_envelope_key(fixture),
		"scene": "res://src/tests/stadium_npc_bound_daylight_test.tscn",
		"groups": [[1280, 720], [700, 393]]}
	var raw: String = JSON.stringify(record, "", true, true)
	file.store_string(raw)
	file.flush()
	_check(file.get_error() == OK, "raw-bound native context evidence writes completely")
	file.close()
	_check(FileAccess.get_file_as_string(path) == raw,
		"raw-bound native context readback preserves complete P and binding bytes")
