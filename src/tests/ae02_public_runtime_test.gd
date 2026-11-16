extends Node3D
## Two saved-fixture installs; bounded real physics probes, no fabricated ContactResult or game.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FIXTURE = preload("res://src/tests/ae02_public_fixture.gd")
const PREFIX: String = "npc:AE-02:r1:"
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0
var _cone_contacts: int = 0
var _reference: Dictionary = {}
var _live_event: Dictionary = {}
var _initial_msaa: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_initial_msaa = get_viewport().msaa_3d
	_check(not R.install_bound(null) and not R.installed_bound(null, {})
		and not R.bind_ball(null, null, null) and not R.teardown(null), "null operations fail closed")
	_check(R.source_qualified(), "current exact concrete source family qualifies")
	var prepared: SeasonState = FIXTURE.season()
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(SeasonSave.snapshot(prepared), "", true, true))) if prepared != null else null
	_check(season != null, "actual full-precision saved Base fixture restores")
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		_reference = StadiumNpcPublicContacts._reference(StadiumNpcSnapshot.capture("AE-02", 1))
		_check(not _reference.is_empty(), "one reference reused for genuine contact probes")
		await _lifecycle(season)
		await _writer_retirement(season)
		_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
			"bounded probes preserve saved assignments, stock, rewards and result history")
	await TestAudioDrain.finish(get_tree())
	print("AE02_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print(("AE02_PUBLIC_RUNTIME_COVERAGE installs=%d completed_cases=%d "
		+ "cone_contacts=%d completed_games=0") %
		[_installs, _cases, _cone_contacts])
	get_tree().quit(0 if _failures == 0 and _installs == 2 and _cases == 2
		and _cone_contacts == 4 else 1)


func _lab(season: SeasonState) -> PitchBatLab:
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty() and fixture.id == 0, "real saved opening fixture")
	if fixture.is_empty():
		return null
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(not lab.yard_bound_startup_failed and R.installed_bound(lab, lab._match_state.stadium),
		"actual saved fixture installs through ordinary public startup")
	if lab.yard_bound_startup_failed or R._property(lab) == null:
		lab.free()
		return null
	_installs += 1
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	return lab


func _lifecycle(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	_topology(lab, property)
	_dynamic_refusals(lab, property, season)
	_camera_entry(lab, property)
	await get_tree().physics_frame
	for site: String in ["O-L1", "O-R1"]:
		for surface: String in ["CONE_BODY", "CONE_BASE"]:
			await _cone_physics(lab, property, site, surface)
	await _presentation(lab, property)
	await _terminal_physics(lab, property, true)
	await _terminal_physics(lab, property, false)
	_check(property.callback_intact() and R.installed_bound(lab, lab._match_state.stadium),
		"issued callbacks and one final cold installation audit agree")
	_check(lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "physical probes create no completed report")
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
		"teardown restores original field, camera, receiver and route owners")
	_check(not R.installed(lab) and lab.has_meta(R.PUBLIC_BOUND)
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and not lab.has_meta("stadium_snapshot") and not R.install_bound(lab),
		"teardown remains sticky and cannot silently fall back")
	_complete_case("lifecycle", before)
	lab.free()
	await get_tree().process_frame


func _topology(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(property.venue_id == "AE-02" and property.public_bound and property.issued
		and property.objects.size() == 33 and property.field.id == &"field.npc_venue"
		and typeof(property.field.id) == TYPE_STRING_NAME
		and not lab.has_meta("stadium_candidate_only")
		and not lab.has_meta("stadium_npc_retained_lab_only")
		and lab._stadium_ledger == null, "33 public copies with issued authority and no human ownership")
	if DisplayServer.get_name() == "headless":
		_check(get_viewport().msaa_3d == _initial_msaa, "headless installation leaves MSAA unchanged")
	var lights: int = 0
	var cones: int = 0
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null and property.construction.is_ancestor_of(model)
			and model.get_meta("npc_instance", "") == row.instance
			and model.get_meta("stadium_item", "") == row.item, "exact installed copy " + row.instance)
		if model == null:
			continue
		if row.item == "ST-037":
			lights += 1
			var beam: SpotLight3D = model.get_node("FieldLight")
			var lens: MeshInstance3D = model.get_node("Visual/LampLens")
			_check(not beam.visible and not lens.material_override.emission_enabled,
				"authored yard light remains dormant " + row.site)
		elif row.item == "ST-001":
			cones += 1
			for surface: String in ["CONE_BASE", "CONE_BODY"]:
				var body: StaticBody3D = model.get_node("Collision/" + surface)
				_check(body.collision_layer == 65 and body.collision_mask == 0
					and body.get_meta("npc_instance", "") == row.instance
					and body.get_meta("owned_copy", "") == row.instance
					and body.get_meta("surface_role", "") == "LIVE_RICOCHET"
					and body.get_meta("surface_id", "") == surface, "authentic live cone body " + surface)
	_check(lights == 4 and cones == 2 and lab._match_state.stadium.environment.mode == "day",
		"four dormant lights and exactly two live cone units")
	var routes: Array[Dictionary] = property.route_obstacles()
	var ids: Array = []
	for route: Dictionary in routes:
		ids.append(route.copy)
		var start: Vector3 = route.center + Vector3(-route.radius - 0.25, 0, 0)
		var finish: Vector3 = route.center + Vector3(route.radius + 0.25, 0, 0)
		var clipped: Vector3 = StadiumDefenderRoutes.clip(start, finish, routes)
		_check(not StadiumDefenderRoutes.clear(start, finish, routes)
			and clipped.distance_to(start) < finish.distance_to(start),
			"actual obstacle clips route " + route.copy)
	ids.sort()
	_check(ids == [PREFIX + "O-L1", PREFIX + "O-R1",
		PREFIX + "RECEIVER-CATCH", PREFIX + "RECEIVER-PRIMARY"]
		and lab._primary_fielder.stadium_obstacles == routes
		and lab._ball_play_resolver.segment_observer == property.observe
		and lab._primary_fielder.stadium_boundary_clip == property.clip,
		"both cone plus paired receiver clearances reach actual fielder and resolver")


func _dynamic_refusals(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	season: SeasonState) -> void:
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[key] += 1
		_check(not R.callback_bound(lab, property), "fresh binding refuses " + key)
		lab._match_state.stadium = snapshot.duplicate(true)
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, FIXTURE.fixture(season))
	_check(not R.callback_bound(lab, property), "replacement match cannot borrow issued owner")
	lab._match_state = state
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(snapshot.binding.owner_club))
	_check(not R.callback_bound(lab, property), "removed saved owner revokes callbacks")
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
	_check(property.callback_intact() and not R.install_bound(lab)
		and not R.bind_ball(lab, null, lab._ball_play_resolver),
		"valid issued owner rejects duplicate entry")


func _camera_entry(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(lab._camera_director.get_script() == StadiumNpcAe02PublicCamera
		and lab._pitch_actor.receiver_router == property.receiver_route
		and property.display._match == lab._match_state, "actual camera, receiver and scoreboard paired")
	for left: bool in [false, true]:
		lab._camera_director.set_batter_handedness(left)
		lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
		lab._camera_director.snap(lab._camera)
		_check(is_equal_approx(lab._camera.position.z, -6.5), "authored precontact entry both hands")
	var visibility: StadiumNpcAe02PublicVisibility = lab._camera_director.tracking_visibility
	_check(visibility != null and not visibility.active()
		and visibility.constrain_target(Vector3(100, 2, 0)) == Vector3(100, 2, 0),
		"side-target rule stays inactive before live ball")


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
		and ball.body_entered.is_connected(property._ball_contact.bind(ball, lab._ball_play_resolver)),
		"real ball uses existing body-entered public callback")
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


func _cone_physics(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	site: String, surface: String) -> void:
	var model: Node3D = property.objects[PREFIX + site]
	var height: float = 0.27 if surface == "CONE_BODY" else 0.065
	var start: Vector3 = model.global_position + Vector3(-0.7, height, 0)
	var ball: BattedBallBody = _new_ball(lab, property, start, Vector3(4, 0, 0))
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var score: Array = _score(lab)
	var fake: StaticBody3D = StaticBody3D.new()
	fake.set_meta("npc_instance", PREFIX + site)
	fake.set_meta("owned_copy", PREFIX + site)
	fake.set_meta("surface_id", surface)
	fake.set_meta("surface_role", "LIVE_RICOCHET")
	lab.add_child(fake)
	var original: Array[Dictionary] = property.provenance.duplicate(true)
	property._ball_contact(fake, ball, resolver)
	var other: String = "O-R1" if site == "O-L1" else "O-L1"
	property._ball_contact(property.objects[PREFIX + other].get_node("Collision/" + surface),
		ball, resolver)
	_check(resolver.state.stadium_contacts.is_empty() and property.provenance == original
		and _score(lab) == score, "forged and authentic-but-noncolliding bodies cannot invent contact")
	fake.free()
	for tick in range(45):
		await get_tree().physics_frame
		resolver.advance_time(1.0 / 60.0)
		await get_tree().process_frame
		if not resolver.state.stadium_contacts.is_empty() or property.suspended:
			break
	if resolver.state.stadium_contacts.is_empty():
		_failed_contact(site + "/" + surface, ball, resolver, property, start, Vector3(4, 0, 0))
	ball.freeze = true
	var contacts: Array[Dictionary] = resolver.state.stadium_contacts
	var event: Dictionary = contacts[0] if not contacts.is_empty() else {}
	_check(not event.is_empty() and event.source == "item" and event.kind == "contact"
		and event.id == PREFIX + site and event.surface == surface and event.role == "LIVE_RICOCHET"
		and not resolver.state.dead and resolver.state.last_obstacle_contact == StringName(PREFIX + site),
		"genuine physics body-entered cone contact stays live " + site + "/" + surface)
	if not event.is_empty():
		_check(StadiumNpcPublicContacts._event(event, _reference)
			and StadiumNpcPublicContacts._provenance(property.provenance, _reference),
			"actual ball-position event and provenance validate under report17")
		if event.id == PREFIX + site and event.surface == surface:
			_cone_contacts += 1
		_live_event = event.duplicate(true)
		for key: String in ["id", "surface", "role"]:
			var bad: Dictionary = event.duplicate(true)
			bad[key] = "forged"
			_check(not StadiumNpcPublicContacts._event(bad, _reference),
				"changed genuine contact refuses " + key)
		var bad: Dictionary = event.duplicate(true)
		bad.position = [500, 500, 500]
		_check(not StadiumNpcPublicContacts._event(bad, _reference), "remote cone contact rejects")
	_check(_score(lab) == score, "live cone hit alone creates no score, terminal or play record")
	await _release_ball(lab, ball)


func _terminal_physics(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	receiver: bool) -> void:
	var position_value: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3(0, 0, -4)
	if receiver:
		for body: Dictionary in _reference.items:
			if body.surface == "ST026_PANEL":
				position_value = body.shapes[0].inverse.affine_inverse().origin + Vector3(0, 0, 0.8)
				break
	else:
		for segment: Dictionary in _reference.segments.values():
			if segment.role == "BACK_WALL_TERMINAL":
				var center: Vector2 = (segment.a + segment.b) / 2
				var normal: Vector2 = StadiumRecipeBoundary.inward(segment)
				position_value = Vector3(center.x + normal.x * 0.8, 1, center.y + normal.y * 0.8)
				velocity = Vector3(-normal.x, 0, -normal.y) * 4
				break
	_check(position_value != Vector3.ZERO, "terminal probe uses exact actual collision shape")
	var ball: BattedBallBody = _new_ball(lab, property, position_value, velocity)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	for tick in range(60):
		await get_tree().physics_frame
		resolver.advance_time(1.0 / 60.0)
		await get_tree().process_frame
		if resolver.state.dead or property.suspended:
			break
	if not resolver.state.dead or resolver.state.stadium_contacts.is_empty():
		_failed_contact("receiver" if receiver else "back-wall", ball, resolver, property,
			position_value, velocity)
	ball.freeze = true
	var events: Array[Dictionary] = resolver.state.stadium_contacts
	var expected: String = "RECEIVER_CONTAINMENT_FOUL" if receiver else "BACK_WALL_TERMINAL"
	_check(resolver.state.dead and not events.is_empty() and events[-1].role == expected,
		"genuine physical terminal uses unchanged rule " + expected)
	if not events.is_empty():
		var play: Dictionary = {"contact": ContactResult.Outcome.CONTACT, "exit_speed": velocity.length(),
			"result": "foul" if receiver else "triple"}
		var row: Dictionary = {"play": 0,
			"reason": "receiver_containment" if receiver else "back_wall_on_fly",
			"events": events.duplicate(true)}
		_check(StadiumNpcPublicContacts._rows([row], [play], _reference),
			"schema-only genuine terminal rows retain report17 rules")
		if not _live_event.is_empty():
			row.events.append(_live_event.duplicate(true))
			_check(not StadiumNpcPublicContacts._rows([row], [play], _reference),
				"genuine live event cannot be moved after terminal")
		var count: int = events.size()
		property._ball_contact(property.objects[PREFIX + "O-L1"].get_node("Collision/CONE_BODY"),
			ball, resolver)
		_check(resolver.state.stadium_contacts.size() == count, "dead state cannot receive cone credit")
	await _release_ball(lab, ball)


func _failed_contact(label: String, ball: BattedBallBody, resolver: BallPlayResolver,
	property: StadiumNpcPublicProperty, start: Vector3, launch_velocity: Vector3) -> void:
	# One failure-only passive row per bounded probe, before the fixture freezes its ball.
	var bodies: Array[String] = []
	for body: Node3D in ball.get_colliding_bodies():
		bodies.append(String(body.get_path()))
	var position_value: Vector3 = ball.global_position
	var velocity: Vector3 = ball.linear_velocity
	print("AE02_PUBLIC_CONTACT_FAILURE " + JSON.stringify({"probe": label,
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


func _presentation(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var model: Node3D = property.objects[PREFIX + "O-L1"]
	var body: StaticBody3D = model.get_node("Collision/CONE_BODY")
	var collider: CollisionShape3D = body.get_child(0)
	var physical: Array = [body.global_transform, body.collision_layer, body.collision_mask,
		collider.shape, collider.disabled]
	var camera_pose: Transform3D = lab._camera.global_transform
	var phase: MatchState.Phase = lab._match_state.phase
	var ball: BattedBallBody = _new_ball(lab, property,
		model.global_position + Vector3(0, 0.27, 2), Vector3.ZERO)
	ball.freeze = true
	lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	lab._camera.global_position = model.global_position + Vector3(0, 0.27, -2)
	lab._camera.look_at(ball.global_position)
	property.refresh_actor_presentation(lab)
	_check(not R.teardown(lab), "active real ball blocks idle teardown")
	var study: StadiumNpcRetainedActorCutaway = property.ae02_actors.cone_study
	_check(_faded(study) == 3 and not study.last_hits.is_empty(),
		"genuine camera-to-ball obstruction fades three authored cone Visual meshes")
	_check([body.global_transform, body.collision_layer, body.collision_mask,
		collider.shape, collider.disabled] == physical, "cone fade leaves actual collision unchanged")
	_check(R.installed_bound(lab, lab._match_state.stadium)
		and StadiumNpcPublicContacts._provenance(property.provenance, _reference),
		"report17 cold entry and genuine provenance accept the still-active authored cone fade")
	var visibility: StadiumNpcAe02PublicVisibility = lab._camera_director.tracking_visibility
	_check(visibility.active(), "current issued live offense enables side-target constraint")
	for desired: Vector3 in [Vector3(100, 2, 0), Vector3(-100, 2, 0)]:
		var constrained: Vector3 = visibility.constrain_target(desired)
		for row: Array in visibility.canonical_side_state():
			var gap: float = (Vector2(constrained.x, constrained.z) - row[1]).dot(row[3])
			_check(gap >= 1.2 - 0.00001, "authored current side half-plane keeps1.2m target clearance")
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	property.refresh_actor_presentation(lab)
	_check(_restored(study) and not visibility.active(),
		"nonlive camera restores exact cone materials")
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	var meshes: Array[Node] = lab._batter_avatar.find_children("*", "MeshInstance3D", true, false)
	_check(not meshes.is_empty(), "actual batter has rigid rendered meshes")
	if not meshes.is_empty():
		var mesh: MeshInstance3D = meshes[0] as MeshInstance3D
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		lab._camera.global_position = center + Vector3(0, 0, -2)
		ball.global_position = center + Vector3(0, 0, 2)
		lab._camera.look_at(ball.global_position)
		property.refresh_actor_presentation(lab)
		_check(_faded(property.actor_cutaway) > 0, "genuine batter obstruction retains avatar cutaway")
	get_tree().paused = true
	property.refresh_actor_presentation(lab)
	_check(_restored(study) and _restored(property.actor_cutaway),
		"pause restores authored actor and cone cutaways")
	get_tree().paused = false
	property.restore_presentations()
	_check(_restored(study) and _restored(property.actor_cutaway),
		"explicit lifecycle restoration returns exact actor and cone originals")
	lab._match_state.phase = phase
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera.global_transform = camera_pose
	await _release_ball(lab, ball)
	_check(property.callback_intact(), "fade restoration preserves same issued installation")


func _faded(study: StadiumNpcRetainedActorCutaway) -> int:
	var count: int = 0
	for entry: Dictionary in study.entries.values():
		if entry.faded:
			var mesh: MeshInstance3D = entry.mesh.get_ref()
			_check(mesh.material_override == entry.fade_material
				and is_equal_approx(entry.fade_material.albedo_color.a, 0.2)
				and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"active fade uses exact authored alpha and presentation-only shadow policy")
			count += 1
	return count


func _restored(study: StadiumNpcRetainedActorCutaway) -> bool:
	for entry: Dictionary in study.entries.values():
		var mesh: MeshInstance3D = entry.mesh.get_ref()
		if mesh == null or entry.faded or mesh.material_override != entry.original_material \
			or mesh.cast_shadow != entry.shadow:
			return false
	return true


func _writer_retirement(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	var model: Node3D = property.objects[PREFIX + "O-L1"]
	var original: StaticBody3D = model.get_node("Collision/CONE_BODY")
	var container: Node = original.get_parent()
	var replacement: StaticBody3D = original.duplicate()
	property.retire_installation("AE02 test supported cone body replacement")
	container.remove_child(original)
	container.add_child(replacement)
	replacement.name = "CONE_BODY"
	_check(not property._bodies.has(replacement)
		and replacement.get_meta("npc_instance", "") == PREFIX + "O-L1",
		"copied genuine metadata cannot replace captured physical body membership")
	container.remove_child(replacement)
	container.add_child(original)
	replacement.free()
	_check(property.suspended and not property.issued and not property.callback_intact()
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED, "supported writer retires before static edit")
	_check(not R.rebind_match(lab) and not R.install_bound(lab)
		and PhysicalMatchReport.capture(lab).is_empty() and _score(lab) == score
		and lab._throw_number == 0 and lab._play_records.is_empty(),
		"restored original body cannot reissue authority, fall back or create gameplay evidence")
	_complete_case("writer-retirement", before)
	lab.free()
	await get_tree().process_frame


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AE02_PUBLIC_RUNTIME " + label)


func _complete_case(label: String, before: Array[int]) -> void:
	if _checks > before[0] and _failures == before[1]:
		_cases += 1
	print("AE02_PUBLIC_CASE case=%s checks=%d failures=%d" %
		[label, _checks - before[0], _failures - before[1]])
