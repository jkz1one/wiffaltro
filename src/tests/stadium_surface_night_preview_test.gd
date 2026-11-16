extends Node3D
## One SYNTHETIC paid composition, one paired optical point, private reversible presentation.
## No real pitch/contact, season/save/report activation, or general layout12 night qualification.

const SIZE: Vector2i = Vector2i(1280, 720)
const POINT: Vector3 = Vector3(0, 0.0365, 1)
const PNG_NAME: String = "owned-surface-night-plate-sand.png"
const JSON_NAME: String = "owned-surface-night-plate-sand.json"
const MAX_EVIDENCE_BYTES: int = 131072


class MissingShadowCallbackPreview:
	extends StadiumSurfaceNightPreview

	func _apply_scene() -> void:
		super._apply_scene()
		for connection: Dictionary in _shadow_owner.tree_exited.get_connections():
			_shadow_owner.tree_exited.disconnect(connection["callable"])


class WrongShadowArgumentsPreview:
	extends StadiumSurfaceNightPreview

	func _apply_scene() -> void:
		super._apply_scene()
		for connection: Dictionary in _shadow_owner.tree_exited.get_connections():
			_shadow_owner.tree_exited.disconnect(connection["callable"])
		var wrong: Dictionary = _shadow_before.duplicate(true)
		wrong.size += 1
		_shadow_owner.tree_exited.connect(
			StadiumYardNightPrototype._restore_shadows.bind(_viewport, wrong)
		)


class PaletteFailurePreview:
	extends StadiumSurfaceNightPreview

	func _apply_palette() -> bool:
		# Actual palette mutation followed by failure, not the former no-write override.
		super._apply_palette()
		return false


var _checks: int = 0
var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(
		DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"one-view qualification requires native rendering and an explicit capture directory"
	)
	if _failures == 0:
		await _exercise()
		# Coroutine-local adapters/world/environment references have now left scope.
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro surface-night preview checks passed (%d): " % _checks
				+ "one paid synthetic plate-sand view; exact restoration; runtime/public remain false."
			)
		)
	else:
		print(
			(
				"Wiffaltro surface-night preview checks failed (%d checks, %d failures)."
				% [_checks, _failures]
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture() -> ClubAssetLedger:
	var helper: Node = load("res://src/tests/stadium_surface_night_layout_candidate_test.gd").new()
	for index in range(20):
		helper._credits.append(1000)
		helper._progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(37, helper._credits, helper._progress)
	helper._buy(ledger, "ST-037", 4, StadiumPurchases.LIGHT_VERSION, helper.LIGHT_REQUEST)
	helper._land(ledger, "expanded")
	helper._surface(ledger, "grass")
	helper._surface(ledger, "ground_prep")
	helper._style(ledger, "ST-063b", 1)
	helper._style(ledger, "ST-063i", StadiumGroundStyles.PRICE_VERSION)
	var layout: Dictionary = ledger.view().stadium_active
	var sites: Array = StadiumYardLightModels.SITES.keys()
	sites.sort()
	for index in range(4):
		layout.lights.append(
			{"copy": "purchase:%s:%d" % [helper.LIGHT_REQUEST, index], "site": sites[index]}
		)
	layout.surface = StadiumSurfaceProgression.selection(ledger.surface_owned(), true)
	layout.styles.grass = "ST-063b"
	layout.ground = "ST-063i"
	helper._apply(ledger, layout)
	_checks += helper._checks
	_failures += helper._failures
	var valid_setup: bool = helper._failures == 0
	helper.free()
	return ledger if valid_setup else null


func _exercise() -> void:
	var ledger: ClubAssetLedger = _fixture()
	if ledger == null:
		return
	var candidate: Dictionary = StadiumSurfaceNightLayout.capture(ledger)
	_check(
		not candidate.is_empty() and StadiumSurfaceNightLayout.valid(candidate, ledger),
		"ordinary paid journal captures the accepted exact candidate"
	)
	if candidate.is_empty():
		return
	var entry: Dictionary = candidate.entry
	_check(
		(
			entry.version == 8
			and entry.layout.version == 12
			and entry.tier == "expanded"
			and (
				entry.layout.surface
				== {"foundation": "grass", "condition": "prepared", "height": "short"}
			)
			and entry.layout.styles.grass == "ST-063b"
			and entry.layout.ground == "ST-063i"
			and entry.layout.lights.size() == 4
			and ClubCareer.same(entry.layout.walls, StadiumWallLayout.empty())
		),
		"only the approved prepared-short-grass plate-sand four-pole composition"
	)
	_check(
		StadiumGrassFinish._inside(Vector2(POINT.x, POINT.z), StadiumGroundModels.masks("ST-063i")),
		"the single rolling-height critical point is inside the actual plate-sand mask"
	)
	var shared_shadows: Dictionary = StadiumSurfaceNightPreview._shadows(get_viewport())
	var viewport: SubViewport = SubViewport.new()
	viewport.name = "OwnedSurfaceNightPrivateViewport"
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	viewport.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	lab._status_label.visible = false
	lab._stadium_ledger = ledger
	lab._match_state.stadium = entry.duplicate(true)
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_check(installed, "unchanged ordinary entry8 builder installs the owned daylight property")
	if not installed:
		viewport.queue_free()
		return
	await _preview_installed_property(ledger, candidate, entry, shared_shadows, viewport, lab)


func _preview_installed_property(
	ledger: ClubAssetLedger, candidate: Dictionary, entry: Dictionary, shared_shadows: Dictionary,
	viewport: SubViewport, lab: PitchBatLab
) -> void:
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var surface: MeshInstance3D = property.get_node(
		"OwnedSurfaceFinish/GroundTreatment/SurfaceVisual"
	)
	var original_material: ShaderMaterial = surface.material_override
	original_material.set_meta("preview_restore_probe", "retained-original-metadata")
	original_material.set_meta(
		"surface_day_pigment", original_material.get_shader_parameter("vertex_pigment_scale")
	)
	var original_metadata: Dictionary = _metadata(original_material)
	var original_environment: Environment = lab._world_environment.environment
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	_pose(lab, ball)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(
		(
			viewport.find_world_3d() != get_viewport().find_world_3d()
			and lab._camera.get_viewport() == viewport
			and viewport.get_child_count() == 1
		),
		"the lab, camera, lights and captures own one private viewport/world"
	)
	_check(
		(
			ball.radius_m == 0.0365
			and ball.global_position == POINT
			and ball.freeze
			and not is_instance_valid(lab._batted_ball)
		),
		"real unlaunched diagnostic ball retains ordinary size"
	)
	var screen: Vector2 = lab._camera.unproject_position(ball.global_position)
	_check(
		(
			not lab._camera.is_position_behind(ball.global_position)
			and Rect2(24, 24, 1232, 672).has_point(screen)
		),
		"one right-handed batting-origin tracking point is in frame"
	)
	var baseline: Dictionary = _presentation(lab, property)
	var geometry: Dictionary = _geometry(property, ball).duplicate(true)
	var gameplay: Dictionary = _state(lab._match_state, {})
	var ledger_data: String = _ledger_bytes(ledger)
	var entry_data: String = _bytes(lab._match_state.stadium)
	var candidate_data: String = _bytes(candidate)
	var camera_data: Dictionary = _camera(lab._camera).duplicate(true)
	var invalid: Dictionary = candidate.duplicate(true)
	invalid.contract = "invalid-contract"
	_check(
		(
			not StadiumSurfaceNightPreview.new().bind(lab, invalid, ledger)
			and _presentation(lab, property) == baseline
		),
		"invalid candidate refuses before presentation writes"
	)
	var stale: Dictionary = candidate.duplicate(true)
	stale.entry.revision += 1
	_check(
		(
			not StadiumSurfaceNightPreview.new().bind(lab, stale, ledger)
			and _presentation(lab, property) == baseline
		),
		"stale paid-prefix declaration refuses before writes"
	)
	var day: Dictionary = await _contrast(lab._camera, ball)
	if day.is_empty():
		viewport.queue_free()
		return
	var preview: StadiumSurfaceNightPreview = StadiumSurfaceNightPreview.new()
	var bound: bool = preview.bind(lab, candidate, ledger)
	_check(
		bound and preview.installed(lab),
		"candidate-only reversible night presentation binds exact caller"
	)
	if not bound:
		viewport.queue_free()
		return
	_check(
		(
			surface.material_override != original_material
			and lab._world_environment.environment != original_environment
			and _metadata(original_material) == original_metadata
		),
		"night uses private duplicate resources and leaves original material metadata intact"
	)
	_check(
		is_equal_approx(
			surface.material_override.get_shader_parameter("vertex_pigment_scale"),
			float(original_material.get_shader_parameter("vertex_pigment_scale")) * 0.6
		),
		"existing plate-sand factor is unchanged"
	)
	var night_state: Dictionary = _presentation(lab, property)
	_check(
		preview.bind(lab, candidate, ledger) and _presentation(lab, property) == night_state,
		"repeat apply is idempotent without replacing resources or compounding pigment"
	)
	_check(
		(
			_geometry(property, ball) == geometry
			and _state(lab._match_state, {}) == gameplay
			and _ledger_bytes(ledger) == ledger_data
			and _bytes(candidate) == candidate_data
			and _bytes(lab._match_state.stadium) == entry_data
		),
		"applied presentation changes no physical or paid gameplay authority"
	)
	var night: Dictionary = await _contrast(lab._camera, ball)
	if night.is_empty():
		preview.restore(lab)
		viewport.queue_free()
		return
	var cutoff: float = maxf(0.03, float(day.difference) * 0.65)
	_check(
		float(night.difference) >= cutoff,
		"one plate-sand night contrast meets unchanged max(0.03, day*0.65)"
	)
	_check(
		_camera(lab._camera) == camera_data and ball.global_position == POINT,
		"all four contrast operands use the exact same camera and ball pose"
	)
	_check(
		(
			preview.restore(lab)
			and not preview.installed(lab)
			and _presentation(lab, property) == baseline
		),
		"normal restoration returns every captured pointer, value and metadata exactly"
	)
	_check(
		preview.restore(lab) and _presentation(lab, property) == baseline,
		"repeated restoration is exact and safe"
	)
	_check(
		(
			_geometry(property, ball) == geometry
			and _state(lab._match_state, {}) == gameplay
			and _ledger_bytes(ledger) == ledger_data
			and _bytes(lab._match_state.stadium) == entry_data
			and _bytes(candidate) == candidate_data
		),
		"restoration preserves collider resources/transforms, gameplay, journal and old daylight snapshot"
	)
	for partial: StadiumSurfaceNightPreview in [
		MissingShadowCallbackPreview.new(),
		WrongShadowArgumentsPreview.new(),
		PaletteFailurePreview.new()
	]:
		_check(
			(
				not partial.bind(lab, candidate, ledger)
				and not partial.installed(lab)
				and _presentation(lab, property) == baseline
			),
			"actual partial branch restores environment, material, sun, lamps and atlas"
		)
		_check(
			partial.restore(lab) and _presentation(lab, property) == baseline,
			"each actual partial-application rollback is repeat-safe"
		)
		_check(
			(
				_geometry(property, ball) == geometry
				and _state(lab._match_state, {}) == gameplay
				and _ledger_bytes(ledger) == ledger_data
			),
			"each partial failure preserves exact physics, gameplay and paid journal"
		)
	var evidence: Dictionary = {
		"schema": "owned-surface-night-preview-one-view-v1",
		"synthetic_paid_fixture": true,
		"candidate": candidate,
		"candidate_sha256": candidate_data.sha256_text(),
		"entry_key": StadiumLayoutSnapshot.key(entry),
		"view": "right-handed-batting-origin-tracking",
		"composition": "expanded-prepared-short-grass-ST-063b-ST-063i-four-ST-037-empty-walls",
		"viewport_id": viewport.get_instance_id(),
		"world_id": viewport.find_world_3d().get_instance_id(),
		"camera": _camera(lab._camera),
		"ball_id": ball.get_instance_id(),
		"ball_radius_m": ball.radius_m,
		"ball_point": [ball.global_position.x, ball.global_position.y, ball.global_position.z],
		"dimensions": [SIZE.x, SIZE.y],
		"day": day.operands,
		"night": night.operands,
		"day_contrast": day.difference,
		"night_contrast": night.difference,
		"threshold": cutoff,
		"png": PNG_NAME,
		"geometry_before_sha256": _bytes(geometry).sha256_text(),
		"geometry_after_sha256": _bytes(_geometry(property, ball)).sha256_text(),
		"gameplay_before_sha256": _bytes(gameplay).sha256_text(),
		"gameplay_after_sha256": _bytes(_state(lab._match_state, {})).sha256_text(),
		"ledger_before_sha256": ledger_data.sha256_text(),
		"ledger_after_sha256": _ledger_bytes(ledger).sha256_text(),
		"day_snapshot_before_sha256": entry_data.sha256_text(),
		"day_snapshot_after_sha256": _bytes(lab._match_state.stadium).sha256_text(),
		"presentation_restored_exact": _presentation(lab, property) == baseline,
		"geometry_restored_exact": _geometry(property, ball) == geometry,
		"gameplay_restored_exact": _state(lab._match_state, {}) == gameplay,
		"runtime_ready": StadiumSurfaceNightLayout.RUNTIME_READY,
		"public_ready": StadiumSurfaceNightLayout.PUBLIC_READY
	}
	# Same composition; these are ownership guards, not additional optical views/captures.
	var replacement_guard: StadiumSurfaceNightPreview = StadiumSurfaceNightPreview.new()
	var replacement_bound: bool = replacement_guard.bind(lab, candidate, ledger)
	_check(replacement_bound, "fresh ownership-guard presentation binds after exact rollback")
	if not replacement_bound:
		viewport.queue_free()
		return
	var replacement: Environment = lab._world_environment.environment.duplicate(true)
	lab._world_environment.environment = replacement
	var replacement_state: Dictionary = _presentation(lab, property)
	var own_shadow: Node = lab.get_node_or_null(StadiumSurfaceNightPreview.SHADOW_OWNER)
	_check(
		(
			own_shadow != null
			and own_shadow.tree_exited.get_connections().is_empty()
			and own_shadow.tree_exiting.get_connections().size() == 1
			and own_shadow.tree_exiting.is_connected(replacement_guard._shadow_callback)
		),
		"only the ownership-gated callback is armed before the stale-owner exit"
	)
	if own_shadow != null:
		own_shadow.free()
	_check(
		(
			not replacement_guard.installed(lab)
			and not replacement_guard.restore(lab)
			and _presentation(lab, property) == replacement_state
		),
		"deferred owner exit leaves replacement environment and atlas untouched before restore refusal"
	)
	_check(
		not replacement_guard.restore(lab) and lab._world_environment.environment == replacement,
		"abandoned restoration remains refused"
	)
	# Remove this abandoned private preview as a unit; no restoration into replacement owners.
	await RenderingServer.frame_post_draw
	viewport.queue_free()
	await get_tree().process_frame
	_check(
		StadiumSurfaceNightPreview._shadows(get_viewport()) == shared_shadows,
		"private preview disposal never changes the shared viewport shadow atlas"
	)
	_check(
		(
			not StadiumSurfaceNightLayout.RUNTIME_READY
			and not StadiumSurfaceNightLayout.PUBLIC_READY
			and StadiumLayoutSnapshot.valid(entry)
			and StadiumSurfaceNightLayout.valid(candidate, ledger)
		),
		"candidate flags stay false and the original ordinary daylight entry remains valid"
	)
	evidence["shared_viewport_unchanged"] = (
		StadiumSurfaceNightPreview._shadows(get_viewport()) == shared_shadows
	)
	_write_evidence(evidence, night.image)


func _pose(lab: PitchBatLab, ball: BattedBallBody) -> void:
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.RIGHT
	PitchBatLabPresentation.sync_players(lab)
	var director: MatchCameraDirector = lab._camera_director
	director.set_batter_handedness(false)
	director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	director.clear_presentation_motion()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	director.snap(lab._camera)
	director.prepare_ball_in_play(false, Vector3(0, 1, 0), POINT - Vector3(0, 1, 0))
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	for frame in range(240):
		ball.position = Vector3(0, 1, 0).lerp(POINT, minf(1, frame / 150.0))
		director.update(lab._camera, 1.0 / 60, true, ball.position)
	# lerp at weight1 can round away from the endpoint. Copy the exact diagnostic
	# point and resync the ordinary director; keep the exact native assertions.
	ball.global_position = POINT
	director.update(lab._camera, 1.0 / 60, true, ball.global_position)


func _contrast(camera: Camera3D, ball: Node3D) -> Dictionary:
	var viewport: Viewport = camera.get_viewport()
	ball.visible = true
	await RenderingServer.frame_post_draw
	var present: Image = viewport.get_texture().get_image()
	ball.visible = false
	await RenderingServer.frame_post_draw
	var absent: Image = viewport.get_texture().get_image()
	ball.visible = true
	_check(
		(
			not present.is_empty()
			and not absent.is_empty()
			and present.get_size() == SIZE
			and absent.get_size() == SIZE
		),
		"paired operands are exact 1280x720 private-viewport frames"
	)
	if (
		present.is_empty()
		or absent.is_empty()
		or present.get_size() != SIZE
		or absent.get_size() != SIZE
	):
		return {}
	var logical: Vector2 = camera.unproject_position(ball.global_position)
	var screen: Vector2i = Vector2i(
		logical * Vector2(present.get_size()) / viewport.get_visible_rect().size
	)
	var visible_rgb: Array = []
	var hidden_rgb: Array = []
	var difference: float = 0
	for x in range(maxi(0, screen.x - 5), mini(present.get_width(), screen.x + 6)):
		for y in range(maxi(0, screen.y - 5), mini(present.get_height(), screen.y + 6)):
			var a: Color = present.get_pixel(x, y)
			var b: Color = absent.get_pixel(x, y)
			visible_rgb.append([a.r, a.g, a.b])
			hidden_rgb.append([b.r, b.g, b.b])
			difference = maxf(difference, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	_check(
		visible_rgb.size() == 121 and hidden_rgb.size() == 121,
		"each bounded critical-point operand contains the unchanged 11x11 sample"
	)
	return {
		"difference": difference,
		"image": present,
		"operands":
		{
			"screen": [screen.x, screen.y],
			"origin": [screen.x - 5, screen.y - 5],
			"size": [11, 11],
			"order": "x-major-y-minor",
			"visible_rgb": visible_rgb,
			"hidden_rgb": hidden_rgb
		}
	}


func _presentation(lab: PitchBatLab, property: StadiumPropertyGeometry) -> Dictionary:
	var mesh: MeshInstance3D = property.get_node("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
	var material: ShaderMaterial = mesh.material_override
	var sun: DirectionalLight3D = lab.get_node("StarterFieldGeometry/Sun")
	var result: Dictionary = {
		"environment_owner": lab._world_environment.get_instance_id(),
		"environment": lab._world_environment.environment.get_instance_id(),
		"environment_values":
		StadiumSurfaceNightPreview._environment_values(lab._world_environment.environment),
		"environment_meta": _metadata(lab._world_environment.environment),
		"sun": sun.get_instance_id(),
		"sun_color": sun.light_color,
		"sun_energy": sun.light_energy,
		"surface": mesh.get_instance_id(),
		"material": material.get_instance_id(),
		"material_meta": _metadata(material),
		"pigment": material.get_shader_parameter("vertex_pigment_scale"),
		"atlas": StadiumSurfaceNightPreview._shadows(lab.get_viewport()),
		"has_preview_owner": lab.has_meta(StadiumSurfaceNightPreview.OWNER_META),
		"lamps": {}
	}
	for copy: String in property.objects:
		var model: Node3D = property.objects[copy]
		if model.get_meta("stadium_item", "") != "ST-037":
			continue
		var beam: SpotLight3D = model.get_node("FieldLight")
		var lens: MeshInstance3D = model.get_node("Visual/LampLens")
		result.lamps[copy] = {
			"model": model.get_instance_id(),
			"beam": beam.get_instance_id(),
			"lens": lens.get_instance_id(),
			"visible": beam.visible,
			"material": lens.material_override.get_instance_id(),
			"metadata": _metadata(lens.material_override),
			"emission": lens.material_override.emission_enabled,
			"energy": lens.material_override.emission_energy_multiplier
		}
	return result


func _geometry(property: StadiumPropertyGeometry, ball: BattedBallBody) -> Dictionary:
	var result: Dictionary = {
		"field": property.field.get_instance_id(),
		"ball_radius": ball.radius_m,
		"ball_mass": ball.mass,
		"ball_freeze": ball.freeze,
		"colliders": {}
	}
	_collect_geometry(property, result.colliders)
	_collect_geometry(ball, result.colliders)
	return result


func _collect_geometry(node: Node, result: Dictionary) -> void:
	if node is CollisionObject3D or node is CollisionShape3D:
		var row: Dictionary = {
			"id": node.get_instance_id(),
			"path": str(node.get_path()),
			"transform": node.transform,
			"global_transform": node.global_transform
		}
		if node is CollisionObject3D:
			row["layer"] = node.collision_layer
			row["mask"] = node.collision_mask
		if node is CollisionShape3D:
			row["disabled"] = node.disabled
			row["shape"] = node.shape.get_instance_id()
			row["shape_data"] = {}
			for field: Dictionary in node.shape.get_property_list():
				if int(field.usage) & PROPERTY_USAGE_STORAGE and field.name != "script":
					row.shape_data[field.name] = node.shape.get(field.name)
		result[str(node.get_instance_id())] = row.duplicate(true)
	for child: Node in node.get_children():
		_collect_geometry(child, result)


func _state(value: Variant, visited: Dictionary) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[str(key)] = _state(value[key], visited)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_state(item, visited))
		return result
	if value is Object:
		if not is_instance_valid(value):
			return "freed"
		var id: int = value.get_instance_id()
		if visited.has(id):
			return {"reference": id}
		visited[id] = true
		var result: Dictionary = {"id": id, "class": value.get_class(), "fields": {}}
		for field: Dictionary in value.get_property_list():
			if (
				int(field.usage) & (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE)
				and field.name != "script"
			):
				result.fields[field.name] = _state(value.get(field.name), visited)
		return result
	return value


func _camera(camera: Camera3D) -> Dictionary:
	return {
		"id": camera.get_instance_id(),
		"viewport_id": camera.get_viewport().get_instance_id(),
		"global_transform_columns_origin": _transform_components(camera.global_transform),
		"fov": camera.fov,
		"near": camera.near,
		"far": camera.far,
		"projection": camera.projection,
		"keep_aspect": camera.keep_aspect
	}


func _transform_components(value: Transform3D) -> Array:
	return [
		value.basis.x.x,
		value.basis.x.y,
		value.basis.x.z,
		value.basis.y.x,
		value.basis.y.y,
		value.basis.y.z,
		value.basis.z.x,
		value.basis.z.y,
		value.basis.z.z,
		value.origin.x,
		value.origin.y,
		value.origin.z
	]


func _metadata(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in object.get_meta_list():
		result[str(key)] = object.get_meta(key)
	return result


func _ledger_bytes(ledger: ClubAssetLedger) -> String:
	return _bytes(
		{
			"journal": ledger.to_data(),
			"view": ledger.view(),
			"inventory": ledger.construction().to_data(),
			"generation": ledger.mutation_generation()
		}
	)


func _write_evidence(evidence: Dictionary, night_image: Image) -> void:
	_check(
		DirAccess.make_dir_recursive_absolute(_capture_dir) == OK,
		"bounded capture directory exists"
	)
	_check(
		night_image.save_png(_capture_dir.path_join(PNG_NAME)) == OK,
		"exactly one native night PNG is retained"
	)
	var payload: String = _bytes(evidence)
	_check(
		payload.to_utf8_buffer().size() <= MAX_EVIDENCE_BYTES,
		"four contrast operands and identity proofs fit bounded JSON"
	)
	if payload.to_utf8_buffer().size() > MAX_EVIDENCE_BYTES:
		return
	var file: FileAccess = FileAccess.open(_capture_dir.path_join(JSON_NAME), FileAccess.WRITE)
	_check(file != null, "bounded one-view evidence file opens")
	if file != null:
		file.store_string(payload)
		file.flush()
		_check(file.get_error() == OK, "bounded one-view evidence writes completely")
		file.close()


func _bytes(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
