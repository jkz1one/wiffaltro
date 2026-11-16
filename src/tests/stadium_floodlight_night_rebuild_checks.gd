class_name StadiumFloodlightNightRebuildChecks
extends RefCounted
## Bounded synthetic admission only. No completed games, earned history or Save73 qualification.
# gdlint: disable=max-returns,max-line-length,max-file-lines


class ForeignRelease:
	extends PitchReleaseController


class ForeignCadence:
	extends AtBatCadenceController


class ForeignHomeRun:
	extends PitchBatLabHomeRun
	var mutation: Callable

	func advance(_lab: PitchBatLab, _delta: float) -> void:
		if mutation.is_valid():
			mutation.call()


class ForeignSwingTracker:
	extends SwingContactTracker
	var mutation: Callable

	func sample_segment(_previous: Vector3, _elapsed: float, _pitch: PitchState) -> ContactResult:
		if mutation.is_valid():
			mutation.call()
		return null


const POLICY_CHECKS: Array[String] = ["capture", "cold", "fixture", "proof"]
const RUNTIME_CHECKS: Array[String] = [
	"season",
	"configure",
	"install",
	"members",
	"initial",
	"same_tuple",
	"advance",
	"live_frozen",
	"catch_up",
	"geometry_refusal",
	"material_refusal",
	"restored",
	"idempotent",
	"source_unchanged"
]

const START_CHECKS: Array[String] = ["admission", "initial", "advance", "same_tuple", "restore"]
const CALLBACK_CHECKS: Array[String] = [
	"same_generation_visibility_callback",
	"field_anchor_visibility_callback",
	"raw_snapshot_visibility_callback",
	"raw_policy_visibility_callback",
	"ordinary_career_admission",
	"ordinary_pennant_tree_callback"
]
const ANCHOR_FIELDS: Array[StringName] = [
	&"shallow_anchor_z_m",
	&"middle_anchor_z_m",
	&"middle_center_anchor_z_m",
	&"deep_anchor_z_m",
	&"side_anchor_x_m"
]


static func expected_checks(config: Dictionary) -> int:
	return (
		3 * POLICY_CHECKS.size()
		+ RUNTIME_CHECKS.size()
		+ 3
		+ (
			(2 * START_CHECKS.size() + CALLBACK_CHECKS.size())
			if config.get("label") == "club-sparse"
			else 0
		)
		+ (2 if config.get("label") == "club-two-lower-canopies" else 0)
	)


static func run(
	parent: Node3D, check: Callable, paid: ClubAssetLedger, config: Dictionary, capture: Callable
) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var timings: Dictionary = {
		"policies": 0, "install": 0, "clock": 0, "capture": 0, "probes": 0, "restore": 0, "total": 0
	}
	var result: Dictionary = {
		"label": config.label,
		"profile": config.profile,
		"synthetic_admission": true,
		"actual_games": 0,
		"earned_history": false,
		"policies": [],
		"runtime": {},
		"timings_ms": timings
	}
	var source: String = JSON.stringify(paid.to_data(), "", true, true)
	var season: SeasonState = SeasonState.create(101, true)
	for index in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			check.call(false, config.label + " night season")
			return result
	season._pool_replay_ledger = paid
	season._npc_replay_run = 0
	season.home_property = config.snapshot.duplicate(true)
	var scheduled: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.home == 0 and (scheduled.is_empty() or row.round < scheduled.round):
			scheduled = row.duplicate(true)
	var setup: bool = (
		not scheduled.is_empty() and StadiumLayoutSnapshot.matches(season.home_property, paid)
	)
	check.call(setup, config.label + " night season")
	if not setup:
		return result
	# Existing schedule, disposable cursor only. No results or settlement are fabricated.
	season.round_index = int(scheduled.round)
	for profile: String in ["day", "sunset", "night"]:
		var policy: Dictionary = StadiumSurfaceNightSnapshot.capture_time_policy(
			season, paid, profile
		)
		var admitted: bool = (
			not policy.is_empty()
			and policy.candidate.candidate_version == 2
			and StadiumSurfaceNightSnapshot.valid_policy(policy, season, paid)
		)
		check.call(admitted, config.label + " " + profile + " policy capture")
		if not admitted:
			return result
		var cold: Variant = JSON.parse_string(JSON.stringify(policy, "", true, true))
		var cold_exact: bool = (
			cold is Dictionary
			and StadiumSurfaceNightSnapshot.valid_policy(cold, season, paid)
			and ClubCareer.same(StadiumSurfaceNightSnapshot.normalized_policy(cold), policy)
		)
		check.call(cold_exact, config.label + " " + profile + " policy cold")
		season.owned_surface_night = StadiumSurfaceNightSnapshot.normalized_policy(cold)
		var fixture: Dictionary = StadiumSurfaceNightSnapshot.fixture(season, scheduled)
		var fixture_ok: bool = (
			not fixture.is_empty()
			and fixture.version == 27
			and fixture.environment.mode == profile
			and (
				fixture.environment.start_minute
				== StadiumSurfaceNightSnapshot.start_minute(profile)
			)
			and StadiumSurfaceNightSnapshot.matches_fixture(fixture, season, scheduled, paid)
		)
		check.call(fixture_ok, config.label + " " + profile + " fixture27")
		var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(fixture, policy, paid)
		check.call(
			not proof.is_empty() and StadiumSurfaceNightSnapshot.proof_valid(proof, fixture),
			config.label + " " + profile + " proof"
		)
		result.policies.append(
			{
				"mode": profile,
				"cold_exact": cold_exact,
				"fixture": fixture_ok,
				"candidate": 2,
				"start_minute": StadiumSurfaceNightSnapshot.start_minute(profile)
			}
		)
	timings.policies = Time.get_ticks_msec() - started_ms
	if config.label == "club-sparse":
		result["starts"] = []
		for mode: String in ["day", "sunset"]:
			result.starts.append(
				await _start_profile(parent, check, paid, season, config.label, mode)
			)
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(
		season, paid, "night"
	)
	var stage_ms: int = Time.get_ticks_msec()
	var context: Dictionary = _open_runtime(parent, paid, season)
	timings.install = Time.get_ticks_msec() - stage_ms
	var runner: PhysicalMatchRunner = context.runner
	var lab: PitchBatLab = context.lab
	var viewport: SubViewport = context.viewport
	var state: MatchState = context.state
	check.call(context.configured, config.label + " runtime configure")
	check.call(context.installed, config.label + " runtime install")
	if not context.installed:
		result.runtime = _failure_context(context)
		_close_runtime(context)
		timings.total = Time.get_ticks_msec() - started_ms
		return result
	stage_ms = Time.get_ticks_msec()
	var owner: StadiumSurfaceNightRuntime = context.owner
	result["guard_timing_stages"] = {"install": owner._guard_timings.duplicate(true)}
	var installed: bool = context.installed
	var tower_count: int = int(StadiumFloodlightOwnedItems.PROFILES[config.profile].count)
	var members: bool = (
		owner._floodlight_profile == config.profile
		and owner._towers.size() == tower_count
		and owner._emitters.size() == tower_count
		and owner._lamps.size() == tower_count * (8 if config.profile == "MOGUL4-PREMIUM" else 4)
		and owner._boundary is StadiumBoundaryOwnedRuntime
		and owner._owned_property_intact()
	)
	var active_clock: Array = _clock_values(owner)
	var active_allowed: bool = true
	var active_started_us: int = Time.get_ticks_usec()
	for index in range(3):
		var allowed: bool = StadiumSurfaceNightRuntime.action_allowed(lab)
		active_allowed = active_allowed and allowed
	var active_elapsed_us: int = Time.get_ticks_usec() - active_started_us
	var active_unchanged: bool = _clock_values(owner) == active_clock
	result["active_guard_sample"] = {
		"calls": 3,
		"elapsed_us": active_elapsed_us,
		"all_allowed": active_allowed,
		"clock_unchanged": active_unchanged
	}
	var active_components: Dictionary = {}
	var components_intact: bool = true
	var component_probes: Array[Dictionary] = [
		{"name": "boundary", "probe": (owner._boundary as StadiumBoundaryOwnedRuntime).intact},
		{"name": "props", "probe": owner._property.props_intact},
		{"name": "owned_property", "probe": owner._owned_property_intact},
		{"name": "operands", "probe": owner._operands}
	]
	for component: Dictionary in component_probes:
		var all_intact: bool = true
		var component_started_us: int = Time.get_ticks_usec()
		for index in range(3):
			var intact: bool = component.probe.call()
			all_intact = all_intact and intact
		active_components[component.name] = {
			"calls": 3,
			"elapsed_us": Time.get_ticks_usec() - component_started_us,
			"all_intact": all_intact
		}
		components_intact = components_intact and all_intact
	var components_unchanged: bool = _clock_values(owner) == active_clock
	result["active_components"] = active_components
	result["active_components_clock_unchanged"] = components_unchanged
	result["active_geometry_inventory"] = _geometry_inventory(owner)
	check.call(
		(
			members
			and active_allowed
			and active_unchanged
			and components_intact
			and components_unchanged
		),
		config.label + " exact current tower members"
	)
	if config.label == "club-two-lower-canopies":
		result["source_material_alias"] = _companion_material_alias(owner, check, config.label)
	var initial: bool = _lights(owner, 1.0) and owner._clock_plays == 0 and owner._clock_halves == 0
	check.call(initial, config.label + " initial night lamps")
	var initial_values: Array = _clock_values(owner)
	check.call(
		(
			StadiumSurfaceNightRuntime.boundary_allowed(lab)
			and StadiumSurfaceNightRuntime.boundary_allowed(lab)
			and _clock_values(owner) == initial_values
		),
		config.label + " repeated tuple no drift"
	)
	lab._play_records.append(PlayRecord.new())
	state.top_half = false
	var advanced: bool = StadiumSurfaceNightRuntime.boundary_allowed(lab)
	var progress: float = owner._profile_progress
	check.call(
		(
			advanced
			and owner._clock_plays == 1
			and owner._clock_halves == 1
			and progress > 0.0
			and progress <= 0.002
			and _lights(owner, 1.0)
		),
		config.label + " shared completed-play half clock"
	)
	var held: Array = _clock_values(owner)
	lab._play_records.append(PlayRecord.new())
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	lab._pitch_actor.running = true
	var frozen: bool = (
		StadiumSurfaceNightRuntime.boundary_allowed(lab) and _clock_values(owner) == held
	)
	lab._pitch_actor.running = false
	state.phase = MatchState.Phase.PRE_PITCH
	check.call(frozen, config.label + " live pitch presentation frozen")
	var caught: bool = StadiumSurfaceNightRuntime.boundary_allowed(lab)
	check.call(
		(
			caught
			and owner._clock_plays == 2
			and owner._profile_progress >= progress
			and owner._profile_progress <= progress + 0.002
		),
		config.label + " next safe tuple catches up"
	)
	timings.clock = Time.get_ticks_msec() - stage_ms
	stage_ms = Time.get_ticks_msec()
	if capture.is_valid():
		await capture.call(lab, config.label, "night")
	timings.capture = Time.get_ticks_msec() - stage_ms
	stage_ms = Time.get_ticks_msec()
	# Probe the real guards, restore only test-owned mutations, then exercise normal retirement.
	var tower: Node3D = owner._towers[0].model
	var head: Node3D = tower.get_node("Visual/Head0")
	var pose: Transform3D = head.transform
	head.position.x += 0.05
	var geometry_refused: bool = not owner._owned_property_intact()
	head.transform = pose
	check.call(
		geometry_refused and owner._owned_property_intact(),
		config.label + " actual head geometry refusal"
	)
	var lens: MeshInstance3D = owner._lamps[0].lens
	var original: Material = lens.material_override
	var foreign: StandardMaterial3D = StandardMaterial3D.new()
	lens.material_override = foreign
	var material_refused: bool = not owner._operands()
	lens.material_override = original
	var identity_restored: bool = owner._operands()
	var color_probes: Dictionary = {}
	var colors_refused: bool = true
	for member: String in ["working", "original"]:
		var material: StandardMaterial3D = owner._lamps[0][member]
		var before_color: Color = material.emission
		var baseline: bool = owner._operands()
		var refused: bool = false
		var recovered: bool = false
		if baseline:
			material.emission = Color(
				before_color.r + 0.125, before_color.g, before_color.b, before_color.a
			)
			refused = not owner._operands()
			material.emission = before_color
			recovered = owner._operands() and material.emission == before_color
		color_probes[member] = {"baseline": baseline, "refused": refused, "restored": recovered}
		colors_refused = colors_refused and baseline and refused and recovered
	var material_guards: bool = (
		material_refused
		and identity_restored
		and colors_refused
		and StadiumSurfaceNightRuntime.installed_bound(lab, state.stadium)
	)
	if not material_guards:
		print(
			(
				"FLOODLIGHT_COLOR_PROBE_FAILURE "
				+ JSON.stringify(
					{
						"label": config.label,
						"identity_refused": material_refused,
						"identity_restored": identity_restored,
						"colors": color_probes
					},
					"",
					true,
					true
				)
			)
		)
	check.call(material_guards, config.label + " current glow material replacement refusal")
	timings.probes = Time.get_ticks_msec() - stage_ms
	stage_ms = Time.get_ticks_msec()
	var before_restore_guard_timings: Dictionary = owner._guard_timings.duplicate(true)
	var original_environment: Environment = owner._environment
	var original_surface: ShaderMaterial = owner._material
	StadiumSurfaceNightRuntime.retire(lab, "BOUNDED_FLOODLIGHT_CHECK")
	var restored: bool = (
		owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		and lab._world_environment.environment == original_environment
		and owner._surface.material_override == original_surface
		and not viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
	)
	for row: Dictionary in owner._lamps:
		restored = (
			restored
			and row.lens.material_override == row.original
			and row.lens.visible == row.lens_visible
		)
	for row: Dictionary in owner._emitters:
		restored = (
			restored
			and row.beam.visible == row.visible
			and row.beam.light_energy == row.restore_beam_energy
		)
	check.call(restored, config.label + " exact owned presentation restored")
	StadiumSurfaceNightRuntime.retire(lab, "BOUNDED_FLOODLIGHT_REPEAT")
	check.call(
		(
			owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
			and lab._world_environment.environment == original_environment
		),
		config.label + " repeat retirement idempotent"
	)
	check.call(
		(
			JSON.stringify(paid.to_data(), "", true, true) == source
			and season.player_results.is_empty()
			and season.results.is_empty()
		),
		config.label + " paid source and results unchanged"
	)
	timings.restore = Time.get_ticks_msec() - stage_ms
	result.guard_timing_stages["restore"] = _guard_timing_delta(
		owner._guard_timings, before_restore_guard_timings
	)
	result.runtime = {
		"installed": installed,
		"towers": tower_count,
		"emitters": owner._emitters.size(),
		"glows": owner._lamps.size(),
		"initial_night": initial,
		"advanced": advanced,
		"live_frozen": frozen,
		"geometry_refused": geometry_refused,
		"material_refused": material_refused,
		"color_probes": color_probes,
		"restored": restored
	}
	runner.cancel()
	runner.queue_free()
	await parent.get_tree().process_frame
	result["native_frames"] = await _native_frame_sample(parent, check, paid, season, config.label)
	if config.label == "club-sparse":
		result["transaction_callback"] = await _transaction_callback(
			parent, check, paid, season, config.label
		)
		result["anchor_transaction_callback"] = await _transaction_callback(
			parent, check, paid, season, config.label, "anchor"
		)
		result["snapshot_transaction_callback"] = await _transaction_callback(
			parent, check, paid, season, config.label, "snapshot"
		)
		result["policy_transaction_callback"] = await _transaction_callback(
			parent, check, paid, season, config.label, "policy"
		)
		result["ordinary_career_tree_callback"] = await _ordinary_career_tree_callback(
			parent, check, config.label
		)
	timings.total = Time.get_ticks_msec() - started_ms
	return result


static func _open_runtime(
	parent: Node3D, paid: ClubAssetLedger, season: SeasonState, diagnostics: bool = true
) -> Dictionary:
	var state: MatchState = season.make_match()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	parent.add_child(runner)
	# The actual caller guard requires this PhysicalMatchRunner/SubViewport pair.
	# No runner.start, fabricated AI budget, processing, or deliveries are enabled.
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	runner._viewport = viewport
	runner.add_child(viewport)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("owned_floodlight_diagnostics", diagnostics)
	lab.set_meta("owned_floodlight_timing", true)
	runner._lab = lab
	lab._configured_match = state
	lab._npc_season = season
	lab._stadium_ledger = paid
	lab._field_id = PitchBatLab.FIELD_ID
	lab._sky_backdrop_enabled = true
	lab._automation = MatchAutomation.new()
	lab._automation.seed = SeasonPhysicalFixtures.seed_for(season, season.pending_fixture())
	lab._automation.presentation_enabled = true
	var configured: bool = state != null and StadiumSurfaceNightRuntime.configure(lab, season, paid)
	if configured:
		viewport.add_child(lab)
		_pause(lab)
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var installed: bool = (
		configured
		and owner != null
		and StadiumSurfaceNightRuntime.installed_bound(lab, state.stadium)
	)
	return {
		"runner": runner,
		"viewport": viewport,
		"lab": lab,
		"state": state,
		"owner": owner,
		"configured": configured,
		"installed": installed
	}


static func _start_profile(
	parent: Node3D,
	check: Callable,
	paid: ClubAssetLedger,
	season: SeasonState,
	label: String,
	mode: String
) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var timings: Dictionary = {"install": 0, "clock": 0, "capture": 0, "restore": 0, "total": 0}
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, mode)
	var stage_ms: int = Time.get_ticks_msec()
	var context: Dictionary = _open_runtime(parent, paid, season)
	timings.install = Time.get_ticks_msec() - stage_ms
	check.call(context.configured and context.installed, label + " " + mode + " actual admission")
	if not context.installed:
		var failure: Dictionary = _failure_context(context)
		_close_runtime(context)
		timings.total = Time.get_ticks_msec() - started_ms
		failure["timings_ms"] = timings
		return failure
	stage_ms = Time.get_ticks_msec()
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var state: MatchState = context.state
	var initial_values: Dictionary = _initial_values(owner)
	var initial: bool = _lights(owner, 0.0) and owner._clock_plays == 0 and owner._clock_halves == 0
	check.call(initial, label + " " + mode + " initial dark lamps")
	lab._play_records.append(PlayRecord.new())
	state.top_half = false
	var advanced: bool = StadiumSurfaceNightRuntime.boundary_allowed(lab)
	var factor: float = 0.0 if mode == "day" else minf(1.0, owner._profile_progress * 3.0)
	var clock_lights: bool = (
		advanced
		and owner._profile_progress > 0.0
		and owner._profile_progress <= 0.002
		and _lights(owner, factor)
	)
	if not clock_lights:
		print(
			(
				"FLOODLIGHT_CLOCK_SCALAR_FAILURE "
				+ JSON.stringify(
					{
						"label": label,
						"mode": mode,
						"advanced": advanced,
						"plays": owner._clock_plays,
						"halves": owner._clock_halves,
						"progress": owner._profile_progress,
						"factor": factor,
						"first_difference": _light_difference(owner, factor)
					},
					"",
					true,
					true
				)
			)
		)
	check.call(clock_lights, label + " " + mode + " shared clock lamps")
	var held: Array = _clock_values(owner)
	check.call(
		StadiumSurfaceNightRuntime.boundary_allowed(lab) and _clock_values(owner) == held,
		label + " " + mode + " unchanged tuple"
	)
	timings.clock = Time.get_ticks_msec() - stage_ms
	stage_ms = Time.get_ticks_msec()
	StadiumSurfaceNightRuntime.retire(lab, "BOUNDED_" + mode.to_upper())
	var restored: bool = (
		owner._phase == StadiumSurfaceNightRuntime.Phase.RETIRED
		and not context.viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
		and lab._world_environment.environment == owner._environment
	)
	for row: Dictionary in owner._lamps:
		restored = (
			restored
			and row.lens.material_override == row.original
			and row.lens.visible == row.lens_visible
		)
	for row: Dictionary in owner._emitters:
		restored = (
			restored
			and row.beam.visible == row.visible
			and row.beam.light_energy == row.restore_beam_energy
		)
	check.call(restored, label + " " + mode + " exact owned retirement")
	timings.restore = Time.get_ticks_msec() - stage_ms
	var result: Dictionary = {
		"mode": mode,
		"installed": context.installed,
		"initial_dark": initial,
		"initial_values": initial_values,
		"progress": owner._profile_progress,
		"lamp_factor": factor,
		"restored": restored,
		"timings_ms": timings
	}
	_close_runtime(context)
	await parent.get_tree().process_frame
	timings.total = Time.get_ticks_msec() - started_ms
	return result


static func _failure_context(context: Dictionary) -> Dictionary:
	var owner: StadiumSurfaceNightRuntime = context.owner
	return {
		"configured": context.configured,
		"installed": context.installed,
		"owner_phase": -1 if owner == null else int(owner._phase),
		"property": owner != null and is_instance_valid(owner._property),
		"captured_towers": 0 if owner == null else owner._towers.size(),
		"captured_emitters": 0 if owner == null else owner._emitters.size(),
		"captured_glows": 0 if owner == null else owner._lamps.size()
	}


static func _close_runtime(context: Dictionary) -> void:
	if is_instance_valid(context.lab) and context.lab.get_parent() == null:
		context.lab.free()
		context.runner._lab = null
	context.runner.cancel()
	context.runner.queue_free()


static func _pause(lab: PitchBatLab) -> void:
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.set_process_input(false)
	lab.set_process_unhandled_input(false)
	lab._sounds.set_muted(true)
	lab._at_bat_cadence.stop()
	lab._field_setup_active = false
	lab._pitching_staff_active = false


static func _initial_values(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var energies: Array = []
	var visible: Array = []
	for row: Dictionary in owner._emitters:
		energies.append(row.beam.light_energy)
		visible.append(row.beam.visible)
	return {
		"sun_color": owner._sun.light_color.to_html(true),
		"sun_energy": owner._sun.light_energy,
		"ambient_color": owner._working_environment.ambient_light_color.to_html(true),
		"ambient_energy": owner._working_environment.ambient_light_energy,
		"emitter_energies": energies,
		"emitter_visible": visible,
		"glow_count": owner._lamps.size(),
		"glow_visible": owner._lamps[0].lens.visible,
		"glow_energy": owner._lamps[0].working.emission_energy_multiplier
	}


static func _lights(owner: StadiumSurfaceNightRuntime, factor: float) -> bool:
	return _light_difference(owner, factor).is_empty()


static func _light_difference(owner: StadiumSurfaceNightRuntime, factor: float) -> Dictionary:
	# Independent expectations use native float32 property storage, never runtime expected fields.
	var glow_energy: float = PackedFloat32Array([factor])[0]
	for row: Dictionary in owner._emitters:
		var beam_energy: float = PackedFloat32Array([row.beam_energy * factor])[0]
		if row.beam.light_energy != beam_energy or row.beam.visible != (factor > 0.0):
			return {
				"kind": "emitter",
				"site": row.site,
				"energy": row.beam.light_energy,
				"expected_energy": beam_energy,
				"visible": row.beam.visible,
				"expected_visible": factor > 0.0
			}
	for row: Dictionary in owner._lamps:
		if (
			row.lens.visible != (factor > 0.0)
			or row.working.emission_energy_multiplier != glow_energy
		):
			return {
				"kind": "glow",
				"site": row.site,
				"name": String(row.lens.name),
				"energy": row.working.emission_energy_multiplier,
				"expected_energy": glow_energy,
				"visible": row.lens.visible,
				"expected_visible": factor > 0.0
			}
	return {}


static func _clock_values(owner: StadiumSurfaceNightRuntime) -> Array:
	return [
		owner._clock_plays,
		owner._clock_halves,
		owner._profile_progress,
		owner._sun.light_color,
		owner._sun.light_energy,
		owner._working_environment.ambient_light_energy
	]


static func _transaction_callback(
	parent: Node3D,
	check: Callable,
	paid: ClubAssetLedger,
	season: SeasonState,
	label: String,
	mutation: String = "paid"
) -> Dictionary:
	var anchor_mutation: bool = mutation == "anchor"
	var started_ms: int = Time.get_ticks_msec()
	var before_data: String = JSON.stringify(paid.to_data(), "", true, true)
	var before_spent: int = paid._spent
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var before_anchor: float = field.middle_center_anchor_z_m
	var before_generation: int = paid.mutation_generation()
	var before_revision: int = paid.revision()
	var before_policy: Dictionary = season.owned_surface_night.duplicate(true)
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(
		season, paid, "sunset"
	)
	var install_started_ms: int = Time.get_ticks_msec()
	var context: Dictionary = _open_runtime(parent, paid, season, false)
	var evidence: Dictionary = {
		"installed": context.installed,
		"fired": false,
		"same_generation": false,
		"same_revision": false,
		"refused": false,
		"abandoned": false,
		"presentation_unchanged": false,
		"sticky": false,
		"paid_restored": false,
		"install_ms": Time.get_ticks_msec() - install_started_ms,
		"callback_ms": 0,
		"total_ms": 0
	}
	if context.installed:
		var owner: StadiumSurfaceNightRuntime = context.owner
		var lab: PitchBatLab = context.lab
		var before_snapshot: String = JSON.stringify(owner._snapshot, "", true, true)
		var before_runtime_policy: String = JSON.stringify(
			season.owned_surface_night, "", true, true
		)
		var before_snapshot_seed: int = int(owner._snapshot.binding.match_seed)
		var before_start_minute: int = int(season.owned_surface_night.start_minute)
		if mutation == "paid":
			evidence["backing_probes"] = _backing_probes(owner, lab)
		if anchor_mutation:
			var probes: Dictionary = {}
			for key: StringName in ANCHOR_FIELDS:
				var before: float = field.get(key)
				var baseline: bool = owner._context(lab)
				field.set(key, before + 0.25)
				var refused: bool = not owner._context(lab)
				field.set(key, before)
				probes[String(key)] = {
					"baseline": baseline,
					"refused": refused,
					"restored": field.get(key) == before and owner._context(lab)
				}
			evidence["anchor_probes"] = probes
		var observed: Dictionary = {
			"fired": false, "presentation": [], "generation": -1, "revision": -1
		}
		var callback: Callable = func() -> void:
			observed.fired = true
			if anchor_mutation:
				field.middle_center_anchor_z_m = before_anchor + 0.25
			elif mutation == "snapshot":
				owner._snapshot.binding.match_seed = before_snapshot_seed + 1
			elif mutation == "policy":
				season.owned_surface_night.start_minute = before_start_minute + 1
			else:
				paid._spent = before_spent + 1
			observed.generation = paid.mutation_generation()
			observed.revision = paid.revision()
			observed.presentation = _callback_presentation(owner)
		var beam: SpotLight3D = owner._emitters[0].beam
		beam.visibility_changed.connect(callback, CONNECT_ONE_SHOT)
		lab._play_records.append(PlayRecord.new())
		context.state.top_half = false
		var callback_started_ms: int = Time.get_ticks_msec()
		evidence.refused = not StadiumSurfaceNightRuntime.boundary_allowed(lab)
		evidence.callback_ms = Time.get_ticks_msec() - callback_started_ms
		if beam.visibility_changed.is_connected(callback):
			beam.visibility_changed.disconnect(callback)
		evidence.fired = observed.fired
		evidence.same_generation = (
			observed.generation == before_generation
			and paid.mutation_generation() == before_generation
		)
		evidence.same_revision = (
			observed.revision == before_revision and paid.revision() == before_revision
		)
		evidence.abandoned = owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		evidence.presentation_unchanged = (
			observed.fired and _callback_presentation(owner) == observed.presentation
		)
		# Only the fixture's own scalar mutation is restored; the runtime stays retired.
		paid._spent = before_spent
		if anchor_mutation:
			field.middle_center_anchor_z_m = before_anchor
		elif mutation == "snapshot":
			owner._snapshot.binding.match_seed = before_snapshot_seed
		elif mutation == "policy":
			season.owned_surface_night.start_minute = before_start_minute
		if mutation in ["snapshot", "policy"]:
			evidence["raw_restored"] = (
				JSON.stringify(owner._snapshot, "", true, true) == before_snapshot
				and (
					JSON.stringify(season.owned_surface_night, "", true, true)
					== before_runtime_policy
				)
			)
		evidence.sticky = (
			not StadiumSurfaceNightRuntime.action_allowed(lab)
			and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		)
		evidence.presentation_unchanged = (
			evidence.presentation_unchanged
			and _callback_presentation(owner) == observed.presentation
		)
	else:
		paid._spent = before_spent
		if anchor_mutation:
			field.middle_center_anchor_z_m = before_anchor
	evidence.paid_restored = (
		paid._spent == before_spent
		and paid.mutation_generation() == before_generation
		and paid.revision() == before_revision
		and JSON.stringify(paid.to_data(), "", true, true) == before_data
	)
	var passed: bool = (
		evidence.installed
		and evidence.fired
		and evidence.same_generation
		and evidence.same_revision
		and evidence.refused
		and evidence.abandoned
		and evidence.presentation_unchanged
		and evidence.sticky
		and evidence.paid_restored
	)
	if mutation == "paid":
		passed = passed and evidence.get("backing_probes", {}).size() == 3
		for probe: Dictionary in evidence.get("backing_probes", {}).values():
			passed = passed and probe.baseline and probe.refused and probe.restored
	if anchor_mutation:
		evidence["field_restored"] = (
			ContentDB.get_field(PitchBatLab.FIELD_ID) == field
			and field.get_script() == FieldDefinition
			and field.middle_center_anchor_z_m == before_anchor
		)
		passed = (
			passed
			and evidence.field_restored
			and evidence.get("anchor_probes", {}).size() == ANCHOR_FIELDS.size()
		)
		for probe: Dictionary in evidence.get("anchor_probes", {}).values():
			passed = passed and probe.baseline and probe.refused and probe.restored
	if mutation in ["snapshot", "policy"]:
		evidence["mutation"] = mutation
		passed = passed and evidence.get("raw_restored", false)
	if not passed:
		print("FLOODLIGHT_CALLBACK_FAILURE " + JSON.stringify(evidence, "", true, true))
	check.call(passed, label + " " + mutation + " visibility callback stops transaction")
	_close_runtime(context)
	await parent.get_tree().process_frame
	season.owned_surface_night = before_policy
	evidence.total_ms = Time.get_ticks_msec() - started_ms
	return evidence


static func _callback_presentation(owner: StadiumSurfaceNightRuntime) -> Array:
	var result: Array = [
		owner._environment_owner.environment,
		owner._world.environment,
		StadiumSurfaceNightPreview._environment_values(owner._working_environment),
		owner._working_environment.sky,
		owner._sun.light_color,
		owner._sun.light_energy,
		owner._surface.material_override,
		owner._working_material.get_shader_parameter("vertex_pigment_scale"),
		owner._shadows()
	]
	if owner._owned_sky_material != null:
		for parameter: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
			result.append(owner._owned_sky_material.get_shader_parameter(parameter))
	for row: Dictionary in owner._emitters:
		result.append([row.beam.visible, row.beam.light_energy])
	for row: Dictionary in owner._lamps:
		result.append(
			[
				row.lens.material_override,
				row.lens.visible,
				row.working.emission_enabled,
				row.working.emission_energy_multiplier,
				row.working.emission
			]
		)
	return result


static func _geometry_inventory(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var result: Dictionary = {
		"models": 0,
		"nodes": 0,
		"node_fields": 0,
		"child_slots": 0,
		"metadata_slots": 0,
		"resource_rows": 0,
		"unique_resources": 0,
		"resource_fields": 0,
		"material_rows": 0,
		"material_fields": 0
	}
	var seen: Dictionary = {}
	var models: Array = owner._towers + owner._companions
	for model: Dictionary in models:
		result.models += 1
		var seal: Dictionary = model.geometry
		for row: Dictionary in seal.rows:
			result.nodes += 1
			result.node_fields += row.fields.size()
			result.child_slots += row.children.size()
			result.metadata_slots += StadiumFloodlightOwnedModels.BIND_KEYS.size()
		for row: Dictionary in seal.resources:
			result.resource_rows += 1
			result.resource_fields += row.keys.size()
			seen[row.resource.get_instance_id()] = true
			if row.resource is Material:
				result.material_rows += 1
				result.material_fields += row.keys.size()
	result.unique_resources = seen.size()
	return result


static func _companion_material_alias(
	owner: StadiumSurfaceNightRuntime, check: Callable, label: String
) -> Dictionary:
	var result: Dictionary = {}
	var models: Array = owner._towers + owner._companions
	for item: String in ["ST-029", "ST-053"]:
		var selected: Dictionary = {}
		for row: Dictionary in owner._companions:
			if row.model.get_meta("stadium_item", "") == item:
				selected = row
				break
		if selected.is_empty():
			result[item] = {"missing_model": true}
			check.call(false, label + " " + item + " immutable source material alias guards")
			continue
		var others: Array = []
		for row: Dictionary in models:
			if row.model != selected.model:
				others.append(row.model)
		var operands: Dictionary = StadiumFloodlightGeometryRebuildChecks.alias_check(
			selected.model, selected.geometry, others
		)
		var reference: Node3D = (
			StadiumStraightOwnedModels.create(item)
			if item == "ST-029"
			else StadiumRoofOwnedModels.create(item, "lower")
		)
		operands.appearance_parity = (
			operands.appearance_parity
			and reference != null
			and (
				StadiumFloodlightGeometryRebuildChecks._signature(selected.model)
				== StadiumFloodlightGeometryRebuildChecks._signature(reference)
			)
		)
		if reference != null:
			reference.free()
		var passed: bool = true
		for value: Variant in operands.values():
			passed = passed and value is bool and value
		result[item] = operands
		if not passed:
			print(
				(
					"FLOODLIGHT_SOURCE_ALIAS_FAILURE "
					+ JSON.stringify({"item": item, "operands": operands}, "", true, true)
				)
			)
		check.call(passed, label + " " + item + " immutable source material alias guards")
	return result


static func _guard_timing_delta(current: Dictionary, before: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in current:
		var previous: Dictionary = before.get(key, {"calls": 0, "elapsed_us": 0})
		result[key] = {
			"calls": int(current[key].calls) - int(previous.calls),
			"elapsed_us": int(current[key].elapsed_us) - int(previous.elapsed_us)
		}
	return result


static func _backing_probes(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["paid_championships", "replay_championships", "fixture_id"]:
		var baseline: bool = owner._owned_transaction_configured(lab)
		var before_id: int = owner._fixture_id
		var ledger: ClubAssetLedger = (
			owner._paid if key == "paid_championships" else owner._replay_paid
		)
		var before: Dictionary = {} if ledger == null else ledger._championships.duplicate(true)
		if key == "fixture_id":
			owner._fixture_id += 1
		elif ledger != null:
			ledger._championships["foreign-probe"] = true
		var refused: bool = not owner._owned_transaction_configured(lab)
		if key == "fixture_id":
			owner._fixture_id = before_id
		elif ledger != null:
			ledger._championships = before
		result[key] = {
			"baseline": baseline,
			"refused": refused,
			"restored": owner._owned_transaction_configured(lab)
		}
	return result


static func _ordinary_career_tree_callback(
	parent: Node3D, check: Callable, label: String
) -> Dictionary:
	var started_ms: int = Time.get_ticks_msec()
	var fixture: Dictionary = _ordinary_fixture()
	var evidence: Dictionary = {
		"synthetic_funding": true,
		"played_games": 0,
		"replay_disabled": false,
		"ordinary_ledger": false,
		"configured": false,
		"installed": false,
		"fired": false,
		"refused": false,
		"abandoned": false,
		"presentation_unchanged": false,
		"tree_unchanged": false,
		"pennants_restored": false,
		"sticky": false,
		"same_generation": false,
		"same_revision": false,
		"stage": fixture.get("stage", "fixture"),
		"total_ms": 0
	}
	if not fixture.has("paid") or not fixture.has("season"):
		check.call(false, label + " ordinary career route admits complete owned lights")
		check.call(false, label + " ordinary career pennant tree callback stops transaction")
		print("FLOODLIGHT_ORDINARY_CAREER_FAILURE " + JSON.stringify(evidence, "", true, true))
		return evidence
	var season: SeasonState = fixture.season
	var paid: ClubAssetLedger = fixture.paid
	var ordinary: ClubAssetLedger = StadiumSurfaceNightSnapshot.ledger(season)
	evidence.replay_disabled = season._pool_replay_ledger == null
	evidence.ordinary_ledger = (
		ordinary != null
		and ordinary != paid
		and ClubCareer.same(ordinary.to_data(), paid.to_data())
	)
	evidence["proof_sha256"] = fixture.proof_sha256
	evidence["funding_rows"] = fixture.funding_rows
	var context: Dictionary = _open_runtime(parent, paid, season, false)
	evidence.configured = context.configured
	evidence.installed = context.installed
	var admitted: bool = (
		evidence.replay_disabled
		and evidence.ordinary_ledger
		and evidence.configured
		and evidence.installed
	)
	check.call(admitted, label + " ordinary career route admits complete owned lights")
	if admitted:
		var owner: StadiumSurfaceNightRuntime = context.owner
		var lab: PitchBatLab = context.lab
		var before: Dictionary = season.career._pennants.duplicate(true)
		var generation: int = paid.mutation_generation()
		var revision: int = paid.revision()
		var observed: Dictionary = {"fired": false, "presentation": [], "children": []}
		var callback: Callable = func(_node: Node) -> void:
			observed.fired = true
			season.career._pennants.version = int(before.version) + 1
			observed.presentation = _callback_presentation(owner)
			observed.children = owner._host.get_children()
		owner._host.child_entered_tree.connect(callback, CONNECT_ONE_SHOT)
		StadiumSurfaceNightRuntime.retire(lab, "ORDINARY_CAREER_TREE_MUTATION")
		if owner._host.child_entered_tree.is_connected(callback):
			owner._host.child_entered_tree.disconnect(callback)
		evidence.fired = observed.fired
		evidence.same_generation = paid.mutation_generation() == generation
		evidence.same_revision = paid.revision() == revision
		evidence.abandoned = owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		evidence.refused = evidence.abandoned and not StadiumSurfaceNightRuntime.action_allowed(lab)
		evidence.presentation_unchanged = (
			observed.fired and _callback_presentation(owner) == observed.presentation
		)
		evidence.tree_unchanged = observed.fired and owner._host.get_children() == observed.children
		season.career._pennants = before
		evidence.pennants_restored = ClubCareer.same(season.career._pennants, before)
		evidence.sticky = (
			not StadiumSurfaceNightRuntime.action_allowed(lab)
			and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		)
	var passed: bool = (
		admitted
		and evidence.fired
		and evidence.same_generation
		and evidence.same_revision
		and evidence.refused
		and evidence.abandoned
		and evidence.presentation_unchanged
		and evidence.tree_unchanged
		and evidence.pennants_restored
		and evidence.sticky
	)
	check.call(passed, label + " ordinary career pennant tree callback stops transaction")
	if not passed:
		print("FLOODLIGHT_ORDINARY_CAREER_FAILURE " + JSON.stringify(evidence, "", true, true))
	_close_runtime(context)
	await parent.get_tree().process_frame
	evidence.total_ms = Time.get_ticks_msec() - started_ms
	return evidence


static func _ordinary_fixture() -> Dictionary:
	# Zero executed games: repeat one unchanged checked-in score proof as explicitly
	# synthetic legacy history, then use ordinary migration, start/adopt and paid APIs.
	var source: String = "res://src/tests/fixtures/frozen_v40.json"
	var source_sha: String = "d9b516d44b74dfa8ee5f4c68fc80f315fbd8541d28e45dfebfe3f84c818c6b65"
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != source_sha:
		return {"ok": false, "stage": "ordinary-proof-source"}
	var archived: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
	if (
		not archived is Dictionary
		or not archived.get("career") is Dictionary
		or not archived.career.get("runs") is Array
		or archived.career.runs.is_empty()
	):
		return {"ok": false, "stage": "ordinary-proof-shape"}
	var row: Dictionary = archived.career.runs[0]
	if not row.get("proof") is Dictionary:
		return {"ok": false, "stage": "ordinary-proof-missing"}
	var proof: Dictionary = row.proof.duplicate(true)
	var summary: Dictionary = ClubSeasonRecord.analyze(proof)
	var receipt: Dictionary = ClubSeasonRecord.receipt(proof, false, 0)
	if (
		summary.get("finish") != "runner_up"
		or summary.get("wins") != 10
		or proof.scores.size() != 33
		or receipt.get("total") != 110
		or not ClubCareer.same(receipt, row.receipt)
	):
		return {"ok": false, "stage": "ordinary-proof-validation"}
	# Legacy grass/preparation are existing migration entitlements. Only these five
	# purchases are necessary: 600 + 1600 + (520 + 4*120) + 400 + 300 = 3900.
	var cost: int = (
		int(StadiumCatalog.LAND.expanded.price)
		+ int(StadiumCatalog.LAND.club.price)
		+ int(StadiumFloodlightOwnedItems.PRICES["ST-038"][0])
		+ 4 * int(StadiumFloodlightOwnedItems.PRICES["ST-038"][1])
		+ int(StadiumFieldStyles.PRICES["ST-063b"])
		+ int(StadiumGroundStyles.PRICES["ST-063i"])
	)
	var funding_rows: int = ceili(float(cost) / float(receipt.total))
	if cost != 3900 or funding_rows != 36:
		return {"ok": false, "stage": "ordinary-funding-bound"}
	var history: Array[Dictionary] = []
	for index in range(funding_rows):
		history.append(
			{
				"id": index + 1,
				"seed": int(row.seed),
				"league": "standard",
				"tier": 0,
				"status": "completed",
				"proof": proof.duplicate(true),
				"receipt": receipt.duplicate(true)
			}
		)
	var career: ClubCareer = ClubCareer.from_data({"version": 1, "current": 0, "runs": history})
	if career == null:
		return {"ok": false, "stage": "ordinary-legacy-migration"}
	var season: SeasonState = SeasonState.create(101, false, true, true)
	season.career = career
	if not career.start(season) or career._pennants.get("from_season") != funding_rows + 1:
		return {"ok": false, "stage": "ordinary-start-adopt"}
	for pick in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			return {"ok": false, "stage": "ordinary-draft"}
	var paid: ClubAssetLedger = ClubPlayers.assets(career)
	var through: int = ClubPlayers.income_through(career)
	var progress: Array = StadiumCareerProgress.capture(career)
	if (
		paid == null
		or through != funding_rows
		or progress.size() != funding_rows
		or paid.balance() != 3960
		or paid.surface_owned() != ["grass", "ground_prep"]
	):
		return {"ok": false, "stage": "ordinary-derived-funding"}
	var commands: Array[Dictionary] = [
		{"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION},
		{"op": "stadium_land", "tier": "club", "price_version": StadiumLand.VERSION},
		{
			"op": "stadium_buy",
			"item": "ST-038",
			"quantity": 4,
			"price_version": StadiumFloodlightOwnedItems.PRICE_VERSION
		},
		{"op": "stadium_style", "item": "ST-063b", "price_version": StadiumFieldStyles.VERSION},
		{
			"op": "stadium_style",
			"item": "ST-063i",
			"price_version": StadiumGroundStyles.PRICE_VERSION
		}
	]
	for command: Dictionary in commands:
		command.id = "ordinary-floodlight-paid:%d" % paid.revision()
		command.rev = paid.revision()
		command.through = through
		command.progress_through = progress.size()
		var purchased: Dictionary = paid.commit(command)
		if not purchased.ok:
			return {
				"ok": false,
				"stage": "ordinary-purchase",
				"op": command.op,
				"item": command.get("item", command.get("tier", "")),
				"error": purchased.get("error", "")
			}
	var layout: Dictionary = StadiumFloodlightOwnedItems.upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	if layout.is_empty():
		return {"ok": false, "stage": "ordinary-layout-upgrade"}
	layout.surface = {"foundation": "grass", "condition": "prepared", "height": "short"}
	layout.styles = {"grass": "ST-063b", "line": ""}
	layout.ground = "ST-063i"
	layout = StadiumFloodlightOwnedItems.select_preset(layout, paid.construction(), "CLUB4-LOW")
	var draft: Dictionary = paid.commit(
		{
			"id": "ordinary-floodlight-draft",
			"rev": paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		return {"ok": false, "stage": "ordinary-draft-layout", "error": draft.get("error", "")}
	var applied: Dictionary = paid.commit(
		{
			"id": "ordinary-floodlight-apply",
			"rev": paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumHomeLayout.geometry("club", layout)
		}
	)
	if not applied.ok or paid.balance() != 60:
		return {"ok": false, "stage": "ordinary-apply-layout", "error": applied.get("error", "")}
	career._assets = paid.to_data()
	var cold: ClubCareer = ClubCareer.from_data(
		JSON.parse_string(JSON.stringify(career.to_data(), "", true, true))
	)
	if cold == null:
		return {"ok": false, "stage": "ordinary-career-cold"}
	season.career = cold
	paid = ClubPlayers.assets(cold)
	if paid == null or season._pool_replay_ledger != null or season._npc_replay_run != -1:
		return {"ok": false, "stage": "ordinary-assets-cold"}
	season.home_property = StadiumLayoutSnapshot.capture(paid)
	var scheduled: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		if fixture.home == 0 and (scheduled.is_empty() or fixture.round < scheduled.round):
			scheduled = fixture.duplicate(true)
	if scheduled.is_empty():
		return {"ok": false, "stage": "ordinary-home-fixture"}
	# Same disposable schedule cursor as the other bounded floodlight probes.
	season.round_index = int(scheduled.round)
	season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(
		season, paid, "night"
	)
	var snapshot: Dictionary = StadiumSurfaceNightSnapshot.fixture(season, scheduled)
	if (
		season.owned_surface_night.is_empty()
		or snapshot.is_empty()
		or not StadiumSurfaceNightSnapshot.matches_fixture(snapshot, season, scheduled, paid)
		or not season.results.is_empty()
		or not season.player_results.is_empty()
	):
		return {"ok": false, "stage": "ordinary-full-admission"}
	return {
		"ok": true,
		"season": season,
		"paid": paid,
		"proof_sha256": source_sha,
		"stage": "ready",
		"source_proof_sha256": JSON.stringify(proof, "", true, true).sha256_text(),
		"source_file": source,
		"source_file_sha256": source_sha,
		"funding_rows": funding_rows,
		"synthetic_funding": true,
		"synthetic_history": true,
		"games": 0,
		"funding_credits": 3960,
		"spent": cost,
		"balance": paid.balance()
	}


static func run_live_comparison(
	parent: Node3D, check: Callable, paid: ClubAssetLedger, config: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"label": config.label,
		"profile": config.profile,
		"comparison": "day_night_same_owned_geometry",
		"checks": 16,
		"natural_time_proof": "pinned runner launch argv; runtime engine arguments are filtered",
		"synthetic_admission": true,
		"actual_games": 0,
		"modes": [],
		"matched_context": false
	}
	result["noop_probes"] = _noop_branch_probes(check, config.label)
	result["noop_callbacks"] = []
	for kind: String in ["home_run", "swing"]:
		result.noop_callbacks.append(await _noop_callback_case(parent, check, paid, config, kind))
	var setups: Array[Dictionary] = []
	for mode: String in ["day", "night"]:
		setups.append(_native_comparison_season(paid, config))
	var setup_ok: bool = setups[0].ok and setups[1].ok
	check.call(setup_ok, config.label + " live comparison fresh seasons")
	result["season_setup"] = {"ok": setup_ok, "day": setups[0].stage, "night": setups[1].stage}
	for index in range(2):
		var mode: String = "day" if index == 0 else "night"
		var season: SeasonState = setups[index].season
		var policy: Dictionary = {}
		if setups[index].ok:
			policy = StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, mode)
		var policy_ok: bool = (
			not policy.is_empty()
			and policy.mode == mode
			and policy.candidate.candidate_version == 2
			and StadiumSurfaceNightSnapshot.valid_policy(policy, season, paid)
		)
		check.call(policy_ok, config.label + " " + mode + " live comparison captured policy")
		var sample: Dictionary
		if policy_ok:
			season.owned_surface_night = policy
			sample = await _native_frame_sample(
				parent, check, paid, season, config.label + " " + mode, mode, 30000000
			)
		else:
			sample = {
				"mode": mode,
				"stage": "policy",
				"reason": "setup_or_mode_policy",
				"idle24": false,
				"native_pitch": false,
				"native_batted": false,
				"rows": [],
				"windows": {}
			}
			_native_frame_checks(check, config.label + " " + mode, sample)
		sample["policy_valid"] = policy_ok
		result.modes.append(sample)
	var day: Dictionary = result.modes[0].get("comparison_context", {})
	var night: Dictionary = result.modes[1].get("comparison_context", {})
	var operands: Dictionary = {"both_contexts": not day.is_empty() and not night.is_empty()}
	for key: String in [
		"season_seed",
		"match_seed",
		"fixture",
		"field_id",
		"field_values",
		"property_field_values",
		"field_script",
		"camera_values",
		"camera_mode",
		"camera_shot",
		"layout_values",
		"model_poses",
		"geometry",
		"boundary",
		"profile",
		"towers",
		"companions"
	]:
		operands[key] = day.has(key) and night.has(key) and day[key] == night[key]
	var day_render: Dictionary = result.modes[0].get("context", {}).duplicate(true)
	var night_render: Dictionary = result.modes[1].get("context", {}).duplicate(true)
	day_render.erase("mode")
	night_render.erase("mode")
	operands["renderer_and_clock"] = not day_render.is_empty() and day_render == night_render
	var matched: bool = setup_ok and result.modes[0].policy_valid and result.modes[1].policy_valid
	for value: Variant in operands.values():
		matched = matched and value is bool and value
	result.matched_context = matched
	result["matched_operands"] = operands
	check.call(matched, config.label + " day night exact matched context")
	return result


static func _native_comparison_season(paid: ClubAssetLedger, config: Dictionary) -> Dictionary:
	var season: SeasonState = SeasonState.create(101, true)
	for index in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			return {"ok": false, "stage": "draft", "season": season}
	season._pool_replay_ledger = paid
	season._npc_replay_run = 0
	season.home_property = config.snapshot.duplicate(true)
	var scheduled: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		if fixture.home == 0 and (scheduled.is_empty() or fixture.round < scheduled.round):
			scheduled = fixture.duplicate(true)
	if scheduled.is_empty() or not StadiumLayoutSnapshot.matches(season.home_property, paid):
		return {"ok": false, "stage": "home_fixture", "season": season}
	season.round_index = int(scheduled.round)
	return {"ok": true, "stage": "ready", "season": season}


static func _native_comparison_context(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime
) -> Dictionary:
	var camera: Camera3D = lab._camera
	var poses: Array = []
	var copies: Array = owner._property.objects.keys()
	copies.sort()
	for copy: Variant in copies:
		var model: Node3D = owner._property.objects[copy]
		poses.append([String(copy), String(model.name), model.transform])
	# Native value bytes preserve exact floats without JSON decimal round-trip changes.
	# No instance ID, hash-only equality or environment/light value is compared.
	return {
		"season_seed": owner._season_seed,
		"match_seed": owner._match_seed,
		"fixture": owner._fixture_id,
		"field_id": String(lab._field_id),
		"field_values":
		var_to_bytes(SeasonPhysicalFixtures._resource(lab._field_definition)).hex_encode(),
		"property_field_values":
		var_to_bytes(SeasonPhysicalFixtures._resource(owner._property.field)).hex_encode(),
		"field_script": lab._field_definition.get_script().resource_path,
		"camera_values":
		(
			var_to_bytes(
				[
					camera.global_transform,
					camera.projection,
					camera.fov,
					camera.near,
					camera.far,
					camera.keep_aspect,
					camera.size,
					camera.frustum_offset,
					camera.h_offset,
					camera.v_offset
				]
			)
			. hex_encode()
		),
		"camera_mode": lab._camera_mode,
		"camera_shot": int(lab._camera_director.shot),
		"layout_values": var_to_bytes(owner._snapshot.layout).hex_encode(),
		"model_poses": var_to_bytes(poses).hex_encode(),
		"geometry": owner._geometry_signature,
		"boundary": owner._snapshot.boundary,
		"profile": owner._floodlight_profile,
		"towers": owner._towers.size(),
		"companions": owner._companions.size()
	}


static func _native_frame_arguments() -> Dictionary:
	var visible: Array = Array(OS.get_cmdline_args())
	var seen: bool = false
	for argument: String in visible:
		seen = seen or argument == "--fixed-fps" or argument.begins_with("--fixed-fps=")
	return {
		"engine_visible_args": visible,
		"user_args": Array(OS.get_cmdline_user_args()),
		"fixed_fps_seen": seen,
		"fixed_fps_status": "present_in_exposed_args" if seen else "unknown_engine_args_filtered",
		"absence_proof": "runner exact process argv, not OS.get_cmdline_args"
	}


static func _native_frame_pitch_state(lab: PitchBatLab, observed: Dictionary) -> void:
	var pitch: PitchState = lab._pitch_actor.state
	if pitch != null:
		observed.pitch_simulation_us = roundi(pitch.elapsed_time * 1000000.0)
		observed.pitch_position = pitch.position
		observed.pitch_velocity = pitch.velocity


static func _native_frame_sample(
	parent: Node3D,
	check: Callable,
	paid: ClubAssetLedger,
	season: SeasonState,
	label: String,
	mode: String = "night",
	acquisition_us: int = 15000000
) -> Dictionary:
	# Separate fresh match: the correctness context contains synthetic clock records.
	var result: Dictionary = {
		"idle24": false,
		"native_pitch": false,
		"native_batted": false,
		"stage": "install",
		"reason": "",
		"mode": mode,
		"actual_games": 0,
		"forced_launch": false,
		"limits":
		{
			"idle_draws": 24,
			"releases": 6,
			"acquisition_draws": 180,
			"acquisition_us": acquisition_us,
			"batted_draws": 24,
			"minimum_live_draws": 2
		},
		"row_fields":
		[
			"window",
			"dt_us",
			"draw",
			"physics",
			"phase_before",
			"phase_after",
			"pitch_live",
			"ball_live",
			"action_calls",
			"action_us",
			"action_refused",
			"continue_calls",
			"continue_us",
			"continue_refused",
			"monitor_process_us",
			"monitor_physics_process_us",
			"pitch_simulation_us",
			"pitch_position_mm",
			"pitch_velocity_mm_s",
			"pitch_segments",
			"releases"
		],
		"rows": [],
		"windows": {}
	}
	if mode not in ["day", "night"] or acquisition_us not in [15000000, 30000000]:
		result.reason = "unsupported_sample_mode_or_budget"
		_native_frame_checks(check, label, result)
		return result
	var context: Dictionary = _open_runtime(parent, paid, season, false)
	context["sample_mode"] = mode
	if not context.installed:
		result.reason = "admission"
		result["admission"] = _failure_context(context)
		_close_runtime(context)
		await parent.get_tree().process_frame
		_native_frame_checks(check, label, result)
		return result
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var observed: Dictionary = {
		"releases": 0,
		"parameters": null,
		"segments": 0,
		"pitch_simulation_us": -1,
		"pitch_position": Vector3.ZERO,
		"pitch_velocity": Vector3.ZERO,
		"launches": 0,
		"ball": null,
		"play": null,
		"contact": false,
		"terminal": false,
		"stop_reason": "",
		"pitch_views": {},
		"pitch_draws": 0,
		"pitch_moved": false,
		"ball_draws": 0,
		"ball_moved": false,
		"ball_first": Vector3.ZERO,
		"ball_last": Vector3.ZERO,
		"ball_first_physics": -1,
		"ball_last_physics": -1
	}
	var trace: Callable = _native_frame_trace.bind(lab, observed)
	var segment: Callable = _native_frame_segment.bind(lab, observed)
	var stopped: Callable = _native_frame_stopped.bind(lab, observed)
	var resolved: Callable = _native_frame_resolved.bind(lab, observed)
	var entered: Callable = _native_frame_child.bind(lab, observed)
	# Existing gameplay listeners were connected during ready and remain first.
	lab._pitch_actor.trace_sampled.connect(trace)
	lab._pitch_actor.segment_advanced.connect(segment)
	lab._pitch_actor.flight_stopped.connect(stopped)
	lab._ball_play_resolver.play_resolved.connect(resolved)
	lab.child_entered_tree.connect(entered)
	lab._at_bat_cadence.stop()
	result["comparison_context"] = _native_comparison_context(lab, owner)
	lab.set_process(true)
	lab.set_physics_process(true)
	owner._action_sample_enabled = true
	result["context"] = {
		"viewport": [context.viewport.size.x, context.viewport.size.y],
		"update_mode": context.viewport.render_target_update_mode,
		"own_world": context.viewport.own_world_3d,
		"presented": MatchAutomation.presented(lab),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": RenderingServer.get_video_adapter_name(),
		"video_vendor": RenderingServer.get_video_adapter_vendor(),
		"display": DisplayServer.get_name(),
		"physics_hz": Engine.physics_ticks_per_second,
		"time_scale": Engine.time_scale,
		"max_physics_steps_per_frame": Engine.max_physics_steps_per_frame,
		"command_line": _native_frame_arguments(),
		"mode": owner._time_profile,
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"process": lab.is_processing(),
		"physics_process": lab.is_physics_processing(),
		"counter_scope":
		"actual owned _context/_operands after owner lookup, before failure cleanup",
		"interval_scope": "whole rendered intervals; transition rows can include both phases",
		"monitor_scope":
		"Performance TIME_PROCESS/TIME_PHYSICS_PROCESS; values may lag up to 1 second",
		"pitch_state_scope": "latest observed actual native PitchState, retained after actor reset"
	}
	var previous: Dictionary = _native_frame_stamp(owner, lab)
	var window_start: Dictionary = previous.duplicate(true)
	var idle_good: bool = _native_frame_context(context)
	result.stage = "idle"
	for frame in range(24):
		if not idle_good:
			break
		await RenderingServer.frame_post_draw
		previous = _native_frame_row(result, 0, owner, lab, previous, observed)
		idle_good = (
			_native_frame_context(context)
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
			and not lab._pitch_actor.running
			and not lab._ball_in_play_is_live()
			and observed.releases == 0
			and observed.launches == 0
		)
	result.windows["idle"] = _native_frame_window(previous, window_start)
	result.idle24 = (
		idle_good
		and result.rows.size() == 24
		and previous.draw > window_start.draw
		and previous.physics > window_start.physics
		and _native_frame_unrefused(result.windows.idle.actions)
	)
	if result.idle24:
		result.stage = "acquisition"
		window_start = _native_frame_stamp(owner, lab)
		previous = window_start.duplicate(true)
		PitchBatLabFeelSupport.begin_ai_delivery(lab)
		for frame in range(180):
			if Time.get_ticks_usec() - int(window_start.us) >= acquisition_us:
				result.reason = "acquisition_wall_cap"
				break
			await RenderingServer.frame_post_draw
			previous = _native_frame_row(result, 1, owner, lab, previous, observed)
			if not _native_frame_context(context):
				result.reason = "acquisition_context"
				break
			_native_frame_observe(lab, observed)
			if observed.launches > 0:
				break
			if Time.get_ticks_usec() - int(window_start.us) >= acquisition_us:
				result.reason = "acquisition_wall_cap"
				break
			if (
				not lab._pitch_actor.running
				and (
					lab._match_state.phase
					in [MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION]
				)
			):
				if observed.releases >= 6:
					result.reason = "release_cap"
					break
				if not lab._ball_in_play_is_live() and not lab._home_run.active:
					# Ordinary cleanup, offense/defense updates and next delivery.
					lab._handle_match_advance()
		result.windows["acquisition"] = _native_frame_window(
			_native_frame_stamp(owner, lab), window_start
		)
		if observed.launches == 0 and result.reason.is_empty():
			result.reason = "acquisition_draw_cap"
		result.native_pitch = (
			observed.releases > 0
			and observed.releases <= 6
			and observed.segments > 0
			and observed.pitch_draws >= 2
			and observed.pitch_moved
			and _native_frame_unrefused(result.windows.acquisition.actions)
		)
		if observed.launches == 1 and _native_frame_context(context):
			result.stage = "batted"
			window_start = _native_frame_stamp(owner, lab)
			previous = window_start.duplicate(true)
			# The acquisition's last draw can already be the first live ball draw.
			for frame in range(maxi(0, 24 - int(observed.ball_draws))):
				if observed.terminal:
					break
				await RenderingServer.frame_post_draw
				previous = _native_frame_row(result, 2, owner, lab, previous, observed)
				if not _native_frame_context(context):
					result.reason = "batted_context"
					break
				_native_frame_observe(lab, observed)
			result.windows["batted"] = _native_frame_window(
				_native_frame_stamp(owner, lab), window_start
			)
			result.native_batted = (
				observed.contact
				and observed.launches == 1
				and observed.ball_draws >= 2
				and observed.ball_moved
				and _native_frame_context(context)
				and _native_frame_unrefused(result.windows.batted.actions)
			)
			if not result.native_batted and result.reason.is_empty():
				result.reason = "short_or_invalid_batted_window"
	else:
		result.reason = "idle_context_or_cadence"
	var sampled_ball: BattedBallBody = observed.ball
	result["evidence"] = {
		"releases": observed.releases,
		"segments": observed.segments,
		"pitch_simulation_us": observed.pitch_simulation_us,
		"pitch_position_mm": _native_frame_position_mm(observed.pitch_position),
		"pitch_velocity_mm_s": _native_frame_position_mm(observed.pitch_velocity),
		"pitch_live_draws": observed.pitch_draws,
		"pitch_moved": observed.pitch_moved,
		"launches": observed.launches,
		"contact": observed.contact,
		"batted_live_draws": observed.ball_draws,
		"batted_moved": observed.ball_moved,
		"position_units": "mm",
		"ball_first_position_mm": _native_frame_position_mm(observed.ball_first),
		"ball_last_position_mm": _native_frame_position_mm(observed.ball_last),
		"ball_first_physics": observed.ball_first_physics,
		"ball_last_physics": observed.ball_last_physics,
		"terminal": observed.terminal,
		"stop_reason": observed.stop_reason,
		"owner_phase": int(owner._phase),
		"match_phase": int(lab._match_state.phase),
		"actor_running": lab._pitch_actor.running,
		"ball_valid": is_instance_valid(sampled_ball),
		"ball_started": is_instance_valid(sampled_ball) and sampled_ball._started,
		"ball_frozen": is_instance_valid(sampled_ball) and sampled_ball.freeze,
		"ball_dead": observed.play != null and observed.play.dead,
		"same_ball": is_instance_valid(sampled_ball) and lab._batted_ball == sampled_ball,
		"same_play": observed.play != null and lab._ball_play_resolver.state == observed.play
	}
	if not result.native_pitch and result.reason.is_empty():
		result.reason = "short_or_missing_pitch_window"
	if result.idle24 and result.native_pitch and result.native_batted:
		result.stage = "complete"
		result.reason = ""
	owner._action_sample_enabled = false
	_pause(lab)
	lab._pitch_actor.trace_sampled.disconnect(trace)
	lab._pitch_actor.segment_advanced.disconnect(segment)
	lab._pitch_actor.flight_stopped.disconnect(stopped)
	lab._ball_play_resolver.play_resolved.disconnect(resolved)
	lab.child_entered_tree.disconnect(entered)
	_close_runtime(context)
	await parent.get_tree().process_frame
	_native_frame_checks(check, label, result)
	return result


static func _native_frame_context(context: Dictionary) -> bool:
	var lab: PitchBatLab = context.lab
	return (
		is_instance_valid(lab)
		and not lab.is_queued_for_deletion()
		and context.owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and context.owner._time_profile == context.sample_mode
		and lab.is_processing()
		and lab.is_physics_processing()
		and lab._pitch_actor.is_physics_processing()
		and not lab.get_tree().paused
		and Engine.physics_ticks_per_second == 60
		and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and DisplayServer.get_name() != "headless"
		and MatchAutomation.presented(lab)
		and context.viewport.own_world_3d
		and context.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
	)


static func _native_frame_stamp(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> Dictionary:
	return {
		"us": Time.get_ticks_usec(),
		"draw": Engine.get_frames_drawn(),
		"physics": Engine.get_physics_frames(),
		"phase": int(lab._match_state.phase),
		"actions": owner._action_samples.duplicate(true)
	}


static func _native_frame_delta(current: Dictionary, before: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in ["action_allowed", "continue_action"]:
		var after: Dictionary = current.get(key, {})
		var prior: Dictionary = before.get(key, {})
		result[key] = {
			"calls": int(after.get("calls", 0)) - int(prior.get("calls", 0)),
			"elapsed_us": int(after.get("elapsed_us", 0)) - int(prior.get("elapsed_us", 0)),
			"refused": int(after.get("refused", 0)) - int(prior.get("refused", 0))
		}
	return result


static func _native_frame_window(current: Dictionary, before: Dictionary) -> Dictionary:
	return {
		"elapsed_us": int(current.us) - int(before.us),
		"draw_delta": int(current.draw) - int(before.draw),
		"physics_delta": int(current.physics) - int(before.physics),
		"actions": _native_frame_delta(current.actions, before.actions)
	}


static func _native_frame_row(
	result: Dictionary,
	window: int,
	owner: StadiumSurfaceNightRuntime,
	lab: PitchBatLab,
	previous: Dictionary,
	observed: Dictionary
) -> Dictionary:
	var current: Dictionary = _native_frame_stamp(owner, lab)
	var counters: Dictionary = _native_frame_delta(current.actions, previous.actions)
	_native_frame_pitch_state(lab, observed)
	result.rows.append(
		[
			window,
			int(current.us) - int(previous.us),
			current.draw,
			current.physics,
			previous.phase,
			current.phase,
			lab._pitch_actor.running,
			lab._ball_in_play_is_live(),
			counters.action_allowed.calls,
			counters.action_allowed.elapsed_us,
			counters.action_allowed.refused,
			counters.continue_action.calls,
			counters.continue_action.elapsed_us,
			counters.continue_action.refused,
			roundi(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0),
			roundi(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000000.0),
			observed.pitch_simulation_us,
			_native_frame_position_mm(observed.pitch_position),
			_native_frame_position_mm(observed.pitch_velocity),
			observed.segments,
			observed.releases
		]
	)
	return current


static func _native_frame_unrefused(actions: Dictionary) -> bool:
	return (
		int(actions.action_allowed.calls) > 0
		and int(actions.continue_action.calls) > 0
		and int(actions.action_allowed.refused) == 0
		and int(actions.continue_action.refused) == 0
	)


static func _native_frame_trace(_point: Vector3, lab: PitchBatLab, observed: Dictionary) -> void:
	_native_frame_pitch_state(lab, observed)
	var actor: PitchFlightActor = lab._pitch_actor
	if (
		actor.running
		and actor.state != null
		and actor.parameters != null
		and actor.parameters != observed.parameters
	):
		observed.parameters = actor.parameters
		observed.releases += 1


static func _native_frame_segment(
	_previous: Vector3, _elapsed: float, lab: PitchBatLab, observed: Dictionary
) -> void:
	observed.segments += 1
	_native_frame_pitch_state(lab, observed)


static func _native_frame_stopped(
	reason: StringName, lab: PitchBatLab, observed: Dictionary
) -> void:
	_native_frame_pitch_state(lab, observed)
	observed.stop_reason = String(reason)
	lab._at_bat_cadence.stop()


static func _native_frame_resolved(
	_outcome: BallPlayOutcome, lab: PitchBatLab, observed: Dictionary
) -> void:
	observed.terminal = true
	lab._at_bat_cadence.stop()


static func _native_frame_child(child: Node, lab: PitchBatLab, observed: Dictionary) -> void:
	if child is BattedBallBody:
		child.launch_started.connect(
			_native_frame_launched.bind(lab, observed, child), Object.CONNECT_ONE_SHOT
		)


static func _native_frame_launched(
	_point: Vector3, lab: PitchBatLab, observed: Dictionary, ball: BattedBallBody
) -> void:
	observed.launches += 1
	observed.ball = ball
	observed.play = lab._ball_play_resolver.state
	var contact: ContactResult = lab._swing_tracker.result
	observed.contact = (
		contact != null
		and contact.outcome != ContactResult.Outcome.MISS
		and lab._batted_ball == ball
		and ball.get_parent() == lab
		and ball.get_script() == BattedBallBody
		and ball._started
		and not ball.freeze
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY
	)


static func _native_frame_observe(lab: PitchBatLab, observed: Dictionary) -> void:
	var physics: int = Engine.get_physics_frames()
	var actor: PitchFlightActor = lab._pitch_actor
	if (
		actor.running
		and actor.state != null
		and actor.parameters != null
		and actor.state.elapsed_time > 0.0
		and lab._match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT
	):
		var key: int = actor.parameters.get_instance_id()
		if not observed.pitch_views.has(key):
			observed.pitch_views[key] = {
				"draws": 0,
				"physics": physics,
				"position": actor.state.position,
				"elapsed": actor.state.elapsed_time,
				"moved": false
			}
		var view: Dictionary = observed.pitch_views[key]
		view.draws += 1
		view.moved = (
			view.moved
			or (
				physics != view.physics
				and actor.state.position != view.position
				and actor.state.elapsed_time > float(view.elapsed)
			)
		)
		observed.pitch_draws = maxi(int(observed.pitch_draws), int(view.draws))
		observed.pitch_moved = observed.pitch_moved or view.moved
	var ball: BattedBallBody = observed.ball
	if (
		is_instance_valid(ball)
		and lab._batted_ball == ball
		and ball.get_parent() == lab
		and ball.get_script() == BattedBallBody
		and ball._started
		and not ball.freeze
		and ball.physics_contact_router.is_valid()
		and lab._ball_play_resolver.state == observed.play
		and observed.play != null
		and not observed.play.dead
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY
	):
		if observed.ball_draws == 0:
			observed.ball_first = ball.global_position
			observed.ball_first_physics = physics
		observed.ball_draws += 1
		observed.ball_last = ball.global_position
		observed.ball_last_physics = physics
		observed.ball_moved = (
			physics != observed.ball_first_physics and ball.global_position != observed.ball_first
		)


static func _native_frame_position_mm(value: Vector3) -> Array:
	return [roundi(value.x * 1000.0), roundi(value.y * 1000.0), roundi(value.z * 1000.0)]


static func _native_frame_checks(check: Callable, label: String, result: Dictionary) -> void:
	var size: int = JSON.stringify(result, "", true, true).to_utf8_buffer().size()
	if size > 131000:
		# Explicit failed evidence cap, never a successful truncated frame sample.
		result.rows.clear()
		result.windows.clear()
		result["context"] = {}
		result.idle24 = false
		result.native_pitch = false
		result.native_batted = false
		result.reason = "evidence_size_cap"
		result["untrimmed_bytes"] = size
	if not result.idle24 or not result.native_pitch or not result.native_batted:
		print(
			(
				"FLOODLIGHT_NATIVE_FRAME_FAILURE "
				+ JSON.stringify(
					{
						"label": label,
						"stage": result.stage,
						"reason": result.reason,
						"idle24": result.idle24,
						"pitch": result.native_pitch,
						"batted": result.native_batted,
						"evidence": result.get("evidence", {})
					},
					"",
					true,
					true
				)
			)
		)
	check.call(result.idle24, label + " native presented idle24")
	check.call(result.native_pitch, label + " native presented pitch")
	check.call(result.native_batted, label + " native presented batted flight")


static func _noop_branch_probes(check: Callable, label: String) -> Dictionary:
	# Pure predicates on a detached disposable lab; no gameplay/guard callback is invoked.
	var lab: PitchBatLab = PitchBatLab.new()
	lab._automation = MatchAutomation.new()
	var result: Dictionary = {}
	var release: PitchReleaseController = PitchReleaseController.new()
	lab._release_controller = release
	var row: Dictionary = {"inactive": PitchBatLabFeelSupport.continuous_release_noop(lab)}
	release.active = true
	row["active_refused"] = not PitchBatLabFeelSupport.continuous_release_noop(lab)
	release.active = false
	lab._release_controller = ForeignRelease.new()
	row["foreign_refused"] = not PitchBatLabFeelSupport.continuous_release_noop(lab)
	lab._release_controller = null
	row["null_semantics"] = PitchBatLabFeelSupport.continuous_release_noop(lab)
	lab._release_controller = release
	row["restored"] = PitchBatLabFeelSupport.continuous_release_noop(lab)
	lab._automation = null
	row["manual_refused"] = not PitchBatLabFeelSupport.continuous_release_noop(lab)
	lab._automation = MatchAutomation.new()
	result["release"] = row
	var home: PitchBatLabHomeRun = PitchBatLabHomeRun.new()
	lab._home_run = home
	row = {"inactive": PitchBatLabFeelSupport.home_run_noop(lab)}
	home.active = true
	row["active_refused"] = not PitchBatLabFeelSupport.home_run_noop(lab)
	home.active = false
	lab._home_run = ForeignHomeRun.new()
	row["foreign_refused"] = not PitchBatLabFeelSupport.home_run_noop(lab)
	lab._home_run = null
	row["null_semantics"] = not PitchBatLabFeelSupport.home_run_noop(lab)
	lab._home_run = home
	row["restored"] = PitchBatLabFeelSupport.home_run_noop(lab)
	result["home_run"] = row
	var cadence: AtBatCadenceController = AtBatCadenceController.new()
	lab._at_bat_cadence = cadence
	row = {"inactive": PitchBatLabFeelSupport.cadence_noop(lab)}
	cadence.state = AtBatCadenceController.State.DELIVERY
	row["active_refused"] = not PitchBatLabFeelSupport.cadence_noop(lab)
	cadence.state = AtBatCadenceController.State.DEAD_BALL_HOLD
	row["hold_refused"] = not PitchBatLabFeelSupport.cadence_noop(lab)
	cadence.state = AtBatCadenceController.State.PITCH_LIVE
	row["live_noop"] = PitchBatLabFeelSupport.cadence_noop(lab)
	lab._at_bat_cadence = ForeignCadence.new()
	row["foreign_refused"] = not PitchBatLabFeelSupport.cadence_noop(lab)
	lab._at_bat_cadence = null
	row["null_semantics"] = PitchBatLabFeelSupport.cadence_noop(lab)
	lab._at_bat_cadence = cadence
	lab._home_run = ForeignHomeRun.new()
	row["foreign_home_refused"] = not PitchBatLabFeelSupport.cadence_noop(lab)
	lab._home_run = home
	row["restored"] = PitchBatLabFeelSupport.cadence_noop(lab)
	result["cadence"] = row
	var tracker: SwingContactTracker = SwingContactTracker.new()
	lab._swing_tracker = tracker
	row = {"inactive": PitchBatLabFeelSupport.swing_noop(lab)}
	tracker.active = true
	row["active_refused"] = not PitchBatLabFeelSupport.swing_noop(lab)
	tracker.active = false
	lab._swing_tracker = ForeignSwingTracker.new()
	row["foreign_refused"] = not PitchBatLabFeelSupport.swing_noop(lab)
	lab._swing_tracker = null
	row["null_semantics"] = PitchBatLabFeelSupport.swing_noop(lab)
	lab._swing_tracker = tracker
	row["restored"] = PitchBatLabFeelSupport.swing_noop(lab)
	result["swing"] = row
	for key: String in ["release", "home_run", "cadence", "swing"]:
		var passed: bool = true
		for value: Variant in result[key].values():
			passed = passed and value is bool and value
		if not passed:
			print(
				(
					"FLOODLIGHT_NOOP_PROBE_FAILURE "
					+ JSON.stringify({"branch": key, "operands": result[key]})
				)
			)
		check.call(passed, label + " exact no-op branch " + key)
	lab.free()
	return result


static func _noop_callback_case(
	parent: Node3D, check: Callable, paid: ClubAssetLedger, config: Dictionary, kind: String
) -> Dictionary:
	var flags: Dictionary = {
		"kind": kind,
		"installed": false,
		"fired": false,
		"foreign_script": false,
		"post_guard_retired": false,
		"material_restored": false,
		"sticky": false,
		"cadence_unchanged": false,
		"no_ball": false,
		"actual_callback": false
	}
	var setup: Dictionary = _native_comparison_season(paid, config)
	var context: Dictionary = {}
	if setup.ok:
		setup.season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_time_policy(
			setup.season, paid, "night"
		)
		context = _open_runtime(parent, paid, setup.season, false)
		flags.installed = context.installed
	if not flags.installed:
		if not context.is_empty():
			_close_runtime(context)
			await parent.get_tree().process_frame
		check.call(false, config.label + " actual no-op fallback callback " + kind)
		return flags
	var lab: PitchBatLab = context.lab
	var owner: StadiumSurfaceNightRuntime = context.owner
	var material: StandardMaterial3D
	for row: Dictionary in owner._towers[0].geometry.resources:
		if row.resource is StandardMaterial3D:
			material = row.resource
			break
	if material == null:
		_close_runtime(context)
		await parent.get_tree().process_frame
		check.call(false, config.label + " no-op callback source material exists")
		return flags
	var original: float = material.roughness
	var observed: Dictionary = {
		"fired": false,
		"calls": 0,
		"cadence": -1,
		"cadence_elapsed": -1.0,
		"process_before": Engine.get_process_frames(),
		"physics_before": Engine.get_physics_frames(),
		"callback_process": -1,
		"callback_physics": -1
	}
	var mutation: Callable = _noop_mutate_material.bind(lab, material, original, observed)
	var home: PitchBatLabHomeRun = lab._home_run
	var tracker: SwingContactTracker = lab._swing_tracker
	var arm: Callable
	if kind == "home_run":
		var foreign: ForeignHomeRun = ForeignHomeRun.new()
		foreign.mutation = mutation
		lab._home_run = foreign
		flags.foreign_script = foreign.get_script() != PitchBatLabHomeRun
	else:
		var foreign: ForeignSwingTracker = ForeignSwingTracker.new()
		foreign.mutation = mutation
		arm = _noop_arm_tracker.bind(lab, foreign)
		lab._pitch_actor.trace_sampled.connect(arm, Object.CONNECT_ONE_SHOT)
		flags.foreign_script = foreign.get_script() != SwingContactTracker
	lab._at_bat_cadence.stop()
	lab.set_process(true)
	lab.set_physics_process(true)
	if kind == "swing":
		PitchBatLabFeelSupport.begin_ai_delivery(lab)
	var started_us: int = Time.get_ticks_usec()
	for frame in range(24):
		if Time.get_ticks_usec() - started_us >= 10000000:
			break
		await RenderingServer.frame_post_draw
		if observed.fired:
			break
	# frame_post_draw can still belong to the frame that enabled the lab.
	# Observe its completed process boundary before the unchanged strict witness.
	if observed.fired and kind == "home_run":
		await parent.get_tree().process_frame
	flags["counter_witness"] = {
		"process_before": observed.process_before,
		"process_after": Engine.get_process_frames(),
		"callback_process": observed.callback_process,
		"physics_before": observed.physics_before,
		"physics_after": Engine.get_physics_frames(),
		"callback_physics": observed.callback_physics
	}
	flags.fired = observed.fired and observed.calls == 1
	flags.actual_callback = (
		Engine.get_process_frames() > observed.process_before
		if kind == "home_run"
		else Engine.get_physics_frames() > observed.physics_before
	)
	flags.post_guard_retired = (
		owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
		and not lab.is_processing()
		and not lab.is_physics_processing()
	)
	flags.cadence_unchanged = (
		int(lab._at_bat_cadence.state) == observed.cadence
		and lab._at_bat_cadence.elapsed_seconds == observed.cadence_elapsed
	)
	flags.no_ball = not is_instance_valid(lab._batted_ball)
	material.roughness = original
	flags.material_restored = material.roughness == original
	flags.sticky = (
		not StadiumSurfaceNightRuntime.action_allowed(lab)
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ABANDONED
	)
	_pause(lab)
	if arm.is_valid() and lab._pitch_actor.trace_sampled.is_connected(arm):
		lab._pitch_actor.trace_sampled.disconnect(arm)
	lab._home_run = home
	lab._swing_tracker = tracker
	_close_runtime(context)
	await parent.get_tree().process_frame
	var passed: bool = true
	for key: String in flags:
		if key != "kind" and key != "counter_witness":
			passed = passed and flags[key] is bool and flags[key]
	if not passed:
		print("FLOODLIGHT_NOOP_CALLBACK_FAILURE " + JSON.stringify(flags, "", true, true))
	check.call(passed, config.label + " actual no-op fallback callback " + kind)
	return flags


static func _noop_mutate_material(
	lab: PitchBatLab, material: StandardMaterial3D, original: float, observed: Dictionary
) -> void:
	observed.calls += 1
	if observed.fired:
		return
	observed.fired = true
	observed.callback_process = Engine.get_process_frames()
	observed.callback_physics = Engine.get_physics_frames()
	observed.cadence = int(lab._at_bat_cadence.state)
	observed.cadence_elapsed = lab._at_bat_cadence.elapsed_seconds
	material.roughness = 0.25 if original != 0.25 else 0.75


static func _noop_arm_tracker(
	_point: Vector3, lab: PitchBatLab, tracker: ForeignSwingTracker
) -> void:
	lab._swing_tracker = tracker
	tracker.active = true
