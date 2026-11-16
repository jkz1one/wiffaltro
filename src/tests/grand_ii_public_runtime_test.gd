extends Node3D
## Source-prepared native suite. Six genuine bound installs; no completed games or night pass.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FIXTURE = preload("res://src/tests/grand_ii_public_fixture.gd")
const CASES: Array[String] = ["lifecycle-away", "lifecycle-home", "energy",
	"unleased-light", "atlas", "lens-resource"]
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
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(SeasonSave.snapshot(original), "", true, true))) if original != null else null
	_check(season != null, "full precision save64 rehydrates actual pre-draft fixed record")
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
		if not argument.begins_with("--grand-ii-runtime-case"):
			continue
		var label: String = argument.trim_prefix("--grand-ii-runtime-case=")
		if found or not CASES.has(label):
			_check(false, "exact single --grand-ii-runtime-case= selector required")
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
	print(("GRAND_II_PUBLIC_RUNTIME_CASE case=%s phase=%s elapsed_ms=%d "
		+ "checks=%d failures=%d installs=%d cases=%d") % [_active_case, phase,
		Time.get_ticks_msec() - _case_started_ms, _checks - _case_before[0],
		_failures - _case_before[1], _installs - _case_before[2], _cases - _case_before[3]])


func _phase(label: String) -> void:
	print("GRAND_II_PUBLIC_RUNTIME_PHASE case=%s phase=%s elapsed_ms=%d" %
		[_active_case, label, Time.get_ticks_msec() - _case_started_ms])


func _finish(expected: int) -> void:
	print("GRAND_II_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print(("GRAND_II_PUBLIC_RUNTIME_COVERAGE installs=%d cases=%d "
		+ "completed_games=0 night_qualified=false")
		% [_installs, _cases])
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
	var positive: bool = not lab.yard_bound_startup_failed and property != null \
		and property.issued and property.ordinary_callbacks() and property.callback_intact() \
		and StadiumPropertyRuntime.npc_installed_bound(lab, lab._match_state.stadium)
	_check(positive, "Grand snapshot22 enters common issued wrapper for both neutral player roles")
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
	_check(property.venue_id == "GRAND-II" and property.tier == "mogul"
		and property.objects.size() == 85 and property.field.id == &"field.npc_venue"
		and typeof(property.field.id) == TYPE_STRING_NAME and lab._stadium_ledger == null,
		"85 original copies and typed NPC field without human ownership")
	_check(lab._match_state.stadium.version == 22
		and lab._match_state.stadium.environment.version == 4
		and lab._match_state.stadium.environment.time == "19:10"
		and lab._match_state.stadium.environment.weather == "clear"
		and lab._match_state.stadium.manifest.environment_certificates.is_empty(),
		"versioned clear artistic night slot carries no historical qualification")
	_check(property.boundary.graph.identity() == "PROTOTYPE-CLUB-DUGOUT-STRAIGHT-v1"
		and property.presentation_director.get_script() == StadiumGrandIIPublicCamera
		and property.presentation_director.tracking_visibility._groups.size() == 28,
		"exact straight boundary and twenty-eight exact structure visibility groups")
	_check(StadiumGrandIIEnvironmentV1.installed(lab, lease)
		and StadiumGrandIILightingV1.apply(lab, property).is_empty(),
		"leased profile is exact and duplicate activation refuses")
	var lighting: Dictionary = lease.active_lighting
	_check(not StadiumGrandIEnvironmentV1.installed(lab, lease)
		and not StadiumGrandIEnvironmentV1.restore(lab, lease)
		and not StadiumGrandILightingV1.installed(lab, lighting)
		and not StadiumGrandILightingV1.restore(lab, lighting)
		and StadiumGrandIIEnvironmentV1.installed(lab, lease),
		"I environment/light entry points reject the II lease without mutation")
	_check(lab.find_children("*", "Light3D", true, false).size() == 7
		and lighting.root.get_child_count() == 30 and lighting.heads.size() == 24,
		"six spots plus one existing sun preserve all twenty-four visible heads")
	var shadows: int = 0
	for index in range(6):
		var light: SpotLight3D = lighting.lights[index].node
		var emitter: Dictionary = StadiumGrandIILightingV1.contract().emitters[index]
		var tower: Node3D = property.objects["npc:GRAND-II:r1:" + emitter.site]
		var head_index: int = 1 if emitter.site.ends_with("L") else 2
		var head: Node3D = tower.get_node("Visual/Head%d" % head_index)
		_check(light.global_position.is_equal_approx(head.global_position
			+ head.global_basis.z.normalized() * 0.139)
			and (-light.global_basis.z).is_equal_approx(head.global_basis.z.normalized()),
			"emission origin sits on lens face and -Z follows authored +Z head ray " + emitter.site)
		_check(light.spot_range == 80.0 and light.spot_angle == 68.0
			and is_equal_approx(light.light_energy, 3.0)
			and light.shadow_enabled == (emitter.site in StadiumGrandIILightingV1.SHADOW_SITES),
			"bounded power, cone and per-tower shadow policy " + emitter.site)
		shadows += int(light.shadow_enabled)
	_check(shadows == 4 and not lease.sun.shadow_enabled,
		"four positional casters and no competing dusk directional shadow")
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects[row.instance]
		_check(ClubCareer.same(StadiumGrandIIPublicConstruction.components(model.transform),
			Array(PackedFloat32Array(row.transform))), "authored unchanged copy pose " + row.site)
	_phase("cold-audit-start")
	_check(R.installed(lab) and property.callback_intact(), "cold full audit agrees with issued path")
	_phase("cold-audit-completed")
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season))
		and lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "lighting probe earns no game or settlement")
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
	_check(not property.callback_intact() and property.suspended and not property.issued
		and lab.process_mode == Node.PROCESS_MODE_DISABLED,
		"light/head/atlas edit retires issued authority: " + mutation)
	if injected != null:
		injected.free()
	_phase("cold-audit-start")
	_check(not R.installed(lab) and not R.install_bound(lab),
		"interrupted night trial cannot resume silently: " + mutation)
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
	_check(lab._world_environment.environment == environment.before_environment
		and environment.sun.rotation == environment.before_rotation
		and environment.sun.light_color == environment.before_color
		and environment.sun.light_energy == environment.before_energy
		and environment.sun.shadow_enabled == environment.before_shadows,
		"exact prior environment/sun resources and values restored")
	_check(viewport.positional_shadow_atlas_size == before.size
		and viewport.positional_shadow_atlas_16_bits == before.precision,
		"viewport shadow allocation and precision restored")
	for index in range(4):
		_check(viewport.get_positional_shadow_atlas_quadrant_subdiv(index) == before.quadrants[index],
			"original shadow quadrant restored %d" % index)
	_check(lab.find_children("*", "SpotLight3D", true, false).is_empty()
		and lab._camera_director == old_camera and lab._field_definition == old_field
		and lab.has_meta("stadium_npc_runtime_interrupted")
		and not lab.has_meta("stadium_snapshot"), "temporary lights removed and exact origin restored")
	lab.free()
	await get_tree().process_frame
	_phase("teardown-completed")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GRAND_II_PUBLIC_RUNTIME: " + label)
