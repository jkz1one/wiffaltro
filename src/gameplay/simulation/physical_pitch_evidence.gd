class_name PhysicalPitchEvidence
extends RefCounted
## A caller-supplied authority context, never inferred from untrusted evidence.
## Current routes must first bind their exact catalog-bearing save/request boundary.
## Empty context preserves the historical ContentDB recipe set and decoder behavior.


static func context_valid(pitch_catalog: String) -> bool:
	if pitch_catalog.is_empty() or pitch_catalog == WorkingPitchCatalog.signature():
		return true
	var expanded_signature: String = ExpandedSeasonCatalog.signature()
	return not expanded_signature.is_empty() and pitch_catalog == expanded_signature


static func recipe(id: String, pitch_catalog: String = "") -> PitchDefinition:
	if pitch_catalog.is_empty():
		return ContentDB.get_pitch(StringName(id))
	if not context_valid(pitch_catalog):
		return null
	return _recipe(id, pitch_catalog)


## Internal hot-loop seam. Callers must first reject invalid nonempty context once.
## Never derive context from a proof row or cache signatures across validations.
static func _recipe(id: String, pitch_catalog: String) -> PitchDefinition:
	return ContentDB.get_pitch(StringName(id)) if pitch_catalog.is_empty() \
		else (WorkingPitchCatalog.get_recipe(id) if pitch_catalog == WorkingPitchCatalog.signature() else ExpandedSeasonCatalog.get_recipe(id))
