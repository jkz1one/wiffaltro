class_name StadiumPoolPartyEnvironmentV1
extends RefCounted
## Fixed artistic 13:10 daytime state, not geographic/date astronomy or a certificate.
## Reuses the existing DirectionalLight3D + ProceduralSkyMaterial day renderer.

const VERSION: int = 1
const ENVIRONMENT_VERSION: int = 6
const PROFILE: String = "POOL-PARTY-1310-CLEAR-v1"
static var _issued: Dictionary = {}


static func lighting() -> Dictionary:
	return {"sun_rotation": [-55.0, -30.0, 0.0], "sun_color": [1.0, 1.0, 1.0, 1.0],
		"sun_energy": 1.0, "sun_shadows": true,
		"background_color": [0.12, 0.20, 0.15, 1.0],
		"sky_top": [0.17, 0.43, 0.68, 1.0], "sky_horizon": [0.72, 0.80, 0.86, 1.0],
		"ground_horizon": [0.48, 0.56, 0.45, 1.0],
		"ground_bottom": [0.16, 0.22, 0.18, 1.0], "ambient_energy": 0.58,
		"background": "sky", "ambient_source": "sky", "reflection_source": "sky",
		"tonemap": "linear", "exposure": 1.0, "active_lights": []}


static func capture(seed: int) -> Dictionary:
	if seed < 0 or seed > 2147483647:
		return {}
	return {"version": ENVIRONMENT_VERSION, "seed": seed, "fixture": 32, "mode": "day",
		"profile": PROFILE, "time": "13:10", "weather": "clear", "render_profile": VERSION,
		"lighting": lighting()}


static func valid(value: Variant) -> bool:
	return StadiumNpcSnapshot._keys(value, ["version", "seed", "fixture", "mode", "profile",
		"time", "weather", "render_profile", "lighting"]) \
		and SeasonOwnership._whole(value.seed, 0, 2147483647) \
		and StadiumNpcSnapshot._json_types(value) \
		and _same_profile(value, capture(int(value.seed)))


static func apply(lab: PitchBatLab, environment: Dictionary) -> Dictionary:
	_prune()
	if not is_instance_valid(lab) or not valid(environment) \
		or not is_instance_valid(lab._world_environment) \
		or lab._world_environment.environment == null:
		return {}
	var sun: DirectionalLight3D = (
		lab.get_node_or_null("StarterFieldGeometry/Sun") as DirectionalLight3D)
	if sun == null or sun.get_script() != null \
		or lab._world_environment.get_script() != null \
		or lab._world_environment.get_parent() != lab \
		or lab.get_node_or_null("LabWorldEnvironment") != lab._world_environment:
		return {}
	# Cold admission only: the saved empty active-light list is a real scene constraint.
	var lights: Array[Node] = lab.find_children("*", "Light3D", true, false)
	if lights.size() != 1 or lights[0] != sun:
		return {}
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if not is_instance_valid(property) or property.venue_id != "POOL-PARTY" \
		or not StadiumNpcSnapshot.valid(property.public_snapshot) \
		or property.public_snapshot.version != StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION \
		or not _same_profile(property.public_snapshot.environment, environment):
		return {}
	if _issued.has(lab.get_instance_id()) and not _issued[lab.get_instance_id()].state.restored:
		return {}
	var state: Dictionary = environment.lighting
	var material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	material.sky_top_color = _color(state.sky_top)
	material.sky_horizon_color = _color(state.sky_horizon)
	material.ground_horizon_color = _color(state.ground_horizon)
	material.ground_bottom_color = _color(state.ground_bottom)
	var sky: Sky = Sky.new()
	sky.sky_material = material
	var next: Environment = Environment.new()
	next.background_mode = Environment.BG_SKY
	next.background_color = _color(state.background_color)
	next.sky = sky
	next.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	next.ambient_light_energy = state.ambient_energy
	next.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	next.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	next.tonemap_exposure = state.exposure
	var lease: Dictionary = {"lab": weakref(lab), "world": lab._world_environment,
		"sun": sun, "before_environment": lab._world_environment.environment,
		"before_rotation": sun.rotation, "before_color": sun.light_color,
		"before_energy": sun.light_energy, "before_shadows": sun.shadow_enabled,
		"applied_environment": next, "applied_sky": sky, "applied_material": material,
		"applied_ambient_energy": next.ambient_light_energy, "restored": false}
	sun.rotation_degrees = Vector3(state.sun_rotation[0], state.sun_rotation[1], state.sun_rotation[2])
	sun.light_color = _color(state.sun_color)
	sun.light_energy = state.sun_energy
	sun.shadow_enabled = state.sun_shadows
	lease["applied_rotation"] = sun.rotation
	lab._world_environment.environment = next
	_issued[lab.get_instance_id()] = {"lease": lease, "state": lease.duplicate(true)}
	if not installed(lab, lease):
		restore(lab, lease)
		return {}
	return lease


static func _installed_state(lab: PitchBatLab, lease: Dictionary) -> bool:
	# Issued scene resource identity plus a fixed number of values; no scene/hash traversal.
	if lease.is_empty() or lease.get("restored", true) or not is_instance_valid(lab) \
		or not lease.get("lab") is WeakRef or lease.lab.get_ref() != lab \
		or not is_instance_valid(lease.get("world")) or lab._world_environment != lease.world \
		or lease.world.get_parent() != lab or lab.get_node_or_null("LabWorldEnvironment") != lease.world \
		or not is_instance_valid(lease.get("sun")) \
		or lab.get_node_or_null("StarterFieldGeometry/Sun") != lease.sun \
		or lease.world.environment != lease.applied_environment:
		return false
	var environment: Environment = lease.applied_environment
	var material: ProceduralSkyMaterial = lease.applied_material
	return environment.sky == lease.applied_sky and environment.sky.sky_material == material \
		and environment.background_mode == Environment.BG_SKY \
		and environment.background_color == Color(0.12, 0.20, 0.15, 1.0) \
		and environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY \
		and environment.ambient_light_energy == lease.applied_ambient_energy \
		and environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY \
		and environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR \
		and environment.tonemap_exposure == 1.0 \
		and material.sky_top_color == Color(0.17, 0.43, 0.68, 1.0) \
		and material.sky_horizon_color == Color(0.72, 0.80, 0.86, 1.0) \
		and material.ground_horizon_color == Color(0.48, 0.56, 0.45, 1.0) \
		and material.ground_bottom_color == Color(0.16, 0.22, 0.18, 1.0) \
		and lease.sun.rotation == lease.applied_rotation \
		and lease.sun.light_color == Color(1.0, 1.0, 1.0, 1.0) \
		and lease.sun.light_energy == 1.0 and lease.sun.shadow_enabled


static func _restore_state(lab: PitchBatLab, lease: Dictionary) -> bool:
	if not is_instance_valid(lab) or not lease.get("lab") is WeakRef or lease.lab.get_ref() != lab:
		return false
	var world_valid: bool = is_instance_valid(lease.get("world"))
	var sun_valid: bool = is_instance_valid(lease.get("sun"))
	var owners_match: bool = world_valid and sun_valid \
		and lab._world_environment == lease.world and lease.world.get_parent() == lab \
		and lab.get_node_or_null("LabWorldEnvironment") == lease.world \
		and lab.get_node_or_null("StarterFieldGeometry/Sun") == lease.sun
	# Restore surviving issued owners even after a mutable lab pointer or sibling is removed.
	if not lease.restored:
		if world_valid:
			lease.world.environment = lease.before_environment
		if sun_valid:
			lease.sun.rotation = lease.before_rotation
			lease.sun.light_color = lease.before_color
			lease.sun.light_energy = lease.before_energy
			lease.sun.shadow_enabled = lease.before_shadows
		lease.restored = true
	return owners_match and lease.world.environment == lease.before_environment \
		and lease.sun.rotation == lease.before_rotation and lease.sun.light_color == lease.before_color \
		and lease.sun.light_energy == lease.before_energy \
		and lease.sun.shadow_enabled == lease.before_shadows


static func _color(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3])


static func installed(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.is_empty() or state.restored or lease.size() != state.size():
		return false
	for key: String in state:
		if not lease.has(key) or typeof(lease[key]) != typeof(state[key]) \
			or not is_same(lease[key], state[key]):
			return false
	return _installed_state(lab, state)


static func restore(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = _state(lab, lease)
	if state.is_empty():
		return false
	var restored: bool = _restore_state(lab, state)
	lease["restored"] = state.restored
	return restored


static func _state(lab: PitchBatLab, lease: Dictionary) -> Dictionary:
	if not is_instance_valid(lab) or not _issued.has(lab.get_instance_id()):
		return {}
	var issued: Dictionary = _issued[lab.get_instance_id()]
	return issued.state if is_same(lease, issued.lease) \
		and issued.state.lab.get_ref() == lab else {}


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
		return (value is int or value is float) and is_finite(float(value)) \
			and float(value) == float(expected)
	return typeof(value) == typeof(expected) and value == expected


static func _prune() -> void:
	# Cold admission only; live and restored leases retain their original identities.
	for key: int in _issued.keys():
		if not is_instance_valid(_issued[key].state.lab.get_ref()):
			_issued.erase(key)
