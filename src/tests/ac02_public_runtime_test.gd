extends Node3D
## Three real saved-fixture installs: geometry/lifetime, supported writer, resource retirement.
## Bounded actual sphere queries and native ball contacts; no fabricated game/result evidence.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const AC = preload("res://src/presentation/stadium/stadium_npc_ac02_public_construction.gd")
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const PREFIX: String = "npc:AC-02:r1:"
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0
var _physical_contacts: int = 0
var _reference: Dictionary = {}
var _initial_msaa: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_initial_msaa = get_viewport().msaa_3d
	_check(not R.install_bound(null) and not R.installed_bound(null, {})
		and not R.bind_ball(null, null, null) and not R.teardown(null), "null operations fail closed")
	_check(R.source_qualified(), "current concrete source family qualifies")
	_check(FIXTURE.ready(), "exact joined allocator seed/map pins have been supplied")
	var prepared: SeasonState = FIXTURE.season()
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(SeasonSave.snapshot(prepared), "", true, true))) if prepared != null else null
	_check(season != null, "actual full-precision saved AC02 fixture restores")
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		_reference = StadiumNpcPublicContacts._reference(StadiumNpcSnapshot.capture("AC-02", 1))
		_check(not _reference.is_empty(), "one exact reference reused by bounded physical probes")
		await _lifecycle(season)
		await _writer_retirement(season, false)
		await _writer_retirement(season, true)
		_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
			"probes preserve actual saved assignments, stock, rewards and result history")
	await TestAudioDrain.finish(get_tree())
	print("AC02_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print(("AC02_PUBLIC_RUNTIME_COVERAGE installs=%d completed_cases=%d "
		+ "native_contacts=%d completed_games=0") % [_installs, _cases, _physical_contacts])
	get_tree().quit(0 if _failures == 0 and _installs == 3 and _cases == 3
		and _physical_contacts == 3 else 1)


func _lab(season: SeasonState) -> PitchBatLab:
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty(), "actual scheduled AC02 human-away fixture")
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
	_check(positive, "genuine AC02 issued public startup")
	if not positive:
		lab.free()
		return null
	_installs += 1
	return lab


func _lifecycle(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	_topology(lab, property)
	_target_change(lab, property)
	_cold_refusals(lab, property)
	_dynamic_refusals(lab, property, season)
	await get_tree().physics_frame
	_receiver_camera(lab, property)
	_boundary_probes(property)
	for probe: String in ["low-wall", "standard-wall", "receiver"]:
		await _terminal_physics(lab, property, probe)
	await _presentation(lab, property)
	await _ball_guards(lab, property)
	_check(property.callback_intact() and R.installed_bound(lab, lab._match_state.stadium),
		"issued callbacks and final cold installation agree")
	_check(lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "physical probes generate no completed report")
	var old_field: FieldDefinition = property.old_field
	var old_camera: MatchCameraDirector = property.old_camera
	var old_receiver: Callable = property.old_receiver
	var old_observer: Callable = property.old_observer
	var old_routes: Array[Dictionary] = property.old_obstacles.duplicate(true)
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._at_bat_cadence.stop()
	_check(R.teardown(lab), "idle public teardown succeeds")
	await get_tree().process_frame
	_check(lab._field_definition == old_field and lab._camera_director == old_camera
		and lab._pitch_actor.receiver_router == old_receiver
		and lab._ball_play_resolver.segment_observer == old_observer
		and lab._primary_fielder.stadium_obstacles == old_routes,
		"exact same-origin field, camera, receiver and route owners restore")
	_check(not R.installed(lab) and lab.has_meta(R.PUBLIC_BOUND)
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and not lab.has_meta("stadium_snapshot") and not R.install_bound(lab),
		"teardown stays sticky and cannot silently fall back")
	_complete_case("lifecycle", before)
	lab.free()
	await get_tree().process_frame


func _topology(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(property.venue_id == "AC-02" and property.tier == "club"
		and property.public_bound and property.issued and property.objects.size() == 75
		and property.field == lab._field_definition and property.construction.field == property.field
		and property.field.id == &"field.starter_backyard"
		and typeof(property.field.id) == TYPE_STRING_NAME
		and not lab.has_meta("stadium_candidate_only")
		and not lab.has_meta("stadium_npc_retained_lab_only") and lab._stadium_ledger == null,
		"75 existing public copies, genuine starter field and no private/human authority")
	_check(property.boundary.get_script() == StadiumNpcAc02PublicBoundary
		and property.boundary.source.get_script() == StadiumNpcAc02PublicBoundarySource
		and property.boundary.graph.get_script() == StadiumNpcAc02PublicGraph
		and property.boundary.graph.identity() == "PROTOTYPE-CLUB-DUGOUT-RIGHT-SHELF-v1"
		and property.boundary.graph.segments().size() == 18 and AC.valid(property),
		"exact typed eighteen-edge RightShelf construction and public boundary")
	for description: Dictionary in AC.FIELD.get_property_list():
		if not int(description.usage) & PROPERTY_USAGE_STORAGE or description.name in [
			"script", "resource_path", "resource_name", "resource_local_to_scene"]:
			continue
		var key: String = description.name
		_check(typeof(property.field.get(key)) == typeof(AC.FIELD.get(key))
			and property.field.get(key) == AC.FIELD.get(key),
			"actual exported starter physics value and type retained " + key)
	var towers: int = 0
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null and property.construction.is_ancestor_of(model)
			and model.get_meta("npc_instance", "") == row.instance
			and model.get_meta("stadium_item", "") == row.item
			and ClubCareer.same(AC.components(model.transform), Array(PackedFloat32Array(row.transform))),
			"exact float32 canonical installed copy " + row.instance)
		if model != null and row.item == "ST-038":
			towers += 1
			_check(model.find_children("*", "Light3D", true, false).is_empty(),
				"actual four-head tower stays dormant " + row.site)
	_check(towers == 4 and lab._match_state.stadium.manifest.live_units == 0
		and lab._match_state.stadium.environment.mode == "day"
		and lab._match_state.stadium.environment.profile.is_empty(),
		"four dormant towers, zero obstacle units and saved daylight")
	if DisplayServer.get_name() == "headless":
		_check(get_viewport().msaa_3d == _initial_msaa, "headless does not alter viewport MSAA")
	else:
		_check(get_viewport().msaa_3d >= Viewport.MSAA_4X, "native viewport retains minimum4x MSAA")
	for site: String in ["BASE-L2", "BASE-R2"]:
		var lower: Node3D = property.objects[PREFIX + site]
		var roof: Node3D = property.objects[PREFIX + site + ".ROOF-LOWER"]
		_check(roof.get_parent() == lower and roof.transform == Transform3D.IDENTITY
			and roof.global_transform == lower.global_transform,
			"admitted lower-roof mounting preserves exact authored world pose " + site)
	var visibility: StadiumNpcAc02PublicVisibility = property.presentation_director.tracking_visibility
	_check(visibility != null and visibility.property == property and visibility._groups.size() == 15,
		"original fifteen opaque groups retain actual AC02 owner")
	_check(lab._ball_play_resolver.segment_observer == property.observe
		and lab._primary_fielder.stadium_boundary_clip == property.clip
		and lab._primary_fielder.stadium_obstacles == property.route_obstacles(),
		"actual resolver and fielder routes own installed RightShelf")


func _target_change(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var target: Vector2 = lab._pitch_target
	var marker: MeshInstance3D = lab._pitch_target_marker
	var pose: Transform3D = marker.transform
	var mesh: Mesh = marker.mesh
	var material: Material = marker.material_override
	var direction: float = -1.0 if target.x > 0 else 1.0
	# Real input producer owns target mutation and marker refresh ordering. Never prealign it here.
	PitchBatLabFeelSupport.adjust_pitch_target(lab, Vector2(direction * 0.0625, 0))
	_check(lab._pitch_target != target and lab._pitch_target_marker == marker
		and marker.position == Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015)
		and marker.mesh == mesh and marker.material_override == material,
		"ordinary input producer updates the genuine target marker without replacing its resources")
	_check(property.issued and not property.suspended and property.ac02_guides.owners_intact()
		and R.callback_bound(lab, property) and property.callback_intact(),
		"real target-change refresh reaches receiver callback without retiring issued AC02")
	PitchBatLabFeelSupport.adjust_pitch_target(lab, target - lab._pitch_target)
	_check(lab._pitch_target == target and marker.transform == pose
		and property.issued and not property.suspended and property.callback_intact(),
		"same public input producer restores the exact target and marker with authority intact")


func _cold_refusals(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var model: Node3D = property.objects[PREFIX + "SCORE-SMALL"]
	var pose: Transform3D = model.transform
	model.position.x += 0.01
	_check(not AC.valid(property), "cold full audit rejects moved authored copy")
	model.transform = pose
	var identity: String = model.get_meta("npc_instance")
	model.set_meta("npc_instance", "npc-candidate:AC-02:right-shelf-v1:SCORE-SMALL")
	_check(not AC.valid(property), "private source identity cannot gain public entry")
	model.set_meta("npc_instance", identity)
	var graph: StadiumNpcAc02PublicGraph = property.boundary.graph
	property.boundary.graph = StadiumNpcAc02PublicGraph.new()
	_check(not R._boundary_complete(property),
		"replacement graph cannot borrow captured source identity")
	property.boundary.graph = graph
	var source: Node3D = property.boundary
	var wrong: Node3D = Node3D.new()
	wrong.name = "ClubBoundary"
	property.boundary = wrong
	_check(not R._boundary_complete(property), "ClubBoundary name cannot substitute typed AC02 source")
	property.boundary = source
	wrong.free()
	var body: StaticBody3D = property.boundary.bodies[0]
	var layer: int = body.collision_layer
	body.collision_layer = 0
	_check(R.callback_bound(lab, property) and not R.installed(lab),
		"unannounced static collider edit remains cold-audit-only under issued contract")
	body.collision_layer = layer
	_check(property.callback_intact(), "restored same-frame cold probes preserve issued owner")


func _dynamic_refusals(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	season: SeasonState) -> void:
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[key] += 1
		_check(not R.callback_bound(lab, property), "fresh binding refuses " + key)
		lab._match_state.stadium = snapshot.duplicate(true)
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, FIXTURE.fixture(season))
	_check(not R.callback_bound(lab, property), "replacement MatchState cannot borrow issued owner")
	lab._match_state = state
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(snapshot.binding.owner_club))
	_check(not R.callback_bound(lab, property), "removed saved owner revokes callback authority")
	season.npc_venues = assignments
	for marker: String in ["stadium_candidate_only", "stadium_npc_retained_lab_only"]:
		lab.set_meta(marker, false)
		_check(not R.callback_bound(lab, property), "private marker presence refuses " + marker)
		lab.remove_meta(marker)
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = Callable()
	_check(not R.callback_bound(lab, property), "missing actual resolver route refuses")
	lab._ball_play_resolver.segment_observer = observer
	var router: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	_check(not R.callback_bound(lab, property), "missing actual receiver route refuses")
	lab._pitch_actor.receiver_router = router
	property.display.bind_match(null)
	_check(not R.callback_bound(lab, property), "detached live scoreboard refuses")
	property.display.bind_match(state)
	var mask: int = lab._camera.cull_mask
	lab._camera.cull_mask = 0
	_check(not R.callback_bound(lab, property), "changed actual camera mask refuses")
	lab._camera.cull_mask = mask
	_check(property.callback_intact(), "restored dynamic operands retain valid issued installation")


func _receiver_camera(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(property.receiver != null and property.display != null
		and property.display._match == lab._match_state and property.receiver.sounds == lab._sounds
		and lab._pitch_actor.receiver_router == property.receiver_route
		and lab._camera_director.get_script() == StadiumNpcAc02PublicCamera,
		"actual AC02 receiver, camera and scoreboard are paired")
	for sample: Array in [[Vector3(0, 1.3, 0), "ST026_PANEL"],
		[Vector3(1.5, 1.3, 0), "ST073_CENTER_NET"]]:
		var path: Dictionary = property.receiver.trace(sample[0], Vector3(0, 0, -40), 0.0365)
		_check(path.hit.get("surface") == sample[1]
			and String(path.hit.get("copy", "")).begins_with("npc:AC-02:r1:"),
			"real earliest receiver surface has exact r1 copy identity")
	_check(lab._camera_director.tracking_visibility != null
		and lab._camera_director.tracking_visibility.property == property,
		"actual camera visibility refers to installed AC02 property")


func _boundary_probes(property: StadiumNpcPublicProperty) -> void:
	var boundary: StadiumNpcAc02PublicBoundary = property.boundary
	for sample: Array in [["BACK-02", 1.0, "BACK_WALL_TERMINAL"],
		["BACK-02", 2.0, "BACK_CLEAR"], ["BACK-03", 2.0, "BACK_WALL_TERMINAL"]]:
		var row: Dictionary = _reference.segments[sample[0]]
		var center: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumRecipeBoundary.inward(row)
		var hit: Dictionary = StadiumNpcAc02PublicSweep.event(boundary,
			Vector3(center.x + inward.x, sample[1], center.y + inward.y),
			Vector3(center.x - inward.x, sample[1], center.y - inward.y))
		_check(hit.get("role") == sample[2], "actual radius.0365 low/tall wall sphere query " + sample[0])
		if sample[2] == "BACK_CLEAR":
			_check(not hit.has("npc_instance"), "graph-only clearance never invents copy provenance")
	# Both paths flank the genuine10,21 join, using the actual adjacent face normals.
	for side: Array in [["BACK-02", false, "BACK_CLEAR"], ["BACK-03", true, "BACK_WALL_TERMINAL"]]:
		var row: Dictionary = _reference.segments[side[0]]
		var along: Vector2 = (row.b - row.a).normalized()
		var center: Vector2 = row.a + along * 0.25 if side[1] else row.b - along * 0.25
		var inward: Vector2 = StadiumRecipeBoundary.inward(row)
		var hit: Dictionary = StadiumNpcAc02PublicSweep.event(boundary,
			Vector3(center.x + inward.x * 0.5, 2, center.y + inward.y * 0.5),
			Vector3(center.x - inward.x * 0.5, 2, center.y - inward.y * 0.5))
		_check(hit.get("role") == side[2], "actual low/standard side of shared height-step " + side[0])
	for body: StaticBody3D in boundary.bodies:
		if body.get_meta("surface_kind", "") != "pole":
			continue
		var split: float = body.get_meta("wall_cap_height")
		for upper: bool in [false, true]:
			var point: Vector3 = body.global_position
			point.y = split + 0.25 if upper else split - 0.25
			var hit: Dictionary = StadiumNpcAc02PublicSweep._contact(boundary, body,
				point + Vector3(0, 0, -0.5), point + Vector3(0, 0, 0.5), 0.0365)
			_check(hit.get("role") == ("FOUL_POLE_UPPER" if upper else "FOUL_POLE_LOWER"),
				"actual left/right pole sphere query retains authored cap split")
	for role: String in ["DUGOUT_FACE_LIVE", "DUGOUT_OPENING_DEAD"]:
		for row: Dictionary in boundary.graph.segments():
			if row.role != role:
				continue
			var center: Vector2 = (row.a + row.b) / 2
			var inward: Vector2 = StadiumRecipeBoundary.inward(row)
			var hit: Dictionary = StadiumNpcAc02PublicSweep.event(boundary,
				Vector3(center.x + inward.x * 0.5, 0.5, center.y + inward.y * 0.5),
				Vector3(center.x - inward.x * 0.5, 0.5, center.y - inward.y * 0.5))
			_check(hit.get("role") == role, "actual sphere query keeps dugout live/dead distinction")
			break


func _presentation(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var guides: StadiumNpcAc02PublicGuides = property.ac02_guides
	_check(guides != null and guides.owners_intact() and guides._guides.size() == 5,
		"five genuine current guide node/mesh/material owners are admitted")
	if guides == null:
		return
	var old_half: bool = lab._match_state.top_half
	var old_phase: MatchState.Phase = lab._match_state.phase
	var camera_pose: Transform3D = lab._camera.global_transform
	if lab._player_is_batting():
		lab._match_state.top_half = not old_half
	PitchBatLabPresentation.sync_players(lab)
	_check(lab._player_is_pitching() and not lab._player_is_batting(),
		"existing role logic supplies actual human defensive half")
	var velocity: Vector3 = Vector3(10.4, 2, 21)
	var ball: BattedBallBody = _new_ball(lab, property, Vector3(0, 1, 0), velocity)
	ball.freeze = true
	lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	lab._camera_director.prepare_ball_in_play(true, ball.global_position, velocity)
	var visibility: StadiumNpcAc02PublicVisibility = lab._camera_director.tracking_visibility
	_check(visibility.step_enrolled and visibility.step_segment == "BACK-02"
		and visibility.step_neighbor == "BACK-03",
		"actual defensive launch enrolls real low-to-tall step")
	property.refresh_actor_presentation(lab)
	_check(guides._suppressed and _guide_visibility(guides, false),
		"live defensive ball suppresses only five admitted guides")
	get_tree().paused = true
	property.refresh_actor_presentation(lab)
	_check(not guides._suppressed and _guide_visibility(guides, true),
		"pause restores genuine four bars and current defensive marker")
	get_tree().paused = false
	property.refresh_actor_presentation(lab)
	var marker: MeshInstance3D = lab._pitch_target_marker
	var foreign: MeshInstance3D = MeshInstance3D.new()
	foreign.name = "PitchTarget"
	foreign.visible = true
	lab._pitch_target_marker = foreign
	_check(not guides.owners_intact() and not R.callback_bound(lab, property),
		"same-named foreign guide cannot replace current captured owner")
	guides.refresh()
	_check(not guides._suppressed and foreign.visible and _guide_visibility(guides, true),
		"binding loss restores admitted originals without suppressing foreign guide")
	lab._pitch_target_marker = marker
	foreign.free()
	property.refresh_actor_presentation(lab)
	lab._match_state.top_half = old_half
	PitchBatLabPresentation.sync_players(lab)
	property.refresh_actor_presentation(lab)
	_check(not guides._suppressed, "offensive role restores defensive-only suppression")
	property.restore_presentations()
	_check(not guides._suppressed and property.callback_intact(),
		"explicit presentation restoration retains same issued owner")
	lab._match_state.phase = old_phase
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera.global_transform = camera_pose
	await _release_ball(lab, ball)


func _guide_visibility(guides: StadiumNpcAc02PublicGuides, visible: bool) -> bool:
	for row: Dictionary in guides._guides:
		var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		if mesh == null or mesh.visible != visible or mesh.mesh != row.mesh \
			or mesh.material_override != row.material:
			return false
	return true


func _ball_guards(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var ball: BattedBallBody = _new_ball(lab, property, Vector3(0, 2, 10), Vector3.ZERO)
	ball.freeze = true
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var boundary: StadiumNpcAc02PublicBoundary = property.boundary
	var score: Array = _score(lab)
	var before: Array[Dictionary] = property.provenance.duplicate(true)
	var fake: StaticBody3D = StaticBody3D.new()
	fake.set_meta("npc_instance", PREFIX + "RECEIVER-PRIMARY")
	fake.set_meta("owned_copy", PREFIX + "RECEIVER-PRIMARY")
	fake.set_meta("surface_id", "ST026_PANEL")
	lab.add_child(fake)
	property._ball_contact(fake, ball, resolver)
	property._boundary_contact_batch(ball,
		[{"body": boundary.bodies[0], "position": Vector3.ZERO}], resolver)
	_check(property.provenance == before and resolver.state.stadium_contacts.is_empty()
		and _score(lab) == score,
		"forged body and fabricated native manifold get no provenance or result")
	fake.free()
	var other: BallPlayResolver = BallPlayResolver.new()
	other.start_play(property.field, false)
	_check(not property._ball_owned(ball, other)
		and property.observe(other, Vector3.ZERO, Vector3.ONE).is_empty(),
		"foreign resolver cannot borrow current ball or segment observer")
	var remembered: int = boundary._resolver_ids[ball.get_instance_id()]
	boundary._resolver_ids[ball.get_instance_id()] = -1
	_check(not R.callback_bound(lab, property), "stale per-ball resolver map rejects issued callback")
	boundary._resolver_ids[ball.get_instance_id()] = remembered
	lab._batted_ball = null
	_check(not property._ball_owned(ball, resolver), "stale non-current ball refuses")
	lab._batted_ball = ball
	_check(property.callback_intact(), "restored exact ball lifetime remains issued")
	_check(not R.teardown(lab), "active actual ball blocks idle teardown")
	await _release_ball(lab, ball)
	_check(boundary._bound_balls.is_empty() and boundary._previous.is_empty()
		and boundary._resolver_ids.is_empty() and boundary.last_live.is_empty(),
		"actual ball exit clears all Club lifetime maps")


func _terminal_physics(lab: PitchBatLab, property: StadiumNpcPublicProperty, probe: String) -> void:
	var receiver: bool = probe == "receiver"
	var start: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3(0, 0, -4)
	if receiver:
		for body: Dictionary in _reference.bodies:
			if body.role == "RECEIVER_CONTAINMENT_FOUL" and body.segment == "ST026_PANEL":
				start = body.shapes[0].inverse.affine_inverse().origin + Vector3(0, 0, 0.8)
				break
	else:
		var segment: Dictionary = _reference.segments["BACK-02" if probe == "low-wall" else "BACK-03"]
		var center: Vector2 = (segment.a + segment.b) / 2
		var normal: Vector2 = StadiumRecipeBoundary.inward(segment)
		start = Vector3(center.x + normal.x * 0.8, 1, center.y + normal.y * 0.8)
		velocity = Vector3(-normal.x, 0, -normal.y) * 4
	_check(start != Vector3.ZERO, "native probe derives exact actual collision location " + probe)
	var ball: BattedBallBody = _new_ball(lab, property, start, velocity)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	for tick in range(60):
		await get_tree().physics_frame
		resolver.advance_time(1.0 / 60.0)
		await get_tree().process_frame
		if resolver.state.dead or property.suspended:
			break
	if not resolver.state.dead or resolver.state.stadium_contacts.is_empty():
		_failed_contact(probe, ball, resolver, property, start, velocity)
	ball.freeze = true
	var events: Array[Dictionary] = resolver.state.stadium_contacts
	var role: String = "RECEIVER_CONTAINMENT_FOUL" if receiver else "BACK_WALL_TERMINAL"
	var valid: bool = resolver.state.dead and not events.is_empty() and events[-1].role == role
	_check(valid, "genuine native ball contact retains original Club terminal rule " + probe)
	if valid:
		_physical_contacts += 1
		_check(events[-1].source == "boundary"
			and StadiumNpcPublicContacts._event(events[-1], _reference)
			and StadiumNpcPublicContacts._provenance(property.provenance, _reference),
			"actual native ball position and public contact provenance satisfy report17")
		if receiver:
			var witnessed: bool = false
			for contact: Dictionary in property.provenance:
				witnessed = witnessed or (contact.instance == PREFIX + "RECEIVER-PRIMARY"
					and contact.surface == "ST026_PANEL")
			_check(witnessed, "native receiver contact carries exact actual public copy and surface")
		var play: Dictionary = {"contact": ContactResult.Outcome.CONTACT,
			"exit_speed": velocity.length(), "result": "foul" if receiver else "triple"}
		var row: Dictionary = {"play": 0,
			"reason": "stadium_receiver" if receiver else "back_wall_on_fly",
			"events": events.duplicate(true)}
		_check(StadiumNpcPublicContacts._rows([row], [play], _reference),
			"schema-only native terminal row preserves exact report17 reason")
		var bad: Dictionary = events[-1].duplicate(true)
		bad.id = "PROTOTYPE-CLUB-DUGOUT-LEFT-LOFT-v1"
		_check(not StadiumNpcPublicContacts._event(bad, _reference),
			"foreign graph cannot borrow actual AC02 hit")
	await _release_ball(lab, ball)


func _new_ball(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	position_value: Vector3, velocity: Vector3) -> BattedBallBody:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(property.field, false)
	_check(R.bind_ball(lab, ball, lab._ball_play_resolver)
		and ball.physics_contact_router == property._boundary_contact_batch.bind(lab._ball_play_resolver)
		and ball.launch_started.is_connected(property.boundary._seed.bind(ball.get_instance_id())),
		"real ball uses current public Club router and launch seed")
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = position_value
	launch.velocity = velocity
	ball.launch(launch)
	return ball


func _release_ball(lab: PitchBatLab, ball: BattedBallBody) -> void:
	ball.freeze = true
	lab._batted_ball = null
	ball.free()
	lab._at_bat_cadence.stop()
	await get_tree().process_frame


func _failed_contact(label: String, ball: BattedBallBody, resolver: BallPlayResolver,
	property: StadiumNpcPublicProperty, start: Vector3, launch_velocity: Vector3) -> void:
	# One failure-only passive row per bounded probe, before the fixture freezes its ball.
	var bodies: Array[String] = []
	for body: Node3D in ball.get_colliding_bodies():
		bodies.append(String(body.get_path()))
	var position_value: Vector3 = ball.global_position
	var velocity: Vector3 = ball.linear_velocity
	print("AC02_PUBLIC_CONTACT_FAILURE " + JSON.stringify({"probe": label,
		"start": [start.x, start.y, start.z],
		"launch_velocity": [launch_velocity.x, launch_velocity.y, launch_velocity.z],
		"position": [position_value.x, position_value.y, position_value.z],
		"velocity": [velocity.x, velocity.y, velocity.z], "freeze": ball.freeze,
		"sleeping": ball.sleeping, "started": ball._started, "can_process": ball.can_process(),
		"native_contacts": ball.get_contact_count(), "colliding_bodies": bodies,
		"events": resolver.state.stadium_contacts.size(), "dead": resolver.state.dead,
		"elapsed": resolver.state.elapsed_seconds, "owner_suspended": property.suspended,
		"router_valid": ball.physics_contact_router.is_valid(), "paused": get_tree().paused,
		"physics_frame": Engine.get_physics_frames()}, "", true, true))


func _writer_retirement(season: SeasonState, resource_change: bool) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	var original: StaticBody3D = property.boundary.bodies[0]
	if resource_change:
		var collider: CollisionShape3D = original.get_child(0)
		var shape: ConvexPolygonShape3D = collider.shape as ConvexPolygonShape3D
		_check(shape != null and shape.points.size() == 8 and shape.margin == 0,
			"actual authored wall is an eight-point zero-margin prism")
		if shape != null:
			var points: PackedVector3Array = shape.points.duplicate()
			var changed: PackedVector3Array = points.duplicate()
			changed[0].x = _next_float32(changed[0].x)
			shape.points = changed
			_check(property.suspended and not property.issued,
				"real static shape Resource.changed retires issued authority")
			shape.points = points
	else:
		var container: Node = original.get_parent()
		var replacement: StaticBody3D = original.duplicate()
		property.retire_installation("AC02 test supported wall body replacement")
		container.remove_child(original)
		container.add_child(replacement)
		_check(not property._bodies.has(replacement) and replacement != original,
			"copied physical body and metadata cannot replace captured body membership")
		container.remove_child(replacement)
		container.add_child(original)
		replacement.free()
	_check(property.suspended and not property.issued and not property.callback_intact()
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED,
		"static retirement stays sticky after exact restore")
	_check(not R.rebind_match(lab) and not R.install_bound(lab)
		and PhysicalMatchReport.capture(lab).is_empty() and _score(lab) == score
		and lab._throw_number == 0 and lab._play_records.is_empty(),
		"restored source cannot reissue, fall back or create gameplay evidence")
	_complete_case("resource-retirement" if resource_change else "writer-retirement", before)
	lab.free()
	await get_tree().process_frame


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
		push_error("AC02_PUBLIC_RUNTIME " + label)


func _complete_case(label: String, before: Array[int]) -> void:
	if _checks > before[0] and _failures == before[1]:
		_cases += 1
	print("AC02_PUBLIC_CASE case=%s checks=%d failures=%d" %
		[label, _checks - before[0], _failures - before[1]])
