extends RefCounted
const D = preload("res://src/gameplay/stadium/stadium_hillside_definition_v1.gd")
const SOURCE_PATHS = D.SOURCE_PATHS
const RETAINED_SOURCE_SUCCESSORS = D.RETAINED_SOURCE_SUCCESSORS
static var observed: Dictionary = {}
static var pins: Dictionary = {}
static var qualification: bool = true
static var qualifier_calls: int = 0
static func model_pins() -> Dictionary:
	return pins
static func qualifier() -> bool:
	qualifier_calls += 1
	return qualification
static func sources_valid() -> bool:
	var pins: Dictionary = model_pins()
	var needs_current_profile: bool = false
	for key: String in SOURCE_PATHS:
		var observed: String = observed.get(SOURCE_PATHS[key], "")
		if observed == pins[key].sha256:
			continue
		var successor: Dictionary = RETAINED_SOURCE_SUCCESSORS.get(key, {})
		if successor.is_empty() or pins[key].sha256 != successor.retained \
			or observed != successor.current:
			return false
		needs_current_profile = true
	return not needs_current_profile or qualifier()


