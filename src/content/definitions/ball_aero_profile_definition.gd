class_name BallAeroProfileDefinition
extends DefinitionBase

@export_range(0.001, 1.0, 0.001, "or_greater") var mass_kg: float = 0.020
@export_range(0.001, 0.25, 0.0001, "or_greater") var radius_m: float = 0.0365

# Prototype coefficients. These are tuning data, not final physics claims.
@export_range(0.0, 2.0, 0.001, "or_greater") var drag_coefficient: float = 0.22
@export_range(0.0, 5.0, 0.001, "or_greater") var magnus_scale: float = 1.00
@export_range(0.0, 5.0, 0.001, "or_greater") var perforation_force_scale: float = 1.00
@export_range(0.0, 2.0, 0.001, "or_greater") var orientation_stability: float = 1.00
