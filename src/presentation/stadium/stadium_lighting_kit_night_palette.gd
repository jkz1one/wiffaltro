class_name StadiumLightingKitNightPalette
extends RefCounted
## Independent early-yard presentation contract. Detached resources only; no admission authority.
const VERSION: int = 1
const FAMILY: String = "st111-early-yard-presentation-v1"
const BASELINE: String = "BASE2048"
const PROFILES: Array[String] = [BASELINE, "ATLAS4096", "ATLAS4096_KITBIAS2", "KIT_FILL2048"]
static var _signature_cache: Dictionary = {}


static func contract(profile: String = BASELINE) -> Dictionary:
	if not PROFILES.has(profile):
		return {}
	return {
		"version": VERSION,
		"family": FAMILY,
		"profile": profile,
		"background": "14263d",
		"ambient": {"source": "color", "color": "92acc9", "energy": 0.52},
		"reflection": "disabled",
		"sky": "none",
		"tonemap": ["linear", 1.0, 1.0],
		"effects":
		{
			"glow": false,
			"fog": false,
			"volumetric_fog": false,
			"ssao": false,
			"ssil": false,
			"ssr": false,
			"sdfgi": false,
			"adjustment": false
		},
		"sun":
		{
			"color": "93accb",
			"energy": 0.28,
			"rotation_degrees": [-55.0, -30.0, 0.0],
			"shadow": true
		},
		"lens_emission_multiplier": 0.8,
		"kit_source_override":
		(
			{"shadow_enabled": false}
			if profile == "KIT_FILL2048"
			else {"shadow_normal_bias": 2.0} if profile == "ATLAS4096_KITBIAS2" else {}
		),
		"rear_source_override": {},
		"shadow_atlas":
		{
			"size": 2048 if profile in [BASELINE, "KIT_FILL2048"] else 4096,
			"precision": false,
			"quadrant_subdivisions": [4, 4, 4, 4]
		},
		"surface": "unchanged-owned-rough-dirt",
		"ball": "unchanged-gameplay-material",
		"source_geometry": StadiumLightingKitModels.signature(),
		"qualification": "separate-reviewed-pattern-evidence-required"
	}


static func signature(profile: String = BASELINE) -> String:
	if not PROFILES.has(profile):
		return ""
	if not _signature_cache.has(profile):
		_signature_cache[profile] = JSON.stringify(contract(profile), "", true, true).sha256_text()
	return _signature_cache[profile]


static func signatures() -> Dictionary:
	var result: Dictionary = {}
	for profile: String in PROFILES:
		result[profile] = signature(profile)
	return result


static func kit_source_values(profile: String) -> Dictionary:
	return (
		{&"shadow_enabled": false}
		if profile == "KIT_FILL2048"
		else {&"shadow_normal_bias": 2.0} if profile == "ATLAS4096_KITBIAS2" else {}
	)


static func environment() -> Environment:
	# Canonical owned resource, not an arbitrary inherited palette. Nothing mutates the Day resource.
	var result: Environment = Environment.new()
	result.background_mode = Environment.BG_COLOR
	result.background_color = Color("14263d")
	result.sky = null
	result.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	result.ambient_light_color = Color("92acc9")
	result.ambient_light_energy = 0.52
	result.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	result.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	result.tonemap_exposure = 1.0
	result.tonemap_white = 1.0
	result.glow_enabled = false
	result.fog_enabled = false
	result.volumetric_fog_enabled = false
	result.ssao_enabled = false
	result.ssil_enabled = false
	result.ssr_enabled = false
	result.sdfgi_enabled = false
	result.adjustment_enabled = false
	return result


static func lens(original: StandardMaterial3D) -> StandardMaterial3D:
	if original == null or original.get_script() != null:
		return null
	var result: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if result == null:
		return null
	# Disabled emission can be omitted by duplicate(); copy it deliberately.
	result.emission = original.emission
	result.emission_enabled = true
	result.emission_energy_multiplier = 0.8
	return result


static func sun_values() -> Dictionary:
	return {"light_color": Color("93accb"), "light_energy": float(PackedFloat32Array([0.28])[0])}


static func sun_geometry_valid(sun: DirectionalLight3D) -> bool:
	return (
		is_instance_valid(sun)
		and sun.get_script() == null
		and sun.position == Vector3.ZERO
		and sun.rotation_degrees.is_equal_approx(Vector3(-55.0, -30.0, 0.0))
		and sun.scale == Vector3.ONE
		and sun.shadow_enabled
		and not sun.top_level
	)


static func shadows(profile: String = BASELINE) -> Dictionary:
	if not PROFILES.has(profile):
		return {}
	return {
		"size": 2048 if profile in [BASELINE, "KIT_FILL2048"] else 4096,
		"precision": false,
		"quadrants":
		[
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
		]
	}
