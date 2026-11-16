class_name StadiumGrandIIIEnvironmentV1
extends RefCounted
## Exact 19:10 clear artistic preset, not geographic/date astronomy or a night certificate.
## Render revision2: bounded coverage/ambient trial; authored profile family remains unchanged.
## Reversible sky/sun plus four issued premium towers; native readability remains unqualified.

const VERSION: int = 2
const ENVIRONMENT_VERSION: int = 5
const PROFILE: String = "GRAND-III-1910-CLEAR-v1"
const TIME_ENVIRONMENT_VERSION: int = 8
const TIME_RENDER_VERSION: int = 3
const TIME_SKY_SHADER: Shader = preload(
	"res://src/presentation/stadium/stadium_game_stars.gdshader"
)
static var _issued: Dictionary = {}


static func lighting() -> Dictionary:
	var result: Dictionary = StadiumGrandIEnvironmentV1.lighting()
	result.active_lights = StadiumGrandIIILightingV1.contract()
	return result


static func capture(seed: int) -> Dictionary:
	if seed < 0 or seed > 2147483647:
		return {}
	return {
		"version": ENVIRONMENT_VERSION,
		"seed": seed,
		"fixture": 32,
		"mode": "night",
		"profile": PROFILE,
		"time": "19:10",
		"weather": "clear",
		"render_profile": VERSION,
		"lighting": lighting()
	}


static func capture_time(seed: int, mode: String) -> Dictionary:
	if seed < 0 or seed > 2147483647 or mode not in ["day", "sunset", "night"]:
		return {}
	var start: int = {"day": 790, "sunset": 970, "night": 1150}[mode]
	return {
		"version": TIME_ENVIRONMENT_VERSION,
		"seed": seed,
		"fixture": 32,
		"mode": mode,
		"profile": "GRAND-III-TIME-%s-v2" % mode.to_upper(),
		"time": "%02d:%02d" % [start / 60, start % 60],
		"weather": "clear",
		"render_profile": TIME_RENDER_VERSION,
		"start_minute": start,
		"rule": StadiumSurfaceNightSnapshot.CLOCK_RULE,
		"lighting":
		{
			"profile": "grand-iii-shared-time-v2",
			"active_lights": StadiumGrandIIILightingV1.contract()
		}
	}


static func valid(value: Variant) -> bool:
	if value is Dictionary and value.get("version") == TIME_ENVIRONMENT_VERSION:
		return (
			StadiumNpcSnapshot._keys(
				value,
				[
					"version",
					"seed",
					"fixture",
					"mode",
					"profile",
					"time",
					"weather",
					"render_profile",
					"lighting",
					"start_minute",
					"rule"
				]
			)
			and SeasonOwnership._whole(value.seed, 0, 2147483647)
			and value.mode is String
			and StadiumNpcSnapshot._json_types(value)
			and not capture_time(int(value.seed), value.mode).is_empty()
			and _same_profile(value, capture_time(int(value.seed), value.mode))
		)
	return (
		StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"fixture",
				"mode",
				"profile",
				"time",
				"weather",
				"render_profile",
				"lighting"
			]
		)
		and SeasonOwnership._whole(value.seed, 0, 2147483647)
		and StadiumNpcSnapshot._json_types(value)
		and _same_profile(value, capture(int(value.seed)))
	)


static func apply(lab: PitchBatLab, environment: Dictionary) -> Dictionary:
	_prune()
	if environment.get("version") == TIME_ENVIRONMENT_VERSION:
		return _apply_time(lab, environment)
	var lease: Dictionary = StadiumGrandIEnvironmentV1.apply(lab, environment, false, true)
	if lease.is_empty():
		return {}
	# Keep original issuance, and separate cleanup preimages unavailable through shallow aliases.
	var state: Dictionary = lease.duplicate(true)
	state.active_lighting = lease.active_lighting
	_issued[lab.get_instance_id()] = {"lease": lease, "state": state}
	return lease


static func installed(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.get("time_profile", false):
		return _time_installed(lab, lease, state)
	if state.is_empty() or state.restored or lease.size() != state.size():
		return false
	for key: String in state:
		if (
			not lease.has(key)
			or typeof(lease[key]) != typeof(state[key])
			or not is_same(lease[key], state[key])
		):
			return false
	return StadiumGrandIEnvironmentV1.installed(lab, state, false, true)


static func restore(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.is_empty():
		return false
	if state.get("time_profile", false):
		return _restore_time(lab, lease, state)
	# Original light lease survives public replacement with a shallow duplicate or malformed value.
	var restored: bool = StadiumGrandIEnvironmentV1.restore(lab, state, false, true)
	lease["restored"] = state.restored
	return restored


static func _state(lab: PitchBatLab, lease: Dictionary) -> Dictionary:
	if not is_instance_valid(lab) or not _issued.has(lab.get_instance_id()):
		return {}
	var issued: Dictionary = _issued[lab.get_instance_id()]
	return (
		issued.state if is_same(lease, issued.lease) and issued.state.lab.get_ref() == lab else {}
	)


static func _same_profile(value: Variant, expected: Variant, depth: int = 0) -> bool:
	if depth > 16:
		return false
	if expected is Dictionary:
		if not value is Dictionary or value.size() != expected.size():
			return false
		for key: String in expected:
			if not value.has(key) or not _same_profile(value[key], expected[key], depth + 1):
				return false
		return true
	if expected is Array:
		if not value is Array or value.size() != expected.size():
			return false
		for index in range(expected.size()):
			if not _same_profile(value[index], expected[index], depth + 1):
				return false
		return true
	if expected is int or expected is float:
		return (
			(value is int or value is float)
			and is_finite(float(value))
			and float(value) == float(expected)
		)
	return typeof(value) == typeof(expected) and value == expected


static func _prune() -> void:
	# Cold admission only; live and restored leases retain their original identities.
	for key: int in _issued.keys():
		if not is_instance_valid(_issued[key].state.lab.get_ref()):
			_issued.erase(key)


static func _apply_time(lab: PitchBatLab, environment: Dictionary) -> Dictionary:
	if (
		not is_instance_valid(lab)
		or not valid(environment)
		or (
			_issued.has(lab.get_instance_id()) and not _issued[lab.get_instance_id()].state.restored
		)
		or not is_instance_valid(lab._world_environment)
		or not is_instance_valid(lab._pitch_actor)
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._pitch_actor.running
		or is_instance_valid(lab._batted_ball)
	):
		diagnose_install(lab, "environment/preflight")
		return {}
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	var world: WorldEnvironment = lab._world_environment
	var sun: DirectionalLight3D = (
		lab.get_node_or_null("StarterFieldGeometry/Sun") as DirectionalLight3D
	)
	if (
		not is_instance_valid(property)
		or property.venue_id != "GRAND-III"
		or not property.is_inside_tree()
		or property.suspended
		or property.bound_state != lab._match_state
		or not StadiumNpcSnapshot.valid(property.public_snapshot)
		or not ClubCareer.same(property.public_snapshot.environment, environment)
		or world.get_script() != null
		or world.get_parent() != lab
		or lab.get_node_or_null("LabWorldEnvironment") != world
		or world.environment == null
		or sun == null
		or sun.get_script() != null
	):
		diagnose_install(lab, "environment/property-world-sun")
		return {}
	var before: Environment = world.environment
	var original_guards: Array[Dictionary] = [StadiumGrandIIILightingV1._guard(before)]
	var sky_values: Dictionary = {}
	if before.sky != null:
		if not before.sky.sky_material is ProceduralSkyMaterial:
			diagnose_install(lab, "environment/original-sky-material")
			return {}
		original_guards.append(StadiumGrandIIILightingV1._guard(before.sky))
		original_guards.append(StadiumGrandIIILightingV1._guard(before.sky.sky_material))
		sky_values = {
			"sky_top_color": before.sky.sky_material.sky_top_color,
			"sky_horizon_color": before.sky.sky_material.sky_horizon_color
		}
	var day: Dictionary = {
		"environment": {"ambient_light_energy": before.ambient_light_energy},
		"sun": {"color": sun.light_color, "energy": sun.light_energy},
		"pigment": 1.0
	}
	var values: Dictionary = StadiumSurfaceNightRuntime.time_values(
		environment.mode, 0.0, day, sky_values
	)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = TIME_SKY_SHADER
	for key: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		material.set_shader_parameter(key, values[key])
	var sky: Sky = Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.sky_material = material
	var next: Environment = before.duplicate() as Environment
	next.sky = sky
	for key: String in _environment_values(values):
		next.set(key, _environment_values(values)[key])
	var lease: Dictionary = {
		"lab": weakref(lab),
		"world": world,
		"sun": sun,
		"before_environment": before,
		"before_rotation": sun.rotation,
		"before_color": sun.light_color,
		"before_energy": sun.light_energy,
		"before_shadows": sun.shadow_enabled,
		"applied_environment": next,
		"applied_sky": sky,
		"applied_material": material,
		"active_lighting": {},
		"time_profile": true,
		"restored": false
	}
	var state: Dictionary = {
		"lab": lease.lab,
		"property": property,
		"match": lab._match_state,
		"pitch": lab._pitch_actor,
		"viewport": lab.get_viewport(),
		"lease": lease,
		"public": lease.duplicate(true),
		"environment": JSON.stringify(environment, "", true, true),
		"mode": environment.mode,
		"day": day,
		"sky_values": sky_values,
		"original_guards": original_guards,
		"guards":
		[
			StadiumGrandIIILightingV1._guard(next),
			StadiumGrandIIILightingV1._guard(sky),
			StadiumGrandIIILightingV1._guard(material),
			StadiumGrandIIILightingV1._guard(sun),
			StadiumGrandIIILightingV1._guard(TIME_SKY_SHADER)
		],
		"time_profile": true,
		"restored": false,
		"installing": true,
		"updating": true,
		"restoring": false,
		"interrupted": false,
		"pending": {},
		"plays": 0,
		"halves": 0,
		"progress": 0.0,
		"write_plays": lab._play_records.size(),
		"write_halves": _halves(lab._match_state),
		"target_lamps": values.lamps
	}
	_issued[lab.get_instance_id()] = {"lease": lease, "state": state}
	world.environment = next
	if (
		not installation_intact(lab, lease)
		or not _write_value(lab, lease, sun, &"light_color", values.sun)
		or not _write_value(lab, lease, sun, &"light_energy", _float32(values.sun_energy))
	):
		diagnose_install(lab, "environment/initial-palette")
		_restore_time(lab, lease, state)
		return {}
	var lights: Dictionary = StadiumGrandIIILightingV1.apply_time(lab, property, lease)
	lease.active_lighting = lights
	state.public.active_lighting = lights
	if (
		lights.is_empty()
		or not installation_intact(lab, lease)
		or not StadiumGrandIIILightingV1.update_time(lab, lights, lease, values.lamps)
	):
		diagnose_install(lab, "environment/lights-or-initial-energy")
		_restore_time(lab, lease, state)
		return {}
	state.installing = false
	state.updating = false
	if not installed(lab, lease):
		diagnose_install(lab, "environment/final-installed")
		_restore_time(lab, lease, state)
		return {}
	return lease


static func _environment_values(values: Dictionary) -> Dictionary:
	return {
		"background_mode": Environment.BG_SKY,
		"background_color": values.horizon_color,
		"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
		"ambient_light_color": values.ambient,
		"ambient_light_energy": _float32(values.ambient_energy),
		"reflected_light_source": Environment.REFLECTION_SOURCE_DISABLED
	}


static func _time_owners(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	if (
		not is_instance_valid(lab)
		or not lab.is_inside_tree()
		or lab.is_queued_for_deletion()
		or state.is_empty()
		or state.restored
		or not is_same(state.lease, lease)
		or lease != state.public
		or not is_instance_valid(state.property)
		or state.property.get_script() != StadiumNpcPublicProperty
		or not is_instance_valid(state.pitch)
		or lab._match_state != state.match
		or state.property.bound_state != state.match
		or StadiumNpcPublicRuntime._property(lab) != state.property
		or state.property.get_parent() != lab.get_node_or_null("StarterFieldGeometry")
		or not state.property.is_inside_tree()
		or state.property.is_queued_for_deletion()
		or lab._pitch_actor != state.pitch
		or state.pitch.get_script() != PitchFlightActor
		or not is_instance_valid(state.viewport)
		or lab.get_viewport() != state.viewport
		or not is_instance_valid(lease.world)
		or not is_instance_valid(lease.sun)
		or lab._world_environment != lease.world
		or lease.world.get_parent() != lab
		or lease.world.get_script() != null
		or lab.get_node_or_null("LabWorldEnvironment") != lease.world
		or lab.get_node_or_null("StarterFieldGeometry/Sun") != lease.sun
		or not is_instance_valid(lease.applied_environment)
		or not is_instance_valid(lease.applied_sky)
		or not is_instance_valid(lease.applied_material)
		or lease.world.environment != lease.applied_environment
		or lease.applied_environment.sky != lease.applied_sky
		or lease.applied_sky.sky_material != lease.applied_material
		or lease.applied_material.shader != TIME_SKY_SHADER
	):
		return false
	return (
		(
			JSON.stringify(state.property.public_snapshot.environment, "", true, true)
			== state.environment
		)
		and StadiumGrandIIILightingV1._guards_match(state.original_guards)
		and StadiumGrandIIILightingV1._guards_match(state.guards)
	)


static func _time_installed(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	return (
		not state.interrupted
		and not state.restoring
		and _time_owners(lab, lease, state)
		and not state.property.suspended
		and not lease.active_lighting.is_empty()
		and StadiumGrandIIILightingV1.installed(lab, lease.active_lighting)
	)


static func _safe_tuple(lab: PitchBatLab, state: Dictionary) -> bool:
	return (
		state.match.phase == MatchState.Phase.PRE_PITCH
		and not state.pitch.running
		and not is_instance_valid(lab._batted_ball)
		and lab._play_records.size() == state.write_plays
		and _halves(state.match) == state.write_halves
	)


static func installation_intact(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	return (
		not state.is_empty()
		and state.get("installing", false)
		and state.updating
		and _time_owners(lab, lease, state)
		and not state.property.suspended
		and _safe_tuple(lab, state)
	)


static func time_write_intact(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if (
		state.is_empty()
		or not state.get("updating", false)
		or state.interrupted
		or state.restoring
		or not _time_owners(lab, lease, state)
		or state.property.suspended
		or not _safe_tuple(lab, state)
	):
		return false
	if state.installing:
		return (
			lease.active_lighting.is_empty()
			or StadiumGrandIIILightingV1.installed(lab, lease.active_lighting)
		)
	return StadiumNpcPublicRuntime.callback_bound(lab, state.property)


static func lamp_write_intact(
	lab: PitchBatLab, lease: Dictionary, lights: Dictionary, fraction: float
) -> bool:
	var state: Dictionary = _state(lab, lease)
	return (
		not state.is_empty()
		and state.get("time_profile", false)
		and is_same(lease.active_lighting, lights)
		and state.target_lamps == fraction
		and time_write_intact(lab, lease)
	)


static func owns_dynamic_resource(lab: PitchBatLab, lease: Dictionary, resource: Resource) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.is_empty() or not state.get("time_profile", false) or state.restored:
		return false
	if resource == lease.applied_environment or resource == lease.applied_material:
		return true
	return StadiumGrandIIILightingV1.owns_dynamic_resource(lab, lease.active_lighting, resource)


static func dynamic_resource_change(
	lab: PitchBatLab, lease: Dictionary, resource: Resource
) -> bool:
	var state: Dictionary = _state(lab, lease)
	if (
		state.is_empty()
		or not state.get("time_profile", false)
		or not time_write_intact(lab, lease)
	):
		return false
	# Exactly the one issued resource/setter currently in flight, with every expected operand checked.
	if not state.pending.is_empty():
		return (
			state.pending.object == resource
			and resource.get(state.pending.field) == state.pending.value
		)
	return StadiumGrandIIILightingV1.dynamic_resource_change(lab, lease.active_lighting, resource)


static func _write_value(
	lab: PitchBatLab, lease: Dictionary, object: Object, field: StringName, value: Variant
) -> bool:
	if not time_write_intact(lab, lease):
		diagnose_install(lab, "palette/pre-write/" + String(field))
		return false
	var state: Dictionary = _state(lab, lease)
	var guard: Dictionary = {}
	for candidate: Dictionary in state.guards:
		if candidate.object == object:
			guard = candidate
	if guard.is_empty() or not guard.keys.has(field):
		diagnose_install(lab, "palette/unissued-field/" + String(field))
		return false
	# Set the exact native post-value before the setter can emit Resource.changed.
	guard.values[guard.keys.find(field)] = value
	state.pending = {"object": object, "field": field, "value": value}
	object.set(field, value)
	var valid_write: bool = time_write_intact(lab, lease)
	if not valid_write:
		diagnose_install(lab, "palette/post-write/" + String(field))
	state.pending = {}
	return valid_write


static func advance_time(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.is_empty():
		return false
	if not state.get("time_profile", false):
		return true
	if state.updating or not installed(lab, lease):
		return false
	if (
		state.match.phase != MatchState.Phase.PRE_PITCH
		or state.pitch.running
		or is_instance_valid(lab._batted_ball)
	):
		return true
	var plays: int = lab._play_records.size()
	var halves: int = _halves(state.match)
	if plays < state.plays or halves < state.halves:
		return false
	if plays == state.plays and halves == state.halves:
		return true
	var clock: Dictionary = StadiumSurfaceNightSnapshot.clock(state.mode, plays, halves)
	if clock.is_empty():
		return false
	var progress: float = minf(
		StadiumSurfaceNightSnapshot.drift(state.mode, clock), state.progress + 0.002
	)
	var values: Dictionary = StadiumSurfaceNightRuntime.time_values(
		state.mode, progress, state.day, state.sky_values
	)
	state.write_plays = plays
	state.write_halves = halves
	state.target_lamps = values.lamps
	state.updating = true
	var applied: bool = _write_palette(lab, lease, values)
	state.updating = false
	if not applied:
		state.interrupted = true
		return false
	state.plays = plays
	state.halves = halves
	state.progress = progress
	return installed(lab, lease)


static func _write_palette(lab: PitchBatLab, lease: Dictionary, values: Dictionary) -> bool:
	for key: String in _environment_values(values):
		if not _write_value(
			lab, lease, lease.applied_environment, StringName(key), _environment_values(values)[key]
		):
			return false
	for key: StringName in StadiumSurfaceNightRuntime.SKY_PARAMETERS:
		if not _write_value(
			lab,
			lease,
			lease.applied_material,
			StringName("shader_parameter/" + String(key)),
			values[key]
		):
			return false
	return (
		_write_value(lab, lease, lease.sun, &"light_color", values.sun)
		and _write_value(lab, lease, lease.sun, &"light_energy", _float32(values.sun_energy))
		and StadiumGrandIIILightingV1.update_time(lab, lease.active_lighting, lease, values.lamps)
	)


static func _restore_time(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	if state.restoring:
		return false
	if state.restored:
		return _time_restored(lab, lease, state)
	state.restoring = true
	var restored: bool = _restore_time_owned(lab, lease, state)
	state.restoring = false
	if not restored:
		state.interrupted = true
	return restored


static func _restore_time_owned(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	# Independently issued lamps/atlas can be cleaned even when the separate sky graph was replaced.
	# That never supplies authority to restore or modify the replacement environment resource.
	if (
		not is_instance_valid(lab)
		or lab._match_state != state.match
		or not is_same(state.lease, lease)
		or lease != state.public
		or not is_instance_valid(state.property)
		or state.property.get_script() != StadiumNpcPublicProperty
		or state.property.bound_state != state.match
		or StadiumNpcPublicRuntime._property(lab) != state.property
		or not is_instance_valid(state.viewport)
		or lab.get_viewport() != state.viewport
	):
		return false
	var environment_owned: bool = _time_owners(lab, lease, state)
	state.updating = false
	state.installing = false
	if (
		not lease.active_lighting.is_empty()
		and not StadiumGrandIIILightingV1.restore(lab, lease.active_lighting)
	):
		return false
	if not environment_owned or not _time_owners(lab, lease, state):
		return false
	for field: StringName in [&"light_color", &"light_energy"]:
		var value: Variant = lease.before_color if field == &"light_color" else lease.before_energy
		var sun_guard: Dictionary = state.guards[3]
		sun_guard.values[sun_guard.keys.find(field)] = value
		lease.sun.set(field, value)
		if not _time_owners(lab, lease, state):
			return false
	lease.world.environment = lease.before_environment
	if (
		not is_instance_valid(lab)
		or lab._match_state != state.match
		or StadiumNpcPublicRuntime._property(lab) != state.property
		or not is_instance_valid(lease.world)
		or lab._world_environment != lease.world
		or lease.world.environment != lease.before_environment
	):
		return false
	state.restored = true
	lease.restored = true
	state.public.restored = true
	return true


static func _halves(state: MatchState) -> int:
	return (state.inning - 1) * 2 + (0 if state.top_half else 1)


static func _float32(value: float) -> float:
	return PackedFloat32Array([value])[0]


static func _time_restored(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	return (
		is_instance_valid(lab)
		and is_same(lease, state.lease)
		and lease == state.public
		and lab._match_state == state.match
		and is_instance_valid(state.property)
		and StadiumNpcPublicRuntime._property(lab) == state.property
		and state.property.bound_state == state.match
		and is_instance_valid(lease.world)
		and lab._world_environment == lease.world
		and lease.world.get_parent() == lab
		and lease.world.get_script() == null
		and lab.get_node_or_null("LabWorldEnvironment") == lease.world
		and lease.world.environment == lease.before_environment
		and is_instance_valid(lease.sun)
		and lab.get_node_or_null("StarterFieldGeometry/Sun") == lease.sun
		and StadiumGrandIIILightingV1._matches(state.guards[3])
		and StadiumGrandIIILightingV1._guards_match(state.original_guards)
		and StadiumGrandIIILightingV1.time_restored(lab, lease.active_lighting)
	)


static func diagnose_install(lab: PitchBatLab, stage: String) -> void:
	# Failure-only native operand observation. No acceptance predicate or resource is changed.
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or (
			lab._match_state.stadium.get("environment", {}).get("version")
			!= TIME_ENVIRONMENT_VERSION
		)
	):
		return
	print(
		"GRAND_III_TIME_INSTALL_DIAGNOSTIC ",
		JSON.stringify(
			{
				"stage": stage,
				"phase_actual": lab._match_state.phase,
				"phase_expected": MatchState.Phase.PRE_PITCH,
				"pitch_running":
				lab._pitch_actor.running if is_instance_valid(lab._pitch_actor) else null,
				"body_live": is_instance_valid(lab._batted_ball)
			},
			"",
			true,
			true
		)
	)
	_diagnose_preflight(lab, stage)
	if _issued.has(lab.get_instance_id()):
		var state: Dictionary = _issued[lab.get_instance_id()].state
		if state.get("time_profile", false):
			_diagnose_time_owners(lab, state.lease, state, stage)
			if not StadiumGrandIIILightingV1.diagnose_guards(
				state.original_guards, stage + "/original"
			):
				StadiumGrandIIILightingV1.diagnose_guards(state.guards, stage + "/issued")


static func _diagnose_time_owners(
	lab: PitchBatLab, lease: Dictionary, state: Dictionary, stage: String
) -> void:
	if not is_instance_valid(lab):
		_diagnose_predicate(stage, "not is_instance_valid(lab)")
		return
	if not lab.is_inside_tree():
		_diagnose_predicate(stage, "not lab.is_inside_tree()")
		return
	if lab.is_queued_for_deletion():
		_diagnose_predicate(stage, "lab.is_queued_for_deletion()")
		return
	if state.is_empty():
		_diagnose_predicate(stage, "state.is_empty()")
		return
	if state.restored:
		_diagnose_predicate(stage, "state.restored")
		return
	if not is_same(state.lease, lease):
		_diagnose_predicate(stage, "not is_same(state.lease, lease)")
		return
	if lease != state.public:
		_diagnose_predicate(stage, "lease != state.public")
		return
	if not is_instance_valid(state.property):
		_diagnose_predicate(stage, "not is_instance_valid(state.property)")
		return
	if state.property.get_script() != StadiumNpcPublicProperty:
		_diagnose_predicate(stage, "state.property.get_script() != StadiumNpcPublicProperty")
		return
	if not is_instance_valid(state.pitch):
		_diagnose_predicate(stage, "not is_instance_valid(state.pitch)")
		return
	if lab._match_state != state.match:
		_diagnose_predicate(stage, "lab._match_state != state.match")
		return
	if state.property.bound_state != state.match:
		_diagnose_predicate(stage, "state.property.bound_state != state.match")
		return
	if StadiumNpcPublicRuntime._property(lab) != state.property:
		_diagnose_predicate(stage, "StadiumNpcPublicRuntime._property(lab) != state.property")
		return
	if state.property.get_parent() != lab.get_node_or_null("StarterFieldGeometry"):
		_diagnose_predicate(
			stage, 'state.property.get_parent() != lab.get_node_or_null("StarterFieldGeometry")'
		)
		return
	if not state.property.is_inside_tree():
		_diagnose_predicate(stage, "not state.property.is_inside_tree()")
		return
	if state.property.is_queued_for_deletion():
		_diagnose_predicate(stage, "state.property.is_queued_for_deletion()")
		return
	if lab._pitch_actor != state.pitch:
		_diagnose_predicate(stage, "lab._pitch_actor != state.pitch")
		return
	if state.pitch.get_script() != PitchFlightActor:
		_diagnose_predicate(stage, "state.pitch.get_script() != PitchFlightActor")
		return
	if not is_instance_valid(state.viewport):
		_diagnose_predicate(stage, "not is_instance_valid(state.viewport)")
		return
	if lab.get_viewport() != state.viewport:
		_diagnose_predicate(stage, "lab.get_viewport() != state.viewport")
		return
	if not is_instance_valid(lease.world):
		_diagnose_predicate(stage, "not is_instance_valid(lease.world)")
		return
	if not is_instance_valid(lease.sun):
		_diagnose_predicate(stage, "not is_instance_valid(lease.sun)")
		return
	if lab._world_environment != lease.world:
		_diagnose_predicate(stage, "lab._world_environment != lease.world")
		return
	if lease.world.get_parent() != lab:
		_diagnose_predicate(stage, "lease.world.get_parent() != lab")
		return
	if lease.world.get_script() != null:
		_diagnose_predicate(stage, "lease.world.get_script() != null")
		return
	if lab.get_node_or_null("LabWorldEnvironment") != lease.world:
		_diagnose_predicate(stage, 'lab.get_node_or_null("LabWorldEnvironment") != lease.world')
		return
	if lab.get_node_or_null("StarterFieldGeometry/Sun") != lease.sun:
		_diagnose_predicate(stage, 'lab.get_node_or_null("StarterFieldGeometry/Sun") != lease.sun')
		return
	if not is_instance_valid(lease.applied_environment):
		_diagnose_predicate(stage, "not is_instance_valid(lease.applied_environment)")
		return
	if not is_instance_valid(lease.applied_sky):
		_diagnose_predicate(stage, "not is_instance_valid(lease.applied_sky)")
		return
	if not is_instance_valid(lease.applied_material):
		_diagnose_predicate(stage, "not is_instance_valid(lease.applied_material)")
		return
	if lease.world.environment != lease.applied_environment:
		_diagnose_predicate(stage, "lease.world.environment != lease.applied_environment")
		return
	if lease.applied_environment.sky != lease.applied_sky:
		_diagnose_predicate(stage, "lease.applied_environment.sky != lease.applied_sky")
		return
	if lease.applied_sky.sky_material != lease.applied_material:
		_diagnose_predicate(stage, "lease.applied_sky.sky_material != lease.applied_material")
		return
	if lease.applied_material.shader != TIME_SKY_SHADER:
		_diagnose_predicate(stage, "lease.applied_material.shader != TIME_SKY_SHADER")
		return

	if (
		JSON.stringify(state.property.public_snapshot.environment, "", true, true)
		!= state.environment
	):
		_diagnose_predicate(stage, "canonical environment differs from captured environment")
		return


static func _diagnose_predicate(stage: String, predicate: String) -> void:
	print(
		"GRAND_III_TIME_INSTALL_OPERAND ",
		JSON.stringify(
			{"stage": stage, "refusing_predicate": predicate, "actual": true, "expected": false},
			"",
			true,
			true
		)
	)


static func _diagnose_preflight(lab: PitchBatLab, stage: String) -> void:
	# Read-only copies of the corresponding failed admission operands.
	if stage == "stage/admissible-or-source":
		if not StadiumNpcPublicRuntime._public_context(lab):
			_diagnose_predicate(stage, "not _public_context(lab)")
		elif not StadiumNpcPublicRuntime._fresh_match(lab._match_state):
			_diagnose_predicate(stage, "not _fresh_match(lab._match_state)")
		elif not StadiumNpcPublicRuntime._admissible(lab):
			_diagnose_predicate(stage, "not _admissible(lab) remaining host/origin operands")
		elif not StadiumNpcPublicRuntime.source_qualified():
			_diagnose_predicate(stage, "not source_qualified()")
		return
	if stage == "environment/preflight":
		var environment: Dictionary = lab._match_state.stadium.environment
		if not is_instance_valid(lab):
			_diagnose_predicate(stage, "not is_instance_valid(lab)")
			return
		if not valid(environment):
			_diagnose_predicate(stage, "not valid(environment)")
			return
		if _issued.has(lab.get_instance_id()) and not _issued[lab.get_instance_id()].state.restored:
			_diagnose_predicate(
				stage,
				"(_issued.has(lab.get_instance_id()) and not _issued[lab.get_instance_id()].state.restored)"
			)
			return
		if not is_instance_valid(lab._world_environment):
			_diagnose_predicate(stage, "not is_instance_valid(lab._world_environment)")
			return
		if not is_instance_valid(lab._pitch_actor):
			_diagnose_predicate(stage, "not is_instance_valid(lab._pitch_actor)")
			return
		if lab._match_state == null:
			_diagnose_predicate(stage, "lab._match_state == null")
			return
		if lab._match_state.phase != MatchState.Phase.PRE_PITCH:
			_diagnose_predicate(stage, "lab._match_state.phase != MatchState.Phase.PRE_PITCH")
			return
		if lab._pitch_actor.running:
			_diagnose_predicate(stage, "lab._pitch_actor.running")
			return
		if is_instance_valid(lab._batted_ball):
			_diagnose_predicate(stage, "is_instance_valid(lab._batted_ball)")
			return
	if stage == "environment/property-world-sun":
		var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
		var world: WorldEnvironment = lab._world_environment
		var sun: DirectionalLight3D = (
			lab.get_node_or_null("StarterFieldGeometry/Sun") as DirectionalLight3D
		)
		var environment: Dictionary = lab._match_state.stadium.environment
		if not is_instance_valid(property):
			_diagnose_predicate(stage, "not is_instance_valid(property)")
			return
		if property.venue_id != "GRAND-III":
			_diagnose_predicate(stage, 'property.venue_id != "GRAND-III"')
			return
		if not property.is_inside_tree():
			_diagnose_predicate(stage, "not property.is_inside_tree()")
			return
		if property.suspended:
			_diagnose_predicate(stage, "property.suspended")
			return
		if property.bound_state != lab._match_state:
			_diagnose_predicate(stage, "property.bound_state != lab._match_state")
			return
		if not StadiumNpcSnapshot.valid(property.public_snapshot):
			_diagnose_predicate(stage, "not StadiumNpcSnapshot.valid(property.public_snapshot)")
			return
		if not ClubCareer.same(property.public_snapshot.environment, environment):
			_diagnose_predicate(
				stage, "not ClubCareer.same(property.public_snapshot.environment, environment)"
			)
			return
		if world.get_script() != null:
			_diagnose_predicate(stage, "world.get_script() != null")
			return
		if world.get_parent() != lab:
			_diagnose_predicate(stage, "world.get_parent() != lab")
			return
		if lab.get_node_or_null("LabWorldEnvironment") != world:
			_diagnose_predicate(stage, 'lab.get_node_or_null("LabWorldEnvironment") != world')
			return
		if world.environment == null:
			_diagnose_predicate(stage, "world.environment == null")
			return
		if sun == null:
			_diagnose_predicate(stage, "sun == null")
			return
		if sun.get_script() != null:
			_diagnose_predicate(stage, "sun.get_script() != null")
			return
