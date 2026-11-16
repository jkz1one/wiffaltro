class_name StadiumNpcYardTwoCameraMotionV1
extends BallInPlayCamera
# gdlint: disable=max-returns
## Retained AY-02 only: choose existing coverage from authentic precontact scenery and launch.
## The shared acceleration, turn, projection and FOV implementation is inherited unchanged.

var property_ref: WeakRef
var cone_ref: WeakRef
var cone_pose: Transform3D
var cone_bounds: AABB
var boundary_ref: WeakRef
var boundary_state: Dictionary = {}
var coverage_reason: String = "shared-launch-coverage"
var coverage_boundary: String = ""
var _property_pin: WeakRef
var _cone_pin: WeakRef
var _boundary_pin: WeakRef
var _cone_pose_pin: Transform3D
var _cone_bounds_pin: AABB
var _boundary_bytes: PackedByteArray = []


func bind_candidate(property: StadiumNpcYardTwoPropertyV1) -> bool:
	if property_ref != null or property == null or property.motion != self:
		return false
	var identity: String = StadiumNpcYardTwoV1.PREFIX + "O-R1"
	var cone: Node3D = property.objects.get(identity)
	if (
		not property.model_intact(identity)
		or property.transform != Transform3D.IDENTITY
		or cone == null
		or cone.transform != _cone_pose()
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
	var boundary: StadiumNpcYardBoundaryV1 = property.boundary
	if boundary == null:
		return false
	var reference: StadiumNpcYardBoundaryV1 = StadiumNpcYardBoundaryV1.new()
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
	_property_pin = weakref(property)
	_cone_pin = weakref(cone)
	_boundary_pin = weakref(boundary)
	_cone_pose_pin = cone_pose
	_cone_bounds_pin = cone_bounds
	_boundary_bytes = var_to_bytes(boundary_state)
	return true


func structure_bound(strict: bool = true) -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = (
		_property_pin.get_ref() as StadiumNpcYardTwoPropertyV1 if _property_pin != null else null)
	var cone: Node3D = _cone_pin.get_ref() as Node3D if _cone_pin != null else null
	var boundary: StadiumNpcYardBoundaryV1 = (
		_boundary_pin.get_ref() as StadiumNpcYardBoundaryV1 if _boundary_pin != null else null)
	return (
		property != null and cone != null and boundary != null
		and get_script() == StadiumNpcYardTwoCameraMotionV1
		and property_ref != null and property_ref.get_ref() == property
		and cone_ref != null and cone_ref.get_ref() == cone
		and boundary_ref != null and boundary_ref.get_ref() == boundary
		and property.motion == self and property.camera._live_coverage == self
		and property.transform == Transform3D.IDENTITY
		and property.construction.transform == Transform3D.IDENTITY
		and property.construction.get_parent() == property
		and property.objects.get(StadiumNpcYardTwoV1.PREFIX + "O-R1") == cone
		and cone.get_parent() == property.construction
		and property.boundary == boundary and boundary.get_parent() == property.construction
		and cone_pose == _cone_pose_pin and cone.transform == _cone_pose_pin
		and cone_bounds == _cone_bounds_pin and (not strict or _cone_pose_pin == _cone_pose())
		and not position_filter.is_valid() and framing_lead_degrees == 0.0
		and (not strict or (var_to_bytes(boundary_state) == _boundary_bytes
			and var_to_bytes(_boundary_data(boundary, true)) == _boundary_bytes))
	)


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	super.prepare(defense, ball, launch)
	coverage_reason = "shared-launch-coverage"
	coverage_boundary = ""
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null
	)
	var cone: Node3D = cone_ref.get_ref() as Node3D if cone_ref != null else null
	if (
		property == null
		or cone == null
		or not _launch_admitted(property)
		or property.motion != self or property.camera._live_coverage != self
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
	# _launch_admitted already checked the whole fixed boundary for this issued launch.
	# Keep the original offense/defense branch. Only an authenticated lateral offense
	# launch can acquire the field-side desired-target policy; no future trace is read.
	var flat: Vector3 = Vector3(ball.x, 0, ball.z)
	var crossing: Dictionary = StadiumNpcYardGraphV1.crossing(
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
		var row: Dictionary = StadiumNpcYardGraphV1.segment(identity)
		var normal: Vector2 = StadiumNpcYardGraphV1.inward(row)
		var gap: float = (Vector2(result.x, result.z) - row.a).dot(normal)
		var clearance: float = BallTrackingVisibility.WALL_CAMERA_CLEARANCE
		if gap < clearance:
			result.x += normal.x * (clearance - gap)
			result.z += normal.y * (clearance - gap)
	return result


func _boundary_intact() -> bool:
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null
	)
	var boundary: StadiumNpcYardBoundaryV1 = (
		boundary_ref.get_ref() as StadiumNpcYardBoundaryV1 if boundary_ref != null else null
	)
	return (
		property != null
		and boundary != null
		and property.callback_intact()
		and property.motion == self and property.camera._live_coverage == self
		and property.global_transform == Transform3D.IDENTITY
		and property.construction.global_transform == Transform3D.IDENTITY
		and property.boundary == boundary
		and structure_bound(not property.hot_eligible())
	)


static func _boundary_data(boundary: StadiumNpcYardBoundaryV1, identities: bool) -> Dictionary:
	if boundary.get_script() != StadiumNpcYardBoundaryV1:
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


static func _cone_pose() -> Transform3D:
	for row: Dictionary in StadiumNpcYardTwoCandidateV1.definition().instances:
		if row.site == "O-R1":
			return StadiumNpcYardTwoContractV1.transform(row.transform)
	return Transform3D.IDENTITY


func _launch_admitted(property: StadiumNpcYardTwoPropertyV1) -> bool:
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab \
		if property.lab_ref != null else null
	var issued: bool = lab != null and lab.get_script() == PitchBatLab \
		and property.camera.get_script() == StadiumNpcYardTwoCameraV1 \
		and property.phase == &"playing" and property._play_kind == &"ball_pending" \
		and property._camera_launch_generation == property.play_generation \
		and property.ordinary_callbacks()
	property._camera_launch_generation = -1
	if not issued:
		return property.audit_installation() and structure_bound(true)
	# One-shot generation from a full audit immediately before the known camera dispatch.
	# Unknown callbacks are excluded by exact lab/director scripts and live routing pins.
	return not property._auditing and not property._geometry_scanning \
		and property._visual_writing == null and lab != null and lab.get_script() == PitchBatLab \
		and property.camera.get_script() == StadiumNpcYardTwoCameraV1 \
		and StadiumNpcYardTwoRuntimeV1.binding_valid(lab, property, true, false) \
		and property.routing_intact() and property._physical_records_intact() \
		and structure_bound(false)
