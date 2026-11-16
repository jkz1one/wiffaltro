extends Node3D
## Bounded DG1 candidate study. Headless coverage is never reported as render qualification.
## Native capture invocation: -- --ui-capture-dir=/absolute/output/path

const RIG = preload("res://src/presentation/stadium/stadium_string_light_night_prototype.gd")
const MODEL = preload("res://src/presentation/stadium/stadium_string_light_models.gd")
var _checks: int = 0
var _failures: int = 0
var _capture_dir: String = ""
var _report: Dictionary = {
	"night_qualified": false,
	"admission_changed": false,
	"coverage": [],
	"renders": [],
	"contrast_threshold": null,
	"render_status": "NOT_RUN_HEADLESS",
	"weather": "reference_clear_only",
	"qualification": "CANDIDATE_UNMEASURED"
}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	if DisplayServer.get_name() != "headless":
		_report.render_status = "NATIVE_DIAGNOSTICS_ONLY_NOT_QUALIFIED"
	for profile: String in StadiumStringLightItems.PRESETS:
		for left: bool in [false, true]:
			await _case(profile, left)
	await TestAudioDrain.finish(get_tree())
	_report["engine"] = Engine.get_version_info().string
	_report["display"] = DisplayServer.get_name()
	var output: FileAccess
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		output = FileAccess.open(
			_capture_dir.path_join("string-light-night-diagnostics.json"), FileAccess.WRITE
		)
		_check(output != null, "diagnostic report writable")
	_report["checks"] = _checks
	_report["failures"] = _failures
	if output != null:
		output.store_string(JSON.stringify(_report, "\t", true, true) + "\n")
	print("STRING_LIGHT_NIGHT_RESULT " + JSON.stringify(_report, "", true, true))
	get_tree().quit(0 if _failures == 0 else 1)


func _case(profile: String, left: bool) -> void:
	var before_shadows: Dictionary = _shadow_state()
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(
		StadiumPropertyRuntime.install_lab(
			lab, StadiumStarterLayout.empty(), StadiumStock.new_club()
		),
		"unchanged reference field fixture installs"
	)
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	_check(
		StadiumBoundaryRuntime.assemble(property) != null, "actual full boundary supplies occluders"
	)
	var spans: Array[Node3D] = []
	var poles: Array[Node3D] = []
	for site: String in StadiumStringLightItems.PRESETS[profile]:
		var span: Node3D = MODEL.create("ST-036", {"copy": "study:ST036:" + site, "site": site})
		property.add_child(span)
		spans.append(span)
	if profile.begins_with("MIXED"):
		for site: String in ["YLIGHT-RL", "YLIGHT-RR"]:
			var pole: Node3D = StadiumYardLightModels.create()
			StadiumYardLightModels.place(pole, site)
			pole.set_meta("owned_copy", "study:ST037:" + site)
			pole.set_meta("paid_copy", "study:ST037:" + site)
			property.add_child(pole)
			poles.append(pole)
	# Synthetic study copy bindings do not enter the inventory, save, or match schedule.
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	lab._camera_director.set_batter_handedness(left)
	var sun: DirectionalLight3D = lab.get_node("StarterFieldGeometry/Sun")
	var environment: Environment = lab._world_environment.environment
	var environment_state: Dictionary = _environment_state(environment)
	var sun_state: Array = [sun.light_color, sun.light_energy]
	var material: Material = spans[0].get_node("Visual/Bulb00").material_override
	var geometry: Array = _physical_state(property)
	_rejections(property, lab._world_environment, sun, spans, poles)
	var rig: StadiumStringLightNightPrototype = RIG.install(
		property, lab._world_environment, sun, spans, poles
	)
	_check(rig != null, "only exact complete installed DG1 preset creates study")
	if rig == null:
		lab.free()
		return
	_check(
		rig.profile == profile and rig.sources.size() == spans.size() + poles.size(),
		"bounded broad sources match physical span and pole count"
	)
	_check(
		RIG.install(property, lab._world_environment, sun, spans, poles) == null,
		"second rig cannot overwrite restoration lease"
	)
	_competing_lease(lab, lab._world_environment, sun)
	_check(
		not rig.get_meta("night_qualified") and not rig.get_meta("grants_inventory"),
		"complete candidate never grants Night or inventory"
	)
	var source_binding_ok: bool = true
	for index in range(spans.size()):
		var source: SpotLight3D = rig.sources[index]
		source_binding_ok = (
			source_binding_ok
			and source.global_position.is_equal_approx(
				spans[index].to_global(MODEL.cable_point(0.5))
			)
			and source.get_meta("owned_copy") == spans[index].get_meta("owned_copy")
		)
	_check(source_binding_ok, "each broad source is associated with exact installed span midpoint")
	for span: Node3D in spans:
		_check(
			span.find_children("*", "Light3D", true, false).is_empty(),
			"fourteen bulbs never create fourteen dynamic lights"
		)
	_check(
		(
			_environment_state(environment) == environment_state
			and lab._world_environment.environment != environment
		),
		"night grade duplicates environment instead of mutating shared source"
	)
	_check(not lab._world_environment.environment.glow_enabled, "night study disables bloom")
	var installed_pose: Transform3D = spans[0].transform
	spans[0].position.x += 0.01
	_check(
		(
			not rig.set_night(true)
			and not rig.active
			and lab._world_environment.environment == environment
		),
		"reapplying an invalidated live installation fails closed and restores source state"
	)
	spans[0].transform = installed_pose
	_check(
		rig.set_night(true),
		"restoring exact complete physical installation permits study reactivation"
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _coverage(rig, profile, left)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	ball.set_physics_process(false)
	# Freeze incidental player/effect animation so paired native images differ only by ball visibility.
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	for dark: bool in [false, true]:
		_check(rig.set_night(dark), "day/night toggle is explicit and reversible")
		await _views(lab, ball, profile, left, dark)
	_check(
		_physical_state(property) == geometry,
		"lighting does not move replace hide or disable physical colliders"
	)
	rig.restore()
	_check(
		(
			lab._world_environment.environment == environment
			and _environment_state(environment) == environment_state
		),
		"explicit restore returns identical unmodified source environment"
	)
	_check(
		[sun.light_color, sun.light_energy] == sun_state and _shadow_state() == before_shadows,
		"explicit restore returns original sun and viewport shadow configuration"
	)
	_check(
		spans[0].get_node("Visual/Bulb00").material_override == material,
		"original bulb material identity is restored"
	)
	_check(rig.coverage(Vector3(0, 1.05, 0)) == 0, "inactive rig provides no coverage")
	_check(rig.set_night(true), "restored study can be reactivated without accumulated sources")
	# Freeing the rig while scene survives tests automatic teardown separately from manual restore.
	rig.free()
	_check(
		(
			lab._world_environment.environment == environment
			and _environment_state(environment) == environment_state
			and [sun.light_color, sun.light_energy] == sun_state
			and _shadow_state() == before_shadows
		),
		"tree teardown automatically restores environment sun and viewport"
	)
	_check(
		spans[0].get_node("Visual/Bulb00").material_override == material,
		"tree teardown restores original material objects"
	)
	for pole: Node3D in poles:
		_check(
			not pole.get_node("FieldLight").visible,
			"original inactive pole visibility survives teardown"
		)
	lab.queue_free()
	await get_tree().process_frame
	_check(_shadow_state() == before_shadows, "leaving full scene preserves viewport settings")


func _rejections(
	property: Node3D,
	environment: WorldEnvironment,
	sun: DirectionalLight3D,
	spans: Array[Node3D],
	poles: Array[Node3D]
) -> void:
	var source: Environment = environment.environment
	for size in range(spans.size()):
		var partial: Array[Node3D] = spans.slice(0, size)
		_check(
			RIG.install(property, environment, sun, partial, poles) == null,
			"incomplete or omitted installed spans refuse"
		)
	var repeated: Array[Node3D] = spans.duplicate()
	repeated.append(spans[0])
	_check(
		RIG.install(property, environment, sun, repeated, poles) == null, "duplicate span refuses"
	)
	var first: Node3D = spans[0]
	var old: Transform3D = first.transform
	first.position.x += 0.01
	_check(RIG.install(property, environment, sun, spans, poles) == null, "shifted socket refuses")
	first.transform = old
	first.scale = Vector3(-1, 1, 1)
	_check(
		RIG.install(property, environment, sun, spans, poles) == null, "mirrored assembly refuses"
	)
	first.transform = old
	var copy: String = str(first.get_meta("owned_copy"))
	first.set_meta("owned_copy", "")
	_check(
		RIG.install(property, environment, sun, spans, poles) == null,
		"unbound physical copy refuses"
	)
	first.set_meta("owned_copy", copy)
	var cable: Node = first.get_node("Visual/Cable00")
	var cable_index: int = cable.get_index()
	first.get_node("Visual").remove_child(cable)
	_check(
		RIG.install(property, environment, sun, spans, poles) == null,
		"incomplete physical cable assembly refuses"
	)
	first.get_node("Visual").add_child(cable)
	first.get_node("Visual").move_child(cable, cable_index)
	var dynamic_bulb: OmniLight3D = OmniLight3D.new()
	first.add_child(dynamic_bulb)
	_check(
		RIG.install(property, environment, sun, spans, poles) == null,
		"injected per-bulb dynamic source refuses"
	)
	dynamic_bulb.free()
	var prior_copy: String = str(spans[1].get_meta("owned_copy"))
	spans[1].set_meta("owned_copy", copy)
	spans[1].set_meta("paid_copy", copy)
	_check(
		RIG.install(property, environment, sun, spans, poles) == null,
		"reusing one paid-copy binding refuses"
	)
	spans[1].set_meta("owned_copy", prior_copy)
	spans[1].set_meta("paid_copy", prior_copy)
	if not poles.is_empty():
		StadiumYardLightModels.place(poles[0], "YLIGHT-FL")
		_check(
			RIG.install(property, environment, sun, spans, poles) == null,
			"front pole cannot substitute for rear mixed pole"
		)
		StadiumYardLightModels.place(poles[0], "YLIGHT-RL")
		var none: Array[Node3D] = []
		_check(
			RIG.install(property, environment, sun, spans, none) == null,
			"mixed preset without independently owned rear poles refuses"
		)
	_check(environment.environment == source, "failed activation does not touch environment")


func _competing_lease(lab: Node3D, environment: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var other: Node3D = Node3D.new()
	other.position = Vector3(100, 0, 0)
	lab.add_child(other)
	var other_spans: Array[Node3D] = []
	for site: String in StadiumStringLightItems.PRESETS["FESTOON-6X036-DG1"]:
		var span: Node3D = MODEL.create("ST-036", {"copy": "competing:" + site, "site": site})
		other.add_child(span)
		other_spans.append(span)
	var original: Environment = environment.environment
	var shadows: Dictionary = _shadow_state()
	_check(
		(
			RIG.install(other, environment, sun, other_spans) == null
			and environment.environment == original
			and _shadow_state() == shadows
		),
		"another installation cannot take over an active environment or viewport lease"
	)
	other.free()


func _coverage(rig: StadiumStringLightNightPrototype, profile: String, left: bool) -> void:
	var samples: int = 0
	var uncovered: Array = []
	var minimum: int = 999
	for x in range(-23, 24, 2):
		for z in range(-5, 24, 2):
			if not Geometry2D.is_point_in_polygon(
				Vector2(x, z), PackedVector2Array(StadiumBoundaryGraph.VERTICES)
			):
				continue
			for height: float in [0.2, 1.05, 3.0, 6.0, 10.0, 15.0]:
				var point: Vector3 = Vector3(x, height, z)
				var count: int = rig.coverage(point)
				minimum = mini(minimum, count)
				if count == 0:
					uncovered.append(str(point))
				samples += 1
	# Exact low/high pitch corridor and behind-plate receiver samples supplement the grid.
	for z: float in [-1.5, -0.5, 0.0, 3.0, 7.0, 11.0, 14.0]:
		for x: float in [-0.43, 0.0, 0.43]:
			for height: float in [0.55, 1.05, 1.55]:
				var point: Vector3 = Vector3(x, height, z)
				var count: int = rig.coverage(point)
				minimum = mini(minimum, count)
				if count == 0:
					uncovered.append(str(point))
				samples += 1
	var summary: Dictionary = {
		"profile": profile,
		"left_handed": left,
		"samples": samples,
		"uncovered": uncovered,
		"minimum_open_beams": minimum,
		"rendered_evidence": false
	}
	_report.coverage.append(summary)
	print("STRING_LIGHT_BEAM_COVERAGE " + JSON.stringify(summary))
	_check(
		samples > 1000 and uncovered.is_empty(),
		"both-hand pitch and elevated field samples have actual unoccluded beam"
	)
	_check(rig.coverage(Vector3(0, 1000, 0)) == 0, "finite range excludes distant points")
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = Vector3(0, 3, 10)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1
	collider.shape = sphere
	blocker.add_child(collider)
	add_child(blocker)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		rig.coverage(blocker.position) == 0,
		"actual physics occluder blocks every source rather than cone-only credit"
	)
	blocker.free()
	await get_tree().physics_frame


func _views(
	lab: PitchBatLab, ball: BattedBallBody, profile: String, left: bool, dark: bool
) -> void:
	var director: MatchCameraDirector = lab._camera_director
	var camera: Camera3D = lab._camera
	var prefix: String = (
		"%s-%s-%s"
		% [
			"festoon" if profile.begins_with("FESTOON") else "mixed",
			"left" if left else "right",
			"night" if dark else "day"
		]
	)
	for shot: int in [MatchCameraDirector.Shot.BATTING, MatchCameraDirector.Shot.PITCHING]:
		ball.position = Vector3(0, 1.05, 7 if shot == MatchCameraDirector.Shot.BATTING else 0)
		director.set_shot(shot as MatchCameraDirector.Shot)
		director.snap(camera, ball.position)
		_check(
			_in_frame(camera, ball.position),
			"actual fixed camera contains reference pitch for each hand"
		)
		await _capture(
			camera, ball, prefix + ("-batting-pitch" if shot == 0 else "-pitching-plate")
		)
	for defense: bool in [false, true]:
		for high: bool in [false, true]:
			var start: Vector3 = Vector3(0, 1.05, 0.1)
			var launch: Vector3 = Vector3(3, 14, 16) if high else Vector3(2, 1, 8)
			director.set_shot(
				MatchCameraDirector.Shot.PITCHING if defense else MatchCameraDirector.Shot.BATTING
			)
			director.snap(camera, start)
			director.prepare_ball_in_play(defense, start, launch)
			director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			var framed: bool = true
			for frame in range(91):
				var t: float = frame / 60.0
				ball.position = start + launch * t + Vector3(0, -4.903325 * t * t, 0)
				ball.position.y = maxf(ball.position.y, 0.12)
				director.update(camera, 1.0 / 60, true, ball.position)
				framed = framed and _in_frame(camera, ball.position)
			_check(
				framed,
				"bounded actual tracking camera retains shallow or high-deep reference trajectory"
			)
			await _capture(
				camera,
				ball,
				(
					prefix
					+ ("-defense" if defense else "-offense")
					+ ("-high-deep" if high else "-shallow")
				)
			)


func _capture(camera: Camera3D, ball: BattedBallBody, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return  # Explicit NOT_RUN status, no fake images or successful readability claims.
	ball.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var background: Image = get_viewport().get_texture().get_image()
	ball.visible = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var center: Vector2 = camera.unproject_position(ball.global_position)
	var edge: Vector2 = camera.unproject_position(
		ball.global_position + camera.global_basis.x * WiffleBallVisual.RADIUS
	)
	var radius: float = maxf(1, center.distance_to(edge))
	var count: int = 0
	var changed: int = 0
	var delta_sum: float = 0
	var peak_delta: float = 0
	var ball_luminance: float = 0
	var backdrop_luminance: float = 0
	for y in range(
		maxi(0, int(center.y - radius - 2)), mini(frame.get_height(), int(center.y + radius + 3))
	):
		for x in range(
			maxi(0, int(center.x - radius - 2)), mini(frame.get_width(), int(center.x + radius + 3))
		):
			var value: float = frame.get_pixel(x, y).get_luminance()
			var backdrop: float = background.get_pixel(x, y).get_luminance()
			var difference: float = absf(value - backdrop)
			count += 1
			changed += 1 if difference > 1.0 / 255.0 else 0
			delta_sum += difference
			peak_delta = maxf(peak_delta, difference)
			ball_luminance += value
			backdrop_luminance += backdrop
	var diagnostic: Dictionary = {
		"view": label,
		"projected_ball_radius_px": radius,
		"roi_pixels": count,
		"changed_pixels_above_one_byte": changed,
		"mean_abs_luminance_delta": delta_sum / maxf(1, count),
		"peak_abs_luminance_delta": peak_delta,
		"roi_mean_luminance": ball_luminance / maxf(1, count),
		"background_mean_luminance": backdrop_luminance / maxf(1, count),
		"night_qualified": false,
		"threshold_status": "UNSET_DIAGNOSTIC_ONLY",
		"measurement_space": "display-encoded RGB luminance proxy; not calibrated photometry"
	}
	_report.renders.append(diagnostic)
	print("STRING_LIGHT_CONTRAST_DIAGNOSTIC " + JSON.stringify(diagnostic))
	if not _capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		_check(
			frame.save_png(_capture_dir.path_join(label + ".png")) == OK,
			"native day/night scene capture written"
		)


func _in_frame(camera: Camera3D, point: Vector3) -> bool:
	return (
		not camera.is_position_behind(point)
		and get_viewport().get_visible_rect().has_point(camera.unproject_position(point))
	)


func _physical_state(root: Node) -> Array:
	var result: Array = []
	for collider: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		var body: CollisionObject3D = collider.get_parent()
		result.append(
			[
				collider.get_instance_id(),
				collider.transform,
				collider.shape.get_rid(),
				collider.disabled,
				body.global_transform,
				body.collision_layer,
				body.collision_mask
			]
		)
	return result


func _environment_state(environment: Environment) -> Dictionary:
	return {
		"mode": environment.background_mode,
		"background": environment.background_color,
		"source": environment.ambient_light_source,
		"color": environment.ambient_light_color,
		"energy": environment.ambient_light_energy,
		"reflection": environment.reflected_light_source,
		"glow": environment.glow_enabled,
		"exposure": environment.tonemap_exposure
	}


func _shadow_state() -> Dictionary:
	var viewport: Viewport = get_viewport()
	var result: Dictionary = {
		"size": viewport.positional_shadow_atlas_size,
		"precision": viewport.positional_shadow_atlas_16_bits,
		"quadrants": []
	}
	for index in range(4):
		result.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	return result


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("STRING_LIGHT_NIGHT_FAILURE " + message)
