extends Node

const MANIFEST_PATH := "res://src/content/manifest/content_manifest.tres"

var manifest: ContentManifest

var pitch_by_id: Dictionary = {}
var player_by_id: Dictionary = {}
var delivery_by_id: Dictionary = {}
var ball_aero_by_id: Dictionary = {}
var ball_setup_by_id: Dictionary = {}
var swing_by_id: Dictionary = {}
var field_by_id: Dictionary = {}

func _ready() -> void:
	reload_manifest()

func reload_manifest() -> bool:
	_clear_indexes()

	manifest = load(MANIFEST_PATH) as ContentManifest
	if manifest == null:
		push_error("ContentDB: failed to load %s" % MANIFEST_PATH)
		return false

	var valid := true
	valid = _index_definitions(manifest.pitches, pitch_by_id, "Pitch") and valid
	valid = _index_definitions(manifest.players, player_by_id, "Player") and valid
	valid = _index_definitions(manifest.deliveries, delivery_by_id, "Delivery") and valid
	valid = _index_definitions(
		manifest.ball_aero_profiles,
		ball_aero_by_id,
		"BallAeroProfile"
	) and valid
	valid = _index_definitions(manifest.ball_setups, ball_setup_by_id, "BallSetup") and valid
	valid = _index_definitions(manifest.swing_profiles, swing_by_id, "SwingProfile") and valid
	valid = _index_definitions(manifest.fields, field_by_id, "Field") and valid
	return valid

func validate_or_error() -> bool:
	if manifest == null:
		return reload_manifest()

	return (
		_validate_index(pitch_by_id, "Pitch")
		and _validate_index(player_by_id, "Player")
		and _validate_index(delivery_by_id, "Delivery")
		and _validate_index(ball_aero_by_id, "BallAeroProfile")
		and _validate_index(ball_setup_by_id, "BallSetup")
		and _validate_index(swing_by_id, "SwingProfile")
		and _validate_index(field_by_id, "Field")
	)

func get_pitch(id: StringName) -> PitchDefinition:
	return pitch_by_id.get(id) as PitchDefinition

func get_player(id: StringName) -> PlayerDefinition:
	return player_by_id.get(id) as PlayerDefinition

func get_delivery(id: StringName) -> DeliveryProfileDefinition:
	return delivery_by_id.get(id) as DeliveryProfileDefinition

func get_ball_setup(id: StringName) -> BallSetupDefinition:
	return ball_setup_by_id.get(id) as BallSetupDefinition

func get_swing(id: StringName) -> SwingProfileDefinition:
	return swing_by_id.get(id) as SwingProfileDefinition

func get_field(id: StringName) -> FieldDefinition:
	return field_by_id.get(id) as FieldDefinition

func _clear_indexes() -> void:
	pitch_by_id.clear()
	player_by_id.clear()
	delivery_by_id.clear()
	ball_aero_by_id.clear()
	ball_setup_by_id.clear()
	swing_by_id.clear()
	field_by_id.clear()

func _index_definitions(definitions: Array, target: Dictionary, label: String) -> bool:
	var valid := true

	for definition in definitions:
		if definition == null:
			push_error("ContentDB: %s definition is null." % label)
			valid = false
			continue

		if not definition is DefinitionBase:
			push_error("ContentDB: %s entry is not a DefinitionBase." % label)
			valid = false
			continue

		var typed_definition := definition as DefinitionBase
		if not typed_definition.is_valid_definition():
			push_error("ContentDB: invalid %s definition id/display name." % label)
			valid = false
			continue

		if target.has(typed_definition.id):
			push_error("ContentDB: duplicate %s id '%s'." % [label, typed_definition.id])
			valid = false
			continue

		target[typed_definition.id] = typed_definition

	return valid

func _validate_index(index: Dictionary, label: String) -> bool:
	for id in index:
		var definition := index[id] as DefinitionBase
		if definition == null or not definition.is_valid_definition():
			push_error("ContentDB: invalid %s entry '%s'." % [label, id])
			return false

	return true
