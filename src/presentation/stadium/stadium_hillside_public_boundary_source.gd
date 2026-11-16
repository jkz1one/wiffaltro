class_name StadiumHillsidePublicBoundarySource
extends Node3D
## DD bespoke infrastructure, never catalog wall copies. The property owns contact binding.
## Reuses retained closed-slice/panel math; each CI interval is physically replaced by ST032.

const QUERY_MASK: int = StadiumTimberDugoutBoundary.QUERY_MASK

var member_bodies: Array[StaticBody3D] = []
var items: Array[Node3D] = []

var graph: StadiumHillsidePublicBoundary
var bodies: Array[StaticBody3D] = []
var slice_count: int = 0


func build() -> bool:
	if get_script() != StadiumHillsidePublicBoundarySource or get_child_count() != 0 \
		or graph != null or transform != Transform3D.IDENTITY:
		return false
	graph = StadiumHillsidePublicBoundary.create_hillside()
	var rows: Array[Dictionary] = graph.segments()
	if rows.size() != graph.polygon().size():
		return false
	for index in range(rows.size()):
		# Exclude the WHOLE six-metre replacement, including its two face pieces.
		# The retained timber asset alone supplies the fronts, aperture and exterior rails.
		if rows[index].role.begins_with("DUGOUT"):
			continue
		if not _slab(rows[index], index, rows.size()):
			return false
	set_meta("production_ready", false)
	set_meta("perimeter_signature", graph.signature())
	set_meta("terrain_profile", "hill")
	return bodies.size() == 10


func _slab(row: Dictionary, index: int, count: int) -> bool:
	var corners: PackedVector2Array = [row.a, row.b,
		graph.outer_vertex((index + 1) % count), graph.outer_vertex(index)]
	var parts: Array[PackedVector2Array] = StadiumHillsideBoundaryBody._split_at_knots(corners)
	if parts.is_empty() or slice_count + parts.size() > StadiumHillsideBoundaryBody.MAX_SLICES:
		return false
	var body: StaticBody3D = StaticBody3D.new()
	body.name = row.id
	body.collision_layer = 1 | QUERY_MASK
	body.collision_mask = 2
	body.set_meta("boundary_segment", row.id)
	body.set_meta("ball_surface", &"stadium_boundary")
	_tag(body, row.id, row.role, row.priority, "boundary")
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for part: PackedVector2Array in parts:
		var points: PackedVector3Array = []
		for lift: float in [0.0, float(row.height)]:
			for corner: Vector2 in part:
				var support: float = StadiumHillsideTerrain.support_height(corner, "hill")
				if not is_finite(support):
					body.free()
					return false
				points.append(Vector3(corner.x, support + lift, corner.y))
		var collider: CollisionShape3D = CollisionShape3D.new()
		collider.name = "TerrainSlice%03d" % slice_count
		var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
		shape.margin = 0.0
		shape.points = points
		collider.shape = shape
		body.add_child(collider)
		slice_count += 1
		StadiumHillsideBoundaryBody._add_prism(surface, points, part.size())
	surface.generate_normals()
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "TerrainConformedPanels"
	visual.mesh = surface.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("507f96") if row.role == "BACK_WALL_TERMINAL" \
		else Color("897756")
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
	bodies.append(body)
	return true


func geometry_report() -> Dictionary:
	return {"status": "WORKING_SOURCE_ONLY_PUBLIC_UNADMITTED", "segments": bodies.size(),
		"slices": slice_count, "maximum_slices": StadiumHillsideBoundaryBody.MAX_SLICES,
		"profile": "hill", "xz": "unchanged-deeper-center", "max_legal_center_z": 26.0,
		"max_defender_center_z": 26.0 - StadiumRecipeBoundary.DEFENDER_RADIUS,
		"replacements": ["DUGOUT-L", "DUGOUT-R"], "paid_boundary_copies": 0,
		"height_definition": "vertical-sampled-support-plus-retained-relative-height",
		"visual": "same-slice-points-as-collision", "timber_runtime_admitted": false,
		"native_support_error_status": "unmeasured", "production_ready": false}


func register_members(construction: StadiumHillsidePublicConstruction) -> bool:
	# The construction is the common ancestor. Never duplicate or reparent an asset.
	if construction == null or get_parent() != construction or not member_bodies.is_empty():
		return false
	member_bodies.assign(bodies)
	for site: String in StadiumHillsidePublicConstruction.SITES:
		var model: Node3D = construction.objects.get(
			StadiumHillsidePublicConstruction.INSTANCE_PREFIX + site)
		if model == null or model.get_parent() != construction:
			return false
		items.append(model)
		var item: String = model.get_meta("stadium_item", "")
		if item == "ST-027":
			continue
		var collision: Node3D = model.get_node_or_null("Collision") as Node3D
		if collision == null:
			return false
		for body: StaticBody3D in collision.get_children():
			var role: String = body.get_meta("surface_role", "")
			if item == "ST-032":
				if role == "DECORATIVE_AFTER_TERMINAL":
					continue
				if role != "DUGOUT_FACE_LIVE":
					return false
				var inner: bool = String(body.name).ends_with("-1") == (site == "DUGOUT-L")
				_tag(body, site + ("-FACE-IN" if inner else "-FACE-OUT"), role, 350, "dugout")
			elif item == "ST-021":
				_tag(body, site, "FOUL_POLE_CONTACT", 500, "pole")
				body.set_meta("wall_cap_height", 3.25)
			elif item in ["ST-025", "ST-026"]:
				_tag(body, site + ":" + String(body.name), "RECEIVER_CONTAINMENT_FOUL", 450,
					"receiver")
			else:
				return false
			member_bodies.append(body)
	return items.size() == 8 and member_bodies.size() > bodies.size()


static func _tag(body: StaticBody3D, id: String, role: String, priority: int,
	kind: String) -> void:
	body.collision_layer |= QUERY_MASK
	body.collision_mask = 2
	body.set_meta("club_surface", id)
	body.set_meta("surface_role", role)
	body.set_meta("surface_priority", priority)
	body.set_meta("surface_kind", kind)
