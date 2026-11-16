class_name StadiumPoolLabGroundProfile
extends RefCounted
## Exact genuine starter-lab Ground recognition, including its mesh and default margin.

const GEOMETRY: Script = preload("res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd")
const SOURCE_SHA: String = "0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5"

static var _reference_bytes: PackedByteArray


static func matches(body: StaticBody3D) -> bool:
	if body == null or not body.is_inside_tree() or body.name != &"Ground":
		return false
	var parent: Node3D = body.get_parent() as Node3D
	if parent == null or parent.get_script() != GEOMETRY:
		return false
	if parent.global_transform != Transform3D.IDENTITY or body.get_script() != null:
		return false
	if body.get_child_count() != 2:
		return false
	var classes: Array[String] = ["CollisionShape3D", "MeshInstance3D"]
	for index: int in range(2):
		var child: Node = body.get_child(index)
		var prefix: String = "@" + classes[index] + "@"
		if (
			child.get_class() != classes[index]
			or child.get_script() != null
			or child.get_child_count() != 0
		):
			return false
		if not String(child.name).begins_with(prefix):
			return false
		var suffix: String = String(child.name).trim_prefix(prefix)
		if (
			suffix.is_empty()
			or not suffix.is_valid_int()
			or int(suffix) < 1
			or str(int(suffix)) != suffix
		):
			return false
	if FileAccess.get_sha256(GEOMETRY.resource_path) != SOURCE_SHA:
		return false
	if _reference_bytes.is_empty():
		var reference: StarterFieldLabGeometry = StarterFieldLabGeometry.new()
		var expected: StaticBody3D = reference._add_static_box(
			"Ground",
			Vector3(0, -0.08, 12),
			Vector3(45, 0.16, 36),
			Color(0.19, 0.34, 0.19),
			&"ground"
		)
		_reference_bytes = _snapshot(expected)
		reference.free()
	return _snapshot(body) == _reference_bytes


static func _snapshot(body: StaticBody3D) -> PackedByteArray:
	var tree: Dictionary = StadiumPoolPartyAssetIntegrity.snapshot(body)
	# The unchanged factory does not name these two leaf children. Engine-generated
	# names are allocation counters, not authored geometry. Pin child order/type,
	# every other stored field/material and exact shape owner separately in guard.
	for child: Dictionary in tree.children:
		child.erase("name")
		child.properties.erase("name")
	return var_to_bytes(tree)
