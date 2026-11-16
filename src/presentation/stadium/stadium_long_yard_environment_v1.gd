class_name StadiumLongYardEnvironmentV1
extends RefCounted
## Fixed artistic late-afternoon state, not geographic/date astronomy or a certificate.
## Reuses the existing DirectionalLight3D + ProceduralSkyMaterial day renderer.

const VERSION: int = 1
const ENVIRONMENT_VERSION: int = 2
const PROFILE: String = "LONG-YARD-1610-CLEAR-v1"


static func lighting() -> Dictionary:
	return {"sun_rotation": [-32.0, -55.0, 0.0], "sun_color": [1.0, 0.88, 0.72, 1.0],
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
		"profile": PROFILE, "time": "16:10", "weather": "clear", "render_profile": VERSION,
		"lighting": lighting()}


static func valid(value: Variant) -> bool:
	return StadiumNpcSnapshot._keys(value, ["version", "seed", "fixture", "mode", "profile",
		"time", "weather", "render_profile", "lighting"]) \
		and SeasonOwnership._whole(value.seed, 0, 2147483647) \
		and StadiumNpcSnapshot._json_types(value) \
		and ClubCareer.same(value, capture(int(value.seed)))


static func apply(lab: PitchBatLab, environment: Dictionary) -> Dictionary:
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
	if not installed(lab, lease):
		restore(lab, lease)
		return {}
	return lease


static func installed(lab: PitchBatLab, lease: Dictionary) -> bool:
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
		and lease.sun.light_color == Color(1.0, 0.88, 0.72, 1.0) \
		and lease.sun.light_energy == 1.0 and lease.sun.shadow_enabled


static func restore(lab: PitchBatLab, lease: Dictionary) -> bool:
	if lease.is_empty() or not is_instance_valid(lab) or not lease.get("lab") is WeakRef \
		or lease.lab.get_ref() != lab or not is_instance_valid(lease.get("world")) \
		or not is_instance_valid(lease.get("sun")) or lease.world.get_parent() != lab \
		or lease.sun.get_parent() != lab.get_node_or_null("StarterFieldGeometry"):
		return false
	# Restore the issued owners even if a mutable lab pointer was substituted. The
	# mismatch still returns false so the runtime retires the interrupted game.
	var owners_match: bool = lab._world_environment == lease.world \
		and lab.get_node_or_null("LabWorldEnvironment") == lease.world \
		and lab.get_node_or_null("StarterFieldGeometry/Sun") == lease.sun
	if not lease.get("restored", false):
		lease.world.environment = lease.before_environment
		lease.sun.rotation = lease.before_rotation
		lease.sun.light_color = lease.before_color
		lease.sun.light_energy = lease.before_energy
		lease.sun.shadow_enabled = lease.before_shadows
		lease.restored = true
	return owners_match and lease.world.environment == lease.before_environment \
		and lease.sun.rotation == lease.before_rotation \
		and lease.sun.light_color == lease.before_color \
		and lease.sun.light_energy == lease.before_energy \
		and lease.sun.shadow_enabled == lease.before_shadows


static func _color(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3])
