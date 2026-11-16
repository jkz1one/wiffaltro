class_name StadiumProperty
extends RefCounted
## Working home-property coordinates. Expansion never scales the playing field or grants items.

const VERSION: int = 1
const BOUNDS: Dictionary = {
	"backyard": Rect2(-26, -10, 52, 42),
	"expanded": Rect2(-32, -16, 64, 54),
	"club": Rect2(-40, -22, 80, 68),
	"mogul": Rect2(-52, -30, 104, 88)
}


static func ground_bounds(tier: String) -> AABB:
	if not BOUNDS.has(tier):
		return AABB()
	var bounds: Rect2 = BOUNDS[tier]
	return AABB(Vector3(bounds.position.x, -0.16, bounds.position.y),
		Vector3(bounds.size.x, 0.16, bounds.size.y))


static func contains(tier: String, envelope: AABB) -> bool:
	if not BOUNDS.has(tier) or envelope.size.x < 0 or envelope.size.y < 0 or envelope.size.z < 0:
		return false
	var bounds: Rect2 = BOUNDS[tier]
	return envelope.position.x >= bounds.position.x and envelope.end.x <= bounds.end.x \
		and envelope.position.z >= bounds.position.y and envelope.end.z <= bounds.end.y


static func reference_wall_width(field: FieldDefinition) -> float:
	# New authored property candidate covers both tolerated fair endpoints.
	# The old 38m lab wall is deliberately unchanged in legacy matches.
	return 2.0 * (field.back_wall_z_m * tan(deg_to_rad(field.fair_half_angle_degrees)) + 0.45)


static func layout_bounds(item: String, position: Vector3) -> AABB:
	match item:
		"ST-001": return AABB(position + Vector3(-0.5, 0, -0.5), Vector3(1, 0.65, 1))
		"ST-003": return AABB(position + Vector3(-1, 0, -1), Vector3(2, 1.2, 2))
		"ST-079": return AABB(position + Vector3(-0.30, 0, -0.18), Vector3(0.60, 0.88, 0.61))
	return AABB()


static func signature(tier: String) -> String:
	if not BOUNDS.has(tier):
		return ""
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var bounds: Rect2 = BOUNDS[tier]
	return JSON.stringify({"geometry": VERSION, "models": StadiumStarterModels.VERSION, "tier": tier,
		"land": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"field": [field.fair_half_angle_degrees, field.safe_hit_z_m, field.deep_air_z_m,
			field.back_wall_z_m, field.home_run_height_m, field.dead_ball_z_m],
		"mound_z": PitchBatLab.MOUND_ORIGIN.z, "sites": StadiumStarterLayout.signature()},
		"", true, true).sha256_text()
