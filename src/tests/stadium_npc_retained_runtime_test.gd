extends Node3D
## Opt-in retained-runtime mechanics and adversarial lifecycle checks, never fixture admission.

const IDS: Array[String] = ["AY-01", "AE-01", "AC-01"]
@export var candidate_v2: bool = false
var _prefix: String = "npc:AE-01:r1:"
var _revision: int = 1
var _runtime: Script = StadiumNpcRetainedRuntime
var _definitions: Script = StadiumNpcVenues

var _failures: int = 0


func _ready() -> void:
	if candidate_v2:
		_revision = 2
		_runtime = StadiumNpcCandidateRuntimeV2
		_definitions = StadiumNpcCandidatesV2
		_prefix = "npc:AE-01:r2:"
	_check(not _runtime.install(null, "AY-01"), "null cannot install")
	_check(not _runtime.installed(null, "AY-01"), "null is never installed")
	_check(not _runtime.teardown(null), "null cannot tear down")
	var unready: PitchBatLab = PitchBatLab.new()
	unready.set_meta("stadium_npc_retained_lab_only", true)
	_check(not _runtime.install(unready, "AY-01"), "unready lab fails closed")
	unready.free()
	for id: String in IDS:
		_guards(id)
		_staging(id)
		await _lifecycle(id)
		await _whole_lab_removal(id)
		for mode: String in ["detach", "free", "live-ball", "live-pitch"]:
			await _unexpected_removal(id, mode)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro candidate NPC r2 runtime passed: AY/AE/AC isolation, integrity and real mechanics."
				if candidate_v2
				else "Wiffaltro retained NPC runtime passed: AY/AE/AC isolation, integrity and real mechanics."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	return lab


func _guards(id: String) -> void:
	var lab: PitchBatLab = _lab()
	_refused(lab, id, _revision, "missing opt-in")
	lab.set_meta("stadium_npc_retained_lab_only", false)
	_refused(lab, id, _revision, "false opt-in")
	lab.set_meta("stadium_npc_retained_lab_only", true)
	for invalid: String in ["", "ay-01", "ae-01", "AY-01 ", "ac-01", "AC-01-unknown", "FOREIGN-01"]:
		_refused(lab, invalid, _revision, "unsupported exact identity")
	for revision: int in [-1, 0, 3 - _revision, 1000000]:
		_refused(lab, id, revision, "unsupported exact revision")
	lab._managed_match = true
	_refused(lab, id, _revision, "managed fixture")
	lab._managed_match = false
	lab._automation = MatchAutomation.new()
	_refused(lab, id, _revision, "automated runner")
	lab._automation = null
	lab._field_id = &"field.unpublished"
	_refused(lab, id, _revision, "nonstarter field")
	lab._field_id = PitchBatLab.FIELD_ID
	lab.set_meta("stadium_property", {})
	_refused(lab, id, _revision, "existing malformed property marker")
	lab.remove_meta("stadium_property")
	lab._batted_ball = BattedBallBody.new()
	_refused(lab, id, _revision, "existing physical batted ball")
	lab._batted_ball.free()
	lab._batted_ball = null
	var receiver: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = func(
		_actor: PitchFlightActor, _start: Vector3, _velocity: Vector3
	) -> bool:
		return false
	_refused(lab, id, _revision, "already bound receiver")
	lab._pitch_actor.receiver_router = receiver
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	host.position.x = 1
	_refused(lab, id, _revision, "nonidentity host")
	host.position.x = 0
	lab._match_mode = false
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "guard probe uses an actual running delivery")
	_refused(lab, id, _revision, "mechanics-mode physical flight")
	lab._match_mode = true
	_refused(lab, id, _revision, "physical flight despite idle logical match phase")
	lab._pitch_actor.reset_pitch()
	lab._release_controller.begin()
	_refused(lab, id, _revision, "live release gesture")
	lab._release_controller.cancel()
	for cadence: int in [
		AtBatCadenceController.State.DELIVERY,
		AtBatCadenceController.State.PITCH_LIVE,
		AtBatCadenceController.State.DEAD_BALL_HOLD
	]:
		lab._at_bat_cadence.state = cadence as AtBatCadenceController.State
		_refused(lab, id, _revision, "busy ordinary cadence")
	lab._at_bat_cadence.stop()
	_check(not _runtime.teardown(lab), "never-installed teardown is harmless")
	lab.free()


func _refused(lab: PitchBatLab, id: String, revision: int, reason: String) -> void:
	var before: Dictionary = _scene_state(lab)
	_check(not _runtime.install(lab, id, revision), "reject " + reason)
	_check(before == _scene_state(lab), "failed install preserves complete bindings: " + reason)


func _staging(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	var before: Dictionary = _scene_state(lab)
	var staged: StadiumNpcRetainedProperty = _runtime._stage(lab, id, _revision)
	_check(staged != null, "valid retained construction can stage before replacing the field")
	if staged != null:
		_check(before == _scene_state(lab), "staging alone leaves the original scene intact")
		var shape: CollisionShape3D = staged.construction.get_node("PropertyGround").get_child(0)
		(shape.shape as BoxShape3D).size.x += 0.125
		_check(
			not _runtime._commit(lab, staged), "changed staged geometry is refused before commit"
		)
		_check(before == _scene_state(lab), "failed staged validation preserves original scene")
		if is_instance_valid(staged):
			staged.free()
	lab.free()


func _lifecycle(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab.set_meta("unrelated_test_metadata", {"preserve": [1, 2, 3]})
	var before: Dictionary = _scene_state(lab)
	var definition: Dictionary = _definitions.definition(id, _revision)
	var definition_bytes: String = JSON.stringify(definition, "", true, true)
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = JSON.stringify(ledger.to_data(), "", true, true)
	_check(_runtime.install(lab, id), "explicit isolated revision %d install " % _revision + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	_check(_runtime.installed(lab, id), "full installed validation " + id)
	_check(
		(
			not _runtime.installed(lab, IDS[1] if id == IDS[0] else IDS[0])
			and not _runtime.installed(lab, id, 3 - _revision)
		),
		"no venue/revision substitution"
	)
	_refused(lab, id, _revision, "reentrant retained installation")
	_identity(lab, property, definition)
	_integrity(lab, property)
	_teardown_guards(lab, id)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if id == "AE-01":
		await _receiver(lab, property)
	if id == "AC-01":
		var checks = preload("res://src/tests/stadium_npc_retained_club_checks.gd").new()
		add_child(checks)
		_receiver_visibility(lab, property)
		checks.candidate_v2 = candidate_v2
		await checks.run(lab, property)
		_failures += checks.failures
		checks.free()
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		_routes(lab, property)
	for sample: Array in [
		[Vector3(0, 4, 20), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN],
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.1, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL]
	]:
		if id == "AC-01" and sample[0].z == 20:
			sample[0] = Vector3(0, 4, 27.3)
		await _flight(lab, property, sample)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(), "retained gameplay cannot issue fixture report"
	)
	_check(
		not StadiumLayoutSnapshot.valid(definition) and not PhysicalMatchReport.valid(definition),
		"definition gains no save or report authority"
	)
	_check(
		definition.environment_certificates.is_empty(),
		"runtime test adds no environment certificate"
	)
	_check(
		(
			(
				definition_bytes
				== JSON.stringify(_definitions.definition(id, _revision), "", true, true)
			)
			and ledger_bytes == JSON.stringify(ledger.to_data(), "", true, true)
		),
		"runtime use preserves published bytes and human inventory"
	)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(_runtime.teardown(lab), "idle retained runtime tears down " + id)
	_check(
		before == _scene_state(lab),
		"teardown restores original nodes/order/metadata/bindings " + id
	)
	_check(not _runtime.installed(lab, id), "removed runtime cannot pass validation")
	_check(not _runtime.teardown(lab), "repeated teardown has no work or side effects")
	_check(
		_runtime.install(lab, id) and _runtime.installed(lab, id),
		"fresh install works after teardown"
	)
	_check(_runtime.teardown(lab), "reinstalled runtime also restores cleanly")
	lab.free()
	await get_tree().process_frame


func _identity(
	lab: PitchBatLab, property: StadiumNpcRetainedProperty, definition: Dictionary
) -> void:
	_check(
		property is StadiumPropertyGeometry and property.venue_id == definition.id,
		"shared gameplay receives a compatibility property with exact NPC identity"
	)
	_check(
		(
			property.construction.get_parent() == property
			and (
				property.boundary.source == property.construction.get_node("ClubBoundary")
				if property.venue_id == "AC-01"
				else property.boundary == property.construction.get_node("BoundaryGraph")
			)
		),
		"actual retained boundary remains part of its retained construction"
	)
	_check(
		(
			lab._field_definition == property.field
			and property.field != ContentDB.get_field(PitchBatLab.FIELD_ID)
		),
		"runtime field uses detached retained values, not shared ContentDB"
	)
	_check(
		property.objects.size() == definition.instances.size(), "all exact NPC instances installed"
	)
	for row: Dictionary in definition.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(is_instance_valid(model), "actual NPC instance exists " + row.instance)
		if not is_instance_valid(model):
			continue
		_check(
			(
				model.get_meta("npc_instance", "") == row.instance
				and model.get_meta("stadium_item", "") == row.item
			),
			"model retains real NPC identity"
		)
		if model.has_meta("owned_copy"):
			_check(
				model.get_meta("owned_copy") == row.instance, "compatibility copy is exact NPC ID"
			)
	for node: Node in property.find_children("*", "", true, false):
		if node.has_meta("owned_copy"):
			_check(
				String(node.get_meta("owned_copy")).begins_with(
					"npc:" + definition.id + ":r%d:" % _revision
				),
				"no paid/candidate ownership is fabricated by compatibility metadata"
			)
	_check(
		(
			lab.get_meta("stadium_candidate_only", false)
			and not lab.has_meta("stadium_snapshot")
			and lab._match_state.stadium.is_empty()
		),
		"runtime opt-in does not enter frozen fixture/save authority"
	)
	if definition.id == "AY-01":
		_check(
			(
				property.receiver == null
				and property.display == null
				and not lab._pitch_actor.receiver_router.is_valid()
				and property.route_obstacles().is_empty()
			),
			"AY preserves free default receiver and zero live objects"
		)
	else:
		var expected_routes: Array[Dictionary] = (
			_candidate_expected_routes(property.venue_id)
			if candidate_v2
			else property.construction.route_obstacles()
		)
		_check(
			(
				property.receiver != null
				and property.display != null
				and property.route_obstacles() == expected_routes
				and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
				and not property.route_obstacles().is_empty()
			),
			"retained paid-tier venue installs actual target-net and read-only board"
		)
		_check(
			(
				(
					property
					. objects["npc:" + definition.id + ":r%d:RECEIVER-CATCH" % _revision]
					. position
				)
				== (Vector3.ZERO if definition.id == "AC-01" else Vector3(0, 0, -2.2))
			),
			"venue keeps its own corrected retained net placement"
		)


func _integrity(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
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
		"property_signature", _definitions.key(_definitions.definition(id, _revision))
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
	_check(_runtime.installed(lab, id), "all restored controls return valid runtime")


func _teardown_guards(lab: PitchBatLab, id: String) -> void:
	lab._automation = MatchAutomation.new()
	_teardown_refused(lab, "automation still attached")
	lab._automation = null
	lab._release_controller.begin()
	_teardown_refused(lab, "active release gesture")
	lab._release_controller.cancel()
	lab._at_bat_cadence.state = AtBatCadenceController.State.PITCH_LIVE
	_teardown_refused(lab, "busy live cadence")
	lab._at_bat_cadence.stop()
	lab._batted_ball = BattedBallBody.new()
	_teardown_refused(lab, "physical ball still live")
	lab._batted_ball.free()
	lab._batted_ball = null
	_restored(lab, id)


func _teardown_refused(lab: PitchBatLab, reason: String) -> void:
	var before: Dictionary = _scene_state(lab)
	_check(not _runtime.teardown(lab), "teardown refuses " + reason)
	_check(before == _scene_state(lab), "busy teardown preserves all geometry and bindings")


func _restored(lab: PitchBatLab, id: String) -> void:
	_check(
		_runtime.installed(lab, id),
		"restored positive control qualifies before the next independent mutation"
	)


func _invalid_then(lab: PitchBatLab, id: String, reason: String) -> void:
	_check(not _runtime.installed(lab, id), "full integrity rejects " + reason)


func _receiver(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var receiver: StadiumPairedReceiver = property.receiver
	for speed: float in [10, 40, 120]:
		for sample: Array in [
			[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1, 1.3, 0), "ST025_NET"],
			[Vector3(-1, 1.3, 0), "ST025_NET"]
		]:
			var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -speed), 0.0365)
			_check(
				not path.hit.is_empty() and path.hit.surface == sample[1],
				"retained receiver reaches earliest real surface at " + str(speed)
			)
			if not path.hit.is_empty():
				_check(
					String(path.hit.copy).begins_with(_prefix),
					"receiver contact uses real NPC identity"
				)
		var miss: Dictionary = receiver.trace(Vector3(2.4, 1.3, 0), Vector3(0, 0, -speed), 0.0365)
		_check(
			(
				miss.hit.is_empty()
				and (
					miss.reason
					== ("receiver_cleanup" if speed > 10 else "receiver_presentation_timeout")
				)
			),
			"retained receiver miss has bounded physical cleanup"
		)
	var property_mode: int = property.process_mode
	var display_mode: int = property.display.process_mode
	property.process_mode = Node.PROCESS_MODE_DISABLED
	property.display.process_mode = Node.PROCESS_MODE_DISABLED
	var previous_match: MatchState = lab._match_state
	lab._start_new_match()
	_check(
		lab._match_state != previous_match and property.display._match == lab._match_state,
		"new match synchronously rebinds retained board without property/display processing"
	)
	property.process_mode = property_mode as Node.ProcessMode
	property.display.process_mode = display_mode as Node.ProcessMode
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"retained board rebinds actual new match and displays it"
	)
	_receiver_visibility(lab, property)
	var target: Node3D = property.objects[_prefix + "RECEIVER-PRIMARY"]
	var panel: Node3D = target.get_node("Visual/ST026_PANEL")
	var panel_rest: Transform3D = panel.transform
	receiver._flex(0.09)
	_check(panel.transform != panel_rest, "retained target visibly flexes")
	_check(_runtime.installed(lab, "AE-01"), "legitimate target flex stays valid")
	receiver._flex(0.18)
	var net: Node3D = property.objects[_prefix + "RECEIVER-CATCH"]
	var strands: MeshInstance3D = net.get_node("Visual/ST025_NET_STRANDS")
	var rest: PackedVector3Array = net.get_meta("net_rest_vertices")
	receiver._flex_net(0.12)
	var vertices: PackedVector3Array = strands.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(vertices != rest, "retained net uses real corrected pocket animation")
	_check(_runtime.installed(lab, "AE-01"), "legitimate net pocket stays valid")
	receiver._flex_net(0.24)
	await get_tree().physics_frame


func _receiver_visibility(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var prefix: String = "npc:" + property.venue_id + ":r%d:" % _revision
	for identity: String in [prefix + "RECEIVER-PRIMARY", prefix + "RECEIVER-CATCH"]:
		var model: Node3D = property.objects[identity]
		for style: Array in [
			[false, 1.0], [true, 1.0], [false, StadiumReceiverVisibility.FADED_ALPHA]
		]:
			StadiumReceiverVisibility._style(model, style[0], style[1])
			_check(
				_runtime.installed(lab, property.venue_id),
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


func _whole_lab_removal(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	_check(_runtime.install(lab, id), "whole-lab removal installs retained " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var originals: Array[Node] = property.old_nodes.duplicate()
	_check(not originals.is_empty(), "whole-lab removal starts with actual detached originals")
	for node: Node in originals:
		_check(
			is_instance_valid(node) and node.get_parent() == null,
			"saved original is alive and detached before entire lab destruction"
		)
	lab.free()
	await get_tree().process_frame
	for node: Variant in originals:
		_check(
			not is_instance_valid(node), "whole-lab destruction releases every detached original"
		)


func _unexpected_removal(id: String, mode: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	var before: Dictionary = _scene_state(lab)
	_check(_runtime.install(lab, id), "removal probe installs retained " + id)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	if mode == "live-ball":
		_check(lab._match_state.begin_pitch(), "unexpected-removal ball begins from ordinary pitch")
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 3, 10)
		launch.velocity = Vector3(0, 2, 12)
		lab._start_ball_in_play(launch)
		_check(
			(
				is_instance_valid(lab._batted_ball)
				and lab._batted_ball.physics_contact_router.is_valid()
			),
			"removal probe has real bound live ball"
		)
	elif mode == "live-pitch":
		lab._match_mode = false
		lab._throw_pitch()
		_check(lab._pitch_actor.running, "removal probe has an actual running pitch")
	if mode.begins_with("live-"):
		lab._automation = MatchAutomation.new()
		lab.set_process(true)
		lab.set_physics_process(true)
	if mode == "detach":
		property.get_parent().remove_child(property)
	else:
		property.free()
	_check(
		(
			not lab.has_meta("stadium_property")
			and not lab.has_meta("stadium_candidate_only")
			and lab._field_definition == before.field
			and lab._ball_play_resolver.segment_observer == before.observer
			and lab._pitch_actor.receiver_router == before.receiver
			and lab._primary_fielder.stadium_boundary_clip == before.clip
		),
		"unexpected removal synchronously clears metadata and restores all callback/field targets"
	)
	_check(not _runtime.installed(lab, id), "removed property fails installed check")
	await get_tree().process_frame
	var prior_automation: MatchAutomation = lab._automation
	lab._automation = MatchAutomation.new()
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"reattached automation cannot recapture removed harness plays as a legacy report"
	)
	lab._automation = prior_automation
	var restored: Dictionary = _scene_state(lab)
	if mode.begins_with("live-"):
		_check(
			(
				lab.process_mode == Node.PROCESS_MODE_DISABLED
				and lab._automation == null
				and not lab._pitch_actor.running
				and not is_instance_valid(lab._batted_ball)
				and not lab._release_controller.active
				and lab.get_meta("stadium_npc_runtime_interrupted", false)
			),
			"live removal safely cancels activity and leaves interrupted lab disabled"
		)
		restored.metadata.erase(&"stadium_npc_runtime_interrupted")
	_check(before == restored, "unexpected removal restores original live nodes/order " + mode)
	if mode == "detach" and is_instance_valid(property):
		property.free()
	if mode.begins_with("live-"):
		_refused(
			lab, id, _revision, "interrupted physical match cannot resume as a new retained runtime"
		)
		lab.free()
		lab = _lab()
		lab.set_meta("stadium_npc_retained_lab_only", true)
	_check(
		_runtime.install(lab, id) and _runtime.installed(lab, id),
		"fresh lab after interruption or restored idle lab accepts retained runtime"
	)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(_runtime.installed(lab, id), "fresh explicit restart retains valid bindings")
	_check(_runtime.teardown(lab), "recovered runtime tears down explicitly")
	lab.free()
	await get_tree().process_frame


func _routes(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
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


func _inside(property: StadiumNpcRetainedProperty, point: Vector3) -> bool:
	var ground: Vector2 = Vector2(point.x, point.z)
	if property.venue_id == "AY-01":
		return StadiumNpcYardGraphV1.contains(ground)
	return property.boundary.graph.contains(ground)


func _flight(lab: PitchBatLab, property: StadiumNpcRetainedProperty, sample: Array) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	if property.receiver != null:
		property.receiver.contacts.clear()
	_check(lab._match_state.begin_pitch(), "real retained game accepts an ordinary pitch")
	var outcomes: Array[BallPlayOutcome] = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome)
	lab._ball_play_resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = sample[0]
	launch.velocity = sample[1]
	launch.is_foul = sample[2]
	lab._start_ball_in_play(launch)
	lab.set_physics_process(true)
	_check(
		lab._batted_ball.physics_contact_router.is_valid(),
		"real ball uses retained physical routing"
	)
	for frame in range(180):
		await get_tree().physics_frame
		if lab._ball_play_resolver.state.dead:
			break
	_check(
		outcomes.size() == 1 and outcomes[0].result == sample[3],
		"one real retained terminal outcome at " + str(sample[0])
	)
	if property.receiver != null and sample[0].z < 1:
		_check(
			property.receiver.contacts.size() == 1,
			"retained target/net foul causes exactly one physical receiver response"
		)
	lab.set_physics_process(false)
	lab._ball_play_resolver.play_resolved.disconnect(callback)
	lab._cleanup_batted_ball()


func _scene_state(lab: PitchBatLab) -> Dictionary:
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var nodes: Array[int] = []
	for node: Node in host.find_children("*", "", true, false):
		nodes.append(node.get_instance_id())
	var metadata: Dictionary = {}
	for key: StringName in lab.get_meta_list():
		metadata[key] = lab.get_meta(key)
	return {
		"nodes": nodes,
		"metadata": metadata.duplicate(true),
		"host": host.transform,
		"field": lab._field_definition,
		"field_id": lab._field_id,
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera_mask": lab._camera.cull_mask,
		"director": lab._camera_director
	}


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _candidate_expected_routes(id: String) -> Array[Dictionary]:
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
