class_name StadiumGrandIIEnvironmentV1
extends RefCounted
## Exact 19:10 clear artistic preset, not geographic/date astronomy or a night certificate.
## Render revision2: bounded coverage/ambient trial; authored profile family remains unchanged.
## Reversible sky/sun plus six issued Grand tower emitters; native readability remains unqualified.

const VERSION: int = 2
const ENVIRONMENT_VERSION: int = 4
const PROFILE: String = "GRAND-II-1910-CLEAR-v1"


static func lighting() -> Dictionary:
	var result: Dictionary = StadiumGrandIEnvironmentV1.lighting()
	result.active_lights = StadiumGrandIILightingV1.contract()
	return result


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


static func apply(lab: PitchBatLab, environment: Dictionary) -> Dictionary:
	return StadiumGrandIEnvironmentV1.apply(lab, environment, true)


static func installed(lab: PitchBatLab, lease: Dictionary) -> bool:
	return StadiumGrandIEnvironmentV1.installed(lab, lease, true)


static func restore(lab: PitchBatLab, lease: Dictionary) -> bool:
	return StadiumGrandIEnvironmentV1.restore(lab, lease, true)
