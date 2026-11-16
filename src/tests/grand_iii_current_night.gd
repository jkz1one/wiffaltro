extends "res://src/tests/grand_iii_public_view_test.gd"
## One current-composition right-handed batting image, with no live launch or pair.
## Inherit actual installation, native capture, role guards and complete teardown.


func _ready() -> void:
	if "--grand-iii-time-views" in OS.get_cmdline_user_args():
		await _time_ready()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_first_case = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(
		(
			DisplayServer.get_name() != "headless"
			and not _capture_dir.is_empty()
			and not ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED
		),
		"current-night view requires actual display, capture directory and held public activation"
	)
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native startup handshake has no hidden failure")
	if _failures == 0:
		await _views()
	await TestAudioDrain.finish(get_tree())
	_check(
		_checks + 1 == 93 and _families == 1 and _captures == 1 and _pairs == 0 and _launches == 0,
		"exact93 guards, one installed family, one primary image and no pair or live launch"
	)
	print("GRAND_III_CURRENT_NIGHT_SCOPE first_case=%s" % _first_case)
	print(
		(
			(
				"GRAND_III_CURRENT_NIGHT_RESULT checks=%d failures=%d families=%d "
				+ "captures=%d pairs=%d launches=%d"
			)
			% [_checks, _failures, _families, _captures, _pairs, _launches]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _shot(label: String) -> void:
	if not label.ends_with("-batting"):
		return
	await super._shot(label)


func _live(
	_lab: PitchBatLab, _property: StadiumNpcPublicProperty, _left: bool, _size: Vector2i
) -> void:
	return


func _time_ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(
		DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"two time-profile views require actual display and capture directory"
	)
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native time-profile startup handshake has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "one ordinary native extent is acknowledged")
	var rows: Array[Dictionary] = []
	if _failures == 0:
		for mode: String in ["sunset", "night"]:
			rows.append(await _time_view(mode))
	await TestAudioDrain.finish(get_tree())
	var file: FileAccess = null
	if not _capture_dir.is_empty():
		file = FileAccess.open(
			_capture_dir.path_join("grand_iii_time_views.json"), FileAccess.WRITE
		)
	_check(file != null, "bounded time-profile view evidence opens")
	_check(
		_checks + 1 == 37 and _families == 2 and _captures == 2 and _pairs == 0 and _launches == 0,
		"exact37 guards, two profile views and zero launches"
	)
	if file != null:
		file.store_string(
			JSON.stringify(
				{
					"version": 1,
					"checks": _checks,
					"failures": _failures,
					"families": _families,
					"captures": _captures,
					"pairs": _pairs,
					"launches": _launches,
					"profiles": rows,
					"scope": "two_initial_profile_views_no_progress_or_game"
				},
				"\t",
				true,
				true
			)
		)
		file.close()
	print(
		(
			"GRAND_III_TIME_VIEWS_RESULT checks=%d failures=%d families=%d captures=%d pairs=%d launches=%d"
			% [_checks, _failures, _families, _captures, _pairs, _launches]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _time_view(mode: String) -> Dictionary:
	var prepared: SeasonState = FIXTURE.season_time(mode)
	_check(prepared != null, "time-profile season uses the existing drafted fixture " + mode)
	if prepared == null:
		return {}
	var saved: Dictionary = SeasonSave.snapshot(prepared)
	var season: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true))
	)
	_check(
		season != null and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"time-profile complete binding survives ordinary save decode " + mode
	)
	if season == null:
		return {}
	var fixture: Dictionary = FIXTURE.fixture(season)
	var before: Dictionary = SeasonSave.snapshot(season)
	var prior_msaa: int = get_viewport().msaa_3d
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = fixture.home == 0
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(
		(
			not lab.yard_bound_startup_failed
			and property != null
			and R.installed_bound(lab, lab._match_state.stadium)
		),
		"actual time-profile neutral startup " + mode
	)
	if property == null or lab.yard_bound_startup_failed:
		lab.queue_free()
		await get_tree().process_frame
		return {}
	var lease: Dictionary = property.environment_lease
	var environment_before: Dictionary = lease.duplicate(false)
	var lighting_before: Dictionary = lease.active_lighting.duplicate(false)
	var atlas_before: Dictionary = lighting_before.before.duplicate(true)
	var environment: Dictionary = lab._match_state.stadium.environment.duplicate(true)
	var original_top: bool = lab._match_state.top_half
	lab._match_state.top_half = lab._player_home
	var batter: PlayerMatchState = lab._match_state.batter()
	var definition: PlayerDefinition = batter.definition
	lab._match_state.top_half = original_top
	var expected_lamp: float = 0.0 if mode == "sunset" else 4.5
	var lights_exact: bool = lease.active_lighting.lights.size() == 4
	for row: Dictionary in lease.active_lighting.lights:
		lights_exact = lights_exact and row.node.light_energy == expected_lamp
	_check(
		(
			environment.version == 8
			and environment.render_profile == 3
			and environment.mode == mode
			and property.objects.size() == 107
			and lease.active_lighting.heads.size() == 32
			and lease.active_lighting.root.get_child_count() == 36
			and lights_exact
		),
		"new profile retains original107 copies and only four authorized lights " + mode
	)
	var geometry_exact: bool = true
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		geometry_exact = (
			geometry_exact
			and ClubCareer.same(
				StadiumGrandIIIPublicConstruction.components(
					property.objects[row.instance].transform
				),
				Array(PackedFloat32Array(row.transform))
			)
		)
	_check(
		(
			geometry_exact
			and StadiumGrandIIIEnvironmentV1.installed(lab, lease)
			and lease.applied_environment.sky == lease.applied_sky
			and lease.applied_sky.sky_material == lease.applied_material
		),
		"authored geometry and exact owned sky graph are installed " + mode
	)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab._at_bat_cadence.stop()
	lab._batter_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_role(lab, false, true)
	_check(
		_near_clear(lab._camera) and not lab._camera.is_position_behind(Vector3(0, 1, 0)),
		"ordinary pitching camera clears native geometry and faces the field " + mode
	)
	var upper_ray: float = (
		lab._camera.project_ray_normal(Vector2(get_viewport().get_visible_rect().size.x * 0.5, 0)).y
	)
	_check(
		upper_ray > 0.30,
		"ordinary pitching view reaches the shader's real above-horizon sky " + mode
	)
	var prior_paused: bool = get_tree().paused
	var prior_lab_mode: Node.ProcessMode = lab.process_mode
	# Preserve the property's required processing flags while pausing its inherited children.
	lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_tree().paused = true
	var label: String = "grand-iii-time-" + mode + "-pitching"
	# Native capture remains the inherited viewport readback, with no image processing.
	await super._shot(label)
	var extent: Vector2i = _native._expected_content_size(get_window().size)
	var filename: String = "%s-%dx%d.png" % [label, extent.x, extent.y]
	var retained: Image = Image.load_from_file(_capture_dir.path_join(filename))
	var stars: Dictionary = {}
	if mode == "night":
		stars = await _time_stars(lab, property, lease, retained)
	lab.process_mode = prior_lab_mode
	get_tree().paused = prior_paused
	batter.definition = definition
	lab._match_state.top_half = original_top
	var authority: bool = R.installed_bound(lab, lab._match_state.stadium)
	_check(
		(
			authority
			and lab.process_mode == prior_lab_mode
			and get_tree().paused == prior_paused
			and ClubCareer.same(before, SeasonSave.snapshot(season))
			and lab._throw_number == 0
			and lab._play_records.is_empty()
			and PhysicalMatchReport.capture(lab).is_empty()
		),
		"view restores match-local hand and retains full authority without a game " + mode
	)
	var result: Dictionary = {
		"mode": mode,
		"environment": environment,
		"image": filename,
		"view": "ordinary_right_pitching",
		"sky_upper_ray_y": upper_ray,
		"geometry_exact": geometry_exact,
		"lights_exact": lights_exact,
		"light_energy": expected_lamp,
		"full_authority": authority,
		"stars": stars
	}
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	lab._at_bat_cadence.stop()
	_check(R.teardown(lab), "rendered time owner releases through actual public teardown " + mode)
	_check(
		(
			lease.is_empty()
			and environment_before.world.environment == environment_before.before_environment
			and environment_before.sun.rotation == environment_before.before_rotation
			and environment_before.sun.light_color == environment_before.before_color
			and environment_before.sun.light_energy == environment_before.before_energy
			and environment_before.sun.shadow_enabled == environment_before.before_shadows
		),
		"rendered time teardown restores exact original environment and sun " + mode
	)
	var restored: bool = (
		get_viewport().positional_shadow_atlas_size == atlas_before.size
		and get_viewport().positional_shadow_atlas_16_bits == atlas_before.precision
		and lab.find_children("*", "SpotLight3D", true, false).is_empty()
	)
	for row: Dictionary in lighting_before.heads:
		restored = (
			restored
			and not is_instance_valid(row.glow)
			and row.lens_material.albedo_color == row.lens_albedo
		)
	for index in range(4):
		restored = (
			restored
			and (
				get_viewport().get_positional_shadow_atlas_quadrant_subdiv(index)
				== atlas_before.quadrants[index]
			)
		)
	_check(
		restored,
		"four lights and32 glows are removed; original lens and atlas values restored " + mode
	)
	await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	_check(get_viewport().msaa_3d == prior_msaa, "view restores the prior MSAA " + mode)
	_families += 1
	return result


func _time_stars(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, lease: Dictionary, retained: Image
) -> Dictionary:
	var state: Dictionary = StadiumGrandIIIEnvironmentV1._state(lab, lease)
	var material: ShaderMaterial = lease.applied_material
	var sky: Sky = lease.applied_sky
	var original: Variant = material.get_shader_parameter(&"star_strength")
	var camera: Transform3D = lab._camera.global_transform
	var fov: float = lab._camera.fov
	var prior: Dictionary = {
		"updating": state.updating,
		"write_plays": state.write_plays,
		"write_halves": state.write_halves,
		"target_lamps": state.target_lamps,
		"pending": state.pending.duplicate(true)
	}
	var guards: Array = []
	for guard: Dictionary in state.guards:
		guards.append(guard.values.duplicate(true))
	var admitted: bool = (
		not state.updating
		and state.pending.is_empty()
		and original > 0.0
		and get_tree().paused
		and R.installed_bound(lab, lab._match_state.stadium)
	)
	_check(
		admitted, "stars-off diagnostic starts from the exact retained Night view and owned lease"
	)
	if not admitted:
		return {}
	# Test-only, scoped use of the same guarded native setter. No owner guard is disabled.
	state.write_plays = lab._play_records.size()
	state.write_halves = StadiumGrandIIIEnvironmentV1._halves(lab._match_state)
	state.updating = true
	var off_written: bool = StadiumGrandIIIEnvironmentV1._write_value(
		lab, lease, material, &"shader_parameter/star_strength", 0.0
	)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var absent: Image = get_viewport().get_texture().get_image()
	var same_owner: bool = (
		is_instance_valid(lab)
		and is_instance_valid(material)
		and is_instance_valid(sky)
		and R._property(lab) == property
		and is_same(StadiumGrandIIIEnvironmentV1._state(lab, lease), state)
		and lease.applied_material == material
		and lease.applied_sky == sky
		and sky.sky_material == material
	)
	var restored: bool = false
	if same_owner:
		restored = StadiumGrandIIIEnvironmentV1._write_value(
			lab, lease, material, &"shader_parameter/star_strength", original
		)
	# Always release the captured local diagnostic context, even if its owner was replaced.
	for key: String in prior:
		state[key] = prior[key]
	await RenderingServer.frame_post_draw
	for index in range(state.guards.size()):
		restored = restored and state.guards[index].values == guards[index]
	var images_valid: bool = (
		retained != null
		and absent != null
		and not retained.is_empty()
		and not absent.is_empty()
		and retained.get_size() == absent.get_size()
		and same_owner
		and is_instance_valid(lab._camera)
		and lab._camera.global_transform == camera
	)
	var positive: int = 0
	var negative: int = 0
	var examined: int = 0
	var maximum: float = 0.0
	if images_valid:
		var pixel_to_view: Vector2 = (
			get_viewport().get_visible_rect().size / Vector2(retained.get_size())
		)
		for y in range(retained.get_height()):
			for x in range(retained.get_width()):
				if lab._camera.project_ray_normal(Vector2(x, y) * pixel_to_view).y <= 0.30:
					continue
				examined += 1
				var on: Color = retained.get_pixel(x, y)
				var off: Color = absent.get_pixel(x, y)
				var delta: Vector3 = Vector3(on.r - off.r, on.g - off.g, on.b - off.b)
				positive += int(delta.x > 0.0 or delta.y > 0.0 or delta.z > 0.0)
				negative += int(delta.x < 0.0 or delta.y < 0.0 or delta.z < 0.0)
				maximum = maxf(maximum, delta.length())
	var authority: bool = (
		same_owner
		and restored
		and material.get_shader_parameter(&"star_strength") == original
		and lab._camera.global_transform == camera
		and lab._camera.fov == fov
		and R.installed_bound(lab, lab._match_state.stadium)
	)
	_check(
		(
			off_written
			and images_valid
			and examined > 0
			and positive > 0
			and maximum > 0.0
			and authority
		),
		(
			"real above-horizon Night pixels show stars; exact native uniform/context and full "
			+ "authority restored"
		)
	)
	return {
		"scope": "unretained_stars_off_diagnostic",
		"stars_on_source": "retained_night_png",
		"off_png_retained": false,
		"original_strength": original,
		"diagnostic_strength": 0.0,
		"pixels_examined": examined,
		"positive_pixels": positive,
		"negative_pixels": negative,
		"maximum_rgb_difference": maximum,
		"images_valid": images_valid,
		"exact_restore": restored,
		"full_authority": authority
	}
