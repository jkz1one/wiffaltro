class_name StadiumHillsideBoundary
extends StadiumRecipeBoundary
## Private Working terrain-relative enclosure. XZ, inset, bands and event authority stay retained.

const PRIVATE_VERSION: int = 1
var terrain_profile: String = "hill"


static func create_hillside(profile: String = "hill") -> StadiumHillsideBoundary:
	if not StadiumHillsideTerrain.PROFILES.has(profile):
		return null
	var result: StadiumHillsideBoundary = StadiumHillsideBoundary.new()
	result._shape = "deeper_center"
	result.terrain_profile = profile
	return result


func identity() -> String:
	return "PRIVATE-HILLSIDE-SAME-XZ-PERIMETER-v1-" + terrain_profile.to_upper()


func top_height(segment_id: String, xz: Vector2) -> float:
	var row: Dictionary = segment(segment_id)
	var support: float = StadiumHillsideTerrain.support_height(xz, terrain_profile)
	return INF if row.is_empty() or not is_finite(support) else support + float(row.height)


func crossing(previous: Vector3, current: Vector3) -> Dictionary:
	# Keep the original candidate fractions, corner priorities and ID tie break.
	var event: Dictionary = super.crossing(previous, current)
	if event.is_empty():
		return event
	var at: Vector3 = event.position
	var top: float = top_height(event.segment, Vector2(at.x, at.z))
	if not is_finite(top):
		return {}
	var row: Dictionary = segment(event.segment)
	event.role = row.role
	if at.y > top + EPS:
		if row.role == "SIDE_RETURN_LIVE":
			event.role = "SIDE_EXIT_DEAD"
		elif row.role == "BACK_WALL_TERMINAL":
			event.role = "BACK_CLEAR"
	return event


func apply(resolver: BallPlayResolver, event: Dictionary) -> bool:
	if event.get("role", "") in ["SIDE_EXIT_DEAD", "BACK_CLEAR"]:
		if not event.get("position") is Vector3 or not event.get("segment") is String:
			return false
		var at: Vector3 = event.position
		var top: float = top_height(event.segment, Vector2(at.x, at.z))
		if not at.is_finite() or not is_finite(top) or at.y <= top + EPS:
			return false
	# Retained terrain is nonnegative, so its valid clear is also above the old base top.
	# The ordinary authority retains all contact recording, ground history and scoring.
	return super.apply(resolver, event)


func signature() -> String:
	return JSON.stringify({"base": super.signature(), "private_version": PRIVATE_VERSION,
		"terrain": StadiumHillsideTerrain.signature(terrain_profile),
		"top": "sampled-support-plus-retained-height", "xz": "unchanged-deeper-center",
		"tessellation": "exact-retained-z-knots", "prism_margin": 0.0},
		"", true, true).sha256_text()
