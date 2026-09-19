class_name BallSetupDefinition
extends DefinitionBase

@export var aero_profile: BallAeroProfileDefinition

@export_range(0.0, 3.0, 0.001, "or_greater") var drag_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.001, "or_greater") var magnus_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.001, "or_greater") var perforation_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.001, "or_greater") var stability_multiplier: float = 1.0
