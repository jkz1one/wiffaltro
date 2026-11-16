extends Node3D
## Raw fixture17 qualification only. No production dispatcher or candidate opt-in is used.
# gdlint: disable=max-file-lines

const IDS: Array[String] = ["AY-01", "AE-01", "AC-01"]
const MATCH_SEED: int = 210017
const ENVIRONMENT_SEED: int = 76003
const COMMON_FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
var _runtime: Script = StadiumNpcRuntime
var _context: StadiumNpcQualificationContext
var _qualification_field: FieldDefinition
var _failures: int = 0
var _revision: int = 2


func _ready() -> void:
	_check(not _runtime.install_bound(null, null), "null install fails closed")
	_check(not _runtime.installed(null, null), "null lab has no installation")
	_check(not _runtime.teardown(null), "null teardown fails closed")
	for id: String in IDS:
		# Positive control comes first for every venue. Admission failure cannot make
		# an all-negative integrity suite appear successful.
		await _lifecycle(id)
		_context_guards(id)
		_startup_guards(id)
		_staging(id)
		await _whole_lab_removal(id)
		await _quarantine(id, false)
		await _quarantine(id, true)
		await _quarantine(id, false, true)
		for mode: String in ["detach", "free", "live-ball", "live-pitch"]:
			await _unexpected_removal(id, mode)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro NPC bound runtime passed: raw fixture17 binding, geometry and lifecycle.")
	get_tree().quit(0 if _failures == 0 else 1)


func _binding(id: String) -> Dictionary:
	# These expectations are caller-owned inputs, never copied out of a tested envelope.
	return {
		"season_id": "0123456789abcdef0123456789abcdef",
		"assignment_key": "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
		"owner_club": 2, "venue_id": id, "venue_revision": 2,
		"fixture": 7, "away": 0, "batting_home": 2, "neutral": false,
		"match_seed": MATCH_SEED, "field": "field.npc_venue"
	}


func _environment() -> Dictionary:
	return {"version": 1, "seed": ENVIRONMENT_SEED, "fixture": 7, "mode": "day", "profile": ""}


func _fixture(id: String) -> Dictionary:
	return StadiumNpcSnapshot.raw_fixture(
		StadiumNpcSnapshot.raw_entry(id, 2), _binding(id), _environment())


func _lab(id: String) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	# _ready() follows the unchanged ordinary path with an empty stadium.
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(lab._match_state.stadium.is_empty(), "ordinary startup has no fabricated NPC admission")
	_check(not lab.has_meta("stadium_property"), "generic startup has not dispatched raw fixture17")
	lab._match_state.stadium = _fixture(id)
	_qualification_field = COMMON_FIELD.duplicate(true) as FieldDefinition
	_context = StadiumNpcQualificationContext.create(
		lab._match_state, _binding(id), _environment(), _qualification_field, MATCH_SEED)
	_check(_context != null, "independently bound raw context is valid " + id)
	return lab


func _lifecycle(id: String) -> void:
	var lab: PitchBatLab = _lab(id)
	lab.set_meta("unrelated_test_metadata", {"preserve": [1, 2, 3]})
	var old_receiver: Callable = func(
		_actor: PitchFlightActor, _start: Vector3, _velocity: Vector3
	) -> bool: return false
	lab._pitch_actor.receiver_router = old_receiver
	# Ordinary managed startup may already have selected DELIVERY, without a release.
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	var before: Dictionary = _scene_state(lab)
	var snapshot_bytes: String = JSON.stringify(lab._match_state.stadium, "", true, true)
	var public_bytes: String = JSON.stringify(StadiumNpcVenues.definition(id, 2), "", true, true)
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = JSON.stringify(ledger.to_data(), "", true, true)
	_check(_runtime.install_bound(lab, _context), "explicit fresh DELIVERY install " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	_check(_runtime.installed(lab, _context), "first post-startup installed validation " + id)
	lab._at_bat_cadence.stop()
	_identity(lab, property)
	_refused(lab, _context, "reentrant install")
	_integrity(lab, property)
	_additional_integrity(lab, property)
	_reference_integrity(lab, property)
	_resealed_forgery(lab, true)
	_teardown_guards(lab)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if id != "AY-01":
		_receiver(lab, property)
		_receiver_visibility(lab, property)
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT)
		PitchBatLabPresentation.sync_players(lab)
		_routes(lab, property)
	for sample: Array in [
		[Vector3(0, 4, 27.3 if id == "AC-01" else 20), Vector3(0, 0, 36), false,
			BallPlayOutcome.Result.HOME_RUN],
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.1, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL]
	]:
		await _flight(lab, property, sample)
	lab._automation = MatchAutomation.new()
	lab._automation.seed = MATCH_SEED
	lab._automation.begin(lab)
	lab._at_bat_cadence.stop()
	var had_snapshot: bool = lab.has_meta("stadium_snapshot")
	var old_snapshot: Variant = lab.get_meta("stadium_snapshot") if had_snapshot else null
	var injected_snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	_check(StadiumNpcSnapshot.raw_envelope_valid(injected_snapshot),
		"report-refusal metadata probe uses the actual complete raw fixture17")
	lab.set_meta("stadium_snapshot", injected_snapshot)
	_check(not _runtime.installed(lab, _context),
		"raw snapshot metadata cannot grant runtime authority")
	_check(PhysicalMatchReport.capture(lab).is_empty(), "raw gameplay cannot emit a public report")
	if had_snapshot:
		lab.set_meta("stadium_snapshot", old_snapshot)
	else:
		lab.remove_meta("stadium_snapshot")
	_check(lab.has_meta("stadium_snapshot") == had_snapshot
		and (not had_snapshot or lab.get_meta("stadium_snapshot") == old_snapshot),
		"report refusal restores exact prior metadata presence and value")
	_check(_runtime.installed(lab, _context), "real bound runtime survives metadata refusal probe")
	lab._automation = null
	_check(not StadiumLayoutSnapshot.valid(lab._match_state.stadium),
		"raw qualification has no public layout admission")
	_check(not StadiumNpcSnapshot.valid(lab._match_state.stadium)
		and StadiumNpcSnapshot.key(lab._match_state.stadium).is_empty(),
		"public NPC admission remains P after real gameplay")
	_check(snapshot_bytes == JSON.stringify(lab._match_state.stadium, "", true, true),
		"gameplay preserves the complete raw fixture")
	_check(public_bytes == JSON.stringify(StadiumNpcVenues.definition(id, 2), "", true, true)
		and ledger_bytes == JSON.stringify(ledger.to_data(), "", true, true),
		"qualification never mutates public definitions or human ownership")
	_restart_bound(lab, id)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(_runtime.teardown(lab), "idle bound runtime teardown " + id)
	_check(before == _scene_state(lab), "teardown restores exact nodes/order/metadata/callbacks " + id)
	_check(lab._pitch_actor.receiver_router == old_receiver, "arbitrary original receiver is restored")
	_check(not _runtime.installed(lab, _context), "teardown revokes installed status")
	_check(not _runtime.teardown(lab), "second teardown is harmless")
	_check(_runtime.install_bound(lab, _context) and _runtime.installed(lab, _context),
		"same independently bound context reinstalls after clean teardown")
	_check(_runtime.teardown(lab), "reinstall tears down cleanly")
	lab.free()
	await get_tree().process_frame


func _identity(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var definition: Dictionary = StadiumNpcVenues.definition(property.venue_id, 2)
	var counts: Dictionary = {"AY-01": 4, "AE-01": 27, "AC-01": 72}
	_check(property is StadiumNpcBoundProperty, "runtime uses its separate bounded property lifecycle")
	_check(property.objects.size() == counts[property.venue_id], "actual independent object count")
	_check(lab._field_definition == _qualification_field and property.field == _qualification_field
		and property.construction.field == _qualification_field,
		"caller-approved concrete field reference reaches the complete construction")
	_check(property.field != COMMON_FIELD and property.field.get_script() == COMMON_FIELD.get_script(),
		"common field stays detached and uses the trusted concrete sport script")
	_check(property.construction.get_parent() == property, "authentic construction remains installed")
	_check(not lab.has_meta("stadium_npc_retained_lab_only")
		and not lab.has_meta("stadium_candidate_only"), "no candidate/lab-only authority shortcuts")
	for row: Dictionary in definition.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(is_instance_valid(model) and model.get_meta("npc_instance", "") == row.instance
			and model.get_meta("stadium_item", "") == row.item,
			"real revision2 model and item exist " + row.instance)
		if is_instance_valid(model):
			_check(model.get_meta("owned_copy", "") == row.instance,
				"legacy contact alias uses NPC identity, not human ownership")
	if property.venue_id == "AY-01":
		_check(property.receiver == null and property.display == null
			and property.route_obstacles().is_empty(), "AY preserves its zero receiver/board policy")
	else:
		_check(property.receiver != null and property.display._match == lab._match_state,
			"real receiver and scoreboard bind the authorized actual match")
		_check(property.route_obstacles() == _expected_routes(property.venue_id)
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles(),
			"both defender routes use independent frozen obstacle reference")


func _context_guards(id: String) -> void:
	var lab: PitchBatLab = _lab(id)
	var before: Dictionary = _scene_state(lab)
	_resealed_forgery(lab, false)
	var binding_changes: Dictionary = {
		"season_id": "fedcba9876543210fedcba9876543210",
		"assignment_key": "1".repeat(64), "owner_club": 3,
		"venue_id": "AE-01" if id == "AY-01" else "AY-01", "venue_revision": 1,
		"fixture": 8, "away": 1, "batting_home": 3, "neutral": true,
		"match_seed": MATCH_SEED + 1, "field": "field.starter_backyard"
	}
	for key: String in binding_changes:
		var expected: Dictionary = _binding(id)
		expected[key] = binding_changes[key]
		var denied: StadiumNpcQualificationContext = StadiumNpcQualificationContext.create(
			lab._match_state, expected, _environment(), _qualification_field, MATCH_SEED)
		_check(denied == null, "independent binding mismatch fails: " + key)
		_refused(lab, denied, "independent binding mismatch " + key)
	var environment_changes: Dictionary = {
		"version": 2, "seed": ENVIRONMENT_SEED + 1, "fixture": 8, "mode": "night", "profile": "other"
	}
	for key: String in environment_changes:
		var expected: Dictionary = _environment()
		expected[key] = environment_changes[key]
		_check(StadiumNpcQualificationContext.create(lab._match_state, _binding(id), expected,
			_qualification_field, MATCH_SEED) == null, "independent environment mismatch " + key)
	_check(StadiumNpcQualificationContext.create(lab._match_state, _binding(id), _environment(),
		_qualification_field, MATCH_SEED + 1) == null, "independent actual match seed mismatch")
	_check(StadiumNpcQualificationContext.create(null, _binding(id), _environment(),
		_qualification_field, MATCH_SEED) == null, "null actual match reference")
	var forged: FieldDefinition = (
		preload("res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new())
	for key: String in StadiumNpcYardV1.FIELD:
		forged.set(key, COMMON_FIELD.get(key))
	_check(StadiumNpcQualificationContext.create(lab._match_state, _binding(id), _environment(),
		forged, MATCH_SEED) == null, "equal exported values cannot spoof the concrete field script")
	var changed: FieldDefinition = COMMON_FIELD.duplicate(true) as FieldDefinition
	changed.back_wall_z_m += 0.001
	_check(StadiumNpcQualificationContext.create(lab._match_state, _binding(id), _environment(),
		changed, MATCH_SEED) == null, "changed common sport values cannot create context")
	var same_bytes: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME)
	same_bytes.stadium = _fixture(id)
	var actual: MatchState = lab._match_state
	lab._match_state = same_bytes
	_refused(lab, _context, "byte-identical fixture on a different MatchState reference")
	lab._match_state = actual
	var wrong_seed: MatchAutomation = MatchAutomation.new()
	wrong_seed.seed = MATCH_SEED + 1
	lab._automation = wrong_seed
	_refused(lab, _context, "live automation seed differs from independently bound match seed")
	lab._automation = null
	var original: Dictionary = lab._match_state.stadium
	lab._match_state.stadium = StadiumNpcSnapshot.raw_entry(id, 2)
	_refused(lab, _context, "entry16 cannot stand in for fixture17")
	lab._match_state.stadium = original
	var mutated: Dictionary = original.duplicate(true)
	mutated.binding.assignment_key = "2".repeat(64)
	lab._match_state.stadium = mutated
	_check(StadiumNpcSnapshot.raw_envelope_valid(mutated), "raw-shaped foreign binding is valid data")
	_refused(lab, _context, "changed valid binding after context qualification")
	lab._match_state.stadium = original
	var field_depth: float = _qualification_field.back_wall_z_m
	_qualification_field.back_wall_z_m += 1
	_refused(lab, _context, "qualified field mutated before installation")
	_qualification_field.back_wall_z_m = field_depth
	_check(before == _scene_state(lab), "all independent context refusals preserve the complete scene")
	_check(_runtime.install_bound(lab, _context) and _runtime.installed(lab, _context),
		"original independent context is a positive control after all mismatches")
	lab._at_bat_cadence.stop()
	_check(_runtime.teardown(lab), "context-guard positive control cleans up")
	lab.free()


func _startup_guards(id: String) -> void:
	var lab: PitchBatLab = _lab(id)
	var unready: PitchBatLab = PitchBatLab.new()
	_check(not _runtime.install_bound(unready, _context),
		"unready lab rejects authentic foreign context")
	unready.free()
	lab._field_id = &"field.unpublished"
	_refused(lab, _context, "nonstarter source field")
	lab._field_id = PitchBatLab.FIELD_ID
	lab.set_meta("stadium_property", {})
	_refused(lab, _context, "malformed existing property")
	lab.remove_meta("stadium_property")
	for flag: String in ["stadium_candidate_only", "stadium_npc_retained_lab_only",
		"stadium_npc_runtime_interrupted", "stadium_npc_runtime_restoring"]:
		lab.set_meta(flag, true)
		_refused(lab, _context, "foreign authority flag " + flag)
		lab.remove_meta(flag)
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	for target: Node in [self, host, host.get_node("PitchReceiverDebug")]:
		target.set_meta("stadium_lab_only", true)
		_refused(lab, _context, "ancestor/host/descendant authoring marker")
		_check(target.get_meta("stadium_lab_only", false), "refusal preserves foreign marker")
		target.remove_meta("stadium_lab_only")
	var home_player: PlayerMatchState = lab._match_state.home_team.roster[0]
	lab._match_state.home_team.roster[0] = lab._match_state.away_team.roster[0]
	_refused(lab, _context, "cross-team duplicate actual player identity")
	lab._match_state.home_team.roster[0] = home_player
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY,
		MatchState.Phase.GAME_END]:
		lab._match_state.phase = phase as MatchState.Phase
		_refused(lab, _context, "logical live or completed match state")
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	host.position.x = 1
	_refused(lab, _context, "nonidentity host transform")
	host.position.x = 0
	lab._batted_ball = BattedBallBody.new()
	_refused(lab, _context, "existing live physical ball")
	lab._batted_ball.free()
	lab._batted_ball = null
	lab._release_controller.begin()
	_refused(lab, _context, "live release gesture")
	lab._release_controller.cancel()
	for state: int in [AtBatCadenceController.State.PITCH_LIVE,
		AtBatCadenceController.State.DEAD_BALL_HOLD]:
		lab._at_bat_cadence.state = state as AtBatCadenceController.State
		_refused(lab, _context, "busy cadence " + str(state))
	lab._at_bat_cadence.state = AtBatCadenceController.State.DELIVERY
	lab._throw_number = 1
	_refused(lab, _context, "DELIVERY after a prior release is not fresh startup")
	lab._throw_number = 0
	lab._match_state.inning = 2
	_refused(lab, _context, "DELIVERY in an advanced inning is not fresh startup")
	lab._match_state.inning = 1
	lab._match_mode = false
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "guard probe creates actual physical pitch flight")
	lab._match_mode = true
	_refused(lab, _context, "running pitch despite logical startup flags")
	lab._pitch_actor.reset_pitch()
	lab.free()


func _staging(id: String) -> void:
	var lab: PitchBatLab = _lab(id)
	var before: Dictionary = _scene_state(lab)
	var staged: StadiumNpcBoundProperty = _runtime._stage(lab, _context)
	_check(staged != null, "raw bound geometry can stage " + id)
	if staged != null:
		_check(before == _scene_state(lab), "staging leaves all original nodes and bindings intact")
		var shape: CollisionShape3D = staged.construction.get_node("PropertyGround").get_child(0)
		(shape.shape as BoxShape3D).size.x += 0.125
		_check(not _runtime._commit(lab, staged, _context), "staged shape damage fails revalidation")
		_check(before == _scene_state(lab), "failed staged geometry commits no scene mutation")
		staged.free()
	staged = _runtime._stage(lab, _context)
	_check(staged != null, "commit-recheck probe starts from authentic staged geometry")
	if staged != null:
		lab._release_controller.begin()
		var busy: Dictionary = _scene_state(lab)
		_check(not _runtime._commit(lab, staged, _context), "commit rechecks newly live release")
		_check(busy == _scene_state(lab), "live-state commit refusal leaves exact scene unchanged")
		lab._release_controller.cancel()
		var snapshot: Dictionary = lab._match_state.stadium
		lab._match_state.stadium = snapshot.duplicate(true)
		lab._match_state.stadium.environment.seed += 1
		var changed: Dictionary = _scene_state(lab)
		_check(not _runtime._commit(lab, staged, _context), "commit rechecks changed fixture binding")
		_check(changed == _scene_state(lab), "binding-recheck failure preserves exact original scene")
		lab._match_state.stadium = snapshot
		staged.free()
	_check(before == _scene_state(lab), "all failed stages restore exact original scene")
	lab.free()


func _refused(lab: PitchBatLab, context: StadiumNpcQualificationContext, reason: String) -> void:
	var before: Dictionary = _scene_state(lab)
	var state: MatchState = lab._match_state
	var stadium: String = JSON.stringify(state.stadium, "", true, true)
	_check(not _runtime.install_bound(lab, context), "reject " + reason)
	_check(before == _scene_state(lab) and lab._match_state == state
		and stadium == JSON.stringify(state.stadium, "", true, true),
		"failed install preserves complete scene and actual state: " + reason)


func _teardown_guards(lab: PitchBatLab) -> void:
	lab._release_controller.begin()
	_teardown_refused(lab, "active release gesture")
	lab._release_controller.cancel()
	lab._at_bat_cadence.state = AtBatCadenceController.State.PITCH_LIVE
	_teardown_refused(lab, "live cadence")
	lab._at_bat_cadence.stop()
	lab._batted_ball = BattedBallBody.new()
	_teardown_refused(lab, "live physical ball")
	lab._batted_ball.free()
	lab._batted_ball = null
	_restored(lab, "")


func _teardown_refused(lab: PitchBatLab, reason: String) -> void:
	var before: Dictionary = _scene_state(lab)
	_check(not _runtime.teardown(lab), "teardown refuses " + reason)
	_check(before == _scene_state(lab), "busy teardown leaves complete geometry and callbacks intact")


func _restored(lab: PitchBatLab, _id: String) -> void:
	_check(_runtime.installed(lab, _context), "restored positive control before independent mutation")


func _invalid_then(lab: PitchBatLab, _id: String, reason: String) -> void:
	_check(not _runtime.installed(lab, _context), "full integrity rejects " + reason)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _integrity(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var id: String = property.venue_id
	var model: Node3D = property.objects.values()[0]
	var owner: Node = model.get_parent()
	var index: int = model.get_index()
	owner.remove_child(model)
	_invalid_then(lab, id, "missing actual NPC object")
	owner.add_child(model)
	owner.move_child(model, index)
	_restored(lab, id)
	var pose: Transform3D = model.transform
	property.set_meta(
		"property_signature", StadiumNpcVenues.key(StadiumNpcVenues.definition(id, _revision))
	)
	property.set_meta("boundary_signature", "copied-valid-signature")
	model.position.x += 0.01
	_invalid_then(lab, id, "changed actual instance transform")
	model.transform = pose
	property.remove_meta("property_signature")
	property.remove_meta("boundary_signature")
	_restored(lab, id)
	var identity: String = model.get_meta("npc_instance")
	model.set_meta("npc_instance", "npc:FOREIGN:r1:FAKE")
	_invalid_then(lab, id, "changed actual NPC identity")
	model.set_meta("npc_instance", identity)
	_restored(lab, id)
	var ground: StaticBody3D = property.construction.get_node("PropertyGround")
	var shape: CollisionShape3D = ground.get_child(0)
	var size: Vector3 = (shape.shape as BoxShape3D).size
	(shape.shape as BoxShape3D).size.x += 0.125
	_invalid_then(lab, id, "changed collision shape resource")
	(shape.shape as BoxShape3D).size = size
	_restored(lab, id)
	shape.disabled = true
	_invalid_then(lab, id, "disabled collision")
	shape.disabled = false
	_restored(lab, id)
	var layer: int = ground.collision_layer
	ground.collision_layer = 0
	_invalid_then(lab, id, "missing physical collision layer")
	ground.collision_layer = layer
	_restored(lab, id)
	var mesh: MeshInstance3D = ground.get_child(1)
	var mesh_size: Vector3 = (mesh.mesh as BoxMesh).size
	(mesh.mesh as BoxMesh).size.z += 0.25
	_invalid_then(lab, id, "changed actual render mesh")
	(mesh.mesh as BoxMesh).size = mesh_size
	_restored(lab, id)
	var material: StandardMaterial3D = mesh.material_override
	var color: Color = material.albedo_color
	material.albedo_color = Color.MAGENTA
	_invalid_then(lab, id, "changed static ground material")
	material.albedo_color = color
	_restored(lab, id)
	var extra: Node3D = Node3D.new()
	property.construction.add_child(extra)
	_invalid_then(lab, id, "foreign child in retained construction")
	extra.free()
	_restored(lab, id)
	var foreign: StaticBody3D = StaticBody3D.new()
	var foreign_shape: CollisionShape3D = CollisionShape3D.new()
	foreign_shape.shape = BoxShape3D.new()
	foreign.add_child(foreign_shape)
	foreign.visible = false
	lab.get_node("StarterFieldGeometry/PitchReceiverDebug").add_child(foreign)
	_invalid_then(lab, id, "hidden foreign collider under surviving host child")
	foreign.free()
	_restored(lab, id)
	if id == "AE-01":
		var boundary: StadiumNpcExpandedBoundaryV1 = property.boundary
		boundary.graph._shape = "straight"
		_invalid_then(lab, id, "corrupted retained runtime graph shape")
		boundary.graph._shape = "deeper_center"
		_restored(lab, id)
	var visibility: BallTrackingVisibility = lab._camera_director.tracking_visibility
	if id == "AC-01":
		var groups: Array = visibility.get("_groups").duplicate(true)
		_check(not groups.is_empty(), "AC actual scenery has member-level visibility groups")
		visibility.get("_groups").clear()
		_invalid_then(lab, id, "cleared retained AC member-level scenery visibility")
		visibility.set("_groups", groups)
		_restored(lab, id)
		var rails: Array = visibility.get("_rails").duplicate(true)
		_check(not rails.is_empty(), "AC actual dugouts contribute camera rail clearances")
		visibility.get("_rails").clear()
		_invalid_then(lab, id, "cleared retained AC dugout camera rails")
		visibility.set("_rails", rails)
		_restored(lab, id)
	var recipe: StadiumRecipeBoundary = visibility._recipe
	visibility._recipe = (
		StadiumNpcExpandedV1.TemplateView.new()
		if id == "AY-01"
		else (StadiumNpcYardV1.TemplateView.new())
	)
	_invalid_then(lab, id, "swapped camera visibility graph")
	visibility._recipe = recipe
	_restored(lab, id)
	var prisms: StadiumWallViewPrisms = visibility._wall_prisms
	visibility._wall_prisms = StadiumWallViewPrisms.new(visibility._recipe)
	visibility._wall_prisms.walls.clear()
	_invalid_then(lab, id, "missing actual camera wall prisms")
	visibility._wall_prisms = prisms
	_restored(lab, id)
	var camera_obstacles: Array[AABB] = visibility._obstacles.duplicate()
	_check(
		camera_obstacles.is_empty() if id == "AC-01" else not camera_obstacles.is_empty(),
		"venue keeps exact retained scenery visibility policy"
	)
	visibility._obstacles.clear()
	if id == "AC-01":
		visibility._obstacles.append(AABB(Vector3.ZERO, Vector3.ONE))
	_invalid_then(lab, id, "cleared actual camera scenery obstacles")
	visibility._obstacles = camera_obstacles
	_restored(lab, id)
	var uprights: Array[AABB] = visibility._uprights.duplicate()
	_check(
		not uprights.is_empty() if id == "AC-01" else uprights.is_empty(),
		"venue keeps exact retained upright hard avoidance policy"
	)
	visibility._uprights.append(AABB(Vector3.ZERO, Vector3.ONE))
	_invalid_then(lab, id, "invented camera upright hard avoidance")
	visibility._uprights = uprights
	_restored(lab, id)
	var wall_z: float = visibility.field_wall_z
	visibility.field_wall_z += 1.0
	_invalid_then(lab, id, "altered retained camera wall depth")
	visibility.field_wall_z = wall_z
	_restored(lab, id)
	property.position.x = 0.1
	_invalid_then(lab, id, "translated runtime root")
	property.position.x = 0
	_restored(lab, id)
	var field_depth: float = property.field.back_wall_z_m
	property.field.back_wall_z_m += 1
	_invalid_then(lab, id, "changed retained field rules")
	property.field.back_wall_z_m = field_depth
	_restored(lab, id)
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = Callable()
	_invalid_then(lab, id, "missing boundary observer")
	lab._ball_play_resolver.segment_observer = observer
	_restored(lab, id)
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = Callable()
	_invalid_then(lab, id, "missing defender clip")
	lab._primary_fielder.stadium_boundary_clip = clip
	_restored(lab, id)
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	lab._primary_fielder.stadium_obstacles.append({"center": Vector3.ZERO, "radius": 5.0})
	_invalid_then(lab, id, "altered actual defender obstacles")
	lab._primary_fielder.stadium_obstacles = obstacles
	_restored(lab, id)
	var router: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = func(
		_actor: PitchFlightActor, _start: Vector3, _velocity: Vector3
	) -> bool:
		return false
	_invalid_then(lab, id, "substituted receiver callback")
	lab._pitch_actor.receiver_router = router
	_check(_runtime.installed(lab, _context), "all restored controls return valid runtime")


func _receiver_visibility(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var prefix: String = "npc:" + property.venue_id + ":r%d:" % _revision
	for identity: String in [prefix + "RECEIVER-PRIMARY", prefix + "RECEIVER-CATCH"]:
		var model: Node3D = property.objects[identity]
		for style: Array in [
			[false, 1.0], [true, 1.0], [false, StadiumReceiverVisibility.FADED_ALPHA]
		]:
			StadiumReceiverVisibility._style(model, style[0], style[1])
			_check(
				_runtime.installed(lab, _context),
				"coherent whole-receiver visible/hidden/faded style remains valid " + identity
			)
		StadiumReceiverVisibility._style(model, false, 1.0)
		var visual: Node3D = model.get_node("Visual")
		var mesh: MeshInstance3D = visual.find_children("*", "MeshInstance3D", true, false)[0]
		mesh.visible = false
		_invalid_then(lab, property.venue_id, "selectively hidden receiver mesh")
		mesh.visible = true
		_restored(lab, property.venue_id)
		var material: StandardMaterial3D = mesh.material_override
		var blend: int = material.blend_mode
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_invalid_then(lab, property.venue_id, "wrong receiver material blend mode")
		material.blend_mode = blend
		_restored(lab, property.venue_id)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_invalid_then(lab, property.venue_id, "opaque receiver with wrong material transparency")
		StadiumReceiverVisibility._style(model, false, 1.0)
		_restored(lab, property.venue_id)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		_invalid_then(lab, property.venue_id, "wrong receiver shadow mode")
		StadiumReceiverVisibility._style(model, false, 1.0)
		_restored(lab, property.venue_id)
		StadiumReceiverVisibility._style(model, false, StadiumReceiverVisibility.FADED_ALPHA)
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		_invalid_then(lab, property.venue_id, "faded receiver without matching transparency")
		StadiumReceiverVisibility._style(model, false, StadiumReceiverVisibility.FADED_ALPHA)
		_restored(lab, property.venue_id)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_invalid_then(lab, property.venue_id, "faded receiver with an incoherent shadow")
		StadiumReceiverVisibility._style(model, false, 1.0)
		_restored(lab, property.venue_id)


func _routes(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var fielder: FielderController = lab._primary_fielder
	var original: Vector3 = fielder.global_position
	fielder.set_physics_process(false)
	for target: Vector3 in [
		Vector3(100, 0, 13),
		Vector3(-100, 0, 13),
		Vector3(0, 0, 100),
		Vector3(0, 0, -100),
		Vector3(1.5, 0, -4.5)
	]:
		fielder.set_anchor(Vector3(0, 0, 10))
		fielder.begin_play()
		fielder.target_position = target
		for step in range(120):
			var before: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 30)
			_check(
				_inside(property, fielder.global_position),
				"actual fielder remains inside retained graph"
			)
			_check(
				StadiumDefenderRoutes.clear(
					before, fielder.global_position, property.route_obstacles()
				),
				"actual fielder does not cut through retained receiver"
			)
		fielder.end_play()
	fielder.set_anchor(original)
	var pitcher_origin: Vector3 = lab._pitcher_marker.global_position
	lab._pitcher_marker.global_position = Vector3(0, 0, 14)
	var clipped: Vector3 = StadiumPropertyRuntime.pitcher_step(
		lab, Vector3(100, 0, 14), 100, Vector3(100, 0, 14)
	)
	_check(_inside(property, clipped), "ordinary pitcher adapter uses the retained boundary")
	lab._pitcher_marker.global_position = pitcher_origin


func _inside(property: StadiumNpcBoundProperty, point: Vector3) -> bool:
	var ground: Vector2 = Vector2(point.x, point.z)
	if property.venue_id == "AY-01":
		return StadiumNpcYardGraphV1.contains(ground)
	return property.boundary.graph.contains(ground)




func _expected_routes(id: String) -> Array[Dictionary]:
	# Fresh untouched r1 reference only; never call r1 factory methods on the r2 object map.
	var reference: Node3D = (
		StadiumNpcExpandedV1.build() if id == "AE-01" else StadiumNpcClubV1.build()
	)
	var rows: Array[Dictionary] = reference.route_obstacles().duplicate(true)
	reference.free()
	for row: Dictionary in rows:
		if not row.has("copy"):
			continue
		var matched: bool = false
		for instance: Dictionary in StadiumNpcVenues.definition(id, 1).instances:
			if row.copy == instance.instance:
				row.copy = "npc:%s:r2:%s" % [id, instance.site]
				matched = true
				break
		_check(matched, "expected receiver route identity resolves to exact frozen reference site")
	return rows


func _additional_integrity(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	lab._ball_play_resolver.play_resolved.disconnect(lab._on_ball_play_resolved)
	_invalid_then(lab, property.venue_id, "lost ordinary resolver-to-match result callback")
	lab._ball_play_resolver.play_resolved.connect(lab._on_ball_play_resolved)
	_restored(lab, property.venue_id)
	var id: String = property.venue_id
	var field: FieldDefinition = property.field
	var impostor: FieldDefinition = field.duplicate(true) as FieldDefinition
	property.field = impostor
	property.construction.field = impostor
	lab._field_definition = impostor
	_invalid_then(lab, id, "equal-valued field reference substitution")
	property.field = field
	property.construction.field = field
	lab._field_definition = field
	_restored(lab, id)
	var original_stadium: Dictionary = lab._match_state.stadium
	lab._match_state.stadium = original_stadium.duplicate(true)
	lab._match_state.stadium.environment.seed += 1
	_invalid_then(lab, id, "changed independently bound environment after installation")
	lab._match_state.stadium = original_stadium
	_restored(lab, id)
	var body: StaticBody3D = property.construction.get_node("PropertyGround")
	var body_script: Script = body.get_script()
	body.set_script(preload("res://src/tests/stadium_npc_bound_forged_body.gd"))
	_invalid_then(lab, id, "equal ground geometry carrying an untrusted behavior script")
	body.set_script(body_script)
	_restored(lab, id)
	var identity: String = property.objects.keys()[0]
	var model: Node3D = property.objects[identity]
	var original_owned: Variant = model.get_meta("owned_copy")
	model.set_meta("owned_copy", "copy:paid-human-item")
	_invalid_then(lab, id, "copied human ownership metadata cannot authorize NPC geometry")
	model.set_meta("owned_copy", original_owned)
	_restored(lab, id)
	property.objects.erase(identity)
	_invalid_then(lab, id, "missing model map entry despite unchanged physical model")
	property.objects[identity] = model
	_restored(lab, id)
	var lookalike: Node3D = Node3D.new()
	lookalike.transform = model.transform
	for key: StringName in model.get_meta_list():
		lookalike.set_meta(key, model.get_meta(key))
	property.objects[identity] = lookalike
	_invalid_then(lab, id, "lookalike model with copied metadata is not actual construction")
	property.objects[identity] = model
	lookalike.free()
	_restored(lab, id)
	if id != "AC-01":
		return
	var boundary: StadiumNpcRetainedClubBoundary = property.boundary
	var source: StadiumNpcClubBoundaryV1 = boundary.source
	var foreign: StadiumNpcClubV1 = StadiumNpcClubV1.build()
	boundary.source = foreign.get_node("ClubBoundary")
	_invalid_then(lab, id, "authentic foreign graph source does not belong to this installation")
	boundary.source = source
	foreign.free()
	_restored(lab, id)
	var bodies: Array[StaticBody3D] = source.bodies.duplicate()
	source.bodies.pop_back()
	_invalid_then(lab, id, "missing actual boundary body membership")
	source.bodies.assign(bodies)
	_restored(lab, id)
	source.bodies.reverse()
	_invalid_then(lab, id, "reordered actual boundary body membership")
	source.bodies.assign(bodies)
	_restored(lab, id)
	boundary.contact_applied.disconnect(property._club_contact)
	_invalid_then(lab, id, "lost preterminal contact callback")
	boundary.contact_applied.connect(property._club_contact)
	_restored(lab, id)
	var protection: Callable = property.receiver.camera_protection
	property.receiver.camera_protection = func() -> bool: return true
	_invalid_then(lab, id, "plausible foreign receiver camera callback")
	property.receiver.camera_protection = protection
	_restored(lab, id)


func _receiver(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var prefix: String = "npc:" + property.venue_id + ":r2:"
	var samples: Array = [
		[Vector3(0, 1.3, 0), "ST026_PANEL"],
		[Vector3(1, 1.3, 0), "ST025_NET"],
		[Vector3(-1, 1.3, 0), "ST025_NET"]
	]
	if property.venue_id == "AC-01":
		samples = [[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1.5, 1.3, 0), "ST073_CENTER_NET"],
			[Vector3(3, 1.3, 0), "ST073_NET_R"],
			[Vector3(-3, 1.3, 0), "ST073_NET_L"]]
	for speed: float in [15, 40, 120]:
		for sample: Array in samples:
			var path: Dictionary = property.receiver.trace(sample[0], Vector3(0, 0, -speed), 0.0365)
			_check(path.hit.get("surface") == sample[1], "bound receiver reaches actual earliest surface")
			_check(String(path.hit.get("copy", "")).begins_with(prefix),
				"physical receiver trace preserves exact revision2 NPC identity")
	var panel: Node3D = property.receiver.chair.get_node("Visual/ST026_PANEL")
	var rest: Transform3D = panel.transform
	property.receiver._flex(0.09)
	_check(panel.transform != rest and _runtime.installed(lab, _context),
		"actual target flex remains valid under exact geometry policy")
	property.receiver._flex(0.18)


func _restart_bound(lab: PitchBatLab, id: String) -> void:
	var old_context: StadiumNpcQualificationContext = _context
	var old_match: MatchState = lab._match_state
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	var old_display_match: MatchState = property.display._match if property.display != null else null
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	_check(lab._match_state != old_match, "ordinary restart actually changes MatchState identity")
	lab._match_state.stadium = _fixture(id)
	_check(not _runtime.installed(lab, old_context),
		"unchanged fixture bytes do not implicitly authorize replacement MatchState")
	if property.display != null:
		_check(property.display._match != lab._match_state,
			"scoreboard does not silently bind unqualified replacement state")
		_check(old_display_match == old_match, "old scoreboard was bound to the authorized state")
	var wrong_field: FieldDefinition = COMMON_FIELD.duplicate(true) as FieldDefinition
	var wrong: StadiumNpcQualificationContext = StadiumNpcQualificationContext.create(
		lab._match_state, _binding(id), _environment(), wrong_field, MATCH_SEED)
	_check(not _runtime.rebind_match(lab, wrong), "rebind refuses equal-value foreign field reference")
	var replacement: StadiumNpcQualificationContext = StadiumNpcQualificationContext.create(
		lab._match_state, _binding(id), _environment(), _qualification_field, MATCH_SEED)
	_check(replacement != null and _runtime.rebind_match(lab, replacement),
		"explicit independently validated same-fixture state rebind succeeds")
	_context = replacement
	_check(_runtime.installed(lab, _context), "explicit rebind restores real runtime integrity")
	if property.display != null:
		_check(property.display._match == lab._match_state,
			"explicit rebind synchronously refreshes real scoreboard")


func _flight(lab: PitchBatLab, property: StadiumNpcBoundProperty, sample: Array) -> void:
	_restart_bound(lab, property.venue_id)
	if property.receiver != null:
		property.receiver.contacts.clear()
	property.provenance.clear()
	_check(lab._match_state.begin_pitch(), "real bound match accepts ordinary pitch")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	# This unchanged ordinary path emits launch_started BEFORE property.bind_ball.
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	_check(is_instance_valid(ball) and ball.physics_contact_router.is_valid(),
		"ordinary launch-before-bind gets the bounded physical contact route")
	_check(_runtime.installed(lab, _context), "real ball starts fully bound after ordinary launch")
	var body_count: int = ball.body_entered.get_connections().size()
	var launch_count: int = ball.launch_started.get_connections().size()
	var exit_count: int = ball.tree_exited.get_connections().size()
	var ball_count: int = property.bound_balls.size()
	_check(_runtime.bind_ball(lab, ball, lab._ball_play_resolver, _context),
		"repeated real ball bind succeeds idempotently")
	_check(body_count == ball.body_entered.get_connections().size()
		and launch_count == ball.launch_started.get_connections().size()
		and exit_count == ball.tree_exited.get_connections().size()
		and ball_count == property.bound_balls.size(), "idempotent bind adds no callbacks or memberships")
	var ball_id: int = ball.get_instance_id()
	if property.venue_id == "AC-01":
		_club_ball_integrity(lab, property, ball, launch.position)
	lab.set_physics_process(true)
	for frame in range(180):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(outcomes.size() == 1 and outcomes[0].result == sample[3],
		"real bound terminal outcome at " + str(sample[0]))
	if property.receiver != null and sample[0].z < 1:
		_check(property.receiver.contacts.size() == 1, "real receiver reacts exactly once")
		var preterminal: bool = false
		for row: Dictionary in property.provenance:
			_check(String(row.instance).begins_with("npc:" + property.venue_id + ":r2:"),
				"real contact carries bounded venue provenance")
			preterminal = preterminal or row.preterminal
		_check(preterminal, "physical receiver records provenance before terminal state")
	var contacts: Array = lab._ball_play_resolver.state.stadium_contacts.duplicate(true)
	for frame in range(3):
		await get_tree().physics_frame
	_check(outcomes.size() == 1 and contacts == lab._ball_play_resolver.state.stadium_contacts,
		"late contacts cannot rewrite terminal outcome or provenance")
	lab.set_physics_process(false)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()
	await get_tree().process_frame
	if property.venue_id == "AC-01":
		_check(not property.boundary._previous.has(ball_id)
			and not property.boundary._resolver_ids.has(ball_id)
			and not property.boundary._bound_balls.has(ball_id),
			"real ball exit removes prior position, resolver map and weak membership")


func _club_ball_integrity(lab: PitchBatLab, property: StadiumNpcBoundProperty,
	ball: BattedBallBody, start: Vector3) -> void:
	var boundary: StadiumNpcRetainedClubBoundary = property.boundary
	var ball_id: int = ball.get_instance_id()
	var resolver_id: int = lab._ball_play_resolver.get_instance_id()
	_check(boundary._previous.get(ball_id) == start, "AC initial segment is seeded after prior launch")
	_check(boundary._resolver_ids.get(ball_id) == resolver_id
		and boundary._bound_balls.has(ball_id) and boundary._bound_balls[ball_id].get_ref() == ball,
		"AC actual ball and resolver maps point to the ordinary launched ball")
	var launch_callback: Callable = boundary._seed.bind(ball_id)
	var exit_callback: Callable = boundary._forget.bind(ball_id, resolver_id)
	_check(ball.launch_started.is_connected(launch_callback)
		and ball.tree_exited.is_connected(exit_callback), "AC launch and exit callbacks are real")
	ball.launch_started.disconnect(launch_callback)
	_invalid_then(lab, property.venue_id, "lost launch seed callback")
	ball.launch_started.connect(launch_callback)
	_restored(lab, property.venue_id)
	ball.tree_exited.disconnect(exit_callback)
	_invalid_then(lab, property.venue_id, "lost ball-exit cleanup callback")
	ball.tree_exited.connect(exit_callback, CONNECT_ONE_SHOT)
	_restored(lab, property.venue_id)
	var contact: Callable = ball.physics_contact_router
	ball.physics_contact_router = Callable()
	_invalid_then(lab, property.venue_id, "lost actual physical batch callback")
	ball.physics_contact_router = contact
	_restored(lab, property.venue_id)
	boundary._resolver_ids.erase(ball_id)
	_invalid_then(lab, property.venue_id, "lost AC resolver identity map")
	boundary._resolver_ids[ball_id] = resolver_id
	_restored(lab, property.venue_id)
	var reference: WeakRef = boundary._bound_balls[ball_id]
	boundary._bound_balls.erase(ball_id)
	_invalid_then(lab, property.venue_id, "lost AC actual-ball weak membership")
	boundary._bound_balls[ball_id] = reference
	_restored(lab, property.venue_id)
	boundary._previous.erase(ball_id)
	_invalid_then(lab, property.venue_id, "missing initial previous position")
	boundary._previous[ball_id] = start
	_restored(lab, property.venue_id)
	for invalid: Variant in [Vector3(INF, 0, 0), Vector3(0, NAN, 0), Vector2.ZERO]:
		boundary._previous[ball_id] = invalid
		_invalid_then(lab, property.venue_id, "nonfinite or wrong-typed prior position")
		boundary._previous[ball_id] = start
		_restored(lab, property.venue_id)


func _whole_lab_removal(id: String) -> void:
	var lab: PitchBatLab = _lab(id)
	_check(_runtime.install_bound(lab, _context), "whole-lab cleanup installs " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	var originals: Array[Node] = property.old_nodes.duplicate()
	_check(not originals.is_empty(), "whole-lab cleanup has actual detached original nodes")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var resolver: BallPlayResolver = lab._ball_play_resolver
	resolver.start_play(property.field, false)
	_check(_runtime.bind_ball(lab, ball, resolver, _context), "cleanup binds actual lab ball")
	ball.reparent(self)
	lab._batted_ball = null
	var boundary_id: int = property.boundary.get_instance_id()
	var property_id: int = property.get_instance_id()
	lab.free()
	await get_tree().process_frame
	for node: Variant in originals:
		_check(not is_instance_valid(node), "destroying entire lab frees detached original nodes")
	_check(not ball.physics_contact_router.is_valid(),
		"whole-lab destruction clears surviving ball router")
	_check(_no_connections_to(ball, [boundary_id, property_id]),
		"whole-lab destruction clears surviving ball launch/contact/exit listeners")
	ball.free()


func _unexpected_removal(id: String, mode: String) -> void:
	var lab: PitchBatLab = _lab(id)
	var before: Dictionary = _scene_state(lab)
	_check(_runtime.install_bound(lab, _context), "unexpected removal installs " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	lab._at_bat_cadence.stop()
	var external: BattedBallBody = BattedBallBody.new()
	external.freeze = true
	lab.add_child(external)
	lab._batted_ball = external
	lab._ball_play_resolver.start_play(property.field, false)
	_check(_runtime.bind_ball(lab, external, lab._ball_play_resolver, _context),
		"removal probe has actual surviving contact callbacks")
	lab._batted_ball = null
	var boundary_id: int = property.boundary.get_instance_id()
	var property_id: int = property.get_instance_id()
	if mode == "live-ball":
		_check(lab._match_state.begin_pitch(), "live-removal starts from ordinary pitch")
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 3, 10)
		launch.velocity = Vector3(0, 2, 12)
		lab._start_ball_in_play(launch)
		_check(is_instance_valid(lab._batted_ball)
			and lab._batted_ball.physics_contact_router.is_valid(), "removal uses real live bound ball")
	elif mode == "live-pitch":
		# Use the already selected ordinary pitch/aim; only physical delivery changes here.
		# Mechanics-mode or a new AI aim would change the scene independently of restoration.
		lab._ai_pitch_preselected = true
		lab._throw_pitch()
		_check(lab._match_mode and lab._pitch_actor.running,
			"removal uses real running ordinary-match delivery")
	if mode.begins_with("live-"):
		lab.set_process(true)
		lab.set_physics_process(true)
	external.reparent(self)
	if mode == "detach":
		property.get_parent().remove_child(property)
	else:
		property.free()
	_check(not lab.has_meta("stadium_property")
		and lab._field_definition == before.field
		and lab._ball_play_resolver.segment_observer == before.observer
		and lab._pitch_actor.receiver_router == before.receiver
		and lab._primary_fielder.stadium_boundary_clip == before.clip,
		"unexpected removal synchronously restores fields, metadata and all callback targets")
	_check(not external.physics_contact_router.is_valid()
		and _no_connections_to(external, [boundary_id, property_id]),
		"unexpected removal disconnects contact, launch and exit on surviving balls")
	if mode == "detach" and id == "AC-01":
		_check(property.boundary._previous.is_empty() and property.boundary._resolver_ids.is_empty()
			and property.boundary._bound_balls.is_empty() and property.boundary.last_live.is_empty(),
			"detached AC adapter clears all live maps")
	_check(not _runtime.installed(lab, _context), "removed property cannot remain installed")
	await get_tree().process_frame
	var restored: Dictionary = _scene_state(lab)
	if mode.begins_with("live-"):
		_check(lab.process_mode == Node.PROCESS_MODE_DISABLED and not lab._pitch_actor.running
			and not is_instance_valid(lab._batted_ball) and not lab._release_controller.active
			and lab.get_meta("stadium_npc_runtime_interrupted", false),
			"live removal cancels activity and cannot resume interrupted gameplay")
		restored.metadata.erase(&"stadium_npc_runtime_interrupted")
	_check(before == restored, "unexpected removal restores original exact scene " + mode)
	if mode == "detach" and is_instance_valid(property):
		property.free()
	external.free()
	if mode.begins_with("live-"):
		_refused(lab, _context, "interrupted game cannot masquerade as fresh qualification")
	else:
		_check(_runtime.install_bound(lab, _context) and _runtime.installed(lab, _context),
			"idle unexpected removal permits explicit reinstall")
		_check(_runtime.teardown(lab), "recovered idle runtime tears down")
	lab.free()
	await get_tree().process_frame


func _no_connections_to(ball: BattedBallBody, targets: Array) -> bool:
	for event: Signal in [ball.body_entered, ball.launch_started, ball.tree_exited,
		ball.surface_contact]:
		for connection: Dictionary in event.get_connections():
			if connection.callable.get_object_id() in targets:
				return false
	return true


func _scene_state(lab: PitchBatLab) -> Dictionary:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var rows: Array[Dictionary] = []
	for node: Node in host.find_children("*", "", true, false):
		var row: Dictionary = {"id": node.get_instance_id(),
			"parent": node.get_parent().get_instance_id(),
			"index": node.get_index(), "name": node.name, "script": node.get_script(), "metadata": {}}
		for key: StringName in node.get_meta_list():
			row.metadata[key] = node.get_meta(key)
		if node is Node3D:
			row["transform"] = node.transform
			row["visible"] = node.visible
		if node is CollisionObject3D:
			row["layer"] = node.collision_layer
			row["mask"] = node.collision_mask
		if node is CollisionShape3D:
			row["shape"] = node.shape
			row["disabled"] = node.disabled
			if node.shape is BoxShape3D:
				row["size"] = node.shape.size
		if node is MeshInstance3D:
			row["mesh"] = node.mesh
			row["material"] = node.material_override
			if node.mesh is BoxMesh:
				row["mesh_size"] = node.mesh.size
		rows.append(row.duplicate(true))
	var metadata: Dictionary = {}
	for key: StringName in lab.get_meta_list():
		metadata[key] = lab.get_meta(key)
	var host_metadata: Dictionary = {}
	for key: StringName in host.get_meta_list():
		host_metadata[key] = host.get_meta(key)
	return {"nodes": rows, "metadata": metadata.duplicate(true), "host": host.transform,
		"host_metadata": host_metadata.duplicate(true),
		"field": lab._field_definition, "field_id": lab._field_id,
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera_mask": lab._camera.cull_mask, "director": lab._camera_director,
		"visibility": lab._camera_director.tracking_visibility}


func _quarantine(id: String, pitch: bool, near_contact: bool = false) -> void:
	var lab: PitchBatLab = _lab(id)
	_check(_runtime.install_bound(lab, _context), "live stale-context probe installs " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcBoundProperty = lab.get_meta("stadium_property")
	lab._at_bat_cadence.stop()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ball: BattedBallBody
	if pitch:
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "stale-context probe begins actual live pitch")
	else:
		_check(lab._match_state.begin_pitch(), "stale-context ball starts from actual pitch phase")
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 2, 8)
		launch.velocity = Vector3(0, 0, -30)
		if near_contact:
			var step: float = 1.0 / Engine.physics_ticks_per_second
			if id == "AY-01":
				launch.position = Vector3(0, 1.1, StadiumNpcYardGraphV1.BACK_Z - 0.12)
				launch.velocity = Vector3(0, 0, 30)
				_check(not StadiumNpcYardGraphV1.crossing(launch.position,
					launch.position + launch.velocity * step).is_empty(),
					"near stale ball would cross real terminal boundary in the very next step")
			else:
				var panel: StaticBody3D = property.receiver.chair.get_node("Collision/ST026_PANEL")
				launch.position = panel.global_position + Vector3(0, 0, 0.12)
				launch.is_foul = true
				var trace: Dictionary = property.receiver.trace(launch.position,
					launch.velocity, 0.0365)
				_check(trace.hit.get("surface") == "ST026_PANEL"
					and trace.hit.get("elapsed", INF) < step,
					"near stale ball would hit actual receiver in the very next physics step")
		lab._start_ball_in_play(launch)
		ball = lab._batted_ball
		_check(_runtime.installed(lab, _context), "stale-context probe starts with valid actual ball")
	lab.set_process(true)
	lab.set_physics_process(true)
	lab._match_state.stadium.environment.seed += 1
	var before: Dictionary = _quarantine_state(lab, property)
	# The actual property physics/process guard must run; no manual pause helper is called.
	await get_tree().physics_frame
	await get_tree().process_frame
	_check(property.suspended and lab.process_mode == Node.PROCESS_MODE_DISABLED,
		"stale independently bound environment suspends real gameplay")
	_check(not lab._pitch_actor.running and not lab._release_controller.active,
		"quarantine stops real pitch/release activity")
	_check(not lab._ball_play_resolver.play_resolved.is_connected(lab._on_ball_play_resolved),
		"quarantine disconnects terminal resolver-to-match callback")
	_check(not lab._ball_play_resolver.segment_observer.is_valid()
		and not lab._pitch_actor.receiver_router.is_valid(),
		"quarantine removes live segment and receiver entry points")
	if is_instance_valid(ball):
		_check(ball.freeze and not ball.physics_contact_router.is_valid(),
			"quarantine freezes actual launched ball and clears its physical route")
		_check(_no_connections_to(ball,
			[property.get_instance_id(), property.boundary.get_instance_id(), lab.get_instance_id()]),
			"quarantine disconnects ball contact, launch, exit and ordinary surface callbacks")
	if id == "AC-01":
		_check(property.boundary._previous.is_empty() and property.boundary._resolver_ids.is_empty()
			and property.boundary._bound_balls.is_empty(), "quarantine clears all AC live maps")
	for frame in range(12):
		await get_tree().physics_frame
	_check(before == _quarantine_state(lab, property),
		"stale-context quarantine cannot award, contact, resolve or advance match across frames")
	_check(not _runtime.installed(lab, _context), "stale context remains rejected after quarantine")
	lab.free()
	await get_tree().process_frame


func _quarantine_state(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> Dictionary:
	var state: MatchState = lab._match_state
	var result: Dictionary = {"state": state, "phase": state.phase, "inning": state.inning,
		"top": state.top_half, "outs": state.outs, "balls": state.balls, "strikes": state.strikes,
		"away": state.away_team.runs, "home": state.home_team.runs,
		"elapsed": state.elapsed_seconds, "pa": state.plate_appearance_number,
		"performance": state.performance.snapshot(state).duplicate(true),
		"provenance": property.provenance.duplicate(true),
		"receiver": property.receiver.contacts.duplicate(true) if property.receiver != null else []}
	if lab._ball_play_resolver.state != null:
		result["dead"] = lab._ball_play_resolver.state.dead
		result["resolver_elapsed"] = lab._ball_play_resolver.state.elapsed_seconds
		result["contacts"] = lab._ball_play_resolver.state.stadium_contacts.duplicate(true)
	return result


func _resealed_forgery(lab: PitchBatLab, installed: bool) -> void:
	var original: Dictionary = lab._match_state.stadium
	var snapshot: Dictionary = _context._snapshot
	var key: String = _context._snapshot_key
	var state_bytes: PackedByteArray = _context._state_bytes
	var forged: Dictionary = snapshot.duplicate(true)
	forged.manifest.instances[0].transform[9] += 0.01
	forged.manifest_key = JSON.stringify(forged.manifest, "", true, true).sha256_text()
	_context._snapshot = forged
	_context._snapshot_key = JSON.stringify(forged, "", true, true).sha256_text()
	lab._match_state.stadium = forged.duplicate(true)
	_context._state_bytes = var_to_bytes(lab._match_state.stadium)
	var property: StadiumNpcBoundProperty
	if installed:
		property = lab.get_meta("stadium_property")
		property.frozen_snapshot = forged.duplicate(true)
		property.frozen_key = _context._snapshot_key
	_check(_context.matches(lab), "attacker consistently reseals all cheap context fingerprints")
	_check(not StadiumNpcSnapshot.raw_envelope_valid(forged),
		"resealed manifest lacks independently registered actual geometry authority")
	if installed:
		_check(not _runtime.installed(lab, _context),
			"installed fully revalidates raw authority despite copied/resealed internal hashes")
	else:
		_refused(lab, _context, "resealed mutable context cannot invent authored manifest authority")
	lab._match_state.stadium = original
	_context._snapshot = snapshot
	_context._snapshot_key = key
	_context._state_bytes = state_bytes
	if installed:
		property.frozen_snapshot = snapshot.duplicate(true)
		property.frozen_key = key
		_restored(lab, "")


func _reference_integrity(lab: PitchBatLab, property: StadiumNpcBoundProperty) -> void:
	var originals: Dictionary = {"construction": property.construction, "boundary": property.boundary,
		"receiver": property.receiver, "display": property.display}
	for member: String in originals:
		var original: Variant = originals[member]
		# AY legitimately has no receiver or display; null is a positive control there.
		if original != null:
			property.set(member, null)
			_invalid_then(lab, property.venue_id, "null actual " + member + " reference")
			property.set(member, original)
			_restored(lab, property.venue_id)
		var foreign: Node3D = Node3D.new()
		property.set(member, foreign)
		_invalid_then(lab, property.venue_id, "wrong-script actual " + member + " reference")
		property.set(member, original)
		foreign.free()
		_restored(lab, property.venue_id)
	for foreign: Variant in [{"route": "copied-callable-name"}, 17, "receiver"]:
		property.receiver = foreign
		_invalid_then(lab, property.venue_id, "non-Node receiver reference must fail before dereference")
		property.receiver = originals.receiver
		_restored(lab, property.venue_id)
