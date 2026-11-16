class_name WorkingPitchCatalog
extends RefCounted
## Versioned candidate catalog. Public activation belongs to the new progression
## boundary; historical ContentDB and nine-recipe decoder tables stay unchanged.

const VERSION: int = 5
const STATUS: String = "Working design"
const MANIFEST_PATH: String = "res://src/content/manifest/working_pitch_manifest.tres"
const LEGACY_PRICES: Dictionary = {
	"pitch.overhand_four_seam": 10, "pitch.overhand_sinker": 10,
	"pitch.sidearm_sinker": 10, "pitch.overhand_slider": 10,
	"pitch.sidearm_slider": 10, "pitch.drop": 12, "pitch.riser": 12,
	"pitch.knuckleball": 14, "pitch.eephus": 12
}
const ALIASES: Dictionary = {
	"banana ball": "pitch.sidearm_slurve",
	"super curve": "pitch.three_quarter_curveball",
	"gypsy drop": "pitch.drop", "knuckle-drop": "pitch.drop"
}
# Historical definitions remain exact-ID readable, never new offers or practice rows.
# This is ID compatibility, not permission to rebind a source-bound v4 save to v5.
const RETIRED_ALIASES: Dictionary = {
	"pitch.sidearm_switchback": "pitch.switchback",
	"pitch.sidearm_corkscrew": "pitch.corkscrew",
	"pitch.sidearm_trapdoor": "pitch.trapdoor"
}
const RETIRED_PATHS: Dictionary = {
	"pitch.sidearm_switchback": "res://src/content/pitches/exotic/sidearm_switchback.tres",
	"pitch.sidearm_corkscrew": "res://src/content/pitches/exotic/sidearm_corkscrew.tres",
	"pitch.sidearm_trapdoor": "res://src/content/pitches/exotic/sidearm_trapdoor.tres"
}
const HISTORICAL_CANONICAL_PATHS: Dictionary = {
	"pitch.switchback": "res://src/content/pitches/exotic/switchback.tres",
	"pitch.corkscrew": "res://src/content/pitches/exotic/corkscrew.tres",
	"pitch.trapdoor": "res://src/content/pitches/exotic/trapdoor.tres"
}
# Discoverable source names, not additional recipe counts or claimed exact shapes.
const SOURCE_STYLES: Dictionary = {
	"Banana Ball": {"recipe": "pitch.sidearm_slurve", "status": "Sourced alias",
		"source": "https://www.youtube.com/watch?v=l3neWQ3xpbA&t=249s",
		"note": "MLW describes a sidearm Slurve."},
	"Super Curve": {"recipe": "pitch.three_quarter_curveball", "status": "Curveball style",
		"source": "https://www.youtube.com/watch?v=l3neWQ3xpbA&t=390s",
		"note": "Three-quarter release is sourced; independent flight shape remains unresolved."},
	"Gypsy Drop": {"recipe": "pitch.drop", "status": "Drop style; independent identity pending",
		"source": "https://www.youtube.com/watch?v=l3neWQ3xpbA&t=312s",
		"note": "Tumbling Drop source style. No separate recipe until distinct flight is demonstrated."},
	"Knuckle-Drop": {"recipe": "pitch.drop", "status": "Downward style; independent identity pending",
		"source": "https://www.youtube.com/watch?v=l3neWQ3xpbA&t=541s",
		"note": "12-to-6-like downward source style. No random flutter inferred from the name."}
}
# One unique project-fiction design each. Delivery does not create a second offering.
const RESERVED_EXOTICS: Dictionary = {
	"Switchback": ["pitch.switchback"],
	"Corkscrew": ["pitch.corkscrew"],
	"Trapdoor": ["pitch.trapdoor"]
}


static func recipes() -> Array[PitchDefinition]:
	var catalog: ContentManifest = load(MANIFEST_PATH) as ContentManifest
	return catalog.pitches.duplicate() if catalog != null else []


static func conventional_recipes() -> Array[PitchDefinition]:
	var result: Array[PitchDefinition] = []
	for pitch: PitchDefinition in recipes():
		if pitch.exotic_shape.is_empty():
			result.append(pitch)
	return result


static func exotic_recipes() -> Array[PitchDefinition]:
	var result: Array[PitchDefinition] = []
	for pitch: PitchDefinition in recipes():
		if not pitch.exotic_shape.is_empty():
			result.append(pitch)
	return result


static func ids() -> Array[String]:
	var result: Array[String] = []
	for pitch: PitchDefinition in recipes():
		result.append(String(pitch.id))
	return result


static func new_ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in ids():
		if not LEGACY_PRICES.has(id):
			result.append(id)
	return result


static func known_ids() -> Array[String]:
	# Validation/history may reference retired IDs without offering them again.
	var result: Array[String] = ids()
	for id: String in RETIRED_PATHS:
		result.append(id)
	return result


static func canonical_id(id: String) -> String:
	return RETIRED_ALIASES.get(id, id)


static func is_active(id: String) -> bool:
	return ids().has(id)


static func selection_recipe(id: String) -> PitchDefinition:
	# Explicit selection-only alias. Never rewrite receipts, mastery or evidence IDs.
	return get_recipe(canonical_id(id))


static func historical_recipe(id: String) -> PitchDefinition:
	# Exact v4 definitions, including original names. Does not admit a v4 save.
	if HISTORICAL_CANONICAL_PATHS.has(id):
		return load(HISTORICAL_CANONICAL_PATHS[id]) as PitchDefinition
	return get_recipe(id)


static func get_recipe(id: String) -> PitchDefinition:
	if RETIRED_PATHS.has(id):
		return load(RETIRED_PATHS[id]) as PitchDefinition
	for pitch: PitchDefinition in recipes():
		if String(pitch.id) == id:
			return pitch
	return null


static func supports(id: String) -> bool:
	return get_recipe(id) != null


static func lesson_price(id: String) -> int:
	if LEGACY_PRICES.has(id):
		return LEGACY_PRICES[id]
	var pitch: PitchDefinition = get_recipe(id)
	if pitch == null or pitch.rarity == PitchDefinition.Rarity.EXOTIC:
		return -1
	return [10, 12, 14][pitch.rarity]


static func resolve_alias(label: String) -> String:
	return ALIASES.get(label.strip_edges().to_lower(), "")


static func sourced_styles() -> Dictionary:
	return SOURCE_STYLES.duplicate(true)


static func signature() -> String:
	var parts: Array[String] = [str(VERSION), FileAccess.get_sha256(MANIFEST_PATH),
		FileAccess.get_sha256("res://src/content/definitions/pitch_definition.gd"),
		FileAccess.get_sha256("res://src/content/definitions/delivery_profile_definition.gd"),
		FileAccess.get_sha256("res://src/gameplay/pitching/working_pitch_catalog.gd"),
		FileAccess.get_sha256("res://src/gameplay/pitching/pitch_exotic_shape.gd"),
		FileAccess.get_sha256("res://src/gameplay/pitching/working_pitch_called_proof.gd"),
		FileAccess.get_sha256("res://src/gameplay/pitching/working_exotic_eligibility.gd"),
		FileAccess.get_sha256("res://src/gameplay/season/working_exotic_access.gd")]
	for pitch: PitchDefinition in recipes():
		parts.append(FileAccess.get_sha256(pitch.resource_path))
		parts.append(FileAccess.get_sha256(pitch.delivery_profile.resource_path))
		parts.append(str(lesson_price(String(pitch.id))))
	for id: String in HISTORICAL_CANONICAL_PATHS:
		parts.append(FileAccess.get_sha256(HISTORICAL_CANONICAL_PATHS[id]))
	for id: String in RETIRED_PATHS:
		parts.append(FileAccess.get_sha256(RETIRED_PATHS[id]))
		parts.append(FileAccess.get_sha256(get_recipe(id).delivery_profile.resource_path))
	return "|".join(parts).sha256_text()


static func mastered(id: String, level: int) -> PitchDefinition:
	if level < 1 or level > SeasonDevelopment.PITCH_CAP:
		return null
	var recipe: PitchDefinition = get_recipe(id)
	if recipe == null:
		return null
	if LEGACY_PRICES.has(id):
		return PitchMastery.apply(recipe, level)
	var result: PitchDefinition = recipe.duplicate() as PitchDefinition
	result.command_only_quality = true
	result.mastery_level = level
	var movement_steps: int = int(level >= 2) + int(level >= 4)
	var amplitude_steps: int = int(level >= 3) + int(level >= 5)
	if recipe.offering_id in [&"offering.eephus", &"offering.knuckleball"]:
		result.mastery_noise_scale = pow(PitchMastery.RELIABILITY_STEP, level - 1)
	elif (
		recipe.category == PitchDefinition.Category.FASTBALL
		or recipe.offering_id == &"offering.riser"
	):
		result.mastery_movement_scale += PitchMastery.MOVEMENT_STEP * movement_steps
		result.nominal_velocity_mps *= 1.0 + PitchMastery.VELOCITY_STEP * amplitude_steps
	else:
		result.mastery_late_bias = PitchMastery.LATE_STEP * movement_steps
		result.mastery_movement_scale += PitchMastery.AMPLITUDE_STEP * amplitude_steps
	return result
