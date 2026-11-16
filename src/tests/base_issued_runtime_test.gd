extends Node3D
## Actual mutation/refusal probes for the supported-lifecycle issued contract.
## Direct static edits bypassing the writer seam are cold-audit-only, deliberately tested below.
## No pitches, fabricated gameplay, completed games, or legacy-equivalence claims.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FORGED_BODY = preload("res://src/tests/stadium_npc_bound_forged_body.gd")
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(not R.install_bound(null) and not R.bind_ball(null, null, null),
		"null installation and ball binding refuse")
	_check(R.source_qualified(), "cold current-source qualification")
	var season: SeasonState = _season()
	var saved: Dictionary = SeasonSave.snapshot(season)
	await _dynamic_and_writer(season)
	await _signal_retirement(season, "resource", "AY-01")
	await _signal_retirement(season, "script", "AY-01")
	await _signal_retirement(season, "tree", "AC-01")
	await _custom_fallback(season)
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"all probes preserve actual save, stock, rewards, fixtures and result history")
	await TestAudioDrain.finish(get_tree())
	print("BASE_ISSUED_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print("BASE_ISSUED_COVERAGE installs=%d completed_cases=%d completed_games=0" %
		[_installs, _cases])
	get_tree().quit(0 if _failures == 0 and _installs == 5 and _cases == 5 else 1)


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(10, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture_five(10, season.career.current, 0)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "actual draft choice %d" % pick)
	return season


func _fixture(season: SeasonState, id: String) -> Dictionary:
	for fixture: Dictionary in season.schedule:
		if fixture.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return fixture.duplicate(true)
	return {}


func _lab(season: SeasonState, id: String) -> PitchBatLab:
	var fixture: Dictionary = _fixture(season, id)
	_check(not fixture.is_empty(), "actual scheduled fixture " + id)
	if fixture.is_empty():
		return null
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	if not lab.yard_bound_startup_failed:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._at_bat_cadence.stop()
	var property: StadiumNpcPublicProperty = R._property(lab)
	var positive: bool = not lab.yard_bound_startup_failed and property != null \
		and property.issued and property.ordinary_callbacks() and property.callback_intact()
	_check(positive, "genuine issued ordinary startup " + id)
	if not positive:
		lab.free()
		return null
	_installs += 1
	return lab


func _dynamic_and_writer(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season, "AE-01")
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[key] += 1
		_check(not R.callback_bound(lab, property), "fresh binding refusal " + key)
		lab._match_state.stadium = snapshot.duplicate(true)
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, _fixture(season, "AE-01"))
	_check(not R.callback_bound(lab, property), "replacement MatchState cannot borrow issued owner")
	lab._match_state = state
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(snapshot.binding.owner_club))
	_check(not R.callback_bound(lab, property), "removed current saved owner refuses")
	season.npc_venues = assignments
	for marker: String in ["stadium_candidate_only", "stadium_npc_retained_lab_only"]:
		lab.set_meta(marker, false)
		_check(not R.callback_bound(lab, property), "private marker presence refuses " + marker)
		lab.remove_meta(marker)
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = Callable()
	_check(not R.callback_bound(lab, property), "actual missing resolver route refuses")
	lab._ball_play_resolver.segment_observer = observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = Callable()
	_check(not R.callback_bound(lab, property), "actual missing fielder route refuses")
	lab._primary_fielder.stadium_boundary_clip = clip
	var receiver_route: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	_check(not R.callback_bound(lab, property), "actual missing receiver route refuses")
	lab._pitch_actor.receiver_router = receiver_route
	property.display.bind_match(null)
	_check(not R.callback_bound(lab, property), "detached live scoreboard refuses")
	property.display.bind_match(state)
	var camera_mask: int = lab._camera.cull_mask
	lab._camera.cull_mask = 0
	_check(not R.callback_bound(lab, property), "actual camera mask mutation refuses")
	lab._camera.cull_mask = camera_mask
	var pose: Transform3D = property.construction.transform
	property.construction.position.x += 0.01
	_check(not R.callback_bound(lab, property), "direct installation owner transform refuses")
	property.construction.transform = pose
	pose = property.receiver.chair.transform
	property.receiver.chair.position.x += 0.01
	_check(not R.callback_bound(lab, property), "actual dynamic receiver owner mutation refuses")
	property.receiver.chair.transform = pose
	_check(property.callback_intact(), "exact dynamic operands restore before retirement")
	_check(not R.bind_ball(lab, null, lab._ball_play_resolver),
		"issued state cannot admit absent ball")
	var ground: StaticBody3D = property.construction.get_node("PropertyGround")
	var layer: int = ground.collision_layer
	ground.collision_layer = 0
	_check(R.callback_bound(lab, property) and not R.installed(lab),
		"unannounced static collider edit is cold-audit-only under revised contract")
	ground.collision_layer = layer
	_check(property.callback_intact(), "restored static collision before supported edit")
	property.retire_installation("test supported collider edit")
	_check(property.suspended and not property.issued,
		"supported writer retires before touching static geometry")
	ground.collision_layer = 0
	ground.collision_layer = layer
	_sticky(lab, property, score, "supported writer")
	_finish_case("dynamic-and-writer", before)
	lab.free()
	await get_tree().process_frame


func _signal_retirement(season: SeasonState, kind: String, id: String) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season, id)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	var ground: StaticBody3D = property.construction.get_node("PropertyGround")
	if kind == "resource":
		var shape: BoxShape3D = (ground.get_child(0) as CollisionShape3D).shape as BoxShape3D
		var size: Vector3 = shape.size
		shape.size.x = _next_float32(size.x)
		_check(property.suspended and not property.issued, "actual static Resource.changed retires")
		shape.size = size
	elif kind == "script":
		var original: Variant = ground.get_script()
		ground.set_script(FORGED_BODY)
		_check(property.suspended and not property.issued, "actual script change retires")
		ground.set_script(original)
	else:
		var extra: Node3D = Node3D.new()
		property.construction.add_child(extra)
		_check(property.suspended and not property.issued, "actual installed child addition retires")
		property.construction.remove_child(extra)
		extra.free()
	_sticky(lab, property, score, kind)
	_finish_case(kind + "-retirement", before)
	lab.free()
	await get_tree().process_frame


func _custom_fallback(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season, "AE-01")
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	var decoration: MeshInstance3D = null
	var meshes: Array[Node] = property.construction.find_children("*", "MeshInstance3D", true, false)
	for node: MeshInstance3D in meshes:
		if not StadiumNpcRetainedGeometry._receiver_visual(node) and node.get_child_count() == 0:
			decoration = node
			break
	_check(decoration != null, "actual non-receiver decorative mesh selected")
	if decoration == null:
		lab.free()
		return
	var pose: Transform3D = decoration.transform
	decoration.position.x += 0.01
	_check(R.callback_bound(lab, property) and not R.installed(lab),
		"unannounced decorative edit remains visible to cold full-geometry audit")
	decoration.transform = pose
	lab._pitch_actor.trace_sampled.connect(_custom_trace)
	_check(not property.ordinary_callbacks() and property.callback_intact(),
		"actual extra observer takes strict fallback with valid geometry")
	decoration.position.x += 0.01
	_check(not property.callback_intact(), "custom observer fallback refuses changed actual geometry")
	decoration.transform = pose
	lab._pitch_actor.trace_sampled.disconnect(_custom_trace)
	_sticky(lab, property, score, "custom fallback")
	_finish_case("custom-fallback", before)
	lab.free()
	await get_tree().process_frame


func _custom_trace(_point: Vector3) -> void:
	pass


func _sticky(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	score: Array, label: String) -> void:
	_check(property.suspended and not property.issued and not property.callback_intact()
		and lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED, "sticky issued refusal " + label)
	_check(not R.install_bound(lab) and not R.rebind_match(lab), "no in-place reissue " + label)
	_check(_score(lab) == score and lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "refusal creates no gameplay or report " + label)


func _next_float32(value: float) -> float:
	var bytes: PackedByteArray = PackedFloat32Array([value]).to_byte_array()
	bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	return bytes.decode_float(0)


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BASE_ISSUED_RUNTIME " + label)


func _finish_case(label: String, before: Array[int]) -> void:
	if _checks > before[0] and _failures == before[1]:
		_cases += 1
	print("BASE_ISSUED_CASE case=%s checks=%d failures=%d" %
		[label, _checks - before[0], _failures - before[1]])
