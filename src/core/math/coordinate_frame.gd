class_name CoordinateFrame
extends RefCounted

# Field-local convention:
# +Y = up
# +Z = home plate toward center field
# +X = home plate toward right field
const FIELD_RIGHT := Vector3.RIGHT
const FIELD_UP := Vector3.UP
const FIELD_CENTER := Vector3.BACK

# Pitcher at the mound faces home plate (-Z).
const TOWARD_PLATE := Vector3.FORWARD

static func arm_side(is_left_handed: bool) -> Vector3:
	return Vector3.LEFT if is_left_handed else Vector3.RIGHT

static func glove_side(is_left_handed: bool) -> Vector3:
	return -arm_side(is_left_handed)

static func pitcher_frame_vector(
	arm_side_component: float,
	up_component: float,
	toward_plate_component: float,
	is_left_handed: bool
) -> Vector3:
	return (
		arm_side(is_left_handed) * arm_side_component
		+ FIELD_UP * up_component
		+ TOWARD_PLATE * toward_plate_component
	)
