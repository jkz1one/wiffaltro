extends RefCounted
## Bounded registry-only source presentation snapshots; capture is synchronous/read-only.
## Keep states in memory. Only proof(state), never the resource-bearing state, may enter JSON.
## Caller owns the whole-lab capture lock, source parent poses, camera, ball and live/dead state.

const Actors = preload("res://src/tests/stadium_long_yard_actor_proof.gd")


static func capture(lab: PitchBatLab) -> Dictionary:
	var state: Dictionary = {
		"lab_id": lab.get_instance_id(),
		"nodes": [],
		"models": [],
		"materials": {},
		"errors": [],
		"renderer_omissions": [],
		"registry": {},
		"kind": "ACTUAL_SOURCE_PRESENTATION"
	}
	var roots: Dictionary = _roots(lab, state.errors)
	state.registry = _membership(roots)
	var seen: Dictionary = {}
	for role: String in roots:
		var root: Node3D = roots[role]
		var nodes: Array[Node] = [root]
		nodes.append_array(root.find_children("*", "Node3D", true, false))
		for node: Node3D in nodes:
			if seen.has(node.get_instance_id()):
				continue
			seen[node.get_instance_id()] = true
			var row: Dictionary = _node(node, role, lab)
			if node is MeshInstance3D:
				row.render = _mesh_instance(node, state)
			state.nodes.append(row)
	var property: StadiumLongYardProperty = lab.get_meta("stadium_property")
	if property == null or not property.receiver is StadiumLongYardReceiver:
		return state
	for model: Node3D in [property.receiver.chair, property.receiver.net]:
		# Model roots own collision: record/verify their fixed poses, never move them.
		var row: Dictionary = _node(model, "receiver-collision-owner-guard", lab)
		row.meta = _meta(model, "receiver_render_state")
		state.models.append(row)
	return state


static func restore(owner: Node, lab: PitchBatLab, state: Dictionary) -> void:
	# Requires callbacks/tweens already locked; no camera, ball, resolver or physics writes.
	_apply(owner, lab, state, true)


static func release(owner: Node, lab: PitchBatLab, current_state: Dictionary) -> void:
	# Pass a capture made immediately before archived restoration, while the lock is held.
	# Restores original ImmediateMesh identity; its contents were never touched by this helper.
	_apply(owner, lab, current_state, false)


static func proof(state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"kind": state.kind,
		"lab_id": state.lab_id,
		"errors": state.errors.duplicate(),
		"renderer_omissions": state.renderer_omissions.duplicate(),
		"native_geometry_complete": state.renderer_omissions.is_empty() and state.errors.is_empty(),
		"registered_members": state.registry.duplicate(true),
		"registered_count": state.registry.size(),
		"base_markers_present": state.registry.values().has("base-markers"),
		"nodes": [],
		"receiver_owner_guards": [],
		"materials": []
	}
	for row: Dictionary in state.nodes:
		var numeric: Dictionary = _node_proof(row)
		if row.has("render"):
			var draw: Dictionary = row.render
			numeric.render = {
				"mesh_id": _id(draw.mesh.source),
				"mesh_class": draw.mesh.source_class,
				"archived_geometry_mode": draw.mesh.mode,
				"surfaces": [],
				"override_id": _id(draw.override),
				"overlay_id": _id(draw.overlay),
				"shadow": draw.shadow,
				"transparency": draw.transparency,
				"surface_override_ids": [],
				"active_surface_override_ids": [],
				"surface_count": draw.mesh.surface_count,
				"override_slot_policy": draw.override_slot_policy
			}
			for surface: Dictionary in draw.mesh.surfaces:
				numeric.render.surfaces.append(
					{
						"primitive": surface.primitive,
						"format": surface.format,
						"arrays_sha256": surface.arrays_sha256,
						"colors_sha256": surface.colors_sha256,
						"raw_sha256": surface.raw_sha256,
						"material_id": _id(surface.material)
					}
				)
			for material: Material in draw.surface_overrides:
				numeric.render.surface_override_ids.append(_id(material))
			for material: Material in draw.active_surface_overrides:
				numeric.render.active_surface_override_ids.append(_id(material))
		result.nodes.append(numeric)
	for row: Dictionary in state.models:
		result.receiver_owner_guards.append(_node_proof(row))
	for row: Dictionary in state.materials.values():
		var numeric: Dictionary = {"id": row.id, "class": row.kind}
		if row.has("color"):
			numeric.albedo_color = [row.color.r, row.color.g, row.color.b, row.color.a]
			numeric.transparency = row.transparency
		result.materials.append(numeric)
	return result


static func _roots(lab: PitchBatLab, errors: Array) -> Dictionary:
	var result: Dictionary = Actors.actors(lab)
	if result.size() != 4:
		errors.append("four actual registered actors are required")
	var property: StadiumLongYardProperty = lab.get_meta("stadium_property")
	if property == null or not property.receiver is StadiumLongYardReceiver:
		errors.append("genuine installed LONG-YARD receiver is required")
		return result
	for label: String in ["chair", "net"]:
		var model: Node3D = property.receiver.get(label)
		var visual: Node3D = model.get_node_or_null("Visual")
		if visual == null:
			errors.append("actual receiver Visual subtree is missing: " + label)
		else:
			result["receiver-" + label] = visual
	var bases: Node3D = property.get_node_or_null("BaseMarkerSet")
	if bases != null:
		result["base-markers"] = bases
	var visibility: BallVisibility = lab._ball_visibility
	if (
		not is_instance_valid(visibility)
		or visibility.get_parent() != lab
		or not is_instance_valid(visibility._shadow)
		or not is_instance_valid(visibility._trail)
		or visibility._shadow.get_parent() != visibility
		or visibility._trail.get_parent() != visibility
	):
		errors.append("actual BallVisibility root/shadow/trail identities are required")
	else:
		result["ball-visibility"] = visibility
	return result


static func _node(node: Node3D, role: String, lab: PitchBatLab) -> Dictionary:
	return {
		"node": node,
		"id": node.get_instance_id(),
		"parent_id": node.get_parent().get_instance_id(),
		"path": String(lab.get_path_to(node)),
		"role": role,
		"local": node.transform,
		"world": node.global_transform,
		"visible": node.visible,
		"visible_in_tree": node.is_visible_in_tree(),
		"meta": _meta(node, "base_render_state")
	}


static func _meta(node: Node, key: String) -> Dictionary:
	return {"key": key, "present": node.has_meta(key), "value": node.get_meta(key, "")}


static func _mesh_instance(mesh: MeshInstance3D, state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"mesh": _geometry(mesh.mesh, state),
		"override": mesh.material_override,
		"overlay": mesh.material_overlay,
		"surface_overrides": [],
		"active_surface_overrides": [],
		"override_slot_policy": "exact-surface-slots",
		"shadow": int(mesh.cast_shadow),
		"transparency": mesh.transparency
	}
	_material(mesh.material_override, state.materials)
	_material(mesh.material_overlay, state.materials)
	for index: int in range(mesh.get_surface_override_material_count()):
		var material: Material = mesh.get_surface_override_material(index)
		result.surface_overrides.append(material)
		_material(material, state.materials)
	var count: int = result.mesh.surface_count
	result.active_surface_overrides = result.surface_overrides.slice(0, count)
	if (
		mesh.mesh is ImmediateMesh
		and count == 0
		and result.surface_overrides.size() == 1
		and result.surface_overrides[0] == null
	):
		result.override_slot_policy = "empty-ImmediateMesh-single-null-slot-normalized"
	if not _override_record_valid(result):
		state.errors.append(
			"unsupported source surface/override-slot mismatch: " + str(mesh.get_path())
		)
	return result


static func _geometry(mesh: Mesh, state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"source": mesh,
		"source_class": mesh.get_class() if mesh != null else "null",
		"surface_count": mesh.get_surface_count() if mesh != null else 0,
		"mode": "retained-source-resource",
		"surfaces": []
	}
	if mesh == null:
		return result
	if mesh is ImmediateMesh:
		if DisplayServer.get_name() == "headless":
			result.mode = "native-required-ImmediateMesh-renderer-proof-omitted"
			state.renderer_omissions.append("ImmediateMesh:%d" % mesh.get_instance_id())
			return result
		result.mode = "exact-ImmediateMesh-surface-copy-as-ArrayMesh"
	for index: int in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(index).duplicate(true)
		var raw: Dictionary = {}
		var primitive: int = Mesh.PRIMITIVE_TRIANGLES
		if mesh is ImmediateMesh:
			raw = RenderingServer.mesh_get_surface(mesh.get_rid(), index).duplicate(true)
			if not raw.has("primitive") or not raw.has("vertex_data"):
				state.errors.append(
					"ImmediateMesh raw surface unavailable; native renderer required"
				)
			primitive = int(raw.get("primitive", -1))
		elif mesh is ArrayMesh:
			primitive = (mesh as ArrayMesh).surface_get_primitive_type(index)
		var material: Material = mesh.surface_get_material(index)
		_material(material, state.materials)
		# The raw renderer record can contain a RID; retain the actual Material instead.
		raw.erase("material")
		var colors: Variant = arrays[Mesh.ARRAY_COLOR] if arrays.size() == Mesh.ARRAY_MAX else null
		result.surfaces.append(
			{
				"arrays": arrays,
				"primitive": primitive,
				"format": _format(mesh, index),
				"material": material,
				"raw": raw,
				"arrays_sha256": _sha(var_to_bytes(arrays)),
				"colors_sha256": _sha(var_to_bytes(colors)),
				"raw_sha256": _sha(var_to_bytes(raw))
			}
		)
		if arrays.size() != Mesh.ARRAY_MAX:
			state.errors.append("source surface arrays unavailable: " + mesh.get_class())
	return result


static func _material(material: Material, materials: Dictionary) -> void:
	if material == null or materials.has(material.get_instance_id()):
		return
	var row: Dictionary = {
		"resource": material, "id": material.get_instance_id(), "kind": material.get_class()
	}
	if material is StandardMaterial3D:
		row.color = material.albedo_color
		row.transparency = material.transparency
	materials[row.id] = row


static func _apply(owner: Node, lab: PitchBatLab, state: Dictionary, archived: bool) -> void:
	owner._check(
		state.errors.is_empty(), "native presentation capture errors: " + str(state.errors)
	)
	owner._check(
		state.renderer_omissions.is_empty(), "native restore has complete renderer evidence"
	)
	var valid: bool = _valid(lab, state)
	owner._check(
		valid, "archived presentation retains exact registered nodes and receiver owner poses"
	)
	if not valid:
		return
	for row: Dictionary in state.materials.values():
		if row.has("color"):
			var material: StandardMaterial3D = row.resource
			material.albedo_color = row.color
			material.transparency = row.transparency
	for row: Dictionary in state.nodes:
		var node: Node3D = row.node
		node.transform = row.local
		node.visible = row.visible
		_restore_meta(node, row.meta)
		if row.has("render"):
			_apply_mesh(owner, node as MeshInstance3D, row.render, archived)
	for row: Dictionary in state.models:
		_restore_meta(row.node, row.meta)
		owner._check(
			_meta(row.node, row.meta.key) == row.meta, "actual receiver render state restored"
		)
	for row: Dictionary in state.nodes:
		var node: Node3D = row.node
		owner._check(
			(
				node.transform == row.local
				and node.global_transform == row.world
				and node.visible == row.visible
				and node.is_visible_in_tree() == row.visible_in_tree
				and _meta(node, row.meta.key) == row.meta
			),
			"source presentation exact local/world pose and visibility: " + row.path
		)
	for row: Dictionary in state.materials.values():
		if row.has("color"):
			owner._check(
				(
					row.resource.albedo_color == row.color
					and row.resource.transparency == row.transparency
				),
				"source StandardMaterial identity color and transparency restored"
			)


static func _valid(lab: PitchBatLab, state: Dictionary) -> bool:
	if state.get("lab_id", 0) != lab.get_instance_id() or not state.get("errors", []).is_empty():
		return false
	var errors: Array = []
	var roots: Dictionary = _roots(lab, errors)
	if not errors.is_empty() or not state.renderer_omissions.is_empty() or state.models.size() != 2:
		return false
	if _membership(roots) != state.registry or state.nodes.size() != state.registry.size():
		return false
	var seen: Dictionary = {}
	for row: Dictionary in state.nodes:
		var node: Node3D = row.node as Node3D
		if (
			not is_instance_valid(node)
			or seen.has(row.id)
			or not roots.has(row.role)
			or (node is MeshInstance3D) != row.has("render")
			or node.get_instance_id() != row.id
			or node.get_parent().get_instance_id() != row.parent_id
			or String(lab.get_path_to(node)) != row.path
			or not (node == roots[row.role] or roots[row.role].is_ancestor_of(node))
		):
			return false
		if row.has("render") and not _override_record_valid(row.render):
			return false
		seen[row.id] = true
	var property: StadiumLongYardProperty = lab.get_meta("stadium_property")
	var model_ids: Dictionary = {}
	for row: Dictionary in state.models:
		var node: Node3D = row.node as Node3D
		if (
			not is_instance_valid(node)
			or model_ids.has(row.id)
			or node not in [property.receiver.chair, property.receiver.net]
			or node.get_instance_id() != row.id
			or node.get_parent().get_instance_id() != row.parent_id
			or node.transform != row.local
			or node.global_transform != row.world
			or node.visible != row.visible
		):
			return false
		model_ids[row.id] = true
	return true


static func _apply_mesh(owner: Node, node: MeshInstance3D, row: Dictionary, archived: bool) -> void:
	var valid: bool = _override_record_valid(row)
	owner._check(
		valid, "surface override record has an explicit render-effective validity contract"
	)
	if not valid:
		return
	var geometry: Dictionary = row.mesh
	var source: Mesh = geometry.source
	var restored: Mesh = source
	if archived and source is ImmediateMesh:
		restored = _immediate_copy(owner, geometry)
		if restored == null:
			return
	# ed1daf0bf ImmediateMesh.clear_surfaces() does not emit_changed(). Its instance
	# can retain one NULL bookkeeping slot after the sole trail surface disappears.
	# Keep that raw historical slot in proof; there is no material/surface to restore.
	# Rebinding also normalizes a same-resource release without touching mesh contents.
	if row.override_slot_policy == "empty-ImmediateMesh-single-null-slot-normalized":
		if node.mesh == restored:
			node.mesh = null
		print(
			"LONG_YARD_EMPTY_NULL_SLOT_NORMALIZATION node=",
			node.get_path(),
			" raw_slots=1 active=0"
		)
	node.mesh = restored
	var count_matches: bool = (
		node.get_surface_override_material_count() == row.active_surface_overrides.size()
	)
	owner._check(count_matches, "restored override slots match every render-active source surface")
	if not count_matches:
		return
	node.material_override = row.override
	node.material_overlay = row.overlay
	node.cast_shadow = row.shadow
	node.transparency = row.transparency
	for index: int in range(row.active_surface_overrides.size()):
		node.set_surface_override_material(index, row.active_surface_overrides[index])
		owner._check(
			node.get_surface_override_material(index) == row.active_surface_overrides[index],
			"actual archived per-surface material override retains source identity"
		)
	(
		owner
		. _check(
			_geometry_equal(restored, geometry),
			"archived geometry retains exact source arrays/colors/primitive; ImmediateMesh copy is explicit"
		)
	)
	owner._check(
		_effective_materials_equal(node, row),
		"source mesh material identities shadow and instance transparency restored"
	)
	if not archived and source is ImmediateMesh:
		owner._check(
			node.mesh == source, "cleanup restores original untouched ImmediateMesh identity"
		)


static func _override_record_valid(row: Dictionary) -> bool:
	var geometry: Dictionary = row.mesh
	var count: int = geometry.surface_count
	var raw: Array = row.surface_overrides
	var active: Array = row.active_surface_overrides
	if (
		count < 0
		or active.size() != count
		or active != raw.slice(0, count)
		or (
			geometry.mode != "native-required-ImmediateMesh-renderer-proof-omitted"
			and geometry.surfaces.size() != count
		)
	):
		return false
	if row.override_slot_policy == "exact-surface-slots":
		return raw.size() == count
	return (
		row.override_slot_policy == "empty-ImmediateMesh-single-null-slot-normalized"
		and geometry.source is ImmediateMesh
		and geometry.source_class == "ImmediateMesh"
		and count == 0
		and geometry.surfaces.is_empty()
		and raw.size() == 1
		and raw[0] == null
		and active.is_empty()
	)


static func _effective_materials_equal(node: MeshInstance3D, row: Dictionary) -> bool:
	if (
		not _override_record_valid(row)
		or node.get_surface_override_material_count() != row.active_surface_overrides.size()
		or node.material_override != row.override
		or node.material_overlay != row.overlay
		or int(node.cast_shadow) != row.shadow
		or node.transparency != row.transparency
	):
		return false
	for index: int in range(row.active_surface_overrides.size()):
		if node.get_surface_override_material(index) != row.active_surface_overrides[index]:
			return false
	return true


static func _immediate_copy(owner: Node, geometry: Dictionary) -> ArrayMesh:
	var copied: ArrayMesh = ArrayMesh.new()
	var records: Array = []
	for surface: Dictionary in geometry.surfaces:
		var record: Dictionary = surface.raw.duplicate(true)
		if record.has("lods") or record.has("bone_aabbs") or record.has("blend_shape_data"):
			owner._check(false, "unsupported ImmediateMesh LOD/bone/blend record rejected")
			return null
		record.material = surface.material
		records.append(record)
	var supported: bool = copied.has_method("_set_surfaces")
	owner._check(supported, "exact ImmediateMesh copy has qualified raw ArrayMesh serializer")
	if not supported:
		return null
	# Frozen engine ed1daf0bf: mesh.cpp:1468-1553/2159 and
	# rendering/rendering_server.cpp:1854-1898. ImmediateMesh surfaces have no LODs,
	# bones or blends (immediate_mesh.cpp:258-277); reject rather than misconvert those.
	# Raw format/vertex/attribute bytes avoid decoded color/normal requantization.
	if not records.is_empty():
		copied.call("_set_surfaces", records)
	var exact: bool = _geometry_equal(copied, geometry)
	owner._check(exact, "ImmediateMesh raw copy verifies every source surface array exactly")
	return copied if exact else null


static func _geometry_equal(mesh: Mesh, geometry: Dictionary) -> bool:
	if mesh == null:
		return geometry.source == null
	if mesh.get_surface_count() != geometry.surfaces.size():
		return false
	for index: int in range(geometry.surfaces.size()):
		var surface: Dictionary = geometry.surfaces[index]
		var primitive: int = Mesh.PRIMITIVE_TRIANGLES
		if mesh is ArrayMesh:
			primitive = (mesh as ArrayMesh).surface_get_primitive_type(index)
		elif mesh is ImmediateMesh:
			primitive = int(
				RenderingServer.mesh_get_surface(mesh.get_rid(), index).get("primitive", -1)
			)
		if (
			primitive != surface.primitive
			or _format(mesh, index) != surface.format
			or mesh.surface_get_material(index) != surface.material
			or var_to_bytes(mesh.surface_get_arrays(index)) != var_to_bytes(surface.arrays)
		):
			return false
		if not surface.raw.is_empty():
			var actual: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), index)
			actual.erase("material")
			if var_to_bytes(actual) != var_to_bytes(surface.raw):
				return false
	return true


static func _membership(roots: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for role: String in roots:
		var root: Node3D = roots[role]
		var nodes: Array[Node] = [root]
		nodes.append_array(root.find_children("*", "Node3D", true, false))
		for node: Node3D in nodes:
			result[str(node.get_instance_id())] = role
	return result


static func _format(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh:
		return int((mesh as ArrayMesh).surface_get_format(surface))
	if mesh is ImmediateMesh and DisplayServer.get_name() != "headless":
		return int(RenderingServer.mesh_get_surface(mesh.get_rid(), surface).get("format", -1))
	# PrimitiveMesh uses CPU-generated arrays; no renderer-format proof is claimed here.
	return -1


static func _restore_meta(node: Node, meta: Dictionary) -> void:
	if meta.present:
		node.set_meta(meta.key, meta.value)
	elif node.has_meta(meta.key):
		node.remove_meta(meta.key)


static func _node_proof(row: Dictionary) -> Dictionary:
	return {
		"id": row.id,
		"parent_id": row.parent_id,
		"path": row.path,
		"role": row.role,
		"local_basis_columns_then_origin": _pose(row.local),
		"world_basis_columns_then_origin": _pose(row.world),
		"visible": row.visible,
		"visible_in_tree": row.visible_in_tree,
		"render_state": row.meta.duplicate(true)
	}


static func _pose(value: Transform3D) -> Array:
	var result: Array = []
	for vector: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result


static func _id(value: Object) -> int:
	return value.get_instance_id() if is_instance_valid(value) else 0


static func _sha(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()
