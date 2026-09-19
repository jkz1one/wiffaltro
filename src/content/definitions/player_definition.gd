class_name PlayerDefinition
extends DefinitionBase

enum Handedness {
	RIGHT,
	LEFT,
}

@export var bats: Handedness = Handedness.RIGHT
@export var throws: Handedness = Handedness.RIGHT

@export_range(0, 10, 1) var contact: int = 5
@export_range(0, 10, 1) var power: int = 5
@export_range(0, 10, 1) var fielding: int = 5
@export_range(0, 10, 1) var velocity: int = 5
@export_range(0, 10, 1) var break_rating: int = 5
@export_range(0, 10, 1) var control: int = 5
@export_range(0, 10, 1) var stamina: int = 5

@export var natural_delivery: DeliveryProfileDefinition
@export_range(1, 8, 1) var pitch_capacity: int = 3
@export var starting_pitches: Array[PitchDefinition] = []
