extends "res://src/tests/stadium_target_camera_test.gd"
## Four authored poles, full field coverage samples and real native day/night camera views.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for left: bool in [false, true]:
		await _yard(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro yard light checks passed: authored bounds, sampled coverage and native views.")
	get_tree().quit(0 if _failures == 0 else 1)


func _yard(left: bool) -> void:
	var original_shadows: Dictionary = _shadow_state()
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	# Review fixture suppresses the pre-at-bat prompt, not any live-game visibility rule.
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(StadiumPropertyRuntime.install_lab(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "reference property installed")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	_check(StadiumBoundaryRuntime.assemble(property) != null, "complete boundary unchanged")
	var lamps: Array[Node3D] = []
	var helper: Node = load("res://src/tests/stadium_seating_test.gd").new()
	for site: String in StadiumYardLightModels.SITES:
		var model: Node3D = StadiumYardLightModels.create()
		property.add_child(model)
		_check(StadiumYardLightModels.place(model, site), "fixed yard-light site accepted")
		var bounds: AABB = helper._bounds(model, model)
		_check(StadiumYardLightModels.ENVELOPE.grow(0.0001).encloses(bounds),
			"complete visible pole, arm and head fit reserved envelope")
		_check(StadiumProperty.contains("backyard", model.transform * bounds),
			"rotated full model remains inside Backyard land")
		print("YARD_LIGHT_BOUNDS ", site, " ", bounds)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL",
				"light does not become a live field obstacle or scoring object")
		lamps.append(model)
	helper.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var samples: int = 0
	var unlit: int = 0
	for x in range(-23, 24, 2):
		for z in range(-5, 24, 2):
			if not Geometry2D.is_point_in_polygon(Vector2(x, z),
				PackedVector2Array(StadiumBoundaryGraph.VERTICES)):
				continue
			for height: float in [0.2, 1.05, 3.0, 6.0, 10.0]:
				var count: int = StadiumYardNightPrototype.coverage(Vector3(x, height, z), lamps)
				unlit += 1 if count == 0 else 0
				samples += 1
	print("YARD_LIGHT_COVERAGE samples=", samples, " unlit=", unlit)
	_check(samples > 1000 and unlit == 0, "sampled field and elevated ball volume have an open beam")
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
		else PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	var director: MatchCameraDirector = lab._camera_director
	director.set_batter_handedness(left)
	var boundary_state: Array = _boundary_state(property)
	var before: Array = []
	for lamp: Node3D in lamps:
		before.append(_colliders(lamp))
	for dark: bool in [false, true]:
		if dark:
			StadiumYardNightPrototype.apply(lab)
		for lamp: Node3D in lamps:
			StadiumYardLightModels.night(lamp, dark)
		for shot in range(MatchCameraDirector.Shot.size()):
			director.set_shot(shot as MatchCameraDirector.Shot)
			director.snap(lab._camera, Vector3(0, 1.05, 0))
			for lamp: Node3D in lamps:
				var box: AABB = lamp.global_transform * StadiumYardLightModels.ENVELOPE
				_check(not box.grow(lab._camera.near).has_point(lab._camera.global_position),
					"each actual camera remains outside the complete pole envelope")
			if shot in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
				await _shot("yard-%s-%s-%s" % ["left" if left else "right",
					"night" if dark else "day", "batting" if shot == 0 else "pitching"])
	var after_boundary: Array = _boundary_state(property)
	for index in range(boundary_state.size()):
		print("NIGHT_WALL_COMPARE ", index, " old=", boundary_state[index].bounds,
			" new=", after_boundary[index].bounds, " area_delta=",
			after_boundary[index].area - boundary_state[index].area)
		_check(boundary_state[index].shape == after_boundary[index].shape
			and boundary_state[index].transform == after_boundary[index].transform
			and boundary_state[index].material == after_boundary[index].material,
			"night leaves collider, transform and material unchanged")
		_check(boundary_state[index].bounds.is_equal_approx(after_boundary[index].bounds)
			and absf(boundary_state[index].area - after_boundary[index].area) < 0.001,
			"night preserves wall bounds and surface area")
	var after: Array = []
	for lamp: Node3D in lamps:
		after.append(_colliders(lamp))
	_check(ClubCareer.same(before, after), "night changes lighting only, not physical geometry")
	if not left:
		lab._camera.position = Vector3(-30, 7.8, 5)
		lab._camera.look_at(Vector3(-25, 4.2, 0))
		await _shot("yard-light-night-detail")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	_check(ClubCareer.same(original_shadows, _shadow_state()),
		"leaving the night scene restores the prior viewport shadow settings")


func _boundary_state(property: StadiumPropertyGeometry) -> Array:
	var result: Array = []
	for body: StaticBody3D in property.get_node("BoundaryGraph").get_children():
		var mesh: MeshInstance3D = body.get_node("TemplateWallVisual")
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
		var size: int = indices.size() if not indices.is_empty() else vertices.size()
		var area: float = 0
		for offset in range(0, size, 3):
			var a: Vector3 = vertices[indices[offset] if not indices.is_empty() else offset]
			var b: Vector3 = vertices[indices[offset + 1] if not indices.is_empty() else offset + 1]
			var c: Vector3 = vertices[indices[offset + 2] if not indices.is_empty() else offset + 2]
			area += (b - a).cross(c - a).length() * 0.5
		result.append({"shape": body.get_child(0).shape.get_rid(), "transform": body.transform,
			"material": mesh.material_override.get_rid(), "bounds": mesh.get_aabb(), "area": area})
	return result


func _shadow_state() -> Dictionary:
	var viewport: Viewport = get_viewport()
	var result: Dictionary = {"precision": viewport.positional_shadow_atlas_16_bits,
		"size": viewport.positional_shadow_atlas_size, "quadrants": []}
	for index in range(4):
		result.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	return result
