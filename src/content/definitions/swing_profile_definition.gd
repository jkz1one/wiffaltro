class_name SwingProfileDefinition
extends DefinitionBase

@export_range(0.05, 1.5, 0.01) var contact_radius_x_m: float = 0.34
@export_range(0.05, 1.5, 0.01) var contact_radius_y_m: float = 0.30
@export_range(0.05, 2.0, 0.01) var contact_depth_m: float = 0.55

@export_range(1.0, 60.0, 0.1) var bat_speed_mps: float = 28.0
@export_range(-30.0, 45.0, 0.1) var attack_angle_degrees: float = 8.0
@export_range(0.1, 3.0, 0.01) var exit_velocity_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var minimum_contact_quality: float = 0.18
