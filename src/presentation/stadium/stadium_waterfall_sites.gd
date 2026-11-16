class_name StadiumWaterfallSites
extends RefCounted
## Only the archive's major landmark reservation. This is not a production installer.

const Models = preload("res://src/presentation/stadium/stadium_waterfall_models.gd")
const CENTER: Vector3 = Vector3(36.5, 0, 44)
const RESERVATION: AABB = AABB(Vector3(30, 0, 39), Vector3(13, 4, 10))


static func place(root: Node3D, site: String = "LANDMARK-A") -> bool:
	if site != "LANDMARK-A" or not Models.valid(root):
		return false
	var ancestor: Node = root.get_parent()
	if ancestor == null:
		return false
	while ancestor != null:
		if ancestor is Node3D and (ancestor.transform != Transform3D.IDENTITY \
			or not ancestor.visible or ancestor.top_level):
			return false
		if ancestor.process_mode == Node.PROCESS_MODE_DISABLED:
			return false
		ancestor = ancestor.get_parent()
	# Any marked occupant or actual spatial intrusion conflicts, even a spoofed name.
	for sibling: Node in root.get_parent().get_children():
		if sibling != root and (_marked_occupant(sibling) \
			or _intrudes(sibling, Transform3D.IDENTITY)):
			return false
	root.transform = Transform3D(Basis.IDENTITY, CENTER)
	root.set_meta("site", "LANDMARK-A")
	return true


static func _intrudes(node: Node, parent_pose: Transform3D) -> bool:
	var pose: Transform3D = parent_pose
	if node is Node3D:
		pose = node.transform if node.top_level else parent_pose * node.transform
	if node is MeshInstance3D and node.mesh != null:
		if RESERVATION.intersects(pose * node.mesh.get_aabb()):
			return true
	for child: Node in node.get_children():
		if _intrudes(child, pose):
			return true
	return false


static func _marked_occupant(node: Node) -> bool:
	if not node.has_meta("site"):
		return false
	var site: Variant = node.get_meta("site")
	# Malformed site declarations cannot make an occupant silently disappear.
	return typeof(site) != TYPE_STRING or site == "LANDMARK-A"
