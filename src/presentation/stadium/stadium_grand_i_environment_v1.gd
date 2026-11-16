class_name StadiumGrandIEnvironmentV1
extends RefCounted
## Exact 19:10 clear artistic preset, not geographic/date astronomy or a night certificate.
## Render revision2: bounded coverage/ambient trial; authored profile family remains unchanged.
## Reversible sky/sun plus six issued Grand tower emitters; native readability remains unqualified.

const VERSION: int = 2
const ENVIRONMENT_VERSION: int = 3
const PROFILE: String = "GRAND-I-1910-CLEAR-v1"


static func lighting() -> Dictionary:
	return {"sun_rotation": [-8.0, -55.0, 0.0], "sun_color": [1.0, 0.72, 0.49, 1.0],
		"sun_energy": 0.18, "sun_shadows": false,
		"background_color": [0.06, 0.08, 0.13, 1.0],
		"sky_top": [0.08, 0.12, 0.23, 1.0], "sky_horizon": [0.66, 0.40, 0.30, 1.0],
		"ground_horizon": [0.24, 0.26, 0.20, 1.0],
		"ground_bottom": [0.05, 0.07, 0.06, 1.0], "ambient_energy": 0.65,
		"background": "sky", "ambient_source": "sky", "reflection_source": "sky",
		"tonemap": "linear", "exposure": 1.0, "active_lights": StadiumGrandILightingV1.contract()}


static func capture(seed: int) -> Dictionary:
	if seed < 0 or seed > 2147483647:
		return {}
	return {"version": ENVIRONMENT_VERSION, "seed": seed, "fixture": 32, "mode": "night",
		"profile": PROFILE, "time": "19:10", "weather": "clear", "render_profile": VERSION,
		"lighting": lighting()}


static func valid(value: Variant) -> bool:
	return StadiumNpcSnapshot._keys(value, ["version", "seed", "fixture", "mode", "profile",
		"time", "weather", "render_profile", "lighting"]) \
		and SeasonOwnership._whole(value.seed, 0, 2147483647) \
		and StadiumNpcSnapshot._json_types(value) \
		and ClubCareer.same(value, capture(int(value.seed)))


static func apply(lab: PitchBatLab, environment: Dictionary, grand_ii: bool = false,
	grand_iii: bool = false) -> Dictionary:
	if grand_ii and grand_iii:
		return {}
	var accepted: bool = StadiumGrandIIIEnvironmentV1.valid(environment) if grand_iii else (
		StadiumGrandIIEnvironmentV1.valid(environment) if grand_ii else valid(environment))
	if not is_instance_valid(lab) or not accepted \
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
	# Cold admission only: no borrowed night qualification or pre-existing lamp runtime.
	var lights: Array[Node] = lab.find_children("*", "Light3D", true, false)
	if lights.size() != 1 or lights[0] != sun:
		return {}
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if not is_instance_valid(property) \
		or property.venue_id != ("GRAND-III" if grand_iii else ("GRAND-II" if grand_ii else "GRAND-I")) \
		or not StadiumNpcSnapshot.valid(property.public_snapshot) \
		or property.public_snapshot.version != (StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
		if grand_iii else (StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
		if grand_ii else StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION)) \
		or not ClubCareer.same(property.public_snapshot.environment, environment):
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
		"applied_ambient_energy": next.ambient_light_energy, "active_lighting": {},
		"grand_ii": grand_ii, "grand_iii": grand_iii, "restored": false}
	sun.rotation_degrees = Vector3(state.sun_rotation[0], state.sun_rotation[1], state.sun_rotation[2])
	sun.light_color = _color(state.sun_color)
	sun.light_energy = state.sun_energy
	sun.shadow_enabled = state.sun_shadows
	lease["applied_rotation"] = sun.rotation
	lease["applied_energy"] = sun.light_energy
	lab._world_environment.environment = next
	lease.active_lighting = StadiumGrandIIILightingV1.apply(lab, property) if grand_iii else (
		StadiumGrandIILightingV1.apply(lab, property) if grand_ii else (
		StadiumGrandILightingV1.apply(lab, property)))
	if not installed(lab, lease, grand_ii, grand_iii):
		restore(lab, lease, grand_ii, grand_iii)
		return {}
	return lease


static func installed(lab: PitchBatLab, lease: Dictionary, grand_ii: bool = false,
	grand_iii: bool = false) -> bool:
	# Issued scene resource identity plus a fixed number of values; no scene/hash traversal.
	if grand_ii and grand_iii:
		return false
	if lease.is_empty() or not lease.get("grand_ii") is bool or lease.grand_ii != grand_ii \
		or not lease.get("grand_iii") is bool or lease.grand_iii != grand_iii \
		or lease.get("restored", true) or not is_instance_valid(lab) \
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
		and environment.background_color == Color(0.06, 0.08, 0.13, 1.0) \
		and environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY \
		and environment.ambient_light_energy == lease.applied_ambient_energy \
		and environment.reflected_light_source == Environment.REFLECTION_SOURCE_SKY \
		and environment.tonemap_mode == Environment.TONE_MAPPER_LINEAR \
		and environment.tonemap_exposure == 1.0 \
		and material.sky_top_color == Color(0.08, 0.12, 0.23, 1.0) \
		and material.sky_horizon_color == Color(0.66, 0.40, 0.30, 1.0) \
		and material.ground_horizon_color == Color(0.24, 0.26, 0.20, 1.0) \
		and material.ground_bottom_color == Color(0.05, 0.07, 0.06, 1.0) \
		and lease.sun.rotation == lease.applied_rotation \
		and lease.sun.light_color == Color(1.0, 0.72, 0.49, 1.0) \
		and lease.sun.light_energy == lease.applied_energy and not lease.sun.shadow_enabled \
		and (StadiumGrandIIILightingV1.installed(lab, lease.active_lighting) if grand_iii else (
		StadiumGrandIILightingV1.installed(lab, lease.active_lighting)
		if grand_ii else StadiumGrandILightingV1.installed(lab, lease.active_lighting)))


static func restore(lab: PitchBatLab, lease: Dictionary, grand_ii: bool = false,
	grand_iii: bool = false) -> bool:
	if grand_ii and grand_iii:
		return false
	if lease.is_empty() or not lease.get("grand_ii") is bool or lease.grand_ii != grand_ii \
		or not lease.get("grand_iii") is bool or lease.grand_iii != grand_iii \
		or not is_instance_valid(lab) or not lease.get("lab") is WeakRef \
		or lease.lab.get_ref() != lab:
		return false
	# Clean the issued lamps/atlas even when another dynamic owner was removed.
	var lights_restored: bool = true
	if not lease.active_lighting.is_empty():
		lights_restored = StadiumGrandIIILightingV1.restore(lab, lease.active_lighting) \
			if grand_iii else (StadiumGrandIILightingV1.restore(lab, lease.active_lighting) \
			if grand_ii else StadiumGrandILightingV1.restore(lab, lease.active_lighting))
	var world_valid: bool = is_instance_valid(lease.get("world"))
	var sun_valid: bool = is_instance_valid(lease.get("sun"))
	var owners_match: bool = world_valid and sun_valid \
		and lab._world_environment == lease.world and lease.world.get_parent() == lab \
		and lab.get_node_or_null("LabWorldEnvironment") == lease.world \
		and lab.get_node_or_null("StarterFieldGeometry/Sun") == lease.sun
	if not lease.get("restored", false):
		if world_valid:
			lease.world.environment = lease.before_environment
		if sun_valid:
			lease.sun.rotation = lease.before_rotation
			lease.sun.light_color = lease.before_color
			lease.sun.light_energy = lease.before_energy
			lease.sun.shadow_enabled = lease.before_shadows
		lease.restored = true
	return owners_match and lights_restored and lease.world.environment == lease.before_environment \
		and lease.sun.rotation == lease.before_rotation \
		and lease.sun.light_color == lease.before_color \
		and lease.sun.light_energy == lease.before_energy \
		and lease.sun.shadow_enabled == lease.before_shadows


static func _color(value: Array) -> Color:
	return Color(value[0], value[1], value[2], value[3])
