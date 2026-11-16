class_name StadiumWaterfallAnimatedModels
extends RefCounted
## Explicit presentation variant. Historical static factories and physical geometry stay frozen.
const VERSION: int = 1
const Geometry = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")


static func create(live: bool = false) -> Node3D:
	var root: Node3D = Geometry.create() if live else StadiumWaterfallMotionModels.create()
	if live:
		var frozen: Node3D = root.get_node("Visual")
		root.remove_child(frozen)
		frozen.free()
		var visual: Node3D = StadiumWaterfallMotionModels.create()
		visual.name = "Visual"
		root.add_child(visual)
		root.move_child(visual, 0)
	root.set_meta("waterfall_animation_version", VERSION)
	return root


static func visual(root: Node3D) -> Node3D:
	return root.get_node_or_null("Visual") if root.get_meta("live_furnishing", false) else root


static func valid(root: Node3D, phase: float = 0.0) -> bool:
	if (
		not is_instance_valid(root)
		or not Geometry._meta(root, "waterfall_animation_version", VERSION)
	):
		return false
	return (
		valid_live(root, phase)
		if root.get_meta("live_furnishing", false)
		else StadiumWaterfallMotionModels.valid(root, phase)
	)


static func valid_live(root: Node3D, phase: float) -> bool:
	var live: bool = true
	if (
		not is_instance_valid(root)
		or not Geometry._meta(root, "waterfall_animation_version", VERSION)
	):
		return false
	if (
		not is_instance_valid(root)
		or root.get_class() != "Node3D"
		or not Geometry._clean(root)
		or not root.transform.origin.is_finite()
		or not root.basis.is_finite()
		or not root.basis.is_equal_approx(root.basis.orthonormalized())
		or not is_equal_approx(root.basis.determinant(), 1.0)
		or not root.basis.y.is_equal_approx(Vector3.UP)
		or root.get_child_count() != (3 if live else 2)
		or not Geometry.geometry_contract_valid()
	):
		return false
	for row: Array in [
		["stadium_item", Geometry.ITEM],
		["geometry_version", Geometry.VERSION],
		["waterfall_live_version", Geometry.VERSION],
		["live_furnishing", live],
		["scenery_only", not live],
		["working_geometry_only", true],
		["night_qualified", false],
		["obstacle_units", Geometry.LIVE_UNITS if live else 0],
		["envelope", Geometry.envelope()],
		["reservation", Geometry.reservation()]
	]:
		if not Geometry._meta(root, row[0], row[1]):
			return false
	var visual: Node3D = root.get_node_or_null("Visual") as Node3D
	var collision: Node3D = root.get_node_or_null("Collision") as Node3D
	if (
		visual == null
		or visual.transform != Transform3D.IDENTITY
		or not StadiumWaterfallMotionModels.valid(visual, phase)
		or collision == null
		or collision.get_class() != "Node3D"
		or not Geometry._clean(collision)
		or collision.transform != Transform3D.IDENTITY
		or collision.get_child_count() != (1 if live else 0)
	):
		return false
	if not live:
		return true
	var body: StaticBody3D = collision.get_node_or_null(Geometry.SURFACE) as StaticBody3D
	if (
		body == null
		or body.get_class() != "StaticBody3D"
		or not Geometry._clean(body)
		or body.transform != Transform3D.IDENTITY
		or body.collision_layer != 1
		or body.collision_mask != 0
		or body.get_child_count() != Geometry.SOLID_IDS.size()
		or body.physics_material_override != null
		or body.constant_linear_velocity != Vector3.ZERO
		or body.constant_angular_velocity != Vector3.ZERO
		or not Geometry._meta(body, "stadium_item", Geometry.ITEM)
		or not Geometry._meta(body, "surface_id", Geometry.SURFACE)
		or not Geometry._meta(body, "surface_role", Geometry.LIVE)
		or body.get_shape_owners().size() != Geometry.SOLID_IDS.size()
	):
		return false
	for row: Dictionary in Geometry.solid_specs():
		var node: CollisionShape3D = body.get_node_or_null(row.id) as CollisionShape3D
		if (
			node == null
			or node.get_class() != "CollisionShape3D"
			or not Geometry._clean(node)
			or node.get_child_count() != 0
			or node.transform != Transform3D(Basis.IDENTITY, row.center)
			or node.disabled
			or not node.shape is BoxShape3D
			or node.shape.get_script() != null
			or node.shape.size != row.size
			or node.shape.margin != 0.0
		):
			return false
		var owner: int = body.shape_find_owner(node.get_index())
		if (
			body.shape_owner_get_owner(owner) != node
			or body.is_shape_owner_disabled(owner)
			or body.shape_owner_get_shape_count(owner) != 1
			or body.shape_owner_get_shape(owner, 0) != node.shape
			or body.shape_owner_get_transform(owner) != node.transform
		):
			return false
	var carrier: Node3D = root.get_node_or_null("BasinTrap") as Node3D
	return (
		carrier != null
		and carrier.get_class() == "Node3D"
		and Geometry._clean(carrier)
		and carrier.get_child_count() == 0
		and carrier.transform == Transform3D.IDENTITY
		and Geometry._meta(carrier, "volume_id", Geometry.TRAP_ID)
		and Geometry._meta(carrier, "volume", Geometry.basin_volume())
		and Geometry._meta(carrier, "pocket", Geometry.POCKET)
		and Geometry._meta(carrier, "apertures", Geometry.trap_apertures())
		and Geometry._meta(carrier, "body_radius", Geometry.BODY_RADIUS)
		and Geometry._meta(carrier, "maximum_reach", Geometry.MAX_DEFENDER_REACH)
	)


static func capture_trap(model: Node3D, retire: Callable) -> Dictionary:
	if (
		not valid_live(model, 0.0)
		or not StadiumWaterfallLiveRuntime._live(model)
		or not retire.is_valid()
	):
		return {}
	var nodes: Array[Dictionary] = []
	var resources: Array[Dictionary] = []
	var all: Array[Node] = [model]
	all.append_array(model.find_children("*", "Node3D", true, false))
	for node: Node3D in all:
		var fields: Dictionary = {}
		for field: String in StadiumWaterfallLiveRuntime.NODE_FIELDS:
			fields[field] = node.get(field)
		var metadata: Dictionary = {}
		for key: StringName in node.get_meta_list():
			metadata[key] = node.get_meta(key)
		if node is MeshInstance3D:
			for field: String in StadiumWaterfallMotionOwner.NODE_FIELDS:
				fields[field] = node.get(field)
			fields["mesh"] = node.mesh
			fields["material_override"] = node.material_override
			var captured_resources: Array[Resource] = [node.mesh, node.material_override]
			if node.material_override is ShaderMaterial:
				captured_resources.append(node.material_override.shader)
			for resource: Resource in captured_resources:
				if not resource.changed.is_connected(retire):
					resource.changed.connect(retire)
				resources.append(
					{
						"resource": resource,
						"fields": StadiumWaterfallMotionOwner._resource_fields(resource)
					}
				)
		if node is StaticBody3D:
			for field: String in [
				"collision_layer",
				"collision_mask",
				"physics_material_override",
				"constant_linear_velocity",
				"constant_angular_velocity"
			]:
				fields[field] = node.get(field)
		if node is CollisionShape3D:
			fields["shape"] = node.shape
			fields["disabled"] = node.disabled
			if not node.shape.changed.is_connected(retire):
				node.shape.changed.connect(retire)
			resources.append(
				{
					"resource": node.shape,
					"fields": StadiumWaterfallMotionOwner._resource_fields(node.shape)
				}
			)
		nodes.append(
			{
				"node": node,
				"parent": node.get_parent(),
				"name": node.name,
				"children": node.get_child_count(),
				"metadata": metadata,
				"fields": fields
			}
		)
	return {
		"model": model,
		"nodes": nodes,
		"resources": resources,
		"retire": retire,
		"carrier": model.get_node("BasinTrap"),
		"body": model.get_node("Collision/" + Geometry.SURFACE)
	}
