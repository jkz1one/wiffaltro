class_name PitchDefinition
extends DefinitionBase

enum Category {
	FASTBALL,
	BREAKING,
	OFF_SPEED,
	UNCONVENTIONAL,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EXOTIC,
}

@export var category: Category = Category.FASTBALL
@export var rarity: Rarity = Rarity.COMMON
@export var delivery_profile: DeliveryProfileDefinition

@export_range(0.0, 100.0, 0.01, "or_greater") var nominal_velocity_mps: float = 28.0
@export_range(0.0, 6000.0, 1.0, "or_greater") var nominal_spin_rpm: float = 1200.0

# Pitcher-relative unit direction. The launch builder will normalize it.
@export var nominal_spin_axis_pitcher_frame := Vector3.RIGHT

# Ball-local unit direction toward the perforated hemisphere.
@export var nominal_hole_axis_ball_local := Vector3.RIGHT
@export_range(0.0, 3.0, 0.001, "or_greater") var perforation_influence: float = 1.0

@export_range(0.0, 2.0, 0.001, "or_greater") var control_difficulty: float = 1.0
@export_range(0.0, 2.0, 0.001, "or_greater") var execution_difficulty: float = 1.0
@export_range(0.0, 100.0, 0.1, "or_greater") var stamina_cost: float = 5.0

@export var tags: Array[StringName] = []
