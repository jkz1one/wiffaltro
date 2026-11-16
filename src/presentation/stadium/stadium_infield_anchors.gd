class_name StadiumInfieldAnchors
extends RefCounted
## Authored visual diamond fitted to the existing small field, never regulation gameplay geometry.

const VERSION: int = 1
const SIDE_Z: float = 9.5
const SECOND_Z: float = 19.0
const FAIR_INSET: float = 0.40


static func bases() -> Array[Vector2]:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var x: float = SIDE_Z * tan(deg_to_rad(field.fair_half_angle_degrees)) - FAIR_INSET
	return [Vector2(x, SIDE_Z), Vector2(0, SECOND_Z), Vector2(-x, SIDE_Z)]


static func diamond() -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2.ZERO]
	result.append_array(bases())
	return result
