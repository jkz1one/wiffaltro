class_name StadiumHillsidePublicBoundary
extends StadiumDugoutBoundary
## Retained CH XZ and terrain-relative heights, with exact CI flat timber replacements.
## Only the property-owned contact delegate may issue a one-use witnessed event.

const ID: String = "PERIM-HILLSIDE-TIMBER-DEEPER-CENTER-v1"
var contact_adapter: WeakRef


static func create_hillside() -> StadiumHillsidePublicBoundary:
	var result: StadiumHillsidePublicBoundary = StadiumHillsidePublicBoundary.new()
	result._shape = "deeper_center"
	return result


func identity() -> String:
	return ID


func segments() -> Array[Dictionary]:
	var rows: Array[Dictionary] = super.segments()
	for row: Dictionary in rows:
		if row.role == "DUGOUT_OPENING_DEAD":
			row.height = StadiumTimberDugoutContract.ENTRY_HEIGHT
	return rows


func top_height(segment_id: String, xz: Vector2) -> float:
	var row: Dictionary = segment(segment_id)
	var support: float = StadiumHillsideTerrain.support_height(xz, "hill")
	return INF if row.is_empty() or not is_finite(support) else support + float(row.height)


func crossing(previous: Vector3, current: Vector3) -> Dictionary:
	# A descriptive crossing is never a real swept timber contact or runtime authority.
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
		match row.role:
			"SIDE_RETURN_LIVE", "DUGOUT_FACE_LIVE":
				event.role = "SIDE_EXIT_DEAD"
			"BACK_WALL_TERMINAL":
				event.role = "BACK_CLEAR"
			"DUGOUT_OPENING_DEAD":
				event.role = "DUGOUT_EXTERIOR_DEAD"
	return event


func apply(resolver: BallPlayResolver, event: Dictionary) -> bool:
	var adapter: StadiumHillsidePublicContactAdapter = contact_adapter.get_ref() \
		if contact_adapter != null else null
	if adapter == null or not adapter.consume_witness(resolver, event):
		return false
	var row: Dictionary = segment(event.get("segment", ""))
	if row.is_empty() or not event.get("position") is Vector3:
		return false
	if event.get("role", "") in ["SIDE_EXIT_DEAD", "BACK_CLEAR", "DUGOUT_EXTERIOR_DEAD"]:
		var at: Vector3 = event.position
		var top: float = top_height(row.id, Vector2(at.x, at.z))
		if not at.is_finite() or not is_finite(top) or at.y <= top + EPS:
			return false
	# Accepted terrain is nonnegative; valid local clears also clear the old base height.
	# Ordinary graph authorities retain contact recording, ground history and outcomes.
	return super.apply(resolver, event)


func observe(_resolver: BallPlayResolver, _previous: Vector3, _current: Vector3) -> Dictionary:
	return {}


func signature() -> String:
	return JSON.stringify({"base": super.signature(), "version": 1,
		"terrain": StadiumHillsideTerrain.signature("hill"),
		"top": "sampled-support-plus-retained-height", "xz": "unchanged-deeper-center",
		"replacements": "CI-ST032-flat-s10-16-opening-s12-14",
		"tessellation": "exact-retained-z-knots", "prism_margin": 0.0,
		"contact_adapter": "HILLSIDE_ST032_FINITE_SPHERE_v1"}, "", true, true).sha256_text()
