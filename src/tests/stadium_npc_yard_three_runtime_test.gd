extends Node3D
## AY03-only specialization of the independently qualified retained lifecycle controls.

const IDS: Array[String] = ["AY-03"]
var _revision: int = 1
var _runtime: Script = StadiumNpcYardThreeRuntimeV1
var _definitions: Script = StadiumNpcYardThreeCandidateV1

var _failures: int = 0


func _ready() -> void:
	_check(not _runtime.install(null, "AY-03"), "null cannot install")
	_check(not _runtime.installed(null, "AY-03"), "null is never installed")
	_check(not _runtime.teardown(null), "null cannot tear down")
	var unready: PitchBatLab = PitchBatLab.new()
	unready.set_meta("stadium_npc_ay03_installed_lab_only", true)
	_check(not _runtime.install(unready, "AY-03"), "unready lab fails closed")
	unready.free()
	for id: String in IDS:
		_guards(id)
		_staging(id)
		_rollback(id)
		await _lifecycle(id)
		await _whole_lab_removal(id)
		await _destroyed_actor(id)
		await _disposal_before_restore(id, true)
		await _disposal_before_restore(id, false)
		for mode: String in ["detach", "free", "live-ball", "live-pitch"]:
			await _unexpected_removal(id, mode)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AY03 private installed runtime passed: lifecycle, routes and physical controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	return lab


func _guards(id: String) -> void:
	var lab: PitchBatLab = _lab()
	_refused(lab, id, _revision, "missing opt-in")
	lab.set_meta("stadium_npc_ay03_installed_lab_only", false)
	_refused(lab, id, _revision, "false opt-in")
	for wrong: Variant in [1, "true", [], {}]:
		lab.set_meta("stadium_npc_ay03_installed_lab_only", wrong)
		_refused(lab, id, _revision, "wrong-typed private opt-in")
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	lab.remove_meta("stadium_npc_retained_lab_only")
	_refused(lab, id, _revision, "missing persistent legacy report quarantine")
	for wrong: Variant in [false, 1, "true", [], {}]:
		lab.set_meta("stadium_npc_retained_lab_only", wrong)
		_refused(lab, id, _revision, "false/wrong-typed persistent report quarantine")
	lab.set_meta("stadium_npc_retained_lab_only", true)
	for invalid: String in ["", "ay-01", "ae-01", "AY-01 ", "ac-01", "AC-01-unknown", "FOREIGN-01"]:
		_refused(lab, invalid, _revision, "unsupported exact identity")
	for denied: String in ["AY-01", "AY-02", "AE-01", "AC-01", "AM-01", "AM-02"]:
		_refused(lab, denied, 1, "private adapter cannot widen another venue")
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
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
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
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
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
			not _runtime.installed(lab, "AY-01")
			and not _runtime.installed(lab, id, 3 - _revision)
		),
		"no venue/revision substitution"
	)
	_refused(lab, id, _revision, "reentrant retained installation")
	_identity(lab, property, definition)
	_integrity(lab, property)
	_ay03_integrity(lab, property)
	_rebind_controls(lab, property)
	_teardown_guards(lab, id)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _pole_collisions(lab, property)
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		_routes(lab, property)
		_camera(lab, property)
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
	_quarantine_controls(lab, id)
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
	if definition.id == "AY-03":
		_check(
			(
				property.receiver == null
				and property.display == null
				and not lab._pitch_actor.receiver_router.is_valid()
				and property.route_obstacles().is_empty()
			),
			"AY preserves free default receiver and zero live objects"
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
	var visibility: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var recipe: StadiumRecipeBoundary = visibility._recipe
	visibility._recipe = (
		StadiumNpcExpandedV1.TemplateView.new()
		if id == "AY-03"
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


func _whole_lab_removal(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
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
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
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
	if not mode.begins_with("live-"):
		_quarantine_controls(lab, id)
	if mode == "detach" and is_instance_valid(property):
		property.free()
	if mode.begins_with("live-"):
		_refused(
			lab, id, _revision, "interrupted physical match cannot resume as a new retained runtime"
		)
		lab.free()
		lab = _lab()
		lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	_check(
		_runtime.install(lab, id) and _runtime.installed(lab, id),
		"fresh lab after interruption or restored idle lab accepts retained runtime"
	)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(_runtime.rebind_match(lab), "explicit restart rebinds the private match")
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
	if property.venue_id == "AY-03":
		return StadiumNpcYardGraphV1.contains(ground)
	return property.boundary.graph.contains(ground)


func _flight(lab: PitchBatLab, property: StadiumNpcRetainedProperty, sample: Array) -> void:
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	if property.receiver != null:
		property.receiver.contacts.clear()
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(_runtime.rebind_match(lab), "fresh physical probe explicitly rebinds")
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




func _rebind_controls(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var original: MatchState = lab._match_state
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	_check(lab._match_state != original and not _runtime.installed(lab),
		"replacement match cannot silently retain installed authority")
	var replacement: MatchState = lab._match_state
	lab._match_state = null
	_check(not _runtime.rebind_match(lab), "missing match cannot rebind")
	lab._match_state = replacement
	replacement.stadium = {"foreign": true}
	_check(not _runtime.rebind_match(lab), "foreign fixture cannot rebind")
	replacement.stadium = {}
	lab._automation = MatchAutomation.new()
	_check(not _runtime.rebind_match(lab), "running automation cannot rebind")
	lab._automation = null
	_check(_runtime.rebind_match(lab) and _runtime.installed(lab),
		"explicit idle empty-match rebind preserves the exact installed tree")
	_check(property.get("bound_state") == replacement, "rebind pins actual replacement object")


func _ay03_integrity(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var construction: Node3D = property.construction
	property.construction = Node3D.new()
	_invalid_then(lab, "AY-03", "wrong construction type refuses before field access")
	property.construction.free()
	_invalid_then(lab, "AY-03", "freed construction refuses without stale-object access")
	property.construction = null
	_invalid_then(lab, "AY-03", "missing construction refuses without member access")
	property.construction = construction
	_restored(lab, "AY-03")
	var boundary: Node3D = property.boundary
	var boundary_index: int = boundary.get_index()
	construction.remove_child(boundary)
	_invalid_then(lab, "AY-03", "missing BoundaryGraph refuses through nullable lookup")
	construction.add_child(boundary)
	construction.move_child(boundary, boundary_index)
	property.boundary = null
	_invalid_then(lab, "AY-03", "missing boundary member refuses quietly")
	property.boundary = boundary
	var original_field: FieldDefinition = property.field
	property.field = null
	_invalid_then(lab, "AY-03", "missing field refuses quietly")
	property.field = original_field
	var identity: String = "npc:AY-03:r1:SC-L1"
	var chair: Node3D = property.objects[identity]
	property.objects[identity] = 23
	_invalid_then(lab, "AY-03", "wrong object-map value refuses before typed assignment")
	property.objects[identity] = chair
	_restored(lab, "AY-03")
	var light: Node3D = property.objects["npc:AY-03:r1:YLIGHT-FL"]
	var beam: SpotLight3D = light.get_node("FieldLight")
	beam.visible = true
	_invalid_then(lab, "AY-03", "active beam is never admitted")
	beam.visible = false
	_restored(lab, "AY-03")
	var energy: float = beam.light_energy
	beam.light_energy += 0.001
	_invalid_then(lab, "AY-03", "dormant optical properties remain exact")
	beam.light_energy = energy
	_restored(lab, "AY-03")
	var basis: Basis = beam.basis
	var component: float = beam.basis.x.x
	var bytes: PackedByteArray = PackedFloat32Array([component]).to_byte_array()
	bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	beam.basis.x.x = bytes.decode_float(0)
	_check(beam.basis.x.x != component, "actual adjacent-float32 beam mutation changes geometry")
	_invalid_then(lab, "AY-03", "one real float32 step is rejected")
	beam.basis = basis
	_restored(lab, "AY-03")
	var material: StandardMaterial3D = light.get_node("Visual/LampLens").material_override
	material.emission_enabled = true
	_invalid_then(lab, "AY-03", "dormant lens cannot become emissive")
	material.emission_enabled = false
	_restored(lab, "AY-03")
	var mode: Node.ProcessMode = light.process_mode
	light.process_mode = Node.PROCESS_MODE_DISABLED
	_invalid_then(lab, "AY-03", "disabled subtree execution is detected")
	light.process_mode = mode
	_restored(lab, "AY-03")
	var definition: Dictionary = _definitions.definition()
	_check(not StadiumNpcVenues.valid_manifest(definition)
		and StadiumNpcVenues.definition("AY-03", 1).is_empty()
		and StadiumNpcAvailability.record("AY-03", 1).is_empty()
		and StadiumNpcSnapshot.raw_entry("AY-03", 1).is_empty()
		and StadiumNpcSnapshot.capture("AY-03", 1).is_empty()
		and SeasonSave._decode(definition) == null
		and ClubAssetLedger.from_data(definition, 0, []) == null,
		"private installed use opens no public, fixture, season or ownership authority")


func _camera(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var view: StadiumNpcRetainedVisibility = lab._camera_director.tracking_visibility
	var source: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
	var host: Node3D = Node3D.new()
	host.add_child(source)
	source.name = "HomeProperty"
	add_child(host)
	var original: StadiumYardFieldVisibility = StadiumYardFieldVisibility.new()
	original.configure(host)
	_check(view._wall_prisms.walls == original._wall_prisms.walls
		and view._obstacles == original._obstacles,
		"installed camera uses exact original Yard wall and eight-copy scenery occluders")
	for eye: Vector3 in [Vector3(0, 2, -4), Vector3(-12, 8, 8), Vector3(12, 8, 8)]:
		for ball: Vector3 in [Vector3(0, 1, 10), Vector3(-20, 2, 12), Vector3(20, 2, 12)]:
			_check(view.clear_position(eye, ball) == original.clear_position(eye, ball)
				and view._blocked(eye, ball) == original._blocked(eye, ball),
				"both-handed role probes preserve original camera clearance behavior")
	var director: MatchCameraDirector = lab._camera_director
	var saved: Dictionary = {}
	for key: String in StadiumNpcRetainedRuntime.CAMERA_STATE:
		saved[key] = director.get(key)
	var control: MatchCameraDirector = MatchCameraDirector.new()
	control.tracking_visibility = original
	control.set_batter_handedness(lab._match_state.batter().definition.bats
		== PlayerDefinition.Handedness.LEFT)
	director._live_coverage = BallInPlayCamera.new()
	director.clear_presentation_motion()
	director.track_released_pitch(false, Vector3.ZERO)
	for defense: bool in [false, true]:
		for endpoint: Vector3 in [Vector3(0, 1, 22), Vector3(-17, 1, 12), Vector3(17, 1, 12)]:
			for camera: MatchCameraDirector in [director, control]:
				camera.set_shot(MatchCameraDirector.Shot.PITCHING if defense
					else MatchCameraDirector.Shot.BATTING)
				camera.prepare_ball_in_play(defense, Vector3(0, 1, 1), endpoint)
			_check(director._desired_transform(Vector3(0, 1, 1), 1.0 / 60)
				== control._desired_transform(Vector3(0, 1, 1), 1.0 / 60),
				"actual batting/pitching director pose equals independent original view")
			director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			control.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			for step in range(1, 13):
				var point: Vector3 = Vector3(0, 1, 1).lerp(endpoint, float(step) / 12)
				_check(director._desired_transform(point, 1.0 / 60)
					== control._desired_transform(point, 1.0 / 60),
					"actual installed batting/defense tracking matches original for both hands")
	for key: String in saved:
		director.set(key, saved[key])
	_check(lab._camera_director == property.old_camera
		and not lab._camera_director is StadiumExpandedCameraDirector,
		"actual Yard director is retained without Expanded fallback")
	host.free()


func _rollback(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	var before: Dictionary = _scene_state(lab)
	var staged: StadiumNpcYardThreePropertyV1 = _runtime._stage(lab, id, 1)
	_check(staged != null, "rollback starts with a genuine unchanged stage")
	if staged != null:
		var light: SpotLight3D = staged.objects["npc:AY-03:r1:YLIGHT-FL"].get_node("FieldLight")
		var callback: Callable = func() -> void: light.visible = true
		staged.tree_entered.connect(callback, CONNECT_ONE_SHOT)
		_check(not _runtime._commit(lab, staged),
			"tree-entry mutation fails the post-commit actual-state gate")
		_check(before == _scene_state(lab) and staged.get_parent() == null,
			"post-commit rollback restores exact original objects, order and callbacks")
		staged.free()
	lab.free()


func _pole_collisions(lab: PitchBatLab, property: StadiumNpcRetainedProperty) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for site: String in ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]:
		var model: Node3D = property.objects["npc:AY-03:r1:" + site]
		var point: Vector3 = model.global_position + Vector3(0, 2, 0)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + Vector3(0, 0, -1), point + Vector3(0, 0, 1), 1)
		var body: StaticBody3D = model.get_node("Collision/Pole")
		var hit: Dictionary = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body,
			"actual ordinary-lab installed dormant pole ray " + site)
		body.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(space.intersect_ray(ray).is_empty() and not _runtime.installed(lab),
			"body-disable control removes actual pole physics and fails integrity")
		body.process_mode = Node.PROCESS_MODE_INHERIT
		await get_tree().physics_frame
		await get_tree().physics_frame
		hit = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body and _runtime.installed(lab),
			"restored actual pole physics and full runtime integrity")


func _destroyed_actor(id: String) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	_check(_runtime.install(lab, id), "destroyed-actor control starts installed")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var state: MatchState = lab._match_state
	var phase: int = state.phase
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	lab._pitch_actor.free()
	lab._release_controller = null
	lab._at_bat_cadence = null
	_check(not _runtime.installed(lab), "destroyed actor refuses installed validation quietly")
	property.free()
	await get_tree().process_frame
	_check(lab.process_mode == Node.PROCESS_MODE_DISABLED
		and lab.get_meta("stadium_npc_runtime_interrupted", false)
		and not lab.has_meta("stadium_npc_runtime_restoring")
		and lab._automation == null and lab._match_state == state and state.phase == phase
		and not lab.has_meta("stadium_property") and PhysicalMatchReport.capture(lab).is_empty(),
		"destroyed actor and missing controllers restore safely, quarantine, and mint no outcome")
	lab.free()


func _disposal_before_restore(id: String, destroy_lab: bool) -> void:
	var lab: PitchBatLab = _lab()
	lab.set_meta("stadium_npc_ay03_installed_lab_only", true)
	_check(_runtime.install(lab, id), "deferred-disposal control starts installed")
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var originals: Array[Node] = property.old_nodes.duplicate()
	var host: Node = property.get_parent()
	host.remove_child(property)
	_check(lab.has_meta("stadium_npc_runtime_restoring"), "restoration is genuinely pending")
	if destroy_lab:
		lab.free()
	else:
		host.free()
	await get_tree().process_frame
	for node: Variant in originals:
		_check(not is_instance_valid(node), "original detached node reclaimed before deferred restore")
	property.free()
	if not destroy_lab:
		_check(lab.process_mode == Node.PROCESS_MODE_DISABLED
			and lab.get_meta("stadium_npc_runtime_interrupted", false)
			and not lab.has_meta("stadium_npc_runtime_restoring"),
			"missing host keeps surviving lab quarantined without dangling restoration")
		lab.free()


func _quarantine_controls(lab: PitchBatLab, id: String) -> void:
	_check(lab.get_meta("stadium_npc_retained_lab_only", false) == true
		and lab.get_meta("stadium_npc_ay03_installed_lab_only", false) == true
		and PhysicalMatchReport.capture(lab).is_empty(),
		"teardown/removal preserves both caller-owned fences and refuses report capture")
	lab.remove_meta("stadium_npc_retained_lab_only")
	_refused(lab, id, 1, "missing persistent report fence after cleanup")
	_check(not _runtime.installed(lab), "missing report fence cannot validate removed property")
	for wrong: Variant in [false, 1, "true", [], {}]:
		lab.set_meta("stadium_npc_retained_lab_only", wrong)
		_refused(lab, id, 1, "false/wrong-typed persistent report fence after cleanup")
		_check(not _runtime.installed(lab), "wrong report fence cannot validate removed property")
	lab.set_meta("stadium_npc_retained_lab_only", true)
	_check(PhysicalMatchReport.capture(lab).is_empty(), "restored caller fence still refuses report")
