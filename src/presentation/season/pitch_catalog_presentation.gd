class_name PitchCatalogPresentation
extends RefCounted
## Display lookup only. Never used for save admission, learning or ownership.
static func recipe(id: String) -> PitchDefinition:
	var old: PitchDefinition = WorkingPitchProgression.recipe(id)
	return old if old != null else ExpandedSeasonCatalog.get_recipe(id)

static func display_item(id: String) -> Dictionary:
	if id.begins_with("lesson.") and not WorkingPitchCatalog.supports(id.trim_prefix("lesson.")):
		return ExpandedSeasonProgression.lesson(id.trim_prefix("lesson."))
	return WorkingPitchProgression.display_item(id)
