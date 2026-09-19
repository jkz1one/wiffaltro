class_name DeliveryProfileDefinition
extends DefinitionBase

enum Delivery {
	OVERHAND,
	THREE_QUARTER,
	SIDEARM,
	SUBMARINE,
}

@export var delivery: Delivery = Delivery.OVERHAND

# Pitcher-relative meters: X = arm side, Y = up, Z = toward plate.
@export var release_offset_pitcher_frame_m := Vector3(0.25, 1.75, 0.0)
