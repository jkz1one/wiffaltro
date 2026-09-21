class_name StarterFieldLabGeometry
extends Node3D

var pitch_target_marker: MeshInstance3D
var batting_aim_marker: Node3D
var receiver_marker: Node3D

func set_batting_view(batting: bool) -> void:
	for part in ["ZoneLeft", "ZoneRight", "ZoneBottom", "ZoneTop"]:
		var mesh: MeshInstance3D = get_node(part)
		var material: StandardMaterial3D = mesh.material_override
		material.albedo_color.a = 0.35 if batting else 1.0
		material.transparency = (
			BaseMaterial3D.TRANSPARENCY_ALPHA if batting else BaseMaterial3D.TRANSPARENCY_DISABLED
		)
	for outline in batting_aim_marker.get_children():
		for bar in outline.get_children():
			if bar is MeshInstance3D:
				var material: StandardMaterial3D = bar.material_override
				var base_alpha: float = 0.82 if outline.name == "ContactCoverage" else 0.92
				material.albedo_color.a = base_alpha * (0.45 if batting else 1.0)

func build(
	field: FieldDefinition,
	mound_origin: Vector3,
	zone_min_x: float,
	zone_max_x: float,
	zone_min_y: float,
	zone_max_y: float,
	contact_aim_size: Vector2,
	power_aim_size: Vector2
) -> void:
	_add_static_box(
		"Ground",
		Vector3(0.0, -0.08, 12.0),
		Vector3(45.0, 0.16, 36.0),
		Color(0.19, 0.34, 0.19),
		&"ground"
	)
	_add_static_box(
		"BackWall",
		Vector3(
			0.0,
			field.home_run_height_m * 0.5,
			field.back_wall_z_m + 0.25
		),
		Vector3(38.0, field.home_run_height_m, 0.5),
		Color(0.24, 0.36, 0.46),
		&"back_wall",
		true
	)
	_add_box(
		"SafeBoundary",
		Vector3(0.0, 0.012, field.safe_hit_z_m),
		Vector3(18.0, 0.024, 0.08),
		Color(0.95, 0.84, 0.18)
	)
	_add_box(
		"DeepAirBoundary",
		Vector3(0.0, 0.014, field.deep_air_z_m),
		Vector3(29.0, 0.028, 0.08),
		Color(0.25, 0.84, 0.95)
	)
	_add_static_box(
		"LiveObjectPole",
		Vector3(7.0, 1.2, 12.0),
		Vector3(0.35, 2.4, 0.35),
		Color(0.76, 0.53, 0.20),
		&"live_object"
	)
	_add_box(
		"Plate",
		Vector3(0.0, 0.025, 0.0),
		Vector3(0.7, 0.05, 0.45),
		Color(0.92, 0.92, 0.88)
	)
	_add_box(
		"MoundMarker",
		mound_origin + Vector3(0.0, 0.025, 0.0),
		Vector3(0.8, 0.05, 0.8),
		Color(0.55, 0.38, 0.22)
	)
	var foul_half_width: float = field.back_wall_z_m * tan(
		deg_to_rad(field.fair_half_angle_degrees)
	)
	_add_field_line(
		"RightFoulLine",
		Vector3.ZERO,
		Vector3(-foul_half_width, 0.0, field.back_wall_z_m),
		Color(0.88, 0.88, 0.78, 0.78)
	)
	_add_field_line(
		"LeftFoulLine",
		Vector3.ZERO,
		Vector3(foul_half_width, 0.0, field.back_wall_z_m),
		Color(0.88, 0.88, 0.78, 0.78)
	)
	_build_strike_zone(
		zone_min_x,
		zone_max_x,
		zone_min_y,
		zone_max_y
	)
	_build_pitch_receiver()
	_build_aim_markers(contact_aim_size, power_aim_size)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

func _build_strike_zone(
	zone_min_x: float,
	zone_max_x: float,
	zone_min_y: float,
	zone_max_y: float
) -> void:
	var zone_color: Color = Color(1.0, 0.95, 0.68)
	var thickness: float = 0.034
	var center_y: float = (zone_min_y + zone_max_y) * 0.5
	var width: float = zone_max_x - zone_min_x
	var height: float = zone_max_y - zone_min_y

	_add_box(
		"ZoneLeft",
		Vector3(zone_min_x, center_y, 0.0),
		Vector3(thickness, height, thickness),
		zone_color,
		true
	)
	_add_box(
		"ZoneRight",
		Vector3(zone_max_x, center_y, 0.0),
		Vector3(thickness, height, thickness),
		zone_color,
		true
	)
	_add_box(
		"ZoneBottom",
		Vector3(0.0, zone_min_y, 0.0),
		Vector3(width, thickness, thickness),
		zone_color,
		true
	)
	_add_box(
		"ZoneTop",
		Vector3(0.0, zone_max_y, 0.0),
		Vector3(width, thickness, thickness),
		zone_color,
		true
	)

func _build_pitch_receiver() -> void:
	receiver_marker = Node3D.new()
	receiver_marker.name = "PitchReceiverDebug"
	add_child(receiver_marker)
	var receiver_color: Color = Color(0.16, 0.22, 0.23)
	var receiver_z: float = PitchFlightActor.RECEIVER_PLANE_Z
	var half_width: float = 0.95
	var bottom_y: float = 0.18
	var top_y: float = 1.98
	var center_y: float = (bottom_y + top_y) * 0.5
	var thickness: float = 0.045
	_add_marker_bar(
		receiver_marker,
		Vector3(-half_width, center_y, receiver_z),
		Vector3(thickness, top_y - bottom_y, thickness),
		receiver_color
	)
	_add_marker_bar(
		receiver_marker,
		Vector3(half_width, center_y, receiver_z),
		Vector3(thickness, top_y - bottom_y, thickness),
		receiver_color
	)
	_add_marker_bar(
		receiver_marker,
		Vector3(0.0, top_y, receiver_z),
		Vector3(half_width * 2.0, thickness, thickness),
		receiver_color
	)
	_add_marker_bar(
		receiver_marker,
		Vector3(0.0, bottom_y, receiver_z),
		Vector3(half_width * 2.0, thickness, thickness),
		receiver_color
	)
	receiver_marker.visible = false

func _build_aim_markers(
	contact_aim_size: Vector2,
	power_aim_size: Vector2
) -> void:
	pitch_target_marker = MeshInstance3D.new()
	pitch_target_marker.name = "PitchTarget"
	var pitch_marker_mesh: SphereMesh = SphereMesh.new()
	pitch_marker_mesh.radius = 0.055
	pitch_marker_mesh.height = 0.11
	pitch_target_marker.mesh = pitch_marker_mesh
	pitch_target_marker.material_override = _make_material(
		Color(1.0, 0.22, 0.18),
		true
	)
	add_child(pitch_target_marker)

	batting_aim_marker = Node3D.new()
	batting_aim_marker.name = "BattingAim"
	_add_aim_outline(
		batting_aim_marker,
		contact_aim_size,
		Color(0.20, 0.90, 1.0, 0.82),
		"ContactCoverage"
	)
	_add_aim_outline(
		batting_aim_marker,
		power_aim_size,
		Color(1.0, 0.52, 0.18, 0.92),
		"PowerCoverage"
	)
	add_child(batting_aim_marker)

func _add_aim_outline(
	parent: Node3D,
	size: Vector2,
	color: Color,
	outline_name: String
) -> void:
	var outline: Node3D = Node3D.new()
	outline.name = outline_name
	parent.add_child(outline)
	var thickness: float = 0.018
	var depth: float = 0.012
	_add_marker_bar(
		outline,
		Vector3(0.0, size.y * 0.5, 0.0),
		Vector3(size.x, thickness, depth),
		color
	)
	_add_marker_bar(
		outline,
		Vector3(0.0, -size.y * 0.5, 0.0),
		Vector3(size.x, thickness, depth),
		color
	)
	_add_marker_bar(
		outline,
		Vector3(size.x * 0.5, 0.0, 0.0),
		Vector3(thickness, size.y, depth),
		color
	)
	_add_marker_bar(
		outline,
		Vector3(-size.x * 0.5, 0.0, 0.0),
		Vector3(thickness, size.y, depth),
		color
	)

func _add_marker_bar(
	parent: Node3D,
	local_position: Vector3,
	size: Vector3,
	color: Color
) -> void:
	var bar: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.position = local_position
	bar.material_override = _make_material(color, true)
	parent.add_child(bar)

func _add_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	color: Color,
	unshaded: bool = false
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = world_position
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = _make_material(color, unshaded)
	add_child(instance)
	return instance

func _add_field_line(
	node_name: String,
	start: Vector3,
	end: Vector3,
	color: Color
) -> void:
	var delta: Vector3 = end - start
	var line: MeshInstance3D = MeshInstance3D.new()
	line.name = node_name
	line.position = (start + end) * 0.5 + Vector3.UP * 0.018
	line.rotation.y = atan2(delta.x, delta.z)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.045, 0.018, delta.length())
	line.mesh = mesh
	line.material_override = _make_material(color, true)
	add_child(line)

func _add_static_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	color: Color,
	surface_id: StringName,
	unshaded: bool = false
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = world_position
	body.set_meta(&"ball_surface", surface_id)
	body.collision_layer = 1
	body.collision_mask = 2

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision_shape.shape = box_shape
	body.add_child(collision_shape)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _make_material(color, unshaded)
	body.add_child(mesh_instance)
	add_child(body)
	return body

func _make_material(
	color: Color,
	unshaded: bool = false
) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
