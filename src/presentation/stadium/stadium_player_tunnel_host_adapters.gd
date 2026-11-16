class_name StadiumPlayerTunnelHostAdapters
extends RefCounted
## Additive owned-only CI4 host version. Frozen factories remain capped and unchanged.
## Fresh construction without an installed exact tunnel restores the original host.

const VERSION: int = 1
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const STAND_DEPTH: float = 0.7
const EPS: float = 0.00001


static func binding(layout: Dictionary, copy: String, host_key: String) -> Dictionary:
	if (
		not (
			StadiumPlayerTunnelItems.is_family(layout)
			or (
				StadiumMountedDisplayItems.is_family(layout)
				or (
					StadiumStringLightItems.is_family(layout)
					or (
						StadiumSalvageCarItems.is_family(layout)
						or (
							StadiumMasteryBannerItems.is_family(layout)
							or (
								StadiumWaterfallItems.is_family(layout)
								or (
									StadiumLightingKitItems.is_family(layout)
									or (
										StadiumOutfieldPlazaItems.is_family(layout)
										or StadiumWaterfallLiveItems.is_family(layout)
									)
								)
							)
						)
					)
				)
			)
		)
		or host_key not in ["dugout", "lower"]
	):
		return {}
	for row: Dictionary in layout.player_tunnels:
		if row.get(host_key, "") == copy:
			return row.duplicate(true)
	return {}


static func apply_dugout(root: Node3D, row: Dictionary) -> bool:
	if (
		not _owned(root, row, "dugout", "ST-074", "DUGOUT-")
		or not _source_box(root, "Rear", AABB(Vector3(-3, 0, 2.5), Vector3(6, 2.4, 0.15)))
		or not _source_box(
			root,
			"Roof",
			StadiumDugoutRecipe.ENVELOPE.intersection(
				AABB(Vector3(-3, 2.4, 0), Vector3(6, 0.3, 2.65))
			)
		)
		or not _source_box(
			root, "BenchSeat", AABB(Vector3(-2.75, 0.45, 1.83), Vector3(5.5, 0.08, 0.44))
		)
	):
		return false
	var left: bool = row.site == "TUNNEL-L"
	var low_x: float = -2.75 if left else 1.25
	var port: AABB = AABB(Vector3(low_x, 0, 2.4), Vector3(1.5, 2.4, 0.25))
	# The bench lies BEFORE the rear wall. Cutting only Rear would be a false passage.
	var approach: AABB = AABB(Vector3(low_x, 0, 1.65), Vector3(1.5, 2.4, 1.0))
	var changed: Array[Dictionary] = []
	for name_value: String in ["Rear", "BenchSeat", "BenchBack", "BenchLeg-1", "BenchLeg1"]:
		var delta: Dictionary = _cut(root, name_value, approach)
		if not delta.is_empty():
			changed.append(delta)
	# Retained bench end receives its own grounded leg, wholly outside the aperture column.
	StadiumSeatingModels._box(
		root,
		"TunnelBenchEndSupport",
		Vector3(1.15 if not left else -1.15, 0.225, 2.05),
		Vector3(0.15, 0.45, 0.42),
		Color("5b6658")
	)
	_tag_added(root, "TunnelBenchEndSupport")
	_seal(root, row, "dugout-rear-port-v1", port, changed)
	root.set_meta("tunnel_approach_cut", approach)
	return true


static func apply_stand(root: Node3D, row: Dictionary) -> bool:
	if (
		not _owned(root, row, "lower", "ST-029", "BASE-")
		or not _source_box(root, "SolidRow0", AABB(Vector3(-3, 0, 0), Vector3(5.3, 3, 0.7)))
		or not _source_box(root, "EntryStep0", AABB(Vector3(2.3, 0, 0), Vector3(0.7, 0.15, 0.175)))
		or not _source_box(
			root, "EntryStep39", AABB(Vector3(2.3, 0, 6.825), Vector3(0.7, 6, 0.175))
		)
	):
		return false
	var left: bool = row.site == "TUNNEL-L"
	if not left:
		# The original right end is the only ground-to-rear staircase. An aperture cut
		# there would delete low treads. This authorized compatible version relocates
		# the WHOLE intact circulation/seating arrangement to the opposite end.
		# All source members are x-symmetric boxes or symmetric crowd anchors, and
		# inclined rails lie in YZ: changing their centers requires no negative scale.
		for branch: String in ["Visual", "Collision"]:
			for member: Node3D in root.get_node(branch).get_children():
				member.position.x = -member.position.x
	var port: AABB = AABB(Vector3(-3 if left else 2.3, 0, 1.5), Vector3(STAND_DEPTH, 2.4, 2))
	var changed: Array[Dictionary] = []
	for index in range(2, 5):
		var delta: Dictionary = _cut(root, "SolidRow%d" % index, port)
		if delta.is_empty():
			return false
		changed.append(delta)
	_seal(
		root,
		row,
		"baseline-end-port-v1" if left else "baseline-opposite-aisle-end-port-v1",
		port,
		changed
	)
	root.set_meta("tunnel_stair_relocated", not left)
	root.set_meta("tunnel_stair_count", 40)
	root.set_meta("tunnel_retained_seats", 50)
	root.set_meta(
		"tunnel_crest_pose_preserved",
		StadiumStraightOwnedModels.socket("ST-029", "crest").transform
	)
	# The fixed crest socket remains supported. In the right-compatible host the
	# same external plane is the solid underside of steps20..23, not a relocated crest.
	root.set_meta(
		"tunnel_crest_supports",
		["SolidRow5"] if left else ["EntryStep20", "EntryStep21", "EntryStep22", "EntryStep23"]
	)
	return true


static func _owned(
	root: Node3D, row: Dictionary, key: String, item: String, prefix: String
) -> bool:
	if (
		root == null
		or root.get_meta("stadium_item", "") != item
		or root.has_meta("player_tunnel_copy")
		or not row.get("copy") is String
		or str(row.copy).is_empty()
		or not row.get(key) is String
		or str(row[key]).is_empty()
		or row.get("site") not in ["TUNNEL-L", "TUNNEL-R"]
	):
		return false
	var suffix: String = "L" if row.site == "TUNNEL-L" else "R"
	return (
		root.get_meta("owned_copy", "") == row[key]
		and root.get_meta("site", "") == prefix + suffix + ("1" if item == "ST-029" else "")
		and root.get_node_or_null("Visual") != null
		and root.get_node_or_null("Collision") != null
	)


static func _source_box(root: Node3D, id: String, expected: AABB) -> bool:
	var mesh: MeshInstance3D = root.get_node_or_null("Visual/" + id)
	var body: StaticBody3D = root.get_node_or_null("Collision/" + id)
	return (
		mesh != null
		and body != null
		and mesh.mesh is BoxMesh
		and body.get_child_count() == 1
		and body.get_child(0) is CollisionShape3D
		and body.get_child(0).shape is BoxShape3D
		and _same(mesh.transform * mesh.mesh.get_aabb(), expected)
		and _same(
			AABB(body.position - body.get_child(0).shape.size / 2, body.get_child(0).shape.size),
			expected
		)
	)


static func _cut(root: Node3D, id: String, cut: AABB) -> Dictionary:
	var visual: MeshInstance3D = root.get_node("Visual/" + id)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	var original: AABB = visual.transform * visual.mesh.get_aabb()
	var overlap: AABB = original.intersection(cut)
	if not overlap.has_volume():
		return {}
	var parts: Array[AABB] = subtract(original, cut)
	var material: Material = visual.material_override
	var old_meta: Dictionary = {}
	for key: StringName in body.get_meta_list():
		old_meta[key] = body.get_meta(key)
	visual.free()
	body.free()
	for index in range(parts.size()):
		var box: AABB = parts[index]
		var next_id: String = id if index == 0 else id + "TunnelRetained%d" % index
		StadiumSeatingModels._box(root, next_id, box.get_center(), box.size, Color.WHITE)
		var next_mesh: MeshInstance3D = root.get_node("Visual/" + next_id)
		next_mesh.material_override = material
		var next_body: StaticBody3D = root.get_node("Collision/" + next_id)
		for key: StringName in old_meta:
			next_body.set_meta(key, old_meta[key])
		next_body.set_meta("surface_id", next_id)
		next_body.set_meta("owned_surface_id", str(root.get_meta("owned_copy")) + ":" + next_id)
		next_body.get_child(0).name = "Shape"
		next_body.get_child(0).shape.margin = 0
		for key: StringName in ["stadium_item", "owned_copy", "paid_copy", "site", "surface_role"]:
			if next_body.has_meta(key):
				next_mesh.set_meta(key, next_body.get_meta(key))
	return {"member": id, "original": original, "removed": overlap, "retained": parts}


static func subtract(box: AABB, cut: AABB) -> Array[AABB]:
	var intersection: AABB = box.intersection(cut)
	if not intersection.has_volume():
		return [box]
	var result: Array[AABB] = []
	var low: Vector3 = box.position
	var high: Vector3 = box.end
	var a: Vector3 = intersection.position
	var b: Vector3 = intersection.end
	for pair: Array in [
		[low, Vector3(a.x, high.y, high.z)],
		[Vector3(b.x, low.y, low.z), high],
		[Vector3(a.x, low.y, low.z), Vector3(b.x, a.y, high.z)],
		[Vector3(a.x, b.y, low.z), Vector3(b.x, high.y, high.z)],
		[Vector3(a.x, a.y, low.z), Vector3(b.x, b.y, a.z)],
		[Vector3(a.x, a.y, b.z), Vector3(b.x, b.y, high.z)]
	]:
		var piece: AABB = AABB(pair[0], pair[1] - pair[0])
		if piece.size.x > EPS and piece.size.y > EPS and piece.size.z > EPS:
			result.append(piece)
	return result


static func _tag_added(root: Node3D, id: String) -> void:
	for branch: String in ["Visual", "Collision"]:
		var member: Node = root.get_node(branch + "/" + id)
		for key: StringName in [
			"stadium_item", "owned_copy", "paid_copy", "site", "boundary_owned"
		]:
			if root.has_meta(key):
				member.set_meta(key, root.get_meta(key))
		member.set_meta("surface_role", ROLE)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	body.set_meta("owned_surface_id", str(root.get_meta("owned_copy")) + ":" + id)
	body.get_child(0).name = "Shape"
	body.get_child(0).shape.margin = 0


static func _seal(
	root: Node3D, row: Dictionary, profile: String, port: AABB, changes: Array[Dictionary]
) -> void:
	root.set_meta("player_tunnel_copy", row.copy)
	root.set_meta("player_tunnel_adapter_version", VERSION)
	root.set_meta("player_tunnel_host_profile", profile)
	root.set_meta("player_tunnel_host_port", port)
	root.set_meta("player_tunnel_host_changes", changes)


static func _same(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS
