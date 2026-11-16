extends "res://src/tests/stadium_surface_night_preview_test.gd"
## B reuse: one representative composition, four profile/target images, three day pairs.
## Synthetic paid setup and home cursor; no completed game, sale or public activation.

const B_JSON: String = "owned-surface-night-gameplay-b.json"
const B_MAX_BYTES: int = 1048576
const PITCH_ID: StringName = &"pitch.overhand_four_seam"
const PITCH_SEED: int = 41
const ENDPOINTS: Array[Vector3] = [Vector3(0, 0.0365, 1), Vector3(0, 7, 28)]
const POINT_NAMES: Array[String] = ["pitch_depth_1m", "plate_sand", "loft"]

var _setup: Node
var _viewport: SubViewport
var _app: SeasonApp
var _paid: ClubAssetLedger
var _candidate: Dictionary = {}
var _rows: Array[Dictionary] = []
var _day_samples: Dictionary = {}
var _day_geometry: Dictionary = {}
var _source_seasons: Array[SeasonState] = []
var _day_payload: String = ""
var _night_payload: String = ""
var _checkpoint_hashes: Dictionary = {}
var _captures: Array[Dictionary] = []
var _stars: Dictionary = {}
var _save_path: String = ""
var _save_error: String = ""
var _private_before: Dictionary = {}
var _shared_before: Dictionary = {}
var _pngs: Array[String] = []
var _restoration: Dictionary = {}
var _hand_lab: PitchBatLab
var _hand_state: MatchState
var _hand_player: PlayerMatchState
var _hand_original: PlayerDefinition
var _hand_working: PlayerDefinition
var _hand_override: int = -1


func _ready() -> void:
	_save_path = SeasonSave.path
	_save_error = SeasonSave.last_error
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(
		DisplayServer.get_name() != "headless" and not _capture_dir.is_empty(),
		"B requires native rendering and an explicit bounded capture directory"
	)
	if _failures == 0:
		await _exercise()
	await _cleanup_b()
	await TestAudioDrain.finish(get_tree())
	SeasonSave.path = _save_path
	SeasonSave.last_error = _save_error
	print(
		(
			"OWNED_SURFACE_NIGHT_GAMEPLAY_B checks=%d failures=%d pairs=%d images=%d"
			% [_checks, _failures, _rows.size(), _pngs.size()]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _exercise() -> void:
	SeasonSave.path = "user://owned-surface-time-b-%d.json" % OS.get_process_id()
	_setup = load("res://src/tests/stadium_surface_night_gameplay_a_test.gd").new()
	var completed: SeasonState = _setup._funding()
	if completed == null:
		_check(false, "existing closed synthetic funding setup succeeds")
		return
	_paid = _setup._purchases(completed)
	_checks += _setup._checks
	_failures += _setup._failures
	if _paid == null:
		return
	_candidate = StadiumSurfaceNightLayout.capture(_paid)
	_shared_before = StadiumSurfaceNightPreview._shadows(get_viewport())
	_viewport = SubViewport.new()
	_viewport.name = "OwnedTimeBPrivateViewport"
	_viewport.size = SIZE
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_app = SeasonApp.new()
	_viewport.add_child(_app)
	_app.set_process(false)
	_private_before = StadiumSurfaceNightPreview._shadows(_viewport)
	_check(
		(
			_viewport.find_world_3d() != get_viewport().find_world_3d()
			and _viewport.size == SIZE
			and _viewport.own_world_3d
		),
		"one exact1280x720 private world contains the three ordinary managed profile mounts"
	)
	for profile: String in ["day", "sunset", "night"]:
		_app.season = completed
		_app.begin_surface_time_season(profile, 101, 0)
		var fresh: SeasonState = _app.season
		if fresh == null or fresh == completed:
			_check(false, "ordinary explicit time-profile season entry succeeds")
			return
		for pick in range(4):
			if fresh.offers().is_empty() or not fresh.choose_player(fresh.offers()[0]):
				_check(false, "ordinary fixed four-player draft succeeds")
				return
		var saved: bool = SeasonSave.save(fresh)
		var payload: Dictionary = SeasonSave.snapshot(fresh)
		_check(
			(
				saved
				and not payload.is_empty()
				and fresh.round_index == 0
				and fresh.owned_surface_night.version == 2
				and fresh.owned_surface_night.mode == profile
				and payload.version == 73
			),
			"each genuine named profile saves its valid round0 version73 checkpoint"
		)
		if not saved or payload.is_empty():
			return
		var checkpoint: String = FileAccess.get_file_as_string(SeasonSave.path)
		_checkpoint_hashes[profile] = checkpoint.sha256_text()
		if profile == "day":
			_day_payload = checkpoint
		elif profile == "night":
			_night_payload = checkpoint
		# Decode independent diagnostic contexts; never strip or relabel a saved policy.
		var diagnostic: SeasonState = SeasonSave._decode(JSON.parse_string(checkpoint))
		if diagnostic == null:
			_check(false, "ordinary checkpoint decodes for the bounded optical context")
			return
		_source_seasons.append(diagnostic)
	await _gameplay_b_candidate()


func _gameplay_b_candidate() -> void:
	var day: SeasonState = _source_seasons[0]
	_check(StadiumSurfaceNightLayout.valid(_candidate, _paid)
		and ClubCareer.same(day.home_property, _candidate.entry)
		and _source_seasons.all(func(value: SeasonState) -> bool: return \
			ClubCareer.same(value.home_property, day.home_property))
		and day.home_property.version == 8 and day.home_property.layout.version == 12
		and day.home_property.tier == "expanded" and day.home_property.layout.lights.size() == 4
		and day.home_property.layout.surface == {"foundation": "grass", "condition": "prepared", \
			"height": "short"}
		and day.home_property.layout.styles.grass == "ST-063b" and day.home_property.layout.ground == \
			"ST-063i"
		and ClubCareer.same(day.home_property.layout.walls, StadiumWallLayout.empty()),
		"all profiles share the unchanged paid entry8 composition with exactly four owned lamps")
	var home: Dictionary = _setup._first_home(day)
	var same_home: bool = not home.is_empty()
	for season: SeasonState in _source_seasons:
		same_home = same_home and ClubCareer.same(_setup._first_home(season), home)
	_check(same_home, "all optical copies use the same first existing scheduled home fixture")
	if not same_home:
		return
	for season: SeasonState in _source_seasons:
		season.round_index = int(home.round)  # Synthetic diagnostic cursor; no settlement/save follows.
	for season: SeasonState in _source_seasons:
		var profile: String = season.owned_surface_night.mode
		_app.season = season
		_app._fixture_id = int(season.pending_fixture().id)
		_app._open_match(season.make_match(), true, true, PitchBatLab.FIELD_ID)
		var lab: PitchBatLab = _app.lab
		var admitted: bool = (
			is_instance_valid(lab)
			and lab.get_parent() == _app
			and lab._camera.get_viewport() == _viewport
			and lab.has_meta("stadium_property")
		)
		if admitted:
			var current_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
			admitted = (
				current_owner != null
				and current_owner._owned_sky != null
				and current_owner._owned_sky_material != null
				and current_owner._working_environment.sky == current_owner._owned_sky
				and current_owner._owned_sky.sky_material == current_owner._owned_sky_material
				and StadiumSurfaceNightSnapshot.is_time(lab._match_state.stadium)
				and StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium)
			)
		_check(admitted, "ordinary managed profile installation admits the exact paid fixture27")
		if not admitted:
			return
		_setup._pause(lab)
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab._status_label.visible = false
		var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
		var physical: Dictionary = _physical_values(property)
		if profile == "day":
			_day_geometry = physical.duplicate(true)
		var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
		var original: Dictionary = _setup._original(owner)
		original["sky"] = owner._original_sky
		original["sky_material"] = owner._original_sky_material
		original["time_before"] = owner._time_before.duplicate(true)
		for index in range(original.lamps.size()):
			original.lamps[index]["beam_energy"] = owner._lamps[index].beam_energy
		var ledger_data: String = _ledger_bytes(_paid)
		var snapshot_data: String = _bytes(lab._match_state.stadium)
		var proof_data: String = _bytes(owner._proof)
		var season_data: String = _bytes(
			[
				season.schedule,
				season.player_results,
				season.career.to_data(),
				season.home_property,
				season.owned_surface_night
			]
		)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		var actor: PitchFlightActor = PitchFlightActor.new()
		lab.add_child(actor)
		actor.set_physics_process(false)
		var pitch_mesh: MeshInstance3D = actor.get_node("DebugBall")
		var pitch_material: StandardMaterial3D = pitch_mesh.material_override
		var ball_mesh: MeshInstance3D = ball.get_child(1)
		var ball_material: StandardMaterial3D = ball_mesh.material_override
		var expected_pitch_radius: float = PackedFloat32Array([0.075])[0]
		var expected_pitch_roughness: float = PackedFloat32Array([0.85])[0]
		var expected_ball_radius: float = PackedFloat32Array([0.075])[0]
		var expected_ball_roughness: float = PackedFloat32Array([0.78])[0]
		var pitch_color: Color = pitch_material.albedo_color
		var ball_color: Color = ball_material.albedo_color
		var expected_pitch_color: Color = WiffleBallVisual.WHITE
		var expected_ball_color: Color = WiffleBallVisual.WHITE
		print(
			(
				"NIGHT_B_PROBE_OPERANDS "
				+ JSON.stringify(
					{
						"mount": profile,
						"actual":
						{
							"radius_m": ball.radius_m,
							"freeze": ball.freeze,
							"actor_script": actor.get_script().resource_path,
							"pitch_radius": pitch_mesh.mesh.get_aabb().size.x * 0.5,
							"pitch_roughness": pitch_material.roughness,
							"ball_radius": ball_mesh.mesh.get_aabb().size.x * 0.5,
							"ball_roughness": ball_material.roughness,
							"pitch_albedo":
							[pitch_color.r, pitch_color.g, pitch_color.b, pitch_color.a],
							"ball_albedo": [ball_color.r, ball_color.g, ball_color.b, ball_color.a]
						},
						"expected":
						{
							"radius_m": 0.0365,
							"freeze": true,
							"actor_script": "res://src/presentation/ball/pitch_flight_actor.gd",
							"pitch_radius": expected_pitch_radius,
							"pitch_roughness": expected_pitch_roughness,
							"ball_radius": expected_ball_radius,
							"ball_roughness": expected_ball_roughness,
							"pitch_albedo":
							[
								expected_pitch_color.r,
								expected_pitch_color.g,
								expected_pitch_color.b,
								expected_pitch_color.a
							],
							"ball_albedo":
							[
								expected_ball_color.r,
								expected_ball_color.g,
								expected_ball_color.b,
								expected_ball_color.a
							]
						},
						"exact_predicates":
						{
							"radius_m": ball.radius_m == 0.0365,
							"freeze": ball.freeze,
							"actor_script": actor.get_script() == PitchFlightActor,
							"pitch_radius":
							(pitch_mesh.mesh.get_aabb().size.x * 0.5) == expected_pitch_radius,
							"pitch_albedo": pitch_material.albedo_color == WiffleBallVisual.WHITE,
							"pitch_roughness": pitch_material.roughness == expected_pitch_roughness,
							"ball_radius":
							(ball_mesh.mesh.get_aabb().size.x * 0.5) == expected_ball_radius,
							"ball_albedo": ball_material.albedo_color == WiffleBallVisual.WHITE,
							"ball_roughness": ball_material.roughness == expected_ball_roughness
						}
					},
					"",
					true,
					true
				)
			)
		)
		_check(
			(
				pitch_mesh is WiffleBallVisual
				and pitch_mesh.authored_mesh()
				and ball_mesh is WiffleBallVisual
				and ball_mesh.authored_mesh()
				and ball.radius_m == 0.0365
				and ball.freeze
				and actor.get_script() == PitchFlightActor
				and (pitch_mesh.mesh.get_aabb().size.x * 0.5) == expected_pitch_radius
				and pitch_material.albedo_color == WiffleBallVisual.WHITE
				and pitch_material.roughness == expected_pitch_roughness
				and (ball_mesh.mesh.get_aabb().size.x * 0.5) == expected_ball_radius
				and ball_material.albedo_color == WiffleBallVisual.WHITE
				and ball_material.roughness == expected_ball_roughness
			),
			"both probes retain their ordinary production dimensions and materials"
		)
		_hand_lab = lab
		_hand_state = lab._match_state
		_hand_player = _hand_state.batter()
		_hand_original = _hand_player.definition
		_hand_override = _hand_player.batting_hand_override
		var original_match: Dictionary = _state(_hand_state, {})
		_hand_working = _hand_original.duplicate(true)
		_hand_working.bats = PlayerDefinition.Handedness.RIGHT
		_hand_player.definition = _hand_working
		_hand_player.batting_hand_override = -1
		PitchBatLabPresentation.sync_players(lab)
		lab._camera_director.set_batter_handedness(false)
		var stages: Array[String] = [profile]
		if profile == "sunset":
			stages.append("sunset_extra_target")
		for stage: String in stages:
			var progress: Dictionary = StadiumSurfaceNightSnapshot.clock(profile, 0, 0)
			var target: float = 0.0
			if stage == "sunset_extra_target":
				# Pure target visualization, not a played game or the capped safe-boundary sequence.
				progress = StadiumSurfaceNightSnapshot.clock(profile, 240, 12)
				target = StadiumSurfaceNightSnapshot.drift(profile, progress)
				var tuple_before: Array = [
					lab._play_records.size(), lab._match_state.inning, lab._match_state.top_half
				]
				var applied: bool = (
					StadiumSurfaceNightRuntime.boundary_allowed(lab)
					and owner._write_time_values(lab, target)
				)
				_check(
					(
						applied
						and (
							tuple_before
							== [
								lab._play_records.size(),
								lab._match_state.inning,
								lab._match_state.top_half
							]
						)
						and _bytes(owner._proof) == proof_data
						and _bytes(owner._snapshot) == snapshot_data
					),
					("synthetic240-play twelve-half clock renders only its derived target " + \
						"without changing canonical play or proof")
				)
				if not applied:
					return
			ball.visible = false
			actor.reset_pitch()
			var gameplay: Dictionary = _state(lab._match_state, {})
			var observed: Dictionary = _observe(lab, actor, ball, false, false, 1)
			if observed.is_empty():
				return
			var camera: Dictionary = _camera_values(lab._camera)
			var point: Vector3 = ball.global_position
			var contrast: Dictionary = await _contrast(lab._camera, ball)
			if contrast.is_empty():
				return
			_check(
				(
					observed.framed
					and observed.unblocked
					and not observed.points.is_empty()
					and _camera_values(lab._camera) == camera
					and ball.global_position == point
					and _state(lab._match_state, {}) == gameplay
					and _physical_values(property) == physical
					and _ledger_bytes(_paid) == ledger_data
					and _bytes(lab._match_state.stadium) == snapshot_data
					and StadiumSurfaceNightRuntime.action_allowed(lab)
				),
				("representative diagnostic path stays framed and capture preserves " + \
					"exact pose physics and authority")
			)
			var sample: Dictionary = {
				"path": observed.points.duplicate(),
				"camera": camera,
				"point": point,
				"contrast": contrast.difference,
				"operands": contrast.operands
			}
			if profile == "day":
				_day_samples["representative"] = sample
			else:
				var baseline: Dictionary = _day_samples.representative
				var cutoff: float = maxf(0.03, float(baseline.contrast) * 0.65)
				_check(
					contrast.difference >= cutoff,
					"paired profile contrast meets unchanged max(0.03,day*0.65)"
				)
				var exact: bool = (
					sample.path == baseline.path
					and sample.camera == baseline.camera
					and sample.point == baseline.point
					and physical == _day_geometry
				)
				_check(
					exact,
					"native paired diagnostic paths camera poses and physical geometry are exactly equal"
				)
				_rows.append(
					{
						"id": stage,
						"view": "right-batting",
						"point_kind": "plate_sand",
						"path_authority": "diagnostic_interpolation",
						"point": _vector(point),
						"camera": _camera_evidence(lab._camera),
						"path_samples": sample.path.size(),
						"path_sha256": _bytes(_vectors(sample.path)).sha256_text(),
						"day": baseline.operands,
						"profile": contrast.operands,
						"day_contrast": baseline.contrast,
						"profile_contrast": contrast.difference,
						"threshold": cutoff,
						"contrast_pass": contrast.difference >= cutoff,
						"exact_native_pair": exact,
						"framed": observed.framed,
						"unblocked": observed.unblocked
					}
				)
			# Keep all three plate-sand pairs above. Only the retained Night image uses
			# the existing ordinary pitching view, whose real sky reaches the star mask.
			var capture_image: Image = contrast.image
			var capture_view: String = "right-batting"
			var sky_upper_ray_y: float = 0.0
			var capture_camera: Camera3D = lab._camera
			var capture_director: MatchCameraDirector = lab._camera_director
			var previous_shot: int = capture_director.shot
			if profile == "night":
				capture_view = "pitching-sky"
				capture_director.clear_presentation_motion()
				capture_director.track_released_pitch(false, Vector3.ZERO)
				capture_director.set_shot(MatchCameraDirector.Shot.PITCHING)
				capture_director.snap(capture_camera)
				sky_upper_ray_y = capture_camera.project_ray_normal(Vector2(SIZE.x / 2.0, 0.0)).y
				await RenderingServer.frame_post_draw
				capture_image = _viewport.get_texture().get_image()
			var capture_valid: bool = (
				capture_image != null
				and not capture_image.is_empty()
				and capture_image.get_size() == SIZE
				and (
					profile != "night"
					or (
						capture_director.shot == MatchCameraDirector.Shot.PITCHING
						and sky_upper_ray_y > 0.30
						and lab._camera == capture_camera
						and lab._camera_director == capture_director
						and owner._context(lab)
						and owner._operands()
					)
				)
			)
			var png: String = "owned-surface-time-b-" + stage + ".png"
			var saved_png: bool = (
				capture_valid and capture_image.save_png(_capture_dir.path_join(png)) == OK
			)
			_check(
				saved_png,
				"one representative profile/target PNG is retained within the four-image limit"
			)
			if not capture_valid:
				return
			if saved_png:
				_pngs.append(png)
			_captures.append(
				{
					"id": stage,
					"profile": profile,
					"png": png,
					"image_sha256": capture_image.get_data().hex_encode().sha256_text(),
					"view": capture_view,
					"sky_upper_ray_y": sky_upper_ray_y,
					"clock": progress,
					"target": target,
					"applied_sequence_progress": owner._profile_progress,
					"progress_authority":
					(
						"pure_synthetic_target"
						if stage == "sunset_extra_target"
						else "ordinary_profile_start"
					),
					"palette": _palette_evidence(owner),
					"point": _vector(point),
					"camera": _camera_evidence(lab._camera)
				}
			)
			if profile == "night":
				_stars = await _stars_diagnostic(lab, owner, ball, capture_image)
				# Restore the captured diagnostic plate camera only while it is still ours.
				if (
					_stars.get("full_authority", false)
					and lab._camera == capture_camera
					and lab._camera_director == capture_director
					and owner._context(lab)
				):
					capture_director.set_shot(previous_shot as MatchCameraDirector.Shot)
					capture_camera.global_transform = camera.transform
					capture_camera.fov = camera.fov
		var hand_restored: bool = _restore_batter()
		_check(
			(
				hand_restored
				and _state(lab._match_state, {}) == original_match
				and _physical_values(property) == physical
				and _ledger_bytes(_paid) == ledger_data
				and _bytes(lab._match_state.stadium) == snapshot_data
				and _bytes(owner._proof) == proof_data
				and (
					_bytes(
						[
							season.schedule,
							season.player_results,
							season.career.to_data(),
							season.home_property,
							season.owned_surface_night
						]
					)
					== season_data
				)
				and StadiumSurfaceNightRuntime.boundary_allowed(lab)
			),
			("profile samples restore original batter and preserve paid policy " + \
				"physics history and full authority")
		)
		StadiumSurfaceNightRuntime.retire_captured(lab, owner)
		var restored: bool = _restored_b(lab, owner, original)
		_check(
			restored,
			"runtime restores original sky lamps owners resources values geometry and private atlas"
		)
		StadiumSurfaceNightRuntime.retire_captured(lab, owner)
		var idempotent: bool = _restored_b(lab, owner, original)
		_check(idempotent, "second retirement remains exact and idempotent")
		_restoration[profile] = {"exact": restored, "idempotent": idempotent}
		await RenderingServer.frame_post_draw
		_app._close_match()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check(
			(
				StadiumSurfaceNightPreview._shadows(_viewport) == _private_before
				and not _viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
				and StadiumSurfaceNightPreview._shadows(get_viewport()) == _shared_before
			),
			"ordinary close leaves both original atlas states and no stale owner token"
		)
	_check(
		(
			_captures.size() == 4
			and _captures[1].palette.top_color != _captures[3].palette.top_color
			and _captures[1].palette.horizon_color != _captures[3].palette.horizon_color
			and _captures[1].image_sha256 != _captures[3].image_sha256
			and _captures[1].image_sha256 != _captures[2].image_sha256
		),
		("Sunset and Night have distinct native palettes/images and the extra " + \
			"target changes the Sunset image")
	)
	_check(
		(
			_rows.size() == 3
			and _pngs.size() == 4
			and not StadiumSurfaceNightLayout.PUBLIC_READY
			and not StadiumSurfaceNightLayout.RUNTIME_READY
			and not StadiumSurfaceNightSnapshot.PUBLIC_READY
			and FileAccess.get_file_as_string(SeasonSave.path) == _night_payload
		),
		"exact three pairs and four images leave the original round0 save and activation gates unchanged"
	)
	_write_b_evidence()


func _palette_evidence(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		var value: Variant = owner._owned_sky_material.get_shader_parameter(key)
		result[key] = [value.r, value.g, value.b, value.a] if value is Color else value
	result["beam_energy"] = []
	result["beam_visible"] = []
	for row: Dictionary in owner._lamps:
		result.beam_energy.append(row.beam.light_energy)
		result.beam_visible.append(row.beam.visible)
	return result


func _stars_diagnostic(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, ball: BattedBallBody, retained: Image
) -> Dictionary:
	var sky: Sky = owner._owned_sky
	var material: ShaderMaterial = owner._owned_sky_material
	var original: Dictionary = owner._time_expected.parameters.duplicate(true)
	var camera: Dictionary = _camera_values(lab._camera)
	var point: Vector3 = ball.global_position
	var gameplay: Dictionary = _state(lab._match_state, {})
	var captured: bool = (
		_stars_owned(lab, owner, sky, material)
		and original.star_strength > 0.0
		and StadiumSurfaceNightRuntime.boundary_allowed(lab)
	)
	_check(
		captured, "Night stars diagnostic starts from exact owned sky and full boundary authority"
	)
	if not captured:
		return {}
	# Unretained diagnostic only. No image editing or simulated actual-game star state.
	var present: Image = retained  # The exact native Image already written to the Night PNG.
	if (
		not _stars_owned(lab, owner, sky, material)
		or not owner._operands()
		or _camera_values(lab._camera) != camera
		or ball.global_position != point
		or _state(lab._match_state, {}) != gameplay
	):
		_check(false, "captured sky camera pose and state remain exact before the diagnostic write")
		return {}
	material.set_shader_parameter("star_strength", 0.0)
	await RenderingServer.frame_post_draw
	var absent: Image = _viewport.get_texture().get_image()
	var same_owner: bool = _stars_owned(lab, owner, sky, material)
	for parameter: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		var expected: Variant = 0.0 if parameter == &"star_strength" else original[parameter]
		same_owner = same_owner and material.get_shader_parameter(parameter) == expected
	if same_owner:
		material.set_shader_parameter("star_strength", original.star_strength)
	await RenderingServer.frame_post_draw
	var values_restored: bool = same_owner and _stars_owned(lab, owner, sky, material)
	for parameter: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		values_restored = (
			values_restored and material.get_shader_parameter(parameter) == original[parameter]
		)
	var images_valid: bool = (
		present != null
		and absent != null
		and not present.is_empty()
		and not absent.is_empty()
		and present.get_size() == SIZE
		and absent.get_size() == SIZE
		and present.get_format() == absent.get_format()
	)
	var positive_pixels: int = 0
	var negative_pixels: int = 0
	var maximum: float = 0.0
	if images_valid:
		for y in range(SIZE.y):
			for x in range(SIZE.x):
				var on: Color = present.get_pixel(x, y)
				var off: Color = absent.get_pixel(x, y)
				var delta: Vector3 = Vector3(on.r - off.r, on.g - off.g, on.b - off.b)
				if delta.x > 0.0 or delta.y > 0.0 or delta.z > 0.0:
					positive_pixels += 1
				if delta.x < 0.0 or delta.y < 0.0 or delta.z < 0.0:
					negative_pixels += 1
				maximum = maxf(maximum, delta.length())
	var authority: bool = (
		values_restored
		and _camera_values(lab._camera) == camera
		and ball.global_position == point
		and _state(lab._match_state, {}) == gameplay
		and StadiumSurfaceNightRuntime.boundary_allowed(lab)
	)
	_check(
		images_valid and positive_pixels > 0 and maximum > 0.0 and authority,
		("native Night pixels show a positive star contribution and exact " + \
			"uniform/sky/full authority restoration")
	)
	return {
		"scope": "unretained_stars_off_diagnostic",
		"off_png_retained": false,
		"original_strength": original.star_strength,
		"diagnostic_strength": 0.0,
		"pixels_examined": SIZE.x * SIZE.y,
		"positive_pixels": positive_pixels,
		"negative_pixels": negative_pixels,
		"maximum_rgb_difference": maximum,
		"images_valid": images_valid,
		"stars_on_source": "retained_night_png_native_image",
		"exact_restore": values_restored,
		"full_authority": authority
	}


func _stars_owned(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, sky: Sky, material: ShaderMaterial
) -> bool:
	return (
		is_instance_valid(lab)
		and StadiumSurfaceNightRuntime.current(lab) == owner
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and owner._context(lab)
		and sky != null
		and material != null
		and owner._owned_sky == sky
		and owner._owned_sky_material == material
		and owner._working_environment.sky == sky
		and sky.sky_material == material
		and material.shader == StadiumSurfaceNightRuntime.TIME_SKY_SHADER
	)


func _observe(
	lab: PitchBatLab,
	actor: PitchFlightActor,
	ball: BattedBallBody,
	left: bool,
	defense: bool,
	point_index: int
) -> Dictionary:
	var director: MatchCameraDirector = lab._camera_director
	director.clear_presentation_motion()
	director.track_released_pitch(false, Vector3.ZERO)
	director.set_shot(
		MatchCameraDirector.Shot.PITCHING if defense else MatchCameraDirector.Shot.BATTING
	)
	director.snap(lab._camera)
	var points: Array[Vector3] = []
	var framed: bool = true
	var unblocked: bool = true
	if point_index == 0:
		var rated: PitchDefinition = MatchLabSupport.rated_pitch(
			ContentDB.get_pitch(PITCH_ID), ContentDB.get_player(&"player.debug_pitcher"), 1.0
		)
		var parameters: PitchLaunchParameters = PitchAimSolver.solve(
			rated,
			ContentDB.get_ball_setup(&"ball_setup.fresh"),
			PitchBatLab.MOUND_ORIGIN,
			Vector3(0, 1.05, 0),
			left,
			PITCH_SEED
		)
		if parameters == null:
			_check(false, "the one canonical ordinary pitch solves")
			return {}
		actor.start_pitch(parameters)
		for step in range(720):
			actor._physics_process(1.0 / 240.0)
			if not actor.running:
				break
			points.append(actor.global_position)
			framed = framed and _framed(lab._camera, actor.global_position)
			unblocked = (
				unblocked
				and not director.tracking_visibility._blocked(
					lab._camera.global_position, actor.global_position
				)
			)
			if actor.global_position.z <= 1.0:
				actor.running = false  # Freeze the diagnostic prefix before any plate/tween event.
				return {"points": points, "framed": framed, "unblocked": unblocked}
		_check(false, "the canonical actual flight reaches its final pre-plate1m sample")
		return {}
	# Existing diagnostic camera interpolation, not a simulated batted-ball trajectory.
	var endpoint: Vector3 = ENDPOINTS[point_index - 1]
	ball.visible = true
	director.prepare_ball_in_play(defense, Vector3(0, 1, 0), endpoint - Vector3(0, 1, 0))
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	for frame in range(240):
		ball.global_position = Vector3(0, 1, 0).lerp(endpoint, minf(1, frame / 150.0))
		director.update(lab._camera, 1.0 / 60, true, ball.global_position)
		points.append(ball.global_position)
		framed = framed and _framed(lab._camera, ball.global_position)
		unblocked = (
			unblocked
			and not director.tracking_visibility._blocked(
				lab._camera.global_position, ball.global_position
			)
		)
	ball.global_position = endpoint
	director.update(lab._camera, 1.0 / 60, true, ball.global_position)
	points.append(ball.global_position)
	return {
		"points": points,
		"framed": framed and _framed(lab._camera, endpoint),
		"unblocked":
		(
			unblocked
			and not director.tracking_visibility._blocked(lab._camera.global_position, endpoint)
		)
	}


func _framed(camera: Camera3D, point: Vector3) -> bool:
	return (
		not camera.is_position_behind(point)
		and Rect2(24, 24, 1232, 672).has_point(camera.unproject_position(point))
	)


func _camera_values(camera: Camera3D) -> Dictionary:
	return {
		"transform": camera.global_transform,
		"fov": camera.fov,
		"near": camera.near,
		"far": camera.far,
		"projection": camera.projection,
		"keep_aspect": camera.keep_aspect
	}


func _camera_evidence(camera: Camera3D) -> Dictionary:
	var result: Dictionary = _camera_values(camera)
	result.erase("transform")
	result["transform_columns_origin"] = _transform_components(camera.global_transform)
	return result


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _vectors(values: Array) -> Array:
	var result: Array = []
	for value: Vector3 in values:
		result.append(_vector(value))
	return result


func _physical_values(property: StadiumPropertyGeometry) -> Dictionary:
	var result: Dictionary = {}
	_physical_node(property, result, "0")
	return result


func _physical_node(node: Node, result: Dictionary, key: String) -> void:
	var row: Dictionary = {"class": node.get_class()}
	if node is Node3D:
		row["transform"] = node.transform
	if node is CollisionObject3D:
		row["layer"] = node.collision_layer
		row["mask"] = node.collision_mask
	if node is CollisionShape3D:
		row["disabled"] = node.disabled
		row["shape_class"] = node.shape.get_class() if node.shape != null else ""
		row["shape_values"] = {}
		if node.shape != null:
			for field: Dictionary in node.shape.get_property_list():
				if (
					int(field.usage) & PROPERTY_USAGE_STORAGE
					and (
						field.name
						not in [
							"script", "resource_name", "resource_path", "resource_scene_unique_id"
						]
					)
				):
					var value: Variant = node.shape.get(field.name)
					row.shape_values[field.name] = (
						value.duplicate(true) if value is Array or value is Dictionary else value
					)
	result[key] = row
	for index in range(node.get_child_count()):
		_physical_node(node.get_child(index), result, key + "/" + str(index))


func _restored_b(lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, original: Dictionary) -> bool:
	var host: Node = lab.get_node("StarterFieldGeometry")
	var metadata_ok: bool = true
	for key: StringName in StadiumSurfaceNightRuntime.META:
		var before: Dictionary = original.metadata[key]
		metadata_ok = metadata_ok and lab.has_meta(key) == before.present
		if before.present:
			metadata_ok = metadata_ok and lab.get_meta(key) == before.value
	var materials_ok: bool = (
		original.surface.material_override == original.material
		and original.material.get_shader_parameter("vertex_pigment_scale") == original.pigment
		and StadiumSurfaceNightPreview._metadata(original.material) == original.material_meta
	)
	for row: Dictionary in original.lamps:
		materials_ok = (
			materials_ok
			and row.lens.material_override == row.material
			and StadiumSurfaceNightPreview._metadata(row.material) == row.metadata
			and row.beam.visible == row.visible
			and row.material.emission_enabled == row.emission
			and row.material.emission_energy_multiplier == row.energy
			and row.beam.light_energy == row.beam_energy
		)
	return (
		owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		and materials_ok
		and original.environment.sky == original.sky
		and original.sky != null
		and original.sky.sky_material == original.sky_material
		and owner._original_sky_values() == original.time_before.sky_values
		and original.sky.radiance_size == original.time_before.radiance_size
		and original.sky.process_mode == original.time_before.process_mode
		and host.get_node("Sun") == original.sun_node
		and original.sun_node.light_color == original.sun.color
		and original.sun_node.light_energy == original.sun.energy
		and _setup._geometry(original.order) == original.geometry
		and lab._world_environment.environment == original.environment
		and (
			StadiumSurfaceNightPreview._environment_values(original.environment)
			== original.environment_values
		)
		and StadiumSurfaceNightPreview._metadata(original.environment) == original.environment_meta
		and host.get_children() == original.order
		and metadata_ok
		and lab._camera_director.tracking_visibility == original.tracking
		and _setup._visibility(original.tracking) == original.visibility
		and lab._ball_play_resolver.segment_observer == original.observer
		and lab._primary_fielder.stadium_boundary_clip == original.clip
		and lab._primary_fielder.stadium_obstacles == original.obstacles
		and StadiumSurfaceNightPreview._shadows(_viewport) == original.shadows
		and not _viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
	)


func _write_b_evidence() -> void:
	var evidence: Dictionary = {
		"version": 2,
		"scope": "owned-surface-time-profiles-b-reuse",
		"planned_checks": 63,
		"checks_before_evidence": _checks,
		"failures_before_evidence": _failures,
		"synthetic_funding": true,
		"synthetic_home_cursor": true,
		"actual_game_qualified": false,
		"actual_sale_qualified": false,
		"actual_extra_innings_qualified": false,
		"applied_progress_sequence_qualified": false,
		"public_ready": false,
		"dimensions": [SIZE.x, SIZE.y],
		"view": "right-batting",
		"point_kind": "plate_sand",
		"path_authority": "diagnostic_interpolation",
		"candidate": _candidate,
		"checkpoint_sha256": _checkpoint_hashes,
		"pairs": _rows,
		"captures": _captures,
		"pngs": _pngs,
		"stars": _stars,
		"restoration": _restoration,
		"shared_viewport_unchanged":
		StadiumSurfaceNightPreview._shadows(get_viewport()) == _shared_before
	}
	var payload: String = _bytes(evidence)
	_check(
		payload.to_utf8_buffer().size() <= B_MAX_BYTES,
		"three paired operands and four captures fit bounded1MiB JSON"
	)
	if payload.to_utf8_buffer().size() > B_MAX_BYTES:
		return
	var file: FileAccess = FileAccess.open(_capture_dir.path_join(B_JSON), FileAccess.WRITE)
	_check(file != null, "bounded B evidence file opens")
	if file != null:
		file.store_string(payload)
		file.flush()
		_check(file.get_error() == OK, "bounded B evidence writes completely")
		file.close()


func _restore_batter() -> bool:
	if _hand_original == null:
		return true
	if (
		not is_instance_valid(_hand_lab)
		or _hand_lab._match_state != _hand_state
		or _hand_state.batter() != _hand_player
		or _hand_player.definition != _hand_working
	):
		return false
	_hand_player.definition = _hand_original
	_hand_player.batting_hand_override = _hand_override
	PitchBatLabPresentation.sync_players(_hand_lab)
	_hand_lab._camera_director.set_batter_handedness(_hand_player.bats_left())
	_hand_original = null
	_hand_working = null
	return true


func _cleanup_b() -> void:
	_restore_batter()
	if is_instance_valid(_app) and is_instance_valid(_app.lab):
		_app._close_match()
	if is_instance_valid(_viewport):
		await RenderingServer.frame_post_draw
		_viewport.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if is_instance_valid(_setup):
		_setup.free()
