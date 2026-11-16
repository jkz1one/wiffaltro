extends "res://src/tests/stadium_grand_i_lab_test.gd"
## Exact Grand I helper inheritance; only explicit Grand III orchestration is overridden.
## Frozen predecessor assertions and thresholds remain unchanged.

const WaterfallContract = preload("res://src/tests/stadium_waterfall_contract.gd")


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(
		not StadiumGrandIIILab.install(lab), "complete candidate requires explicit isolated opt-in"
	)
	lab.set_meta("stadium_grand_i_lab_only", true)
	_check(not StadiumGrandIIILab.install(lab), "Grand I opt-in alone never authorizes Grand III")
	lab.remove_meta("stadium_grand_i_lab_only")
	lab.set_meta("stadium_grand_iii_lab_only", true)
	lab._camera_mode = 1
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var previous_shot: int = lab._camera_director.shot
	lab._managed_match = true
	_check(not StadiumGrandIIILab.install(lab), "candidate cannot enter a managed fixture")
	lab._managed_match = false
	_check(
		StadiumGrandIIILab.install(lab) and not StadiumGrandIIILab.install(lab),
		"one complete assembly"
	)
	if _failures > 0:
		get_tree().quit(1)
		return
	_check(
		lab._camera_director.shot == previous_shot,
		"install preserves the current paused inspection shot"
	)
	lab._camera_director.restore_after_pause()
	_check(
		lab._camera_director.shot == MatchCameraDirector.Shot.PITCHING and lab._camera_mode == 1,
		"closing paused inspection restores the pre-install role camera"
	)
	var property: StadiumClubPropertyGeometry = lab.get_meta("stadium_property")
	_check(
		(
			property is StadiumGrandIIIProperty
			and lab.has_meta("stadium_grand_iii_candidate")
			and not lab.has_meta("stadium_grand_i_candidate")
			and StadiumGrandIIIFixtureStudy.valid(lab.get_meta("stadium_grand_iii_candidate"))
		),
		"installed adapter and source-bound authoring flag have only Grand III identity"
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"candidate cannot produce a misleading ordinary-field production report"
	)
	_check(
		(
			property.get_meta("candidate_venue").items.size() == 107
			and not lab.has_meta("stadium_snapshot")
		),
		"complete NPC candidate grants no saved eligibility"
	)
	_check(
		(
			lab.get_node("StarterFieldGeometry").get_node_or_null("BackWall") == null
			and not property.has_node("TemplateBackWall")
		),
		"old infinite back collisions are absent"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not property.configure_candidate(lab), "complete adapter cannot duplicate its receivers")
	_visibility_contract(lab, property)
	_receiver_routes(property)
	lab._start_new_match()
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	lab._match_state.inning = 3
	lab._match_state.home_team.runs = 7
	property.display._process(0)
	_check(
		(
			property.display._match == lab._match_state
			and property.display.shown.inning == 3
			and property.display.shown.home == 7
		),
		"video board follows the replacement match after restart"
	)
	_routes(lab, property)
	lab._start_new_match()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	for left in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		for shot in range(MatchCameraDirector.Shot.size()):
			lab._camera_director.set_shot(shot as MatchCameraDirector.Shot)
			lab._camera_director.snap(lab._camera, Vector3(0, 1, 5))
			StadiumPropertyRuntime.refresh_receiver_visibility(lab)
			_check(
				_clear_camera(lab._camera), "all fixed views clear complete physical infrastructure"
			)
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _capture(
					(
						"grand-iii-field-%s-%s"
						% [
							"left" if left else "right",
							"batting" if shot == MatchCameraDirector.Shot.BATTING else "pitching"
						]
					)
				)
	for sample: Array in [
		[Vector3(0, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(1.5, 1.1, 0.2), Vector3(0, 0, -40), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 22.7), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN]
	]:
		await _flight(lab, property, sample)
	for left in [false, true]:
		var inward: Vector3 = Vector3(-1 if left else 1, 0, 0)
		var from: Vector3 = StadiumDugoutRecipe.rail_point(13, -0.5, left) + Vector3.UP * 0.6
		for foul in [false, true]:
			await _flight(
				lab,
				property,
				[
					from,
					inward * 8,
					foul,
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE
				]
			)
	_check(
		WaterfallContract.valid(property.objects[StadiumGrandIIIVenueStudy.PREFIX + "LANDMARK-A"]),
		"all gameplay camera cycles preserve the exact opaque waterfall contract"
	)
	lab.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro complete Grand III lab passed: "
				+ "explicit assembly, contained routes and real outcomes."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _visibility_contract(lab: PitchBatLab, property: StadiumClubPropertyGeometry) -> void:
	var visibility: StadiumGrandIIIFieldVisibility = (
		lab._camera_director.tracking_visibility as StadiumGrandIIIFieldVisibility
	)
	_check(
		visibility != null and visibility.ready,
		"complete candidate uses its explicit visibility adapter"
	)
	if visibility == null or not visibility.ready:
		return
	var groups: int = 0
	for model: Node3D in property.objects.values():
		var item: String = model.get_meta("stadium_item")
		if item in ["ST-026", "ST-073", "ST-065", "ST-022", "ST-023"]:
			continue
		groups += 1
		var root: Node = model if item == "ST-046" else model.get_node_or_null("Visual")
		_check(root != null, "every supported item has its own exact authored visual hierarchy")
		if root == null:
			return
		var expected: Array[int] = []
		var expected_members: Array[Dictionary] = []
		var expected_bounds: AABB
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			expected_bounds = box if expected.is_empty() else expected_bounds.merge(box)
			expected.append(mesh.get_instance_id())
			expected_members.append(
				{"inverse": mesh.global_transform.affine_inverse(), "bounds": mesh.get_aabb()}
			)
		var key: String = model.get_meta("candidate_instance")
		_check(
			visibility.model_meshes.has(key) and visibility.model_meshes[key] == expected,
			"opaque camera enrollment contains every actual mesh of " + item
		)
		var matches: int = 0
		for group: Dictionary in visibility._groups:
			if group.identity == key:
				matches += 1
				_check(
					(
						group.item == item
						and group.members == expected_members
						and group.bounds == expected_bounds
					),
					"actual group preserves each real mesh inverse and bounds without collision-tree substitutes"
				)
		_check(matches == 1, "each supported model contributes one distinct opaque group")
		if item == "ST-046":
			_check(
				not model.has_node("Visual") and expected.size() == 21,
				"unchanged waterfall retains all21 direct opaque mesh parts"
			)
		if item == "ST-076":
			_check(
				expected.size() == 90,
				"premium tower enrollment includes16 nested housing/lens meshes and74 direct parts"
			)
	_check(
		groups == 50 and visibility._groups.size() == 50,
		"all50 nonreceiver/nonwall opaque item groups are enrolled"
	)
	var expected_uprights: Array[AABB] = []
	for model: Node3D in property.objects.values():
		if model.get_meta("stadium_item") == "ST-021":
			for mesh: MeshInstance3D in model.get_node("Visual").find_children(
				"*", "MeshInstance3D", true, false
			):
				expected_uprights.append(mesh.global_transform * mesh.get_aabb())
	_check(
		expected_uprights.size() == 4 and visibility._uprights == expected_uprights,
		"exact four genuine foul-pole bounds preserve upright policy without adding premium masts"
	)
	var expected_rails: Array[Dictionary] = []
	for row: Dictionary in property.boundary.graph.segments():
		if row.role.begins_with("DUGOUT"):
			expected_rails.append({"a": row.a, "normal": property.boundary.graph.inward(row)})
	_check(
		(
			visibility._rails == expected_rails
			and expected_rails.size() == 6
			and visibility._obstacles.is_empty()
		),
		"all six actual dugout face/opening rails and original obstacle policy remain unchanged"
	)
	var from: Vector3 = Vector3(36.35, 1.8, 39.65)
	var to: Vector3 = Vector3(36.35, 1.8, 49.65)
	_check(
		visibility.actual_blocked(from, to) and visibility._blocked(from, to),
		"actual opaque waterfall blocks camera segments despite having no gameplay collider"
	)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	_check(
		lab.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
		"waterfall visibility proof is not supplied by an invented collider"
	)
	_check(
		not visibility.actual_blocked(Vector3(42, 1.8, 40), Vector3(42, 1.8, 48)),
		"neighboring actual empty space is not filled by a blanket waterfall reservation"
	)
	var board: Node3D = property.objects[StadiumGrandIIIVenueStudy.PREFIX + "BOARD-LARGE-v2"]
	var visual: Node = board.get_node("Visual")
	visual.name = "MissingVisualControl"
	var rejected: StadiumGrandIIIFieldVisibility = StadiumGrandIIIFieldVisibility.new()
	_check(
		(
			not rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and rejected.last_error.contains("missing required Visual branch for ST-040")
			and not rejected.ready
			and rejected._groups.is_empty()
			and rejected.actual_blocked(from, to)
		),
		"missing required board hierarchy fails closed with exact diagnostic and no partial groups"
	)
	visual.name = "Visual"
	_check(
		(
			rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and rejected.model_meshes == visibility.model_meshes
			and lab._camera_director.tracking_visibility == visibility
		),
		"exact hierarchy restoration recovers enrollment without replacing active camera adapters"
	)

	var waterfall: Node3D = property.objects[StadiumGrandIIIVenueStudy.PREFIX + "LANDMARK-A"]
	var rock: MeshInstance3D = waterfall.get_node("RockMiddle")
	rock.visible = false
	_check(
		(
			not rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and rejected.last_error.contains("invalid direct-mesh ST046 hierarchy")
			and rejected._groups.is_empty()
		),
		"hidden required waterfall part rejects instead of silently disappearing from opaque visibility"
	)
	rock.visible = true
	_check(
		(
			rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and StadiumWaterfallModels.valid(waterfall)
		),
		"exact visible waterfall restores without any factory or material changes"
	)

	var roof: Node3D = property.objects[StadiumGrandIIIVenueStudy.PREFIX + "BASE-L1:ROOF"]
	var roof_visual: Node = roof.get_node("Visual")
	var fascia: MeshInstance3D = roof_visual.get_child(0)
	var index: int = fascia.get_index()
	roof_visual.remove_child(fascia)
	_check(
		(
			not rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and rejected.last_error.contains("incomplete required visual group for ST-053")
		),
		"missing individual roof member rejects instead of partially enrolling the purchase"
	)
	roof_visual.add_child(fascia)
	roof_visual.move_child(fascia, index)
	var original_pose: Transform3D = fascia.transform
	fascia.scale = Vector3.ZERO
	_check(
		not rejected.configure_candidate(property as StadiumGrandIIIProperty),
		"singular visible mesh rejects before unsafe affine inverse"
	)
	fascia.transform = original_pose
	_check(
		(
			rejected.configure_candidate(property as StadiumGrandIIIProperty)
			and rejected.model_meshes == visibility.model_meshes
			and WaterfallContract.valid(waterfall)
		),
		"every exact visual identity restores after bounded malformed controls"
	)
