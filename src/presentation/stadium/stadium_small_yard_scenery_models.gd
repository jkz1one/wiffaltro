class_name StadiumSmallYardSceneryModels
extends RefCounted
## BL scenery adapter only. Accepted live visual bytes and authored dimensions survive.
## The same owned copy changes placement role; no new model, mechanics or inventory.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-001", "ST-003", "ST-004", "ST-008", "ST-009"]
const RADIUS: float = 1.0
const HEIGHT: float = 1.5
const EVENT_KEYS: Array[String] = [
	"surface_id",
	"surface_role",
	"ball_surface",
	"volume_id",
	"volume_role",
	"water_scoring",
	"water_award_active",
	"runtime_adapter",
	"physics_profile"
]


static func create(item: String) -> Node3D:
	if item not in ITEMS:
		return null
	var root: Node3D = source(item)
	if root == null:
		return null
	var collision: Node3D = root.get_node("Collision")
	for child: Node in collision.get_children():
		collision.remove_child(child)
		child.free()
	_clear_event_metadata(root)
	root.set_meta("scenery_adapter_version", VERSION)
	root.set_meta("scenery_only", true)
	root.set_meta("static_geometry", true)
	root.set_meta("envelope", envelope(item))
	root.set_meta("reservation", reservation(item))
	return root


static func source(item: String) -> Node3D:
	if item not in ITEMS:
		return null
	return (
		StadiumStarterModels.create(item)
		if item in ["ST-001", "ST-003"]
		else StadiumGroundPropsModels.create(item)
	)


static func envelope(item: String) -> AABB:
	match item:
		"ST-001":
			return AABB(Vector3(-0.175, 0, -0.175), Vector3(0.35, 0.5, 0.35))
		"ST-003":
			return AABB(Vector3(-0.35, 0, -0.4), Vector3(0.70, 1.0, 0.80))
		"ST-004", "ST-008", "ST-009":
			return StadiumGroundPropsModels.envelope(item)
	return AABB()


static func reservation(item: String) -> AABB:
	return (
		AABB(Vector3(-RADIUS, 0, -RADIUS), Vector3(RADIUS * 2, HEIGHT, RADIUS * 2))
		if item in ITEMS
		else AABB()
	)


static func yaws(item: String) -> Array[int]:
	if item not in ITEMS:
		return []
	return [0] if item == "ST-001" else [0, 90, 180, 270]


static func _clear_event_metadata(node: Node) -> void:
	for key: String in EVENT_KEYS:
		if node.has_meta(key):
			node.remove_meta(key)
	for child: Node in node.get_children():
		_clear_event_metadata(child)
