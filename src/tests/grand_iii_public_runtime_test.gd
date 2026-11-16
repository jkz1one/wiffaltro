extends Node3D
## Source-prepared native suite. Eight bound installs; no completed games or night pass.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FIXTURE = preload("res://src/tests/grand_iii_public_fixture.gd")
const CASES: Array[String] = [
	"lifecycle-away",
	"lifecycle-home",
	"energy",
	"unleased-light",
	"atlas",
	"lens-resource",
	"lease-alias",
	"missing-meta"
]
var _active_case: String = ""
var _case_started_ms: int = 0
var _case_before: Array[int] = []
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var selected_cases: Array[String] = _selected_cases()
	if selected_cases.is_empty():
		_finish(0)
		return
	_check(R.source_qualified(), "exact current sources pinned")
	_check(FIXTURE.ready(), "explicit Grand fixture record available")
	var original: SeasonState = FIXTURE.season()
	var season: SeasonState = (
		SeasonSave._decode(
			JSON.parse_string(JSON.stringify(SeasonSave.snapshot(original), "", true, true))
		)
		if original != null
		else null
	)
	_check(season != null, "full precision save65 rehydrates actual pre-draft fixed record")
	if selected_cases == ["time-profiles"]:
		if season != null:
			await _time_profiles(original, season)
		await TestAudioDrain.finish(get_tree())
		_finish(3)
		return
	if season != null:
		for label: String in selected_cases:
			_begin_case(label)
			if label == "lifecycle-away" or label == "lifecycle-home":
				await _lifecycle(season, label == "lifecycle-home")
			else:
				await _interruption(season, label)
			_case_marker("completed")
	await TestAudioDrain.finish(get_tree())
	_finish(selected_cases.size())


func _selected_cases() -> Array[String]:
	var selected: Array[String] = CASES.duplicate()
	var found: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--grand-iii-runtime-case"):
			continue
		var label: String = argument.trim_prefix("--grand-iii-runtime-case=")
		if found or (not CASES.has(label) and label != "time-profiles"):
			_check(false, "exact single --grand-iii-runtime-case= selector required")
			return []
		found = true
		selected.assign([label])
	return selected


func _begin_case(label: String) -> void:
	_active_case = label
	_case_started_ms = Time.get_ticks_msec()
	_case_before = [_checks, _failures, _installs, _cases]
	_case_marker("begin")


func _case_marker(phase: String) -> void:
	print(
		(
			(
				"GRAND_III_PUBLIC_RUNTIME_CASE case=%s phase=%s elapsed_ms=%d "
				+ "checks=%d failures=%d installs=%d cases=%d"
			)
			% [
				_active_case,
				phase,
				Time.get_ticks_msec() - _case_started_ms,
				_checks - _case_before[0],
				_failures - _case_before[1],
				_installs - _case_before[2],
				_cases - _case_before[3]
			]
		)
	)


func _phase(label: String) -> void:
	print(
		(
			"GRAND_III_PUBLIC_RUNTIME_PHASE case=%s phase=%s elapsed_ms=%d"
			% [_active_case, label, Time.get_ticks_msec() - _case_started_ms]
		)
	)


func _finish(expected: int) -> void:
	print("GRAND_III_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print(
		(
			(
				"GRAND_III_PUBLIC_RUNTIME_COVERAGE installs=%d cases=%d "
				+ "completed_games=0 night_qualified=false"
			)
			% [_installs, _cases]
		)
	)
	get_tree().quit(0 if _failures == 0 and _installs == expected and _cases == expected else 1)


func _lab(season: SeasonState, player_home: bool = false) -> PitchBatLab:
	_phase("start")
	var fixture: Dictionary = FIXTURE.fixture(season, player_home)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	lab._player_home = player_home
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	if not lab.yard_bound_startup_failed:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._at_bat_cadence.stop()
	var property: StadiumNpcPublicProperty = R._property(lab)
	var positive: bool = (
		not lab.yard_bound_startup_failed
		and property != null
		and property.issued
		and property.ordinary_callbacks()
		and property.callback_intact()
		and StadiumPropertyRuntime.npc_installed_bound(lab, lab._match_state.stadium)
	)
	_check(positive, "Grand snapshot23 enters common issued wrapper for both neutral player roles")
	if not positive:
		lab.free()
		return null
	_installs += 1
	_phase("installed")
	return lab


func _lifecycle(season: SeasonState, home: bool) -> void:
	var lab: PitchBatLab = _lab(season, home)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var lease: Dictionary = property.environment_lease
	_check(
		(
			property.venue_id == "GRAND-III"
			and property.tier == "mogul"
			and property.objects.size() == 107
			and property.field.id == &"field.npc_venue"
			and typeof(property.field.id) == TYPE_STRING_NAME
			and lab._stadium_ledger == null
		),
		"107 original copies and typed NPC field without human ownership"
	)
	_check(
		(
			lab._match_state.stadium.version == 23
			and lab._match_state.stadium.environment.version == 5
			and lab._match_state.stadium.environment.time == "19:10"
			and lab._match_state.stadium.environment.weather == "clear"
			and lab._match_state.stadium.manifest.environment_certificates.is_empty()
		),
		"versioned clear artistic night slot carries no historical qualification"
	)
	_check(
		(
			property.boundary.graph.identity() == "PROTOTYPE-CLUB-DUGOUT-STRAIGHT-v1"
			and property.presentation_director.get_script() == StadiumGrandIIIPublicCamera
			and property.presentation_director.tracking_visibility._groups.size() == 50
		),
		"exact straight boundary and fifty exact structure visibility groups"
	)
	_check(
		(
			StadiumGrandIIIEnvironmentV1.installed(lab, lease)
			and StadiumGrandIIILightingV1.apply(lab, property).is_empty()
		),
		"leased profile is exact and duplicate activation refuses"
	)
	var lighting: Dictionary = lease.active_lighting
	_check(
		(
			not StadiumGrandIEnvironmentV1.installed(lab, lease)
			and not StadiumGrandIEnvironmentV1.restore(lab, lease)
			and not StadiumGrandILightingV1.installed(lab, lighting)
			and not StadiumGrandILightingV1.restore(lab, lighting)
			and not StadiumGrandIIEnvironmentV1.installed(lab, lease)
			and not StadiumGrandIIEnvironmentV1.restore(lab, lease)
			and not StadiumGrandIILightingV1.installed(lab, lighting)
			and not StadiumGrandIILightingV1.restore(lab, lighting)
			and StadiumGrandIIIEnvironmentV1.installed(lab, lease)
		),
		"I and II environment/light entry points reject the III lease without mutation"
	)
	_check(
		(
			lab.find_children("*", "Light3D", true, false).size() == 5
			and lighting.root.get_child_count() == 36
			and lighting.heads.size() == 32
		),
		"four premium spots plus one existing sun preserve all thirty-two visible heads"
	)
	var shadows: int = 0
	for index in range(4):
		var light: SpotLight3D = lighting.lights[index].node
		var emitter: Dictionary = StadiumGrandIIILightingV1.contract().emitters[index]
		var tower: Node3D = property.objects["npc:GRAND-III:r1:" + emitter.site]
		var head_index: int = int(emitter.head.trim_prefix("HEAD-")) - 1
		var head: Node3D = tower.get_node("Visual/Head%d" % head_index)
		_check(
			(
				light.global_position.is_equal_approx(
					head.global_position + head.global_basis.z.normalized() * 0.154
				)
				and (-light.global_basis.z).is_equal_approx(head.global_basis.z.normalized())
			),
			"emission origin sits on lens face and -Z follows authored +Z head ray " + emitter.site
		)
		_check(
			(
				light.spot_range == 90.0
				and light.spot_angle == 68.0
				and is_equal_approx(light.light_energy, 4.5)
				and light.shadow_enabled == (emitter.site in StadiumGrandIIILightingV1.SHADOW_SITES)
			),
			"bounded power, cone and per-tower shadow policy " + emitter.site
		)
		shadows += int(light.shadow_enabled)
	_check(
		shadows == 4 and not lease.sun.shadow_enabled,
		"four positional casters and no competing dusk directional shadow"
	)
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects[row.instance]
		_check(
			ClubCareer.same(
				StadiumGrandIIIPublicConstruction.components(model.transform),
				Array(PackedFloat32Array(row.transform))
			),
			"authored unchanged copy pose " + row.site
		)
	_phase("cold-audit-start")
	_check(
		R.installed(lab) and property.callback_intact(), "cold full audit agrees with issued path"
	)
	_phase("cold-audit-completed")
	_check(
		(
			ClubCareer.same(saved, SeasonSave.snapshot(season))
			and lab._throw_number == 0
			and lab._play_records.is_empty()
			and PhysicalMatchReport.capture(lab).is_empty()
		),
		"lighting probe earns no game or settlement"
	)
	await _teardown(lab, property)
	_cases += 1


func _interruption(season: SeasonState, mutation: String) -> void:
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var lease: Dictionary = property.environment_lease.active_lighting
	var injected: SpotLight3D
	match mutation:
		"energy":
			lease.lights[0].node.light_energy = 0.75
		"unleased-light":
			injected = SpotLight3D.new()
			lab.add_child(injected)
		"atlas":
			lease.viewport.positional_shadow_atlas_size = 4096
		"lens-resource":
			lease.heads[0].lens_material.albedo_color = Color.RED
		"lease-alias":
			property.environment_lease.active_lighting = lease.duplicate(false)
		"missing-meta":
			var tower: Node3D = property.objects["npc:GRAND-III:r1:PLIGHT-HL"]
			tower.remove_meta("npc_head_rays")
	_check(
		(
			not property.callback_intact()
			and property.suspended
			and not property.issued
			and lab.process_mode == Node.PROCESS_MODE_DISABLED
		),
		"light/head/atlas edit retires issued authority: " + mutation
	)
	if injected != null:
		injected.free()
	_phase("cold-audit-start")
	_check(
		not R.installed(lab) and not R.install_bound(lab),
		"interrupted night trial cannot resume silently: " + mutation
	)
	_phase("cold-audit-completed")
	await _teardown(lab, property)
	_cases += 1


func _teardown(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_phase("teardown-start")
	# Preserve shallow preimages before teardown clears the issued environment lease.
	var environment: Dictionary = property.environment_lease.duplicate(false)
	var lighting: Dictionary = environment.active_lighting.duplicate(false)
	var before: Dictionary = lighting.before.duplicate(true)
	var viewport: Viewport = lighting.viewport
	var old_camera: MatchCameraDirector = property.old_camera
	var old_field: FieldDefinition = property.old_field
	lab._at_bat_cadence.stop()
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	_check(R.teardown(lab), "shared teardown accepts issued or retired owner")
	await get_tree().process_frame
	_check(
		(
			lab._world_environment.environment == environment.before_environment
			and environment.sun.rotation == environment.before_rotation
			and environment.sun.light_color == environment.before_color
			and environment.sun.light_energy == environment.before_energy
			and environment.sun.shadow_enabled == environment.before_shadows
		),
		"exact prior environment/sun resources and values restored"
	)
	_check(
		(
			viewport.positional_shadow_atlas_size == before.size
			and viewport.positional_shadow_atlas_16_bits == before.precision
		),
		"viewport shadow allocation and precision restored"
	)
	for index in range(4):
		_check(
			viewport.get_positional_shadow_atlas_quadrant_subdiv(index) == before.quadrants[index],
			"original shadow quadrant restored %d" % index
		)
	_check(
		(
			lab.find_children("*", "SpotLight3D", true, false).is_empty()
			and lab._camera_director == old_camera
			and lab._field_definition == old_field
			and lab.has_meta("stadium_npc_runtime_interrupted")
			and not lab.has_meta("stadium_snapshot")
		),
		"temporary lights removed and exact origin restored"
	)
	lab.free()
	await get_tree().process_frame
	_phase("teardown-completed")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GRAND_III_PUBLIC_RUNTIME: " + label)


# Three explicit qualification installs; tuples and final participants are synthetic.
# Save65 codec checks occur before the bounded in-memory final fixture is assigned.
func _time_profiles(original: SeasonState, legacy: SeasonState) -> void:
	_begin_case("time-profiles")
	var old_data: Dictionary = SeasonSave.snapshot(original)
	var old_bytes: String = JSON.stringify(old_data, "", true, true)
	var old_record: Dictionary = SeasonFinalVenue.normalized(legacy.final_venue)
	_check(
		(
			ClubCareer.same(SeasonSave.snapshot(legacy), old_data)
			and old_data.version == 65
			and old_record.environment.version == 5
			and old_record.environment.profile == "GRAND-III-1910-CLEAR-v1"
			and ClubCareer.same(
				old_record.environment,
				StadiumGrandIIIEnvironmentV1.capture(old_record.environment.seed)
			)
		),
		"legacy save65 retains exact environment5 warm record"
	)
	for mode: String in ["day", "sunset", "night"]:
		var season: SeasonState = FIXTURE.season_time(mode)
		var saved: Dictionary = SeasonSave.snapshot(season) if season != null else {}
		var cold: SeasonState = SeasonSave._decode(
			JSON.parse_string(JSON.stringify(saved, "", true, true))
		)
		_check(
			(
				season != null
				and cold != null
				and saved.get("version") == 65
				and ClubCareer.same(SeasonSave.snapshot(cold), saved)
				and season.round_index == 0
				and season.player_results.is_empty()
				and season.final_fixture.is_empty()
			),
			"new %s explicit environment8 has valid unchanged-round0 save65 codec" % mode
		)
		if season == null or cold == null:
			return
		var record: Dictionary = SeasonFinalVenue.normalized(cold.final_venue)
		var fixture: Dictionary = FIXTURE.fixture(cold)
		var snapshot: Dictionary = SeasonFinalVenue.for_fixture(cold, fixture)
		_check(
			(
				not snapshot.is_empty()
				and snapshot.version == 23
				and record.environment.version == 8
				and record.environment.mode == mode
				and (
					record.environment.start_minute
					== StadiumSurfaceNightSnapshot.start_minute(mode)
				)
				and snapshot.binding.assignment_key == SeasonFinalVenue.key(record)
				and ClubCareer.same(snapshot.environment, record.environment)
				and (
					StadiumNpcSnapshot.key(snapshot)
					!= StadiumNpcSnapshot.key(
						SeasonFinalVenue.for_fixture(legacy, FIXTURE.fixture(legacy))
					)
				)
				and (
					StadiumFixtureEnvironment.label(cold, fixture)
					== "%s • %s • Gardens" % [mode.capitalize(), record.environment.time]
				)
			),
			"new %s final4 and fixture23 bind the separate time profile and truthful label" % mode
		)
		var wrong_start: Dictionary = saved.duplicate(true)
		wrong_start.final_venue.environment.start_minute += 1
		var wrong_rule: Dictionary = saved.duplicate(true)
		wrong_rule.final_venue.environment.rule = "foreign-rule"
		var wrong_version: Dictionary = saved.duplicate(true)
		wrong_version.final_venue.environment.version = 5
		var wrong_key: Dictionary = snapshot.duplicate(true)
		wrong_key.binding.assignment_key = SeasonFinalVenue.key(old_record)
		_check(
			(
				SeasonSave._decode(wrong_start) == null
				and SeasonSave._decode(wrong_rule) == null
				and SeasonSave._decode(wrong_version) == null
				and not StadiumNpcSnapshot.valid(wrong_key)
			),
			"new %s rejects wrong start rule old environment version and assignment key" % mode
		)
		var source: String = JSON.stringify(SeasonSave.snapshot(cold), "", true, true)
		var lab: PitchBatLab = _lab(cold)
		if lab == null:
			return
		var property: StadiumNpcPublicProperty = R._property(lab)
		var lease: Dictionary = property.environment_lease
		var state: Dictionary = StadiumGrandIIIEnvironmentV1._state(lab, lease)
		var lamp_ok: bool = (
			lease.active_lighting.lights.size() == 4 and lease.active_lighting.heads.size() == 32
		)
		for light: Dictionary in lease.active_lighting.lights:
			lamp_ok = (
				lamp_ok
				and light.node.light_energy >= 0.0
				and light.node.light_energy <= PackedFloat32Array([4.5])[0]
				and (
					light.node.light_energy > 0.0
					if mode == "night"
					else light.node.light_energy == 0.0
				)
			)
		_check(
			(
				state.get("time_profile", false)
				and state.mode == mode
				and state.progress == 0.0
				and state.plays == 0
				and state.halves == 0
				and lamp_ok
				and lease.applied_environment.sky == lease.applied_sky
				and lease.applied_sky.sky_material == lease.applied_material
				and property.objects.size() == 107
				and lab._stadium_ledger == null
			),
			"new %s installs three-profile resources and only four issued premium towers" % mode
		)
		var before: Dictionary = _time_values(lab, lease)
		_check(
			R.admits_action(lab) and R.admits_action(lab) and _time_values(lab, lease) == before,
			"new %s same safe tuple has no repeated update" % mode
		)
		lab._play_records.append(PlayRecord.new())
		lab._match_state.top_half = false
		var advanced: bool = R.admits_action(lab)
		var progress: float = state.progress
		var advanced_lamps: bool = true
		for light: Dictionary in lease.active_lighting.lights:
			advanced_lamps = (
				advanced_lamps
				and (
					light.node.light_energy == 0.0
					if mode == "day"
					else light.node.light_energy > 0.0
				)
			)
		_check(
			(
				advanced
				and advanced_lamps
				and state.plays == 1
				and state.halves == 1
				and progress > 0.0
				and progress <= 0.002
				and property.callback_intact()
				and StadiumGrandIIIEnvironmentV1.installed(lab, lease)
			),
			"new %s advances one capped synthetic safe tuple" % mode
		)
		before = _time_values(lab, lease)
		lab._play_records.append(PlayRecord.new())
		lab._match_state.phase = MatchState.Phase.PITCH_IN_FLIGHT
		lab._pitch_actor.running = true
		var pitch_unchanged: bool = R.admits_action(lab) and _time_values(lab, lease) == before
		lab._pitch_actor.running = false
		lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
		var body: BattedBallBody = BattedBallBody.new()
		lab._batted_ball = body
		var body_unchanged: bool = R.admits_action(lab) and _time_values(lab, lease) == before
		lab._batted_ball = null
		body.free()
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		_check(
			pitch_unchanged and body_unchanged,
			"new %s defers palette changes through pitch and live body" % mode
		)
		var caught_up: bool = R.admits_action(lab)
		before = _time_values(lab, lease)
		var extra: Dictionary = StadiumSurfaceNightSnapshot.clock(mode, 200, 14)
		_check(
			(
				caught_up
				and state.plays == 2
				and state.progress >= progress
				and state.progress <= progress + 0.002
				and R.admits_action(lab)
				and _time_values(lab, lease) == before
				and extra.elapsed_seconds == 4680
				and StadiumSurfaceNightSnapshot.drift(mode, extra) >= state.progress
			),
			"new %s catches up once and keeps pure extra target separate" % mode
		)
		_check(
			(
				JSON.stringify(SeasonSave.snapshot(cold), "", true, true) == source
				and lab._throw_number == 0
				and PhysicalMatchReport.capture(lab).is_empty()
				and cold.player_results.is_empty()
				and cold.physical.reports.is_empty()
			),
			"new %s probes preserve source and create no physical result" % mode
		)
		if mode == "day":
			await _teardown(lab, property)
		elif mode == "sunset":
			await _time_atlas_refusal(lab, property)
		else:
			await _time_resource_refusal(lab, property)
		_cases += 1
	_check(
		(
			SeasonFinalVenue.capture_standard_d4_time(original, "night").is_empty()
			and SeasonFinalVenue.capture_grand_iii_time(6, 1, "foreign").is_empty()
		),
		"new constructor never grants D4 eligibility or accepts an unsupported profile"
	)
	_check(
		(
			JSON.stringify(SeasonSave.snapshot(original), "", true, true) == old_bytes
			and original.round_index == 0
			and original.player_results.is_empty()
			and original.physical.pending.is_empty()
			and original.physical.reports.is_empty()
			and _installs == 3
			and _cases == 3
		),
		"three explicit installations leave original valid round0 history unchanged"
	)
	_case_marker("completed")


func _time_values(lab: PitchBatLab, lease: Dictionary) -> Dictionary:
	var state: Dictionary = StadiumGrandIIIEnvironmentV1._state(lab, lease)
	var values: Dictionary = {
		"plays": state.plays,
		"halves": state.halves,
		"progress": state.progress,
		"ambient": lease.applied_environment.ambient_light_color,
		"energy": lease.applied_environment.ambient_light_energy,
		"sun_color": lease.sun.light_color,
		"sun_energy": lease.sun.light_energy,
		"shader": [],
		"lamps": []
	}
	for key: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		values.shader.append(lease.applied_material.get_shader_parameter(key))
	for light: Dictionary in lease.active_lighting.lights:
		values.lamps.append(light.node.light_energy)
	return values


func _time_atlas_refusal(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var lease: Dictionary = property.environment_lease
	var lights: Dictionary = lease.active_lighting
	var root: Node3D = lights.root
	var viewport: Viewport = lights.viewport
	var original: Dictionary = lights.before.duplicate(true)
	var reached: Array[bool] = [false]
	var same_owner: Array[bool] = [false]
	var state: MatchState = lab._match_state
	root.tree_exiting.connect(
		func() -> void:
			reached[0] = true
			same_owner[0] = (
				is_instance_valid(lab)
				and R._property(lab) == property
				and lab._match_state == state
			)
			viewport.positional_shadow_atlas_size = 4096
			viewport.positional_shadow_atlas_16_bits = true
			for index in range(4):
				viewport.set_positional_shadow_atlas_quadrant_subdiv(
					index, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
				),
		CONNECT_ONE_SHOT
	)
	var before: Dictionary = _time_values(lab, lease)
	_check(
		not StadiumGrandIIIEnvironmentV1.restore(lab, lease) and reached[0] and same_owner[0],
		"actual light-root removal callback changes atlas under the same lab/property and refuses restore"
	)
	_check(
		not is_instance_valid(root) or root.get_parent() != property,
		"refused cleanup does not reattach the removed issued root"
	)
	_check(
		(
			lab._world_environment.environment == lease.applied_environment
			and lease.sun.light_color == before.sun_color
			and lease.sun.light_energy == before.sun_energy
		),
		"refused atlas callback prevents subsequent environment and sun restore writes"
	)
	_check(
		viewport.positional_shadow_atlas_size == 4096 and viewport.positional_shadow_atlas_16_bits,
		"callback replacement atlas allocation and precision remain untouched"
	)
	for index in range(4):
		_check(
			(
				viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
				== Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
			),
			"callback replacement quadrant remains untouched %d" % index
		)
	_check(R.teardown(lab), "generic teardown can remove the abandoned same-owner wrapper")
	# Test-owned cleanup only, after recording all actual refusal observations.
	if is_instance_valid(root) and root.get_parent() == null:
		root.free()
	lab.free()
	await get_tree().process_frame
	_time_restore_atlas(viewport, original)


func _time_resource_refusal(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var lease: Dictionary = property.environment_lease
	var viewport: Viewport = lease.active_lighting.viewport
	var original: Dictionary = lease.active_lighting.before.duplicate(true)
	var light_root: Node3D = lease.active_lighting.root
	var sky: Sky = lease.applied_sky
	var replacement: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_material = replacement
	var values: Array = [
		replacement.sky_top_color, replacement.sky_horizon_color, replacement.sky_energy_multiplier
	]
	_check(
		(
			not R.admits_action(lab)
			and property.suspended
			and not property.issued
			and sky.sky_material == replacement
		),
		"replaced material abandons authority without adopting the replacement"
	)
	var refused: bool = not StadiumGrandIIIEnvironmentV1.restore(lab, lease)
	var lights_clean: bool = (
		not is_instance_valid(light_root)
		and viewport.positional_shadow_atlas_size == original.size
		and viewport.positional_shadow_atlas_16_bits == original.precision
	)
	for index in range(4):
		lights_clean = (
			lights_clean
			and (
				viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
				== original.quadrants[index]
			)
		)
	_check(
		(
			refused
			and lights_clean
			and sky.sky_material == replacement
			and (
				values
				== [
					replacement.sky_top_color,
					replacement.sky_horizon_color,
					replacement.sky_energy_multiplier
				]
			)
		),
		"foreign material remains untouched while exact still-owned lights and atlas clean independently"
	)
	_check(
		(
			R.teardown(lab)
			and sky.sky_material == replacement
			and (
				values
				== [
					replacement.sky_top_color,
					replacement.sky_horizon_color,
					replacement.sky_energy_multiplier
				]
			)
		),
		"generic teardown preserves the replacement rather than claiming full owned restore"
	)
	lab.free()
	await get_tree().process_frame
	# An abandoned lease is not evidence of native atlas restoration.
	_time_restore_atlas(viewport, original)


func _time_restore_atlas(viewport: Viewport, before: Dictionary) -> void:
	viewport.positional_shadow_atlas_size = before.size
	viewport.positional_shadow_atlas_16_bits = before.precision
	for index in range(4):
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index, before.quadrants[index])
