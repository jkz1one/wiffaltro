class_name SwingProfileDefinition
extends DefinitionBase

@export_range(0.05, 1.5, 0.01) var contact_radius_x_m: float = 0.34
@export_range(0.05, 1.5, 0.01) var contact_radius_y_m: float = 0.30
@export_range(0.05, 2.0, 0.01) var contact_depth_m: float = 0.55

@export_range(0.12, 0.60, 0.01) var swing_duration_seconds: float = 0.26
@export_range(0.01, 0.30, 0.005) var contact_window_start_seconds: float = 0.045
@export_range(0.03, 0.40, 0.005) var contact_window_end_seconds: float = 0.185
@export_range(0.02, 0.35, 0.005) var sweet_spot_seconds: float = 0.115

@export_range(1.0, 60.0, 0.1) var bat_speed_mps: float = 28.0
@export_range(-30.0, 45.0, 0.1) var attack_angle_degrees: float = 8.0
@export_range(0.1, 3.0, 0.01) var exit_velocity_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var minimum_contact_quality: float = 0.18

func is_valid_definition() -> bool:
	return (
		super.is_valid_definition()
		and contact_window_start_seconds < sweet_spot_seconds
		and sweet_spot_seconds < contact_window_end_seconds
		and contact_window_end_seconds <= swing_duration_seconds
	)
