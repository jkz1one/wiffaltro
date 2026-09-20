class_name FieldDefinition
extends DefinitionBase

@export_range(10.0, 60.0, 0.5) var fair_half_angle_degrees: float = 42.0
@export_range(1.0, 30.0, 0.1) var safe_hit_z_m: float = 8.0
@export_range(2.0, 40.0, 0.1) var deep_air_z_m: float = 15.0
@export_range(5.0, 60.0, 0.1) var back_wall_z_m: float = 24.0
@export_range(0.5, 10.0, 0.1) var home_run_height_m: float = 3.8
@export_range(5.0, 80.0, 0.5) var dead_ball_z_m: float = 29.0

@export var shallow_anchor_z_m: float = 8.5
@export var middle_anchor_z_m: float = 14.0
@export var middle_center_anchor_z_m: float = 17.0
@export var deep_anchor_z_m: float = 19.5
@export var side_anchor_x_m: float = 5.5


func is_fair_point(point: Vector3) -> bool:
	if point.z < -0.5:
		return false
	var half_width: float = maxf(0.0, point.z) * tan(deg_to_rad(fair_half_angle_degrees)) + 0.45
	return absf(point.x) <= half_width


func fielder_anchor(index: int) -> Vector3:
	var safe_index: int = clampi(index, 0, 8)
	var row: int = floori(float(safe_index) / 3.0)
	var column: int = safe_index % 3
	var z_positions: Array[float] = [
		shallow_anchor_z_m,
		middle_anchor_z_m,
		deep_anchor_z_m,
	]
	var x_positions: Array[float] = [
		-side_anchor_x_m,
		0.0,
		side_anchor_x_m,
	]
	var anchor_z: float = z_positions[row]
	if row == 1 and column == 1:
		anchor_z = middle_center_anchor_z_m
	return Vector3(x_positions[column], 0.0, anchor_z)


func fielder_anchor_name(index: int) -> String:
	var names: Array[String] = [
		"Shallow Right",
		"Shallow Center",
		"Shallow Left",
		"Middle Right",
		"Middle Center",
		"Middle Left",
		"Deep Right",
		"Deep Center",
		"Deep Left",
	]
	return names[clampi(index, 0, 8)]
