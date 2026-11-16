class_name StadiumHillsideAnchorContract
extends RefCounted
## Private Working anchor data. Existing field XZ/availability, retained physical terrain Y.
## This is neither final geometry approval nor ordinary fielder/venue admission.

const ID: String = "HILLSIDE-ANCHORS-WORKING-v1"
const VERSION: int = 1
const SLOT_COUNT: int = 9


static func anchors(field: FieldDefinition, profile: String = "hill") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if field == null or not StadiumHillsideTerrain.PROFILES.has(profile):
		return result
	for index in range(SLOT_COUNT):
		result.append(anchor(field, index, profile))
	return result


static func anchor(field: FieldDefinition, index: int,
	profile: String = "hill") -> Dictionary:
	# FieldDefinition clamps indices; this boundary deliberately refuses invalid callers.
	if field == null or index < 0 or index >= SLOT_COUNT:
		return {}
	var original: Vector3 = field.fielder_anchor(index)
	if not original.is_finite():
		return {}
	var result: Dictionary = support(Vector2(original.x, original.z), profile)
	if result.is_empty():
		return {}
	result["index"] = index
	result["available"] = field.is_fielder_anchor_available(index)
	result["source_anchor"] = original
	return result


static func support(point: Vector2, profile: String = "hill") -> Dictionary:
	if not StadiumHillsideTerrain.contains(point) \
		or not StadiumHillsideTerrain.PROFILES.has(profile):
		return {}
	var ground: float = StadiumHillsideTerrain.support_height(point, profile)
	var design: float = StadiumHillsideTerrain.design_height(point.y, profile)
	var normal: Vector3 = StadiumHillsideTerrain.support_normal(point, profile)
	if not is_finite(ground) or not is_finite(design) or not normal.is_finite():
		return {}
	return {
		"id": ID,
		"version": VERSION,
		"status": "Working",
		"production_ready": false,
		"profile": profile,
		"terrain_signature": StadiumHillsideTerrain.signature(profile),
		"position": Vector3(point.x, ground, point.y),
		"support_height": ground,
		"design_height": design,
		"design_minus_support": design - ground,
		"support_normal": normal,
	}
