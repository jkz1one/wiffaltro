class_name StadiumHillsideTerrain
extends RefCounted
## CV/DD proposed cubic terrain. Private dependency only; no venue or ownership admission.

const VERSION: int = 1
const ID: String = "HILLSIDE-TERRAIN-PROPOSED-v1"
const PROFILES: Array[String] = ["hill", "flat-control"]
const BOUNDS: Rect2 = Rect2(-32, -16, 64, 54)
const START_Z: float = 16.0
const END_Z: float = 26.0
const RISE: float = 2.0
const SAMPLE_STEP: float = 0.25
const BOTTOM: float = -0.16
const EPS: float = 0.00001
# max(abs(h'')) * step^2 / 8, in metres; numerical guard is separate.
const MAX_LINEAR_ERROR: float = 0.0009375


static func contains(point: Vector2) -> bool:
	return point.is_finite() and point.x >= BOUNDS.position.x and point.x <= BOUNDS.end.x \
		and point.y >= BOUNDS.position.y and point.y <= BOUNDS.end.y


static func design_height(z: float, profile: String = "hill") -> float:
	if not is_finite(z) or not PROFILES.has(profile):
		return INF
	if profile == "flat-control":
		return 0.0
	var t: float = clampf((z - START_Z) / (END_Z - START_Z), 0.0, 1.0)
	return RISE * (3.0 * t * t - 2.0 * t * t * t)


static func design_slope(z: float, profile: String = "hill") -> float:
	if not is_finite(z) or not PROFILES.has(profile):
		return INF
	if profile == "flat-control" or z <= START_Z or z >= END_Z:
		return 0.0
	var t: float = (z - START_Z) / (END_Z - START_Z)
	return 1.2 * t * (1.0 - t)


static func knots() -> PackedFloat64Array:
	var result: PackedFloat64Array = [BOUNDS.position.y]
	for index in range(41):
		result.append(START_Z + index * SAMPLE_STEP)
	result.append(23.4)
	var poles: Array[Dictionary] = StadiumFoulPoleSites.rows(
		StadiumRecipeBoundary.create("deeper_center"))
	result.append(poles[0].position.z)
	result.append(BOUNDS.end.y)
	result.sort()
	return result


static func interval(z: float) -> int:
	if not is_finite(z) or z < BOUNDS.position.y or z > BOUNDS.end.y:
		return -1
	var samples: PackedFloat64Array = knots()
	for index in range(samples.size() - 1):
		if z < samples[index + 1] or index == samples.size() - 2:
			return index
	return -1


static func support_height(point: Vector2, profile: String = "hill") -> float:
	if not contains(point) or not PROFILES.has(profile):
		return INF
	var samples: PackedFloat64Array = knots()
	var index: int = interval(point.y)
	var weight: float = inverse_lerp(samples[index], samples[index + 1], point.y)
	return lerpf(design_height(samples[index], profile),
		design_height(samples[index + 1], profile), weight)


static func support_normal(point: Vector2, profile: String = "hill") -> Vector3:
	if not contains(point) or not PROFILES.has(profile):
		return Vector3.INF
	var samples: PackedFloat64Array = knots()
	var index: int = interval(point.y)
	var slope: float = (design_height(samples[index + 1], profile)
		- design_height(samples[index], profile)) / (samples[index + 1] - samples[index])
	return Vector3(0, 1, -slope).normalized()


static func point(x: float, z: float, profile: String = "hill") -> Vector3:
	var y: float = support_height(Vector2(x, z), profile)
	return Vector3(x, y, z) if is_finite(y) else Vector3.INF


static func contract(profile: String = "hill") -> Dictionary:
	if not PROFILES.has(profile):
		return {}
	return {"id": ID, "version": VERSION, "status": "PROPOSED_UNQUALIFIED_DEPENDENCY",
		"profile": profile, "bounds": [-32, -16, 32, 38], "ramp": [16, 26, 2],
		"formula": "2*(3*t*t-2*t*t*t)", "sample_step": SAMPLE_STEP, "knots": Array(knots()),
		"bottom": BOTTOM,
		"max_linear_error": MAX_LINEAR_ERROR, "topology": "closed-clockwise-strip-mesh-v1",
		"support": "same-piecewise-linear-top-as-collider", "production_ready": false}


static func signature(profile: String = "hill") -> String:
	var record: Dictionary = contract(profile)
	return "" if record.is_empty() else JSON.stringify(record, "", true, true).sha256_text()
