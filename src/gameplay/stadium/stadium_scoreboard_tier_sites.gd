class_name StadiumScoreboardTierSites
extends RefCounted
## Candidate sites only. Frozen SCORE-SMALL and production layout families remain unchanged.

const VERSION: int = 2
const SITES: Dictionary = {
	"BOARD-LEFT-v1": {"position": Vector3(-20, 0, 30), "tiers": ["manual", "electronic"]},
	"BOARD-RIGHT-v1": {"position": Vector3(20, 0, 30), "tiers": ["manual", "electronic"]},
	"BOARD-LARGE-v1": {"position": Vector3(36.5, 0, 31.5), "tiers": ["video"]}}


static func inspect(tier: String, site: String, land: String,
	graph: StadiumRecipeBoundary) -> Dictionary:
	if not SITES.has(site) or tier not in SITES[site].tiers or graph == null:
		return {"ok": false, "error": "Unknown compatible candidate board/site/field."}
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, PI), SITES[site].position)
	var box: AABB = pose * StadiumScoreboardTiers.envelope(tier)
	if not StadiumProperty.contains(land, box) or not _outside(box, graph):
		return {"ok": false, "error": "The full board needs outside-play property clearance."}
	var regions: Dictionary = StadiumScoreboardTiers.readouts(tier)
	regions.merge(StadiumScoreboardTiers.detail_slots(tier))
	for key: String in regions:
		var region: Dictionary = regions[key]
		var bottom: Vector3 = region.point - Vector3(0, region.height / 2, 0)
		if not _region_clear(Vector3(0, 1.5, -1),
			pose * (bottom - Vector3(region.width / 2, 0, 0)),
			pose * (bottom + Vector3(region.width / 2, 0, 0)), graph):
			return {"ok": false, "error": "This wall obscures the " + key + " readout."}
	return {"ok": true, "error": "", "pose": pose, "bounds": box,
		"role": "DECORATIVE_AFTER_TERMINAL", "scope": "plate-authored-readout-regions-only"}


static func _outside(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	var rect: Rect2 = Rect2(Vector2(box.position.x, box.position.z),
		Vector2(box.size.x, box.size.z)).grow(0.5)
	var corners: PackedVector2Array = [rect.position,
		Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	return Geometry2D.intersect_polygons(graph.polygon(), corners).is_empty()


static func _clear(eye: Vector3, target: Vector3, graph: StadiumRecipeBoundary) -> bool:
	var from: Vector2 = Vector2(eye.x, eye.z)
	var to: Vector2 = Vector2(target.x, target.z)
	for row: Dictionary in graph.segments():
		var hit: Variant = Geometry2D.segment_intersects_segment(from, to, row.a, row.b)
		if hit != null:
			var fraction: float = from.distance_to(hit) / from.distance_to(to)
			if lerpf(eye.y, target.y, fraction) <= row.height + StadiumRecipeBoundary.THICKNESS:
				return false
	return true


static func _region_clear(eye: Vector3, left: Vector3, right: Vector3,
	graph: StadiumRecipeBoundary) -> bool:
	# Upright regions above ground: the bottom sight plane bounds every higher sightline.
	var normal: Vector3 = (left - eye).cross(right - eye)
	if absf(normal.y) < 0.00001:
		return false
	var triangle: PackedVector2Array = [Vector2(eye.x, eye.z),
		Vector2(left.x, left.z), Vector2(right.x, right.z)]
	for row: Dictionary in graph.segments():
		var span: Vector2 = _clip_segment(row.a, row.b, triangle)
		if span.x > span.y:
			continue
		for fraction: float in [span.x, span.y]:
			var point: Vector2 = row.a.lerp(row.b, fraction)
			var height: float = eye.y - (normal.x * (point.x - eye.x)
				+ normal.z * (point.y - eye.z)) / normal.y
			if height <= row.height + StadiumRecipeBoundary.THICKNESS + 0.00001:
				return false
	return true


static func _clip_segment(a: Vector2, b: Vector2, triangle: PackedVector2Array) -> Vector2:
	var span: Vector2 = Vector2(0, 1)
	var orientation: float = signf((triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]))
	for index in range(3):
		var origin: Vector2 = triangle[index]
		var edge: Vector2 = triangle[(index + 1) % 3] - origin
		var start: float = orientation * edge.cross(a - origin)
		var delta: float = orientation * edge.cross(b - a)
		if absf(delta) < 0.0000001:
			if start < -0.00001:
				return Vector2(1, 0)
		elif delta > 0:
			span.x = maxf(span.x, -start / delta)
		else:
			span.y = minf(span.y, -start / delta)
	return span
