class_name StadiumPoolOwnedFieldIntegrity
extends RefCounted
## Fresh finite field reads, never a successful-validation cache or a mutable field owner.

const POLICY: String = "LIVE_FIELD_VALUES_WITH_COLD_RESOURCE_SEALS_V68"
const FIELD_SCRIPT: GDScript = preload("res://src/content/definitions/field_definition.gd")
const BASE_SCRIPT: GDScript = preload("res://src/content/definitions/definition_base.gd")

var _admitted: bool = false
var _values_bytes: PackedByteArray
var _field_source: String = ""
var _base_source: String = ""


static func capture(field: FieldDefinition) -> StadiumPoolOwnedFieldIntegrity:
	var result: StadiumPoolOwnedFieldIntegrity = StadiumPoolOwnedFieldIntegrity.new()
	# Custom definitions retain the original full Resource path before any finite reads.
	if not _plain_definition(field):
		return result
	result._field_source = FIELD_SCRIPT.source_code
	result._base_source = BASE_SCRIPT.source_code
	result._values_bytes = var_to_bytes(_values(field))
	result._admitted = true
	return result


func matches(field: FieldDefinition, original: PackedByteArray, full: bool = false) -> bool:
	if not _admitted or field == null or field.get_script() != FIELD_SCRIPT:
		return var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field)) == original
	# Identity alone would miss in-place script source edits or reloads. No resealing.
	if not StadiumPoolOwnedFieldIntegrity.sources_current(self, field):
		return false
	if full or not _plain_definition(field):
		return var_to_bytes(StadiumPoolPartyAssetIntegrity._value(field)) == original
	return var_to_bytes(_values(field)) == _values_bytes


static func sources_current(context: StadiumPoolOwnedFieldIntegrity,
	field: FieldDefinition) -> bool:
	# Exact static dispatch also protects cold checks without replacing their full oracle.
	if not context._admitted or field == null or field.get_script() != FIELD_SCRIPT:
		return true
	return (
		FIELD_SCRIPT.source_code == context._field_source
		and BASE_SCRIPT.source_code == context._base_source
	)


static func _plain_definition(field: FieldDefinition) -> bool:
	return (
		field != null and field.get_class() == "Resource"
		and field.get_script() == FIELD_SCRIPT
		and FIELD_SCRIPT.get_base_script() == BASE_SCRIPT
		and BASE_SCRIPT.get_base_script() == null
	)


static func _values(field: FieldDefinition) -> Array:
	# All exported fields, including inherited identity/presentation data. Native bytes
	# retain StringName, float representation, signed zero and the original field types.
	return [
		field.id, field.display_name, field.environment_style,
		field.fair_half_angle_degrees, field.safe_hit_z_m, field.deep_air_z_m,
		field.back_wall_z_m, field.home_run_height_m, field.dead_ball_z_m,
		field.shallow_anchor_z_m, field.middle_anchor_z_m, field.middle_center_anchor_z_m,
		field.deep_anchor_z_m, field.side_anchor_x_m,
		field.shallow_center_available, field.middle_center_available
	]
