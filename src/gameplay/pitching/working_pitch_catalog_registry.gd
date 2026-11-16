extends RefCounted
## Explicit isolated practice/test contexts, not persisted schema descriptors.
## No global selection, save migration, signature substitution or active-game hook.

const V6 = preload("res://src/gameplay/pitching/working_pitch_catalog_v6.gd")
const PREVIEW: String = "isolated_preview"


static func context_for_use(version: Variant, purpose: Variant) -> Dictionary:
	# Persistent contexts are deliberately unsupported, including v5 through this API.
	if typeof(version) != TYPE_INT or typeof(purpose) != TYPE_STRING or purpose != PREVIEW:
		return {}
	var digest: String = _signature(version)
	if digest.is_empty():
		return {}
	return {"version": version, "signature": digest, "purpose": PREVIEW}


static func default_preview_context() -> Dictionary:
	return context_for_use(5, PREVIEW)


static func valid_context(value: Variant, purpose: Variant = PREVIEW) -> bool:
	if typeof(purpose) != TYPE_STRING or purpose != PREVIEW or not value is Dictionary or value.size() != 3:
		return false
	if not value.has("version") or not value.has("signature") or not value.has("purpose"):
		return false
	# Deliberately transient: cold JSON float versions are not admitted or coerced.
	if typeof(value.version) != TYPE_INT or typeof(value.signature) != TYPE_STRING \
		or typeof(value.purpose) != TYPE_STRING or value.purpose != PREVIEW:
		return false
	var expected: String = _signature(value.version)
	return not expected.is_empty() and value.signature == expected


static func _signature(version: int) -> String:
	if version == 5:
		var digest: String = WorkingPitchCatalog.signature()
		return digest if WorkingPitchCatalog.VERSION == 5 and digest == V6.LEGACY_SIGNATURE else ""
	if version == 6:
		return V6.signature()
	return ""


static func ids(context: Variant) -> Array[String]:
	if not valid_context(context):
		return []
	return WorkingPitchCatalog.ids() if context.version == 5 else V6.ids()


static func known_ids(context: Variant) -> Array[String]:
	if not valid_context(context):
		return []
	return WorkingPitchCatalog.known_ids() if context.version == 5 else V6.known_ids()


static func recipes(context: Variant) -> Array[PitchDefinition]:
	if not valid_context(context):
		return []
	if context.version == 6:
		return V6.recipes()
	var result: Array[PitchDefinition] = []
	for pitch: PitchDefinition in WorkingPitchCatalog.recipes():
		result.append(V6.detached_recipe(pitch))
	return result


static func get_recipe(context: Variant, id: String) -> PitchDefinition:
	if not valid_context(context):
		return null
	if context.version == 6:
		return V6.get_recipe(id)
	var pitch: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
	return V6.detached_recipe(pitch)


static func historical_recipe(context: Variant, id: String) -> PitchDefinition:
	if not valid_context(context):
		return null
	var old: PitchDefinition = WorkingPitchCatalog.historical_recipe(id)
	if old != null:
		return V6.detached_recipe(old)
	return V6.get_recipe(id) if context.version == 6 else null


static func lesson_price(context: Variant, id: String) -> int:
	if not valid_context(context):
		return -1
	return WorkingPitchCatalog.lesson_price(id) if context.version == 5 else V6.lesson_price(id)


static func mastered(context: Variant, id: String, level: int) -> PitchDefinition:
	if not valid_context(context):
		return null
	if context.version == 6:
		return V6.mastered(id, level)
	var old: PitchDefinition = WorkingPitchCatalog.mastered(id, level)
	return V6.detached_recipe(old)
