class_name StadiumYardTwoCameraMotion
extends BallInPlayCamera
## Reconstructed AY-02 only: choose existing coverage from authentic precontact scenery and launch.
## The shared acceleration, turn, projection and FOV implementation is inherited unchanged.

var property_ref: WeakRef
var cone_ref: WeakRef
var cone_pose: Transform3D
var cone_bounds: AABB
var boundary_ref: WeakRef
var boundary_state: Dictionary = {}
var coverage_reason: String = "shared-launch-coverage"
var coverage_boundary: String = ""


func bind_candidate(property: StadiumYardTwoProperty) -> bool:
	var identity: String = StadiumYardTwoStudy.PREFIX + "O-R1"
	var cone: Node3D = property.objects.get(identity)
	if (
		not property.model_intact(identity)
		or property.transform != Transform3D.IDENTITY
		or cone == null
		or cone.transform != StadiumYardTwoStudy.pose("O-R1")
	):
		return false
	var first: bool = true
	for mesh: MeshInstance3D in cone.get_node("Visual").find_children(
		"*", "MeshInstance3D", true, false
	):
		# Admission requires an identity host. Compose genuine local transforms before
		# replacement, so the last fallible bind can reject without touching the original lab.
		var pose: Transform3D = mesh.transform
		var parent: Node3D = mesh.get_parent() as Node3D
		while parent != property:
			if parent == null:
				return false
			pose = parent.transform * pose
			parent = parent.get_parent() as Node3D
		var bounds: AABB = pose * mesh.get_aabb()
		cone_bounds = bounds if first else cone_bounds.merge(bounds)
		first = false
	if first:
		return false
	var boundary: StadiumBoundaryPrototype = property.get_node_or_null("BoundaryGraph")
	if boundary == null:
		return false
	var reference: StadiumBoundaryPrototype = StadiumBoundaryPrototype.new()
	var built: bool = reference.build()
	var actual: Dictionary = _boundary_data(boundary, false)
	var canonical: Dictionary = _boundary_data(reference, false) if built else {}
	reference.free()
	if actual.is_empty() or actual != canonical:
		return false
	boundary_ref = weakref(boundary)
	boundary_state = _boundary_data(boundary, true)
	property_ref = weakref(property)
	cone_ref = weakref(cone)
	cone_pose = cone.transform
	return true


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	super.prepare(defense, ball, launch)
	coverage_reason = "shared-launch-coverage"
	coverage_boundary = ""
	var property: StadiumYardTwoProperty = (
		property_ref.get_ref() as StadiumYardTwoProperty if property_ref != null else null
	)
	var cone: Node3D = cone_ref.get_ref() as Node3D if cone_ref != null else null
	if (
		property == null
		or cone == null
		or not property.model_intact(StadiumYardTwoStudy.PREFIX + "O-R1")
		or cone.global_transform != cone_pose
	):
		return
	var horizontal: Vector3 = Vector3(launch.x, 0, launch.z)
	if horizontal.length_squared() <= 0.0001:
		return
	# Project the authentic cone's bounds into the launch plane. The existing 0.4 m
	# visibility margin predicts a foreground conflict before bounded movement begins.
	var corridor: AABB = cone_bounds.grow(0.4)
	var start: Vector3 = Vector3(ball.x, corridor.get_center().y, ball.z)
	if corridor.intersects_segment(start, start + horizontal.normalized() * 100) != null:
		# Presentation coverage only; player role and input ownership remain untouched.
		_defense = true
		_clearance_offset = 14.0
		coverage_reason = "authentic-cone-launch-corridor"
		return
	if not _boundary_intact():
		return
	# Keep the original offense/defense branch. Only an authenticated lateral offense
	# launch can acquire the field-side desired-target policy; no future trace is read.
	var flat: Vector3 = Vector3(ball.x, 0, ball.z)
	var crossing: Dictionary = StadiumBoundaryGraph.crossing(
		flat, flat + horizontal.normalized() * 100
	)
	if not defense and crossing.get("segment", "") in ["SIDE-L-01", "SIDE-R-01"]:
		coverage_boundary = crossing.segment
		coverage_reason = "authentic-side-wall-offense-target"


func constrain_target(desired: Vector3) -> Vector3:
	if (
		coverage_reason != "authentic-side-wall-offense-target"
		or _defense
		or not _boundary_intact()
	):
		return desired
	# Project the desired target, not the actual camera pose. The shared avoidance,
	# acceleration, speed, look-direction and FOV update execute afterwards unchanged.
	var result: Vector3 = desired
	for identity: String in ["SIDE-R-01", "SIDE-L-01"]:
		var row: Dictionary = StadiumBoundaryGraph.segment(identity)
		var normal: Vector2 = StadiumBoundaryGraph.inward(row)
		var gap: float = (Vector2(result.x, result.z) - row.a).dot(normal)
		var clearance: float = BallTrackingVisibility.WALL_CAMERA_CLEARANCE
		if gap < clearance:
			result.x += normal.x * (clearance - gap)
			result.z += normal.y * (clearance - gap)
	return result


func _boundary_intact() -> bool:
	var property: StadiumYardTwoProperty = (
		property_ref.get_ref() as StadiumYardTwoProperty if property_ref != null else null
	)
	var boundary: StadiumBoundaryPrototype = (
		boundary_ref.get_ref() as StadiumBoundaryPrototype if boundary_ref != null else null
	)
	return (
		property != null
		and boundary != null
		and property.global_transform == Transform3D.IDENTITY
		and property.get_node_or_null("BoundaryGraph") == boundary
		and _boundary_data(boundary, true) == boundary_state
	)


static func _boundary_data(boundary: StadiumBoundaryPrototype, identities: bool) -> Dictionary:
	if boundary.get_script() != StadiumBoundaryPrototype:
		return {}
	var rows: Array = []
	for child: Node in boundary.get_children():
		if not child is StaticBody3D or child.get_child_count() != 2:
			return {}
		var body: StaticBody3D = child as StaticBody3D
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		var mesh: MeshInstance3D = body.get_child(1) as MeshInstance3D
		if (
			shape == null
			or not shape.shape is ConvexPolygonShape3D
			or mesh == null
			or mesh.mesh == null
			or not mesh.material_override is StandardMaterial3D
		):
			return {}
		var material: StandardMaterial3D = mesh.material_override
		rows.append(
			{
				"name": String(body.name),
				"pose": body.transform,
				"segment": body.get_meta("boundary_segment", ""),
				"surface": body.get_meta("ball_surface", ""),
				"layer": body.collision_layer,
				"mask": body.collision_mask,
				"body_script": body.get_script(),
				"shape_pose": shape.transform,
				"shape_disabled": shape.disabled,
				"shape_points": shape.shape.points,
				"shape_script": shape.get_script(),
				"mesh_name": String(mesh.name),
				"mesh_pose": mesh.transform,
				"mesh_faces": mesh.mesh.get_faces(),
				"mesh_script": mesh.get_script(),
				"visible": mesh.visible,
				"alpha": mesh.transparency,
				"color": material.albedo_color,
				"cull": material.cull_mode,
				"roughness": material.roughness,
				"transparency": material.transparency,
				"ids":
				(
					[
						body.get_instance_id(),
						shape.get_instance_id(),
						shape.shape.get_instance_id(),
						mesh.get_instance_id(),
						mesh.mesh.get_instance_id(),
						material.get_instance_id()
					]
					if identities
					else []
				)
			}
		)
	return {"pose": boundary.transform, "rows": rows}
