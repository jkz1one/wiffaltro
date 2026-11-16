class_name StadiumNpcYardTwoInstalledProof
extends RefCounted
## Finite reconstructed test oracles; original authoring is used only in these tests.
# gdlint: disable=max-file-lines

const MAP: String = "res://src/tests/fixtures/npc_yard_two_installed_baseline.json"
const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
const P: String = "npc:AY-02:r1:"


static func record(owner: Node, id: String, ok: bool, detail: String) -> void:
	if not owner._seen.has(id):
		owner._seen[id] = []
	owner._seen[id].append(ok)
	if not ok:
		owner._failures += 1
		push_error(id + ": " + detail)
	print("AY02_ASSERT ", JSON.stringify({"id": id, "passed": ok, "detail": detail}))


static func finish(owner: Node, scene: String) -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	var expected: Array[String] = []
	if scene == "runtime":
		for id: String in baseline.runtime_suites[owner._suite]:
			expected.append(id)
	else:
		for row: Dictionary in baseline.cases:
			if row.execution_scene == scene and row.status != "DEFERRED_RENDERED":
				expected.append(row.id)
	for id: String in expected:
		if not owner._seen.has(id):
			owner._failures += 1
			push_error("AY02 missing required assertion " + id)
	for id: String in owner._seen:
		if not expected.has(id):
			owner._failures += 1
			push_error("AY02 undeclared assertion " + id)
	var report: Dictionary = {
		"schema": "ay02-reconstructed-cases-v1",
		"scene": scene,
		"required": expected,
		"assertions": owner._seen,
		"failures": owner._failures,
		"rendered_qualification": false
	}
	var marker: String = "AY02_RECONSTRUCTED_" + scene.to_upper()
	if scene == "runtime":
		report.suite = owner._suite
		marker += "_" + owner._suite.to_upper()
	print("AY02_CASE_REPORT ", JSON.stringify(report))
	if owner._failures == 0:
		print(marker + "_PASS")
	owner.get_tree().quit(0 if owner._failures == 0 else 1)


static func public_closed() -> bool:
	var data: Dictionary = StadiumNpcYardTwoCandidateV1.definition()
	return (
		StadiumNpcVenues.definition("AY-02", 1).is_empty()
		and StadiumNpcAvailability.record("AY-02", 1).is_empty()
		and StadiumNpcSnapshot.raw_entry("AY-02", 1).is_empty()
		and StadiumNpcSnapshot.capture("AY-02", 1).is_empty()
		and StadiumNpcSnapshot.fixture(data, {}, {}).is_empty()
		and StadiumNpcSnapshot.raw_fixture(data, {}, {}).is_empty()
		and not StadiumLayoutSnapshot.valid(data)
		and not PhysicalMatchReport.valid(data)
		and SeasonSave._decode(data) == null
		and ClubAssetLedger.from_data(data, 0, []) == null
	)


static func public_private_fences_current() -> bool:
	var private_data: Dictionary = StadiumNpcYardTwoCandidateV1.definition()
	var manifest: Dictionary = StadiumNpcVenues.definition("AY-02", 1)
	var entry: Dictionary = StadiumNpcSnapshot.capture("AY-02", 1)
	return not manifest.is_empty() and manifest.get("id") == "AY-02" \
		and manifest.get("revision") == 1 \
		and not StadiumNpcAvailability.record("AY-02", 1).is_empty() \
		and StadiumNpcSnapshot.valid(entry) \
		and entry.get("version") == StadiumNpcSnapshot.PUBLIC_VERSION \
		and entry.get("manifest", {}) == manifest \
		and StadiumNpcSnapshot.raw_entry("AY-02", 1).is_empty() \
		and StadiumNpcSnapshot.fixture(private_data, {}, {}).is_empty() \
		and StadiumNpcSnapshot.raw_fixture(private_data, {}, {}).is_empty() \
		and not StadiumLayoutSnapshot.valid(private_data) \
		and not PhysicalMatchReport.valid(private_data) \
		and SeasonSave._decode(private_data) == null \
		and ClubAssetLedger.from_data(private_data, 0, []) == null


# AY02_CASE_PHASE: REPORT
static func report_controls(owner: Node) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab._automation = MatchAutomation.new()
	lab._automation.seed = 29
	owner.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var before: PackedByteArray = game_state(lab)
	var first: Dictionary = PhysicalMatchReport.capture(lab)
	owner._assert(
		"QUA-01/fresh_partial_before",
		not first.is_empty() and lab._match_state.phase != MatchState.Phase.GAME_END,
		"Fresh genuine original lab capture is partial, never completed-game evidence"
	)
	lab.set_meta("stadium_npc_retained_lab_only", true)
	lab.set_meta("stadium_npc_ay02_installed_lab_only", true)
	owner._assert(
		"QUA-05/fence",
		PhysicalMatchReport.capture(lab).is_empty() and game_state(lab) == before,
		"Exact fence alone blocks the same genuine capture"
	)
	lab.remove_meta("stadium_npc_retained_lab_only")
	lab.remove_meta("stadium_npc_ay02_installed_lab_only")
	owner._assert(
		"QUA-01/fresh_partial_after",
		(
			var_to_bytes(PhysicalMatchReport.capture(lab)) == var_to_bytes(first)
			and game_state(lab) == before
		),
		"Removing test fence restores exact partial bytes without fabricated terminal state"
	)
	lab.free()
	var path: String = "res://src/tests/fixtures/npc_r2_legacy_report_positive.json"
	var digest: String = "f81affe8112489a09e26c3bd914ef6c0099c091e830e72b6c1347de666a35fad"
	var index: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://src/tests/fixtures/npc_r2_completed_artifact_index.json"
		)
	)
	var key: String = "builds/verification/20261008T170743141012Z/physical-reports/physical-ai-29.json"
	owner._assert(
		"QUA-01/historical_completed",
		(
			FileAccess.get_sha256(path) == digest
			and index.files[key].sha256 == digest
			and PhysicalMatchReport.valid(JSON.parse_string(FileAccess.get_file_as_string(path)))
		),
		"Separate exact historical completed report has its original provenance only"
	)
	var season: SeasonState = SeasonState.create(42, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var request: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var genuine: bool = PhysicalMatchRequest.capture(request) != null
	request.stadium = StadiumNpcYardTwoCandidateV1.definition()
	owner._assert(
		"QUA-06/physical_request",
		genuine and PhysicalMatchRequest.capture(request) == null,
		"Genuine positive request becomes refused with private definition"
	)
	owner._assert(
		"QUA-06/public_dispatch", public_private_fences_current(),
		"Public AY02 is qualified separately; private definitions and raw aliases stay refused"
	)


static func game_state(lab: PitchBatLab) -> PackedByteArray:
	var state: MatchState = lab._match_state
	var plays: Array = []
	for play: PlayRecord in lab._play_records:
		plays.append(play.to_dict())
	return var_to_bytes(
		[
			state.phase,
			state.inning,
			state.top_half,
			state.balls,
			state.strikes,
			state.outs,
			state.away_team.runs,
			state.home_team.runs,
			state.plate_appearance_number,
			plays
		]
	)


static func resolver_state(resolver: BallPlayResolver) -> PackedByteArray:
	var state: BallPlayState = resolver.state
	return var_to_bytes(
		[
			state.is_fair,
			state.is_foul_play,
			state.has_grounded,
			state.first_ground_position,
			state.result_floor,
			state.last_defender_touch,
			state.last_obstacle_contact,
			state.stadium_contacts,
			state.defender_touched,
			state.bobbled,
			state.caught,
			state.dead,
			state.catch_position,
			state.catch_time,
			state.elapsed_seconds
		]
	)


static func parameters(height: float) -> PitchLaunchParameters:
	var value: PitchLaunchParameters = PitchLaunchParameters.new()
	value.pitch_id = &"pitch.overhand_four_seam"
	value.position = Vector3(0, height, 0.4)
	value.velocity = Vector3(0, 0, -10)
	value.drag_coefficient = 0
	value.magnus_scale = 0
	value.perforation_force_scale = 0
	value.seed = 51
	return value


static func fresh(owner: Node, lab: PitchBatLab, begin: bool = true) -> bool:
	lab._cleanup_batted_ball()
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	var valid: bool = R.rebind_match(lab)
	if begin:
		valid = valid and lab._match_state.begin_pitch()
	if not valid:
		owner._failures += 1
		push_error("AY02 genuine fresh fixture could not rebind/begin")
	return valid


static func physical(model: Node3D) -> PackedByteArray:
	var rows: Array = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var shape: CollisionShape3D = body.get_child(0)
		rows.append(
			[
				body,
				body.transform,
				body.collision_layer,
				body.collision_mask,
				body.process_mode,
				body.disable_mode,
				shape,
				shape.transform,
				shape.disabled,
				shape.shape,
				StadiumNpcRetainedGeometry._stored(shape.shape)
			]
		)
	return var_to_bytes(rows)


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func integrity(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	fresh(owner, lab)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 3, 10)
	lab._start_ball_in_play(launch)
	lab._batted_ball.freeze = true
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var cone: Node3D = property.objects[P + "O-R1"]
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	var original: Variant
	var pose: Transform3D
	owner._assert(
		"INT-09/callback_positive",
		callback_accepts(lab, property),
		"Actual installed observer and guarded manifold callback resolve expected histories"
	)
	var replacement: Node3D = chair.duplicate()
	original = property.objects[P + "RECEIVER-PRIMARY"]
	property.objects[P + "RECEIVER-PRIMARY"] = replacement
	owner._assert(
		"INT-01/chair_identity",
		callback_refuses(lab, property),
		"Copied-tag chair refuses callbacks"
	)
	property.objects[P + "RECEIVER-PRIMARY"] = original
	replacement.free()
	replacement = cone.duplicate()
	property.objects[P + "O-R1"] = replacement
	owner._assert(
		"INT-02/cone_identity", callback_refuses(lab, property), "Copied-tag cone refuses callbacks"
	)
	property.objects[P + "O-R1"] = cone
	replacement.free()
	var extra: StaticBody3D = body.duplicate()
	chair.get_node("Collision").add_child(extra)
	owner._assert("INT-03/appended_body", callback_refuses(lab, property), "Appended body refuses")
	extra.free()
	var container: Node = body.get_parent()
	var index: int = body.get_index()
	container.remove_child(body)
	owner._assert(
		"INT-03/missing_body", callback_refuses(lab, property), "Missing genuine member refuses"
	)
	chair.add_child(body)
	owner._assert(
		"INT-03/reparented_body", callback_refuses(lab, property), "Reparented real body refuses"
	)
	chair.remove_child(body)
	container.add_child(body)
	container.move_child(body, index)
	var shape_resource: Shape3D = shape.shape
	shape.shape = shape_resource.duplicate(true)
	owner._assert(
		"INT-04/shape_resource", callback_refuses(lab, property), "Equal shape resource refuses"
	)
	shape.shape = shape_resource
	var shape_copy: Node = shape.duplicate()
	body.remove_child(shape)
	body.add_child(shape_copy)
	owner._assert("INT-04/shape_node", callback_refuses(lab, property), "Equal shape node refuses")
	shape_copy.free()
	body.add_child(shape)
	body.move_child(shape, 0)
	var script_model: GDScript = GDScript.new()
	script_model.source_code = "extends Node3D\n"
	var compiled_model: bool = script_model.reload() == OK
	chair.set_script(script_model)
	owner._assert(
		"INT-05/model_script",
		compiled_model and callback_refuses(lab, property),
		"Same-valued attached resource/node script must refuse real callbacks"
	)
	chair.set_script(null)
	var script_shape: GDScript = GDScript.new()
	script_shape.source_code = "extends BoxShape3D\n"
	var compiled_shape: bool = script_shape.reload() == OK
	shape_resource.set_script(script_shape)
	owner._assert(
		"INT-05/shape_script",
		compiled_shape and callback_refuses(lab, property),
		"Same-valued attached resource/node script must refuse real callbacks"
	)
	shape_resource.set_script(null)
	var script_mesh: GDScript = GDScript.new()
	script_mesh.source_code = "extends BoxMesh\n"
	var compiled_mesh: bool = script_mesh.reload() == OK
	mesh.mesh.set_script(script_mesh)
	owner._assert(
		"INT-05/mesh_script",
		compiled_mesh and callback_refuses(lab, property),
		"Same-valued attached resource/node script must refuse real callbacks"
	)
	mesh.mesh.set_script(null)
	var script_material: GDScript = GDScript.new()
	script_material.source_code = "extends StandardMaterial3D\n"
	var compiled_material: bool = script_material.reload() == OK
	mesh.material_override.set_script(script_material)
	owner._assert(
		"INT-05/material_script",
		compiled_material and callback_refuses(lab, property),
		"Same-valued attached resource/node script must refuse real callbacks"
	)
	mesh.material_override.set_script(null)
	var original_field_script: Script = property.field.get_script()
	var field_values: Dictionary = {}
	for item: Dictionary in property.field.get_property_list():
		if int(item.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and item.name != "script":
			field_values[item.name] = property.field.get(item.name)
	var script_field: GDScript = GDScript.new()
	script_field.source_code = "extends FieldDefinition\n"
	var compiled_field: bool = script_field.reload() == OK
	property.field.set_script(script_field)
	for key: String in field_values:
		property.field.set(key, field_values[key])
	owner._assert(
		"INT-05/field_script",
		compiled_field and callback_refuses(lab, property),
		"Same-valued field resource with a foreign script refuses both callbacks"
	)
	property.field.set_script(original_field_script)
	for key: String in field_values:
		property.field.set(key, field_values[key])
	var exact_pose: Transform3D = body.transform
	body.position.y = next_f32(body.position.y)
	owner._assert(
		"INT-06/one_ulp_pose",
		body.transform != exact_pose and callback_refuses(lab, property),
		"One float32 ULP in actual collider pose is refused"
	)
	body.transform = exact_pose
	var box: BoxShape3D = shape_resource as BoxShape3D
	var exact_size: Vector3 = box.size
	box.size.x = next_f32(box.size.x)
	owner._assert(
		"INT-06/one_ulp_dimension",
		box.size != exact_size and callback_refuses(lab, property),
		"One float32 ULP in collider dimensions is refused"
	)
	box.size = exact_size
	var wrapper_node: Node3D = property
	pose = wrapper_node.transform
	wrapper_node.position.x += 0.125
	owner._assert(
		"INT-06/wrapper_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	wrapper_node.transform = pose
	var construction_node: Node3D = property.construction
	pose = construction_node.transform
	construction_node.position.x += 0.125
	owner._assert(
		"INT-06/construction_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	construction_node.transform = pose
	var model_node: Node3D = cone
	pose = model_node.transform
	model_node.position.x += 0.125
	owner._assert(
		"INT-06/model_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	model_node.transform = pose
	var body_node: Node3D = body
	pose = body_node.transform
	body_node.position.x += 0.125
	owner._assert(
		"INT-06/body_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	body_node.transform = pose
	var shape_node: Node3D = shape
	pose = shape_node.transform
	shape_node.position.x += 0.125
	owner._assert(
		"INT-06/shape_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	shape_node.transform = pose
	var boundary_node: Node3D = property.boundary
	pose = boundary_node.transform
	boundary_node.position.x += 0.125
	owner._assert(
		"INT-06/boundary_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	boundary_node.transform = pose
	var lab_node: Node3D = lab
	pose = lab_node.transform
	lab_node.position.x += 0.125
	owner._assert(
		"INT-06/lab_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	lab_node.transform = pose
	var host_node: Node3D = property.get_parent()
	pose = host_node.transform
	host_node.position.x += 0.125
	owner._assert(
		"INT-06/host_pose",
		callback_refuses(lab, property),
		"Complete callback admission includes every actual physical ancestor"
	)
	host_node.transform = pose
	original = body.get("collision_layer")
	body.set("collision_layer", 0)
	owner._assert(
		"INT-07/layer", callback_refuses(lab, property), "Exact physical execution policy"
	)
	body.set("collision_layer", original)
	original = body.get("collision_mask")
	body.set("collision_mask", 3)
	owner._assert("INT-07/mask", callback_refuses(lab, property), "Exact physical execution policy")
	body.set("collision_mask", original)
	original = body.get("disable_mode")
	body.set("disable_mode", CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE)
	owner._assert(
		"INT-07/disable_mode", callback_refuses(lab, property), "Exact physical execution policy"
	)
	body.set("disable_mode", original)
	original = body.get("process_mode")
	body.set("process_mode", Node.PROCESS_MODE_DISABLED)
	owner._assert(
		"INT-07/process_mode", callback_refuses(lab, property), "Exact physical execution policy"
	)
	body.set("process_mode", original)
	original = shape.get("disabled")
	shape.set("disabled", true)
	owner._assert(
		"INT-07/disabled", callback_refuses(lab, property), "Exact physical execution policy"
	)
	shape.set("disabled", original)
	original = chair.get_meta("npc_instance")
	chair.set_meta("npc_instance", "foreign")
	owner._assert(
		"INT-08/instance", callback_refuses(lab, property), "Exact typed retained metadata"
	)
	chair.set_meta("npc_instance", original)
	original = chair.get_meta("owned_copy")
	chair.set_meta("owned_copy", "foreign")
	owner._assert("INT-08/alias", callback_refuses(lab, property), "Exact typed retained metadata")
	chair.set_meta("owned_copy", original)
	original = chair.get_meta("stadium_item")
	chair.set_meta("stadium_item", "foreign")
	owner._assert("INT-08/item", callback_refuses(lab, property), "Exact typed retained metadata")
	chair.set_meta("stadium_item", original)
	original = chair.get_meta("npc_site")
	chair.set_meta("npc_site", "foreign")
	owner._assert("INT-08/site", callback_refuses(lab, property), "Exact typed retained metadata")
	chair.set_meta("npc_site", original)
	original = chair.get_meta("npc_host")
	chair.set_meta("npc_host", "foreign")
	owner._assert("INT-08/host", callback_refuses(lab, property), "Exact typed retained metadata")
	chair.set_meta("npc_host", original)
	original = body.get_meta("surface_id")
	body.set_meta("surface_id", "foreign")
	owner._assert(
		"INT-08/surface", callback_refuses(lab, property), "Exact typed retained metadata"
	)
	body.set_meta("surface_id", original)
	original = body.get_meta("surface_role")
	body.set_meta("surface_role", "foreign")
	owner._assert("INT-08/role", callback_refuses(lab, property), "Exact typed retained metadata")
	body.set_meta("surface_role", original)
	var field: FieldDefinition = property.field
	property.field = field.duplicate(true)
	owner._assert(
		"INT-09/field_identity", callback_refuses(lab, property), "Equal foreign field refuses"
	)
	property.field = field
	var camera: StadiumNpcYardTwoCameraV1 = property.camera
	property.camera = StadiumNpcYardTwoCameraV1.new()
	owner._assert(
		"INT-09/support_identity", callback_refuses(lab, property), "Exact camera support identity"
	)
	property.camera = camera
	var motion: StadiumNpcYardTwoCameraMotionV1 = property.motion
	property.motion = StadiumNpcYardTwoCameraMotionV1.new()
	owner._assert(
		"INT-09/motion_identity",
		callback_refuses(lab, property),
		"Foreign camera-motion support cannot authorize physical callbacks"
	)
	property.motion = motion
	var view: StadiumNpcYardTwoVisibilityV1 = property.visibility
	property.visibility = StadiumNpcYardTwoVisibilityV1.new()
	owner._assert(
		"INT-09/visibility_identity",
		callback_refuses(lab, property),
		"Foreign view support refuses exact callback admission"
	)
	property.visibility = view
	var boundary_body: Node = property.boundary.get_node("BACK-TERMINAL-01")
	var boundary_index: int = boundary_body.get_index()
	var copied_body: Node = boundary_body.duplicate()
	property.boundary.remove_child(boundary_body)
	property.boundary.add_child(copied_body)
	property.boundary.move_child(copied_body, boundary_index)
	owner._assert(
		"INT-09/boundary_body",
		callback_refuses(lab, property),
		"Equal copied boundary body cannot replace the genuine body handle"
	)
	copied_body.free()
	property.boundary.add_child(boundary_body)
	property.boundary.move_child(boundary_body, boundary_index)
	var router: Callable = lab._batted_ball.physics_contact_router
	lab._batted_ball.physics_contact_router = Callable()
	owner._assert(
		"INT-09/ball_callback", not R.installed(lab), "Bound actual ball callback is immutable"
	)
	lab._batted_ball.physics_contact_router = router
	var contacts: int = property.receiver.contacts.size()
	var path: Dictionary = property.receiver.trace(Vector3(0, 0.65, 0), Vector3(0, 0, -10), 0.0365)
	property.receiver.present_contact(path.hit.duplicate(true), "pitch")
	property.receiver._finish(lab._pitch_actor, path.duplicate(true))
	owner._assert(
		"INT-10/forged_payload",
		(
			property.receiver.contacts.size() == contacts
			and not property.receiver.route(
				lab._pitch_actor, Vector3(0, 0.65, 0), Vector3(0, 0, -10)
			)
		),
		"Even a copied genuine trace carries no epoch/token ownership"
	)
	var fake: StaticBody3D = body.duplicate()
	owner._assert(
		"INT-10/foreign_collider",
		(
			property.contact_identity(fake).is_empty()
			and (
				property
				. receiver
				. _owned_hit({"collider_id": fake.get_instance_id(), "point": Vector3.ZERO}, 0.0)
				. is_empty()
			)
		),
		"Foreign actual ID cannot inherit tags"
	)
	fake.free()
	var visual: Node3D = chair.get_node("Visual")
	pose = visual.transform
	var tween: Tween = owner.create_tween()
	tween.pause()
	tween.tween_property(visual, "rotation:z", 0.02, 0.1)
	tween.custom_step(0.05)
	owner._assert(
		"INT-12/foreign_tween",
		callback_refuses(lab, property),
		"Real unowned visual Tween is outside the genuine rock allowance"
	)
	tween.kill()
	visual.transform = pose
	owner._assert(
		"INT-12/restoration",
		R.installed(lab) and callback_accepts(lab, property),
		"Restored exact objects/resources/scripts/poses have positive callback outcomes/history"
	)
	lab._cleanup_batted_ball()


static func callback_refuses(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var resolver: BallPlayResolver = lab._ball_play_resolver
	resolver.start_play(property.field)
	var before: PackedByteArray = resolver_state(resolver)
	var history: PackedByteArray = var_to_bytes([property.provenance, property.boundary.contacts])
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void: outcomes.append(value.result)
	resolver.play_resolved.connect(hook)
	var refused: bool = (
		property.observe(resolver, Vector3(0, 0.6, 22), Vector3(0, 0.6, 25)).is_empty()
	)
	var batch: Array[Dictionary] = [
		{"body": property.boundary.get_node("BACK-TERMINAL-01"), "position": Vector3(0, 0.6, 23.4)}
	]
	property._boundary_contact_batch(lab._batted_ball, batch, resolver)
	resolver.play_resolved.disconnect(hook)
	return (
		refused
		and not property.callback_intact()
		and outcomes.is_empty()
		and resolver_state(resolver) == before
		and var_to_bytes([property.provenance, property.boundary.contacts]) == history
	)


static func callback_accepts(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(hook)
	resolver.start_play(property.field)
	var event: Dictionary = property.observe(resolver, Vector3(0, 0.6, 22), Vector3(0, 0.6, 25))
	var observer_ok: bool = (
		not event.is_empty()
		and resolver.state.dead
		and outcomes.size() == 1
		and outcomes[0] == [BallPlayOutcome.Result.TRIPLE, &"back_wall_on_fly"]
		and resolver.state.stadium_contacts.size() == 1
	)
	resolver.start_play(property.field)
	var count: int = property.boundary.contacts.size()
	property.boundary._forget(lab._batted_ball.get_instance_id())
	var batch: Array[Dictionary] = [
		{"body": property.boundary.get_node("BACK-TERMINAL-01"), "position": Vector3(0, 0.6, 23.4)}
	]
	lab._batted_ball.physics_contact_router.call(lab._batted_ball, batch)
	var batch_ok: bool = (
		resolver.state.dead
		and outcomes.size() == 2
		and outcomes[1] == [BallPlayOutcome.Result.TRIPLE, &"back_wall_on_fly"]
		and resolver.state.stadium_contacts.size() == 1
		and property.boundary.contacts.size() == count + 1
		and property.boundary.contacts[-1].segment == "BACK-TERMINAL-01"
	)
	resolver.play_resolved.disconnect(hook)
	return observer_ok and batch_ok and property.callback_intact()


# AY02_CASE_PHASE: PHYSICS
static func physics_controls(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	fresh(owner, lab, false)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	var receiver: StadiumNpcYardTwoReceiverV1 = property.receiver
	var hit: Dictionary = receiver.trace(Vector3(0, 0.65, 0), Vector3(0, 0, -10), 0.0365)
	owner._assert(
		"PHY-01/back",
		not hit.hit.is_empty() and hit.hit.surface == "ST079_BACK",
		"Genuine installed sphere sweep first hits chair back"
	)
	hit = receiver.trace(Vector3(0, 0.47, 0), Vector3(0, 0, -10), 0.0365)
	owner._assert(
		"PHY-01/seat", not hit.hit.is_empty() and hit.hit.surface == "ST079_SEAT", "Seat sweep"
	)
	hit = receiver.trace(Vector3(0.27, 0.60, 0), Vector3(0, 0, -10), 0.0365)
	owner._assert(
		"PHY-01/arm",
		not hit.hit.is_empty() and String(hit.hit.surface).begins_with("ST079_ARM"),
		"Arm sweep"
	)
	hit = receiver.trace(Vector3(0.22, 0.22, 0), Vector3(0, 0, -10), 0.0365)
	owner._assert(
		"PHY-01/leg",
		not hit.hit.is_empty() and String(hit.hit.surface).begins_with("ST079_FRONT_LEG"),
		"Leg sweep"
	)
	var chair: Node3D = receiver.chair
	var mode: Node.ProcessMode = chair.process_mode
	chair.process_mode = Node.PROCESS_MODE_DISABLED
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	owner._assert(
		"PHY-02/disabled", chair_ray(owner).is_empty(), "Disabled real receiver has no hit"
	)
	chair.process_mode = mode
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	owner._assert(
		"PHY-02/disabled_restored",
		not chair_ray(owner).is_empty() and R.installed(lab),
		"Restored same chair resumes actual physical hits"
	)
	var parent: Node = chair.get_parent()
	var index: int = chair.get_index()
	parent.remove_child(chair)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	owner._assert("PHY-02/removed", chair_ray(owner).is_empty(), "Removed actual chair has no hits")
	parent.add_child(chair)
	parent.move_child(chair, index)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	owner._assert(
		"PHY-02/removed_restored",
		not chair_ray(owner).is_empty() and R.installed(lab),
		"Exact identity restoration recovers the physics positive"
	)
	hit = receiver.trace(Vector3(0, 1.3, 0), Vector3(0, 0, -10), 0.0365)
	owner._assert(
		"PHY-04/cleanup",
		(
			hit.hit.is_empty()
			and hit.reason == "receiver_cleanup"
			and is_equal_approx(hit.points[-1].z, -1.4)
		),
		"Original cleanup-plane arithmetic"
	)
	hit = receiver.trace(Vector3(0, 1.3, 0), Vector3(0, 0, -0.5), 0.0365)
	owner._assert(
		"PHY-04/timeout",
		(
			hit.hit.is_empty()
			and hit.reason == "receiver_presentation_timeout"
			and hit.times[-1] == 0.24
			and StadiumPitchReceiver.STEP == 1.0 / 240.0
		),
		"Exact retained timeout and step; no rounded literal"
	)
	var row: Dictionary = await chair_hit(owner, lab, property, false)
	owner._assert(
		"PHY-06/fair",
		row.once and row.provenance and row.presentation and row.physical,
		"Exactly one actual FOUL/receiver_containment from genuine chair, with one presentation"
	)
	row = await chair_hit(owner, lab, property, true)
	owner._assert(
		"PHY-06/foul",
		row.once and row.provenance and row.presentation and row.physical,
		"Incoming foul also has one exact chair containment outcome, not obstacle-contact inference"
	)
	row = await cone_hit(owner, lab, property, "positive")
	owner._assert(
		"PHY-07/ricochet",
		row.hit and row.live and row.ricochet and row.provenance,
		"Actual cone collision has subsequent reversing velocity and spatial motion"
	)
	row = await cone_hit(owner, lab, property, "disabled")
	owner._assert("PHY-08/disabled", not row.hit, "Disabled actual cone removes collision")
	row = await cone_hit(owner, lab, property, "restored")
	owner._assert(
		"PHY-08/disabled_restored",
		row.hit and row.live and row.ricochet and row.provenance,
		"Exact cone restoration resumes genuine moving ricochet"
	)
	row = await cone_hit(owner, lab, property, "removed")
	owner._assert("PHY-08/removed", not row.hit, "Removed cone has no collision")
	row = await cone_hit(owner, lab, property, "restored")
	owner._assert(
		"PHY-08/removed_restored",
		row.hit and row.live and row.ricochet and row.provenance,
		"Same cone identity after removal resumes actual motion"
	)
	fresh(owner, lab, false)
	var routes: Array[Dictionary] = property.route_obstacles()
	owner._assert(
		"PHY-09/routes",
		(
			routes.size() == 2
			and routes[0].copy == P + "RECEIVER-PRIMARY"
			and routes[0].center == chair.global_position
			and routes[0].radius == Vector2(0.30, 0.43).length() + 0.32
			and routes[1].copy == P + "O-R1"
			and routes[1].center == property.objects[P + "O-R1"].global_position
			and routes[1].radius == Vector2(0.175, 0.175).length() + 0.32
			and StadiumNpcYardTwoContractV1.canonical().live_units == 1
		),
		"Exact two clearance circles; only cone counts as live unit"
	)
	owner._assert("PHY-10/right_cone", fielder(lab, false, false, false), "Right-hand cone passage")
	owner._assert("PHY-10/left_cone", fielder(lab, true, false, false), "Left-hand cone passage")
	owner._assert(
		"PHY-10/right_chair", fielder(lab, false, true, false), "Right-hand chair passage"
	)
	owner._assert("PHY-10/left_chair", fielder(lab, true, true, false), "Left-hand chair passage")
	owner._assert(
		"PHY-10/stationary_negative",
		not fielder(lab, false, false, true),
		"Stationary fielder cannot pass the progress/arrival oracle"
	)
	arithmetic(owner, property)
	installed_observer(owner, lab, property)
	side_observer(owner, lab, property)
	await boundary_physics(owner, lab, property)
	await corner_orders(owner, lab, property)
	fresh(owner, lab, false)


static func chair_ray(owner: Node3D) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 0.65, 0), Vector3(0, 0.65, -1.4), StadiumPitchReceiver.LAYER
	)
	return owner.get_world_3d().direct_space_state.intersect_ray(query)


static func chair_hit(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1, foul: bool
) -> Dictionary:
	fresh(owner, lab)
	var count: int = property.receiver.contacts.size()
	var history_count: int = property.provenance.size()
	var original: PackedByteArray = physical(property.receiver.chair)
	var outcomes: Array = []
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var callback: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(callback)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 0.75, 0.2)
	launch.velocity = Vector3(0, 0, -6)
	launch.is_foul = foul
	lab._start_ball_in_play(launch)
	var observed: Array[Node] = []
	lab._batted_ball.body_entered.connect(
		func(body: Node) -> void:
			if property.receiver.chair.is_ancestor_of(body):
				observed.append(body)
	)
	for frame in range(90):
		await owner.get_tree().physics_frame
		if resolver.state.dead:
			break
	for frame in range(4):
		await owner.get_tree().physics_frame
	var new_rows: Array = property.provenance.slice(history_count)
	var provenance_ok: bool = false
	for body: Node in observed:
		var member: Dictionary = property.contact_identity(body)
		if not member.is_empty() and new_rows.size() == 1:
			provenance_ok = (
				provenance_ok
				or (
					new_rows[0].instance == P + "RECEIVER-PRIMARY"
					and new_rows[0].surface == member.surface
					and new_rows[0].preterminal
				)
			)
	var answer: Dictionary = {
		"once":
		(
			outcomes == [[BallPlayOutcome.Result.FOUL, &"receiver_containment"]]
			and resolver.state.dead
		),
		"provenance": provenance_ok,
		"presentation":
		(
			property.receiver.contacts.size() == count + 1
			and property.receiver.contacts[-1].kind == "batted"
		),
		"physical": false
	}
	lab._cleanup_batted_ball()
	await owner.get_tree().create_timer(0.30).timeout
	answer.physical = physical(property.receiver.chair) == original and R.installed(lab)
	resolver.play_resolved.disconnect(callback)
	return answer


static func cone_hit(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1, mode: String
) -> Dictionary:
	fresh(owner, lab)
	var cone: Node3D = property.objects[P + "O-R1"]
	var parent: Node = cone.get_parent()
	var index: int = cone.get_index()
	var prior_mode: Node.ProcessMode = cone.process_mode
	var provenance_start: int = property.provenance.size()
	if mode == "disabled":
		cone.process_mode = Node.PROCESS_MODE_DISABLED
	elif mode == "removed":
		parent.remove_child(cone)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(8, 0.42, 15.2)
	launch.velocity = Vector3(0, 0, -6)
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	var history_start: int = lab._ball_play_resolver.state.stadium_contacts.size()
	var contacts: Array = []
	ball.body_entered.connect(
		func(body: Node) -> void:
			if cone.is_ancestor_of(body):
				contacts.append([body, ball.global_position])
	)
	var reversed_motion: bool = false
	for frame in range(60):
		await owner.get_tree().physics_frame
		if not contacts.is_empty():
			reversed_motion = (
				reversed_motion
				or (
					ball.linear_velocity.z > 0.1
					and ball.global_position.z > contacts[0][1].z + 0.001
				)
			)
			if reversed_motion:
				break
	var new_provenance: Array = property.provenance.slice(provenance_start)
	var new_history: Array = lab._ball_play_resolver.state.stadium_contacts.slice(history_start)
	var provenance_joined: bool = not contacts.is_empty()
	for observed: Array in contacts:
		var member: Dictionary = property.contact_identity(observed[0])
		var source_joined: bool = false
		var history_joined: bool = false
		if not member.is_empty() and member.model == cone and member.instance == P + "O-R1":
			for row: Dictionary in new_provenance:
				source_joined = (
					source_joined
					or (
						row.instance == member.instance
						and row.surface == member.surface
						and row.preterminal
					)
				)
			for row: Dictionary in new_history:
				history_joined = (
					history_joined
					or (
						row.source == "item"
						and row.id == member.instance
						and row.surface == String(member.surface)
						and row.role == "LIVE_RICOCHET"
						and row.kind == "contact"
					)
				)
		provenance_joined = provenance_joined and source_joined and history_joined
	var answer: Dictionary = {
		"hit": not contacts.is_empty(),
		"ricochet": reversed_motion,
		"provenance": provenance_joined,
		"live":
		(
			not lab._ball_play_resolver.state.dead
			and ball.gravity_scale > 0
			and lab._ball_play_resolver.state.last_obstacle_contact == StringName(P + "O-R1")
		)
	}
	lab._cleanup_batted_ball()
	cone.process_mode = prior_mode
	if mode == "removed":
		parent.add_child(cone)
		parent.move_child(cone, index)
	await owner.get_tree().physics_frame
	return answer


static func fielder(lab: PitchBatLab, left: bool, chair: bool, stationary: bool) -> bool:
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	var actor: FielderController = lab._primary_fielder
	var original: Vector3 = actor.global_position
	var old_stationary: bool = actor.stationary
	actor.set_physics_process(false)
	var start: Vector3 = Vector3(-2, 0, -0.5) if chair else Vector3(8, 0, 11)
	var target: Vector3 = Vector3(2, 0, -0.5) if chair else Vector3(8, 0, 17)
	actor.set_anchor(start)
	actor.begin_play()
	actor.stationary = stationary
	actor.target_position = target
	var clear: bool = true
	var distance: float = 0.0
	for tick in range(600):
		var before: Vector3 = actor.global_position
		actor._physics_process(1.0 / 60.0)
		distance += before.distance_to(actor.global_position)
		clear = (
			clear
			and StadiumDefenderRoutes.clear(before, actor.global_position, actor.stadium_obstacles)
		)
	var progressed: bool = distance > 2.0 and actor.global_position.distance_to(target) < 0.05
	actor.end_play()
	actor.set_anchor(original)
	actor.stationary = old_stationary
	return clear and progressed


# AY02_CASE_PHASE: ARITHMETIC
static func arithmetic(owner: Node, property: StadiumNpcYardTwoPropertyV1) -> void:
	owner._assert(
		"PHY-11/arithmetic_0_0_false_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_0_false_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_0_true_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_0_true_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_1_false_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_1_false_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_1_true_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_1_true_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_2_false_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_2_false_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_2_true_false",
		arithmetic_pair(property.field, "REAR-DEAD-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_0_2_true_true",
		arithmetic_pair(property.field, "REAR-DEAD-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_0_false_false",
		arithmetic_pair(property.field, "SIDE-R-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_0_false_true",
		arithmetic_pair(property.field, "SIDE-R-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_0_true_false",
		arithmetic_pair(property.field, "SIDE-R-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_0_true_true",
		arithmetic_pair(property.field, "SIDE-R-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_1_false_false",
		arithmetic_pair(property.field, "SIDE-R-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_1_false_true",
		arithmetic_pair(property.field, "SIDE-R-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_1_true_false",
		arithmetic_pair(property.field, "SIDE-R-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_1_true_true",
		arithmetic_pair(property.field, "SIDE-R-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_2_false_false",
		arithmetic_pair(property.field, "SIDE-R-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_2_false_true",
		arithmetic_pair(property.field, "SIDE-R-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_2_true_false",
		arithmetic_pair(property.field, "SIDE-R-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_1_2_true_true",
		arithmetic_pair(property.field, "SIDE-R-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_0_false_false",
		arithmetic_pair(property.field, "RETURN-R-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_0_false_true",
		arithmetic_pair(property.field, "RETURN-R-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_0_true_false",
		arithmetic_pair(property.field, "RETURN-R-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_0_true_true",
		arithmetic_pair(property.field, "RETURN-R-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_1_false_false",
		arithmetic_pair(property.field, "RETURN-R-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_1_false_true",
		arithmetic_pair(property.field, "RETURN-R-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_1_true_false",
		arithmetic_pair(property.field, "RETURN-R-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_1_true_true",
		arithmetic_pair(property.field, "RETURN-R-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_2_false_false",
		arithmetic_pair(property.field, "RETURN-R-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_2_false_true",
		arithmetic_pair(property.field, "RETURN-R-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_2_true_false",
		arithmetic_pair(property.field, "RETURN-R-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_2_2_true_true",
		arithmetic_pair(property.field, "RETURN-R-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_0_false_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_0_false_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_0_true_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_0_true_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_1_false_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_1_false_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_1_true_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_1_true_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_2_false_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_2_false_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_2_true_false",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_3_2_true_true",
		arithmetic_pair(property.field, "BACK-TERMINAL-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_0_false_false",
		arithmetic_pair(property.field, "RETURN-L-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_0_false_true",
		arithmetic_pair(property.field, "RETURN-L-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_0_true_false",
		arithmetic_pair(property.field, "RETURN-L-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_0_true_true",
		arithmetic_pair(property.field, "RETURN-L-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_1_false_false",
		arithmetic_pair(property.field, "RETURN-L-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_1_false_true",
		arithmetic_pair(property.field, "RETURN-L-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_1_true_false",
		arithmetic_pair(property.field, "RETURN-L-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_1_true_true",
		arithmetic_pair(property.field, "RETURN-L-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_2_false_false",
		arithmetic_pair(property.field, "RETURN-L-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_2_false_true",
		arithmetic_pair(property.field, "RETURN-L-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_2_true_false",
		arithmetic_pair(property.field, "RETURN-L-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_4_2_true_true",
		arithmetic_pair(property.field, "RETURN-L-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_0_false_false",
		arithmetic_pair(property.field, "SIDE-L-01", 0.4, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_0_false_true",
		arithmetic_pair(property.field, "SIDE-L-01", 0.4, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_0_true_false",
		arithmetic_pair(property.field, "SIDE-L-01", 0.4, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_0_true_true",
		arithmetic_pair(property.field, "SIDE-L-01", 0.4, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_1_false_false",
		arithmetic_pair(property.field, "SIDE-L-01", 2.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_1_false_true",
		arithmetic_pair(property.field, "SIDE-L-01", 2.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_1_true_false",
		arithmetic_pair(property.field, "SIDE-L-01", 2.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_1_true_true",
		arithmetic_pair(property.field, "SIDE-L-01", 2.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_2_false_false",
		arithmetic_pair(property.field, "SIDE-L-01", 4.0, false, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_2_false_true",
		arithmetic_pair(property.field, "SIDE-L-01", 4.0, false, true),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_2_true_false",
		arithmetic_pair(property.field, "SIDE-L-01", 4.0, true, false),
		"Arithmetic only: original crossing/apply oracle"
	)
	owner._assert(
		"PHY-11/arithmetic_5_2_true_true",
		arithmetic_pair(property.field, "SIDE-L-01", 4.0, true, true),
		"Arithmetic only: original crossing/apply oracle"
	)


static func arithmetic_pair(
	field: FieldDefinition, segment: String, height: float, grounded: bool, foul: bool
) -> bool:
	var row: Dictionary = StadiumBoundaryGraph.segment(segment)
	var midpoint: Vector2 = (row.a + row.b) / 2
	var normal: Vector2 = StadiumBoundaryGraph.inward(row)
	var start: Vector3 = Vector3(midpoint.x + normal.x, height, midpoint.y + normal.y)
	var end: Vector3 = Vector3(midpoint.x - normal.x, height, midpoint.y - normal.y)
	var a: BallPlayResolver = BallPlayResolver.new()
	var b: BallPlayResolver = BallPlayResolver.new()
	a.start_play(field, foul)
	b.start_play(field, foul)
	a.state.has_grounded = grounded
	b.state.has_grounded = grounded
	var outcomes_a: Array = []
	var outcomes_b: Array = []
	a.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void:
			outcomes_a.append(
				[outcome.result, outcome.reason, outcome.caught, outcome.resolution_position]
			)
	)
	b.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void:
			outcomes_b.append(
				[outcome.result, outcome.reason, outcome.caught, outcome.resolution_position]
			)
	)
	var one: Dictionary = StadiumNpcYardGraphV1.crossing(start, end)
	var two: Dictionary = StadiumBoundaryGraph.crossing(start, end)
	var applied_a: bool = StadiumNpcYardGraphV1.apply(a, one)
	var applied_b: bool = StadiumBoundaryGraph.apply(b, two)
	return (
		one == two
		and applied_a == applied_b
		and var_to_bytes(outcomes_a) == var_to_bytes(outcomes_b)
		and resolver_state(a) == resolver_state(b)
	)


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func installed_observer(
	owner: Node, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	fresh(owner, lab)
	var outcomes: Array = []
	var resolver: BallPlayResolver = lab._ball_play_resolver
	resolver.start_play(property.field)
	var hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(hook)
	var observer: Callable = resolver.segment_observer
	var event: Dictionary = observer.call(resolver, Vector3(0, 2, 22), Vector3(0, 2, 25))
	owner._assert(
		"PHY-11/installed_observer",
		(
			observer == property.observe
			and not event.is_empty()
			and event.segment == "BACK-TERMINAL-01"
			and outcomes.size() == 1
			and outcomes[0] == [BallPlayOutcome.Result.TRIPLE, &"back_wall_on_fly"]
			and resolver.state.stadium_contacts.size() == 1
		),
		"Actual installed callback with actual resolver/outcome/history; not a physical flight"
	)
	resolver.play_resolved.disconnect(hook)


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func side_observer(
	owner: Node, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	fresh(owner, lab)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	resolver.start_play(property.field)
	var oracle: BallPlayResolver = BallPlayResolver.new()
	oracle.start_play(property.field)
	var segment: Dictionary = StadiumBoundaryGraph.segment("SIDE-R-01")
	var middle: Vector2 = (segment.a + segment.b) / 2
	var inward: Vector2 = StadiumBoundaryGraph.inward(segment)
	var from: Vector3 = Vector3(middle.x + inward.x, 0.6, middle.y + inward.y)
	var to: Vector3 = Vector3(middle.x - inward.x, 0.6, middle.y - inward.y)
	var outcomes: Array = []
	var original_outcomes: Array = []
	var callback: Callable = func(outcome: BallPlayOutcome) -> void:
		outcomes.append([outcome.result, outcome.reason])
	resolver.play_resolved.connect(callback)
	oracle.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void:
			original_outcomes.append([outcome.result, outcome.reason])
	)
	var expected: Dictionary = StadiumBoundaryObserver.observe(oracle, from, to)
	var actual: Dictionary = resolver.segment_observer.call(resolver, from, to)
	owner._assert(
		"PHY-11/installed_side_observer",
		(
			resolver.segment_observer == property.observe
			and not actual.is_empty()
			and actual == expected
			and actual.segment == "SIDE-R-01"
			and outcomes.is_empty()
			and original_outcomes.is_empty()
			and not resolver.state.dead
			and resolver.state.last_obstacle_contact == &"SIDE-R-01"
			and resolver.state.stadium_contacts.size() == 1
			and resolver_state(resolver) == resolver_state(oracle)
		),
		"Real installed side observer matches original live outcome/history; no flight claim"
	)
	resolver.play_resolved.disconnect(callback)


# AY02_CASE_PHASE: PHYSICS
static func boundary_physics(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	var row: Dictionary = await boundary_flight(owner, lab, property, "BACK-TERMINAL-01", false)
	owner._assert(
		"PHY-11/physical_back_fair",
		(
			row.hit
			and row.once
			and row.result == BallPlayOutcome.Result.TRIPLE
			and row.reason == &"back_wall_on_fly"
		),
		"Actual gravity-on installed back-wall collision has one exact fair outcome/history"
	)
	row = await boundary_flight(owner, lab, property, "BACK-TERMINAL-01", true)
	owner._assert(
		"PHY-11/physical_back_foul",
		(
			row.hit
			and row.once
			and row.result == BallPlayOutcome.Result.FOUL
			and row.reason == &"foul_back_wall"
		),
		"Actual installed foul wall collision remains foul"
	)
	row = await boundary_flight(owner, lab, property, "SIDE-R-01", false)
	owner._assert(
		"PHY-11/physical_side",
		(
			row.hit
			and not row.dead
			and row.count == 0
			and row.last_obstacle == &"SIDE-R-01"
			and row.history
		),
		"Actual live side wall records last_obstacle_contact and does not mint terminal outcome"
	)


static func boundary_flight(
	owner: Node3D,
	lab: PitchBatLab,
	property: StadiumNpcYardTwoPropertyV1,
	segment: String,
	foul: bool
) -> Dictionary:
	fresh(owner, lab)
	var edge: Dictionary = StadiumBoundaryGraph.segment(segment)
	var center: Vector2 = (edge.a + edge.b) / 2
	var normal: Vector2 = StadiumBoundaryGraph.inward(edge)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(
		center.x + normal.x * 0.5,
		2.0 if segment == "BACK-TERMINAL-01" else 0.7,
		center.y + normal.y * 0.5
	)
	launch.velocity = Vector3(-normal.x * 6, 0, -normal.y * 6)
	launch.is_foul = foul
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(hook)
	var count: int = property.boundary.contacts.size()
	lab._start_ball_in_play(launch)
	var bodies: Array[Node] = []
	lab._batted_ball.body_entered.connect(
		func(body: Node) -> void:
			if (
				property.boundary.is_ancestor_of(body)
				and body.get_meta("boundary_segment", "") == segment
			):
				bodies.append(body)
	)
	for frame in range(90):
		await owner.get_tree().physics_frame
		if not bodies.is_empty() and property.boundary.contacts.size() > count:
			break
	var answer: Dictionary = {
		"hit": not bodies.is_empty(),
		"dead": resolver.state.dead,
		"count": outcomes.size(),
		"once": outcomes.size() == 1,
		"result": outcomes[0][0] if outcomes.size() == 1 else -1,
		"reason": outcomes[0][1] if outcomes.size() == 1 else &"",
		"last_obstacle": resolver.state.last_obstacle_contact,
		"history":
		(
			property.boundary.contacts.size() == count + 1
			and property.boundary.contacts[-1].segment == segment
		)
	}
	answer.once = answer.once and answer.history
	lab._cleanup_batted_ball()
	resolver.play_resolved.disconnect(hook)
	return answer


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func corner_orders(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	owner._assert(
		"PHY-12/right_forward",
		corner(owner, lab, property, 3, false),
		"Actual overlap bodies, forward callback order; no physical-flight claim"
	)
	owner._assert(
		"PHY-12/right_reverse",
		corner(owner, lab, property, 3, true),
		"Same observed body set, reversed order"
	)
	owner._assert(
		"PHY-12/left_forward", corner(owner, lab, property, 4, false), "Left forward order"
	)
	owner._assert(
		"PHY-12/left_reverse", corner(owner, lab, property, 4, true), "Left reverse order"
	)


static func corner(
	owner: Node3D,
	lab: PitchBatLab,
	property: StadiumNpcYardTwoPropertyV1,
	index: int,
	reverse: bool
) -> bool:
	fresh(owner, lab)
	var corner_point: Vector2 = StadiumBoundaryGraph.VERTICES[index]
	var position: Vector3 = Vector3(corner_point.x, 0.6, corner_point.y)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.0365
	query.transform = Transform3D(Basis.IDENTITY, position)
	query.collision_mask = 1
	var batch: Array[Dictionary] = []
	for hit: Dictionary in owner.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if property.boundary.is_ancestor_of(hit.collider):
			batch.append({"body": hit.collider, "position": position})
	if batch.size() != 2:
		return false
	batch.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return String(a.body.name) < String(b.body.name)
	)
	if reverse:
		batch.reverse()
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 3, 10)
	lab._start_ball_in_play(launch)
	lab._batted_ball.freeze = true
	var count: int = property.boundary.contacts.size()
	var outcomes: Array = []
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var hook: Callable = func(value: BallPlayOutcome) -> void: outcomes.append(value.result)
	resolver.play_resolved.connect(hook)
	lab._batted_ball.physics_contact_router.call(lab._batted_ball, batch)
	lab._batted_ball.physics_contact_router.call(lab._batted_ball, batch)
	var okay: bool = outcomes == [BallPlayOutcome.Result.TRIPLE]
	okay = okay and property.boundary.contacts.size() == count + 1
	okay = okay and property.boundary.contacts[-1].segment == "BACK-TERMINAL-01"
	resolver.play_resolved.disconnect(hook)
	lab._cleanup_batted_ball()
	return okay


# AY02_CASE_PHASE: PHYSICS
static func called_pitches(owner: Node3D) -> void:
	await called_strike_hits(owner)
	await called_strike_misses(owner)
	await called_ball_hits(owner)
	await called_resets(owner)


# AY02_CASE_PHASE: PHYSICS
static func called_strike_hits(owner: Node3D) -> void:
	var row: Dictionary = await called_pitch(owner, 0.65, false)
	owner._assert(
		"PHY-03/right_strike_hit",
		row.calls and row.contacts == 1 and row.ended,
		"Actual right-handed strike continues into one genuine chair contact"
	)
	owner._assert(
		"INT-11/genuine_rock",
		row.rock and row.physical and row.admitted,
		"Start/mid/end of real owned rock keep physical bytes and callback admission"
	)
	row = await called_pitch(owner, 0.65, true)
	owner._assert(
		"PHY-03/left_strike_hit",
		row.calls and row.contacts == 1 and row.ended,
		"Actual left-handed strike chair contact"
	)


# AY02_CASE_PHASE: PHYSICS
static func called_strike_misses(owner: Node3D) -> void:
	var row: Dictionary = await called_pitch(owner, 1.3, false)
	owner._assert(
		"PHY-03/right_strike_miss",
		row.calls and row.contacts == 0 and row.ended,
		"Actual called strike may miss physical receiver without altering call"
	)
	row = await called_pitch(owner, 1.3, true)
	owner._assert(
		"PHY-03/left_strike_miss",
		row.calls and row.contacts == 0 and row.ended,
		"Left-handed called strike miss"
	)


# AY02_CASE_PHASE: PHYSICS
static func called_ball_hits(owner: Node3D) -> void:
	var row: Dictionary = await called_pitch(owner, 0.47, false)
	owner._assert(
		"PHY-03/right_ball_hit",
		row.calls and row.contacts == 1 and row.ended,
		"Actual called ball and one chair impact stay separate"
	)
	row = await called_pitch(owner, 0.47, true)
	owner._assert(
		"PHY-03/left_ball_hit",
		row.calls and row.contacts == 1 and row.ended,
		"Left-handed called ball hit"
	)


# AY02_CASE_PHASE: PHYSICS
static func called_resets(owner: Node3D) -> void:
	var row: Dictionary = await reset_control(owner, false)
	owner._assert(
		"PHY-05/reset_alone",
		row.started and row.no_contact and row.follow_dead,
		"Actual actor reset alone blocks exact retained stale callback before owner cancellation"
	)
	row = await reset_control(owner, true)
	owner._assert(
		"PHY-05/rock_cancel",
		row.started and row.no_contact and row.follow_dead,
		"Separate explicit owner cancellation kills genuine active rock without another contact"
	)


static func called_pitch(owner: Node3D, height: float, left: bool) -> Dictionary:
	var lab: PitchBatLab = owner._lab()
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	var answer: Dictionary = {
		"calls": false,
		"contacts": -1,
		"ended": false,
		"rock": false,
		"physical": false,
		"admitted": false
	}
	if not R.install(lab):
		lab.free()
		return answer
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var actor: PitchFlightActor = lab._pitch_actor
	actor.set_physics_process(false)
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	lab._match_state.begin_pitch()
	actor.start_pitch(parameters(height))
	actor._physics_process(0.2)
	var calls: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
	answer.calls = calls == (Vector2i(1, 0) if height < 0.55 else Vector2i(0, 1))
	var rest: PackedByteArray = physical(property.receiver.chair)
	var paused_position: Vector3 = actor.global_position
	owner.get_tree().paused = true
	for frame in range(4):
		await owner.get_tree().process_frame
	answer.ended = (
		actor.global_position == paused_position and property.receiver.contacts.is_empty()
	)
	owner.get_tree().paused = false
	answer.physical = true
	answer.admitted = true
	var peak: float = 0
	for frame in range(40):
		await owner.get_tree().create_timer(0.01).timeout
		peak = maxf(peak, absf(property.receiver.chair.get_node("Visual").rotation.z))
		answer.physical = answer.physical and physical(property.receiver.chair) == rest
		answer.admitted = answer.admitted and R.installed(lab) and property.callback_intact()
	answer.rock = peak > deg_to_rad(0.2)
	answer.ended = answer.ended and not actor.visible
	answer.contacts = property.receiver.contacts.size()
	answer.calls = (
		answer.calls and calls == Vector2i(lab._match_state.balls, lab._match_state.strikes)
	)
	lab.free()
	await owner.get_tree().process_frame
	return answer


static func reset_control(owner: Node3D, rock_mode: bool) -> Dictionary:
	var lab: PitchBatLab = owner._lab()
	var answer: Dictionary = {"started": false, "no_contact": false, "follow_dead": false}
	if not R.install(lab):
		lab.free()
		return answer
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	await owner.get_tree().physics_frame
	await owner.get_tree().physics_frame
	lab._match_state.begin_pitch()
	lab._pitch_actor.set_physics_process(false)
	lab._pitch_actor.start_pitch(parameters(0.65))
	lab._pitch_actor._physics_process(0.2)
	var follow: Tween = property.receiver._follow
	var path: Dictionary = property.receiver._issued_path
	var epoch: int = property.receiver._epoch
	if rock_mode:
		for frame in range(40):
			await owner.get_tree().create_timer(0.01).timeout
			if property.receiver.contacts.size() == 1:
				break
		follow = property.receiver._owned_rock
		answer.started = (
			property.receiver.contacts.size() == 1 and follow != null and follow.is_valid()
		)
		property.receiver.cancel_owned()
	else:
		answer.started = follow != null and follow.is_valid() and not path.is_empty()
		lab._pitch_actor.reset_pitch()
		property.receiver._finish_owned(lab._pitch_actor, path, epoch, follow)
	await owner.get_tree().create_timer(0.30).timeout
	answer.no_contact = property.receiver.contacts.size() == (1 if rock_mode else 0)
	answer.follow_dead = follow != null and not follow.is_valid()
	property.receiver.cancel_owned()
	lab.free()
	return answer


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func camera_controls(
	owner: Node3D, lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1
) -> void:
	fresh(owner, lab, false)
	owner._assert(
		"CAM-01/right_entry", entry(lab, property, false), "Right exact owned entry/denials"
	)
	owner._assert("CAM-01/left_entry", entry(lab, property, true), "Left exact owned entry/denials")
	var source: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
	owner.add_child(source)
	var oracle: StadiumYardTwoCameraMotion = StadiumYardTwoCameraMotion.new()
	var positive: bool = oracle.bind_candidate(source)
	owner._assert(
		"CAM-02/batting_cone",
		positive and camera_branch(property, oracle, false, Vector3(8, -0.85, 13.4)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/batting_center",
		positive and camera_branch(property, oracle, false, Vector3(0, 0, 18)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/batting_left",
		positive and camera_branch(property, oracle, false, Vector3(-22, 3, 10)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/batting_right",
		positive and camera_branch(property, oracle, false, Vector3(22, 3, 10)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/batting_zero",
		positive and camera_branch(property, oracle, false, Vector3.ZERO),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/defense_cone",
		positive and camera_branch(property, oracle, true, Vector3(8, -0.85, 13.4)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/defense_center",
		positive and camera_branch(property, oracle, true, Vector3(0, 0, 18)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/defense_left",
		positive and camera_branch(property, oracle, true, Vector3(-22, 3, 10)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/defense_right",
		positive and camera_branch(property, oracle, true, Vector3(22, 3, 10)),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-02/defense_zero",
		positive and camera_branch(property, oracle, true, Vector3.ZERO),
		"Exact original finite launch branch"
	)
	owner._assert(
		"CAM-03/batting_left",
		positive and camera_target(property, oracle, false, -1),
		"Exact original desired target, with unchanged defense arithmetic"
	)
	owner._assert(
		"CAM-03/batting_right",
		positive and camera_target(property, oracle, false, 1),
		"Exact original desired target, with unchanged defense arithmetic"
	)
	owner._assert(
		"CAM-03/defense_left",
		positive and camera_target(property, oracle, true, -1),
		"Exact original desired target, with unchanged defense arithmetic"
	)
	owner._assert(
		"CAM-03/defense_right",
		positive and camera_target(property, oracle, true, 1),
		"Exact original desired target, with unchanged defense arithmetic"
	)
	source.free()
	var cone: Node3D = property.objects[P + "O-R1"]
	var pose: Transform3D = cone.transform
	cone.position.x += 1
	property.motion.prepare(false, Vector3(0, 1, 0), Vector3(8, -0.85, 13.4))
	owner._assert(
		"CAM-04/foreign_cone",
		property.motion.coverage_reason == "shared-launch-coverage",
		"Changed cone cannot acquire visual coverage authority"
	)
	cone.transform = pose
	var camera: MatchCameraDirector = lab._camera_director
	lab._camera_director = MatchCameraDirector.new()
	owner._assert(
		"CAM-04/foreign_director",
		not property.camera.acquire_precontact_entry(),
		"Foreign actual director cannot acquire entry"
	)
	lab._camera_director = camera
	var receiver: StadiumNpcYardTwoReceiverV1 = property.receiver
	var foreign_receiver: StadiumNpcYardTwoReceiverV1 = StadiumNpcYardTwoReceiverV1.new()
	property.camera.set_shot(MatchCameraDirector.Shot.BATTING)
	var genuine_entry: bool = property.camera.acquire_precontact_entry()
	var entry_pose: Transform3D = lab._camera.global_transform
	property.receiver = foreign_receiver
	owner._assert(
		"CAM-04/foreign_receiver",
		(
			genuine_entry
			and not property.camera.acquire_precontact_entry()
			and lab._camera.global_transform == entry_pose
		),
		"Equal-class foreign receiver cannot authorize an entry or mutate the camera"
	)
	property.receiver = receiver
	foreign_receiver.free()
	owner._assert(
		"CAM-04/receiver_restored",
		(
			property.callback_intact()
			and property.camera.acquire_precontact_entry()
			and lab._camera.global_transform == entry_pose
		),
		"The exact original receiver recovers its original admitted camera pose"
	)
	var graph: Node3D = property.boundary
	var fake: Node3D = graph.duplicate()
	property.construction.add_child(fake)
	property.boundary = fake
	owner._assert(
		"CAM-04/copied_graph",
		not property.motion._boundary_intact(),
		"Copied graph and copied boundary tags do not establish identity"
	)
	property.boundary = graph
	fake.free()
	owner._assert(
		"CAM-05/inspection_restore",
		actor_restore(lab, property, false),
		"Actual owned actor fade restores exact materials/shadows through inspection"
	)
	owner._assert(
		"CAM-05/pause_restore",
		actor_restore(lab, property, true),
		"Paused inspection restores actual owned actor state without gameplay advance"
	)
	owner._assert(
		"CAM-05/detach_restore",
		actor_detach(owner),
		"Actual property detach restores actor materials"
	)
	owner._assert(
		"CAM-06/chair_visibility",
		chair_style(lab, property),
		"Chair hidden/visible/faded equals original; no net/target/collision alteration"
	)
	headless_quality(owner, property)
	private_cleanup(owner)
	(
		owner
		. _assert(
			"CAM-08/ball_unchanged",
			ball_unchanged(lab, property),
			"Camera and direct property inspection preserve exact ball geometry/material/physics and FOV"
		)
	)


static func entry(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1, left: bool) -> bool:
	var director: StadiumNpcYardTwoCameraV1 = property.camera
	var pose: Transform3D = lab._camera.global_transform
	var optics: PackedByteArray = camera_optics(lab._camera)
	var expected_optics: Dictionary = camera_optics_fields(lab._camera)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	director.clear_presentation_motion()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	var clauses: Dictionary = {"acquire_entry": director.acquire_precontact_entry()}
	var position: Vector3 = Vector3(-0.18 if left else 0.18, 2.10, -6.5)
	var basis: Basis = Basis.looking_at((Vector3(0, 1.10, 7.1) - position).normalized(), Vector3.UP)
	var authored: Transform3D = Transform3D(basis, position)
	var desired_matches_authored: bool = director._desired_transform(Vector3.ZERO, 1.0) == authored
	var effective: Transform3D = authored.orthonormalized()
	var actual: Transform3D = lab._camera.global_transform
	var actual_optics: PackedByteArray = camera_optics(lab._camera)
	var observed_optics: Dictionary = camera_optics_fields(lab._camera)
	var scale_disabled: bool = lab._camera.is_scale_disabled()
	clauses.entry_transform_exact = desired_matches_authored and scale_disabled and actual == effective
	clauses.entry_optics_exact = actual_optics == optics
	var phase: MatchState.Phase = lab._match_state.phase
	lab._match_state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	lab._camera.global_transform = pose
	var pitch_in_flight_pose: Transform3D = lab._camera.global_transform
	clauses.pitch_in_flight_denied = not director.acquire_precontact_entry()
	clauses.pitch_in_flight_pose_unchanged = lab._camera.global_transform == pitch_in_flight_pose
	lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
	lab._camera.global_transform = pose
	var ball_in_play_pose: Transform3D = lab._camera.global_transform
	clauses.ball_in_play_denied = not director.acquire_precontact_entry()
	clauses.ball_in_play_pose_unchanged = lab._camera.global_transform == ball_in_play_pose
	lab._match_state.phase = phase
	director.cycle_paused_view()
	clauses.paused_view_denied = not director.acquire_precontact_entry()
	director.restore_after_pause()
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._camera.global_transform = pose
	var live_ball_pose: Transform3D = lab._camera.global_transform
	clauses.live_ball_denied = not director.acquire_precontact_entry()
	clauses.live_ball_pose_unchanged = lab._camera.global_transform == live_ball_pose
	lab._batted_ball = null
	ball.free()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	clauses.reacquire_entry = director.acquire_precontact_entry()
	var okay: bool = true
	for clause: bool in clauses.values():
		okay = okay and clause
	var identity: Dictionary = {
		"schema": "ay02-camera-entry-diagnostic-v1",
		"case_id": "CAM-01/left_entry" if left else "CAM-01/right_entry",
		"hand": "left" if left else "right"
	}
	camera_entry_diagnostic(identity, {
		"kind": "clauses", "clauses": clauses, "aggregate_passed": okay
	})
	camera_entry_diagnostic(identity, {
		"kind": "transform",
		"entry_actual": camera_transform_fields(actual),
		"entry_expected": camera_transform_fields(authored),
		"is_scale_disabled": scale_disabled,
		"actual_basis_equals_authored_orthonormalized": actual.basis == authored.basis.orthonormalized()
	})
	camera_entry_diagnostic(identity, {
		"kind": "optics", "actual": observed_optics, "expected": expected_optics,
		"actual_serialized_hex": actual_optics.hex_encode(),
		"expected_serialized_hex": optics.hex_encode()
	})
	return okay


static func camera_entry_diagnostic(identity: Dictionary, fields: Dictionary) -> void:
	var record: Dictionary = identity.duplicate()
	record.merge(fields)
	var line: String = "AY02_CAMERA_ENTRY_DIAGNOSTIC " + JSON.stringify(record, "", false)
	if not camera_diagnostic_finite(record) or line.to_utf8_buffer().size() + 1 > 4096:
		push_error("AY02 camera diagnostic is nonfinite or exceeds its fixed line bound")
		return
	print(line)


static func camera_diagnostic_finite(value: Variant) -> bool:
	if value is float or value is int:
		return is_finite(float(value)) and JSON.stringify(value).length() <= 25
	if value is Array:
		for item: Variant in value:
			if not camera_diagnostic_finite(item):
				return false
	if value is Dictionary:
		for item: Variant in value.values():
			if not camera_diagnostic_finite(item):
				return false
	return true


static func camera_transform_fields(value: Transform3D) -> Dictionary:
	return {
		"components": [
			value.basis.x.x, value.basis.x.y, value.basis.x.z,
			value.basis.y.x, value.basis.y.y, value.basis.y.z,
			value.basis.z.x, value.basis.z.y, value.basis.z.z,
			value.origin.x, value.origin.y, value.origin.z
		],
		"serialized_hex": var_to_bytes(value).hex_encode()
	}


static func camera_optics_fields(camera: Camera3D) -> Dictionary:
	return {
		"projection": camera.projection, "fov": camera.fov, "size": camera.size,
		"near": camera.near, "far": camera.far, "keep_aspect": camera.keep_aspect,
		"frustum_offset": [camera.frustum_offset.x, camera.frustum_offset.y],
		"h_offset": camera.h_offset, "v_offset": camera.v_offset, "cull_mask": camera.cull_mask
	}


static func camera_optics(camera: Camera3D) -> PackedByteArray:
	return var_to_bytes(
		[
			camera.projection,
			camera.fov,
			camera.size,
			camera.near,
			camera.far,
			camera.keep_aspect,
			camera.frustum_offset,
			camera.h_offset,
			camera.v_offset,
			camera.cull_mask
		]
	)


static func actor_materials(lab: PitchBatLab) -> Array:
	var rows: Array = []
	for actor: Node3D in StadiumGrandIIICameraDirector.presentation_actors(lab):
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			rows.append([mesh, mesh.material_override, mesh.cast_shadow])
	return rows


static func actor_same(rows: Array) -> bool:
	for row: Array in rows:
		if (
			not is_instance_valid(row[0])
			or row[0].material_override != row[1]
			or row[0].cast_shadow != row[2]
		):
			return false
	return not rows.is_empty()


static func fade_actual(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var actors: Array[Node3D] = StadiumGrandIIICameraDirector.presentation_actors(lab)
	var target: MeshInstance3D
	for actor: Node3D in actors:
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.is_visible_in_tree() and mesh.mesh != null:
				target = mesh
				break
		if target != null:
			break
	if target == null:
		return false
	var center: Vector3 = target.global_transform * target.get_aabb().get_center()
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	ball.global_position = center + Vector3(0, 0, 2)
	lab._camera.global_position = center - Vector3(0, 0, 2)
	property.camera.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	property.camera.refresh_actor_cutaway(lab._camera, true)
	return (
		not property.actor_cutaway.last_hits.is_empty()
		and target.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


static func actor_restore(
	lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1, paused: bool
) -> bool:
	var rows: Array = actor_materials(lab)
	var pose: Transform3D = lab._camera.global_transform
	var state: PackedByteArray = game_state(lab)
	var faded: bool = fade_actual(lab, property) and not actor_same(rows)
	lab.get_tree().paused = paused
	property.camera.cycle_paused_view()
	property.camera.refresh_actor_cutaway(lab._camera, true)
	var restored: bool = actor_same(rows) and game_state(lab) == state
	lab.get_tree().paused = false
	property.camera.restore_after_pause()
	lab._cleanup_batted_ball()
	lab._camera.global_transform = pose
	property.camera.set_shot(MatchCameraDirector.Shot.BATTING)
	return faded and restored and property.callback_intact()


static func actor_detach(owner: Node3D) -> bool:
	var lab: PitchBatLab = owner._lab()
	if not R.install(lab):
		lab.free()
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var rows: Array = actor_materials(lab)
	var faded: bool = fade_actual(lab, property) and not actor_same(rows)
	property.get_parent().remove_child(property)
	var restored: bool = actor_same(rows)
	property.free()
	lab.free()
	return faded and restored


static func chair_style(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var chair: Node3D = property.receiver.chair
	var oracle: Node3D = StadiumStarterModels.create("ST-079")
	lab.add_child(oracle)
	oracle.global_transform = chair.global_transform
	var original: PackedByteArray = physical(chair)
	property.camera.set_shot(MatchCameraDirector.Shot.BATTING)
	property.refresh_receiver_presentation(lab)
	StadiumReceiverVisibility.apply(oracle, true, lab._camera)
	var same: bool = visual_style(chair) == visual_style(oracle)
	property.refresh_receiver_presentation(lab, true)
	StadiumReceiverVisibility.apply(oracle, false, lab._camera)
	same = same and visual_style(chair) == visual_style(oracle)
	var pose: Transform3D = lab._camera.global_transform
	var center: Vector3 = StadiumReceiverVisibility._bounds(chair).get_center()
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	ball.global_position = center + Vector3(0, 0, 2)
	lab._camera.global_position = center - Vector3(0, 0, 2)
	property.refresh_receiver_presentation(lab, true)
	StadiumReceiverVisibility.apply(oracle, false, lab._camera, ball)
	same = (
		same
		and visual_style(chair) == visual_style(oracle)
		and chair.get_meta("receiver_render_state", "") == "faded"
	)
	lab._cleanup_batted_ball()
	lab._camera.global_transform = pose
	property.refresh_receiver_presentation(lab)
	oracle.free()
	return (
		same
		and physical(chair) == original
		and property.objects.size() == 4
		and not property.objects.has(P + "RECEIVER-NET")
		and not property.objects.has(P + "STRIKE-TARGET")
	)


static func visual_style(model: Node3D) -> PackedByteArray:
	var rows: Array = [model.get_node("Visual").visible]
	for mesh: MeshInstance3D in model.get_node("Visual").find_children(
		"*", "MeshInstance3D", true, false
	):
		rows.append(
			[
				String(mesh.name),
				mesh.transform,
				mesh.material_override.albedo_color,
				mesh.material_override.transparency,
				mesh.cast_shadow
			]
		)
	return var_to_bytes(rows)


static func ball_snapshot(ball: BattedBallBody, camera: Camera3D) -> PackedByteArray:
	var rows: Array = [
		ball.transform,
		ball.mass,
		ball.radius_m,
		ball.collision_layer,
		ball.collision_mask,
		ball.linear_velocity,
		ball.angular_velocity,
		ball.gravity_scale,
		ball.aero_drag_coefficient,
		ball.aero_magnus_scale,
		ball.aero_perforation_force_scale,
		camera_optics(camera),
		ball.physics_material_override.get_instance_id(),
		StadiumNpcRetainedGeometry._stored(ball.physics_material_override)
	]
	for shape: CollisionShape3D in ball.find_children("*", "CollisionShape3D", true, false):
		rows.append(
			[
				shape.get_instance_id(),
				shape.transform,
				shape.disabled,
				shape.shape.get_instance_id(),
				StadiumNpcRetainedGeometry._stored(shape.shape)
			]
		)
	for mesh: MeshInstance3D in ball.find_children("*", "MeshInstance3D", true, false):
		rows.append(
			[
				mesh.get_instance_id(),
				mesh.transform,
				mesh.mesh.get_instance_id(),
				StadiumNpcRetainedGeometry._stored(mesh.mesh),
				mesh.cast_shadow,
				mesh.material_override.get_instance_id(),
				StadiumNpcRetainedGeometry._stored(mesh.material_override)
			]
		)
	return var_to_bytes(rows)


static func ball_unchanged(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	var before: PackedByteArray = ball_snapshot(ball, lab._camera)
	property.camera.refresh_actor_cutaway(lab._camera, false)
	property.refresh_actor_presentation(lab)
	var same: bool = before == ball_snapshot(ball, lab._camera)
	lab._cleanup_batted_ball()
	return same


static func camera_branch(
	property: StadiumNpcYardTwoPropertyV1,
	oracle: StadiumYardTwoCameraMotion,
	defense: bool,
	launch: Vector3
) -> bool:
	property.motion.prepare(defense, Vector3(0, 1, 0), launch)
	oracle.prepare(defense, Vector3(0, 1, 0), launch)
	for key: String in [
		"coverage_reason",
		"coverage_boundary",
		"_defense",
		"_clearance_offset",
		"_air_coverage",
		"_ground_coverage",
		"_carry",
		"_age",
		"_velocity",
		"_turn_speed",
		"_height"
	]:
		if property.motion.get(key) != oracle.get(key):
			return false
	return true


static func camera_target(
	property: StadiumNpcYardTwoPropertyV1,
	oracle: StadiumYardTwoCameraMotion,
	defense: bool,
	side: int
) -> bool:
	var launch: Vector3 = Vector3(side * 22, 3, 10)
	property.motion.prepare(defense, Vector3(0, 1, 0), launch)
	oracle.prepare(defense, Vector3(0, 1, 0), launch)
	var desired: Vector3 = Vector3(side * 50, 8, 12)
	return (
		property.motion.constrain_target(desired) == oracle.constrain_target(desired)
		and (not defense or property.motion.constrain_target(desired) == desired)
	)


# AY02_CASE_PHASE: HEADLESS_ONLY
static func headless_quality(owner: Node, property: StadiumNpcYardTwoPropertyV1) -> void:
	owner._assert(
		"CAM-07/headless_noop",
		(
			DisplayServer.get_name() == "headless"
			and not StadiumWallRenderQuality.attach(property.boundary)
		),
		"Headless-only no-op; all three actual viewport lease cases are DEFERRED_RENDERED"
	)


# AY02_CASE_PHASE: INSTALLED_CALLBACK
static func private_cleanup(owner: Node3D) -> void:
	var lab: PitchBatLab = owner._lab()
	var other: PitchBatLab = owner._lab()
	var admitted: bool = R.install(lab) and R.install(other)
	if not admitted:
		owner._failures += 1
		lab.free()
		other.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var foreign: StadiumNpcYardTwoPropertyV1 = other.get_meta("stadium_property")
	var rows: Array = actor_materials(lab)
	var foreign_rows: Array = actor_materials(other)
	var faded: bool = fade_actual(lab, property) and fade_actual(other, foreign)
	var camera: StadiumNpcYardTwoCameraV1 = property.camera
	var presenter: StadiumNpcYardTwoActorPresentationV1 = property.actor_presentation
	var cutaway: StadiumNpcRetainedActorCutaway = property.actor_cutaway
	var copied_camera: StadiumNpcYardTwoCameraV1 = StadiumNpcYardTwoCameraV1.new()
	copied_camera.property_ref = weakref(property)
	copied_camera.actor_cutaway = foreign.actor_cutaway
	copied_camera._restore_owned()
	owner._assert(
		"CAM-05/copied_camera_cleanup",
		faded and not actor_same(rows) and not actor_same(foreign_rows),
		"Copied camera cannot restore either owner's fade"
	)
	var copied_presenter: StadiumNpcYardTwoActorPresentationV1 = (
		StadiumNpcYardTwoActorPresentationV1.new()
	)
	copied_presenter.property_ref = weakref(property)
	copied_presenter.actor_cutaway = foreign.actor_cutaway
	copied_presenter._restore_owned()
	owner._assert(
		"CAM-05/copied_presenter_cleanup",
		faded and not actor_same(rows) and not actor_same(foreign_rows),
		"Copied presenter cannot restore foreign presentation"
	)
	property.camera = copied_camera
	property.actor_presentation = copied_presenter
	property.actor_cutaway = foreign.actor_cutaway
	camera._restore_owned()
	owner._assert(
		"CAM-05/original_camera_cleanup",
		faded and actor_same(rows) and not actor_same(foreign_rows),
		"Original camera restores only its privately pinned helper"
	)
	property.camera = camera
	property.actor_presentation = presenter
	property.actor_cutaway = cutaway
	lab._cleanup_batted_ball()
	faded = fade_actual(lab, property) and not actor_same(rows)
	property.actor_presentation = copied_presenter
	property.actor_cutaway = foreign.actor_cutaway
	presenter._restore_owned()
	owner._assert(
		"CAM-05/original_presenter_cleanup",
		faded and actor_same(rows) and not actor_same(foreign_rows),
		"Original presenter cleans up despite replaced public links"
	)
	property.actor_presentation = presenter
	property.actor_cutaway = cutaway
	lab._cleanup_batted_ball()
	faded = fade_actual(lab, property) and not actor_same(rows)
	property.actor_cutaway = foreign.actor_cutaway
	property.restore_presentations()
	owner._assert(
		"CAM-05/property_private_cleanup",
		faded and actor_same(rows) and not actor_same(foreign_rows),
		"Property cleanup ignores a replaced public helper"
	)
	property.actor_cutaway = cutaway
	copied_presenter.free()
	lab.free()
	other.free()


static func next_f32(value: float) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, value)
	var bits: int = bytes.decode_u32(0)
	bytes.encode_u32(0, bits + (1 if value >= 0 else -1))
	return bytes.decode_float(0)
