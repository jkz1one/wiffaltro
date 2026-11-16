extends RefCounted
## Isolated preview provider only. No save, ownership, shop or proof admission.
## V5 and every input to its signature remain byte-identical.

const VERSION: int = 6
const LEGACY_SIGNATURE: String = "e261848e30d2b98936b3774f2b346097505a6265fead28f93725625bacaa0bcc"
const MANIFEST_PATH: String = "res://src/content/manifest/working_pitch_manifest_v6.tres"


static func detached_recipe(source: PitchDefinition) -> PitchDefinition:
	if source == null:
		return null
	var result: PitchDefinition = source.duplicate(true) as PitchDefinition
	# External Resource references remain shared by duplicate(true). Detach the
	# authored delivery explicitly so preview edits cannot mutate any catalog.
	if source.delivery_profile != null:
		result.delivery_profile = source.delivery_profile.duplicate(true) as DeliveryProfileDefinition
	return result


static func recipes() -> Array[PitchDefinition]:
	var manifest: ContentManifest = load(MANIFEST_PATH) as ContentManifest
	if manifest == null or manifest.pitches.size() != 43:
		return []
	var old: Array[PitchDefinition] = WorkingPitchCatalog.recipes()
	if old.size() != 41:
		return []
	var seen: Array[String] = []
	var result: Array[PitchDefinition] = []
	for index in range(manifest.pitches.size()):
		var pitch: PitchDefinition = manifest.pitches[index]
		if pitch == null or pitch.delivery_profile == null or seen.has(String(pitch.id)):
			return []
		if index < 41 and (pitch.id != old[index].id or pitch.resource_path != old[index].resource_path):
			return []
		seen.append(String(pitch.id))
		result.append(detached_recipe(pitch))
	if seen[41] != "pitch.submarine_two_seam" or seen[42] != "pitch.submarine_curveball":
		return []
	return result


static func ids() -> Array[String]:
	var result: Array[String] = []
	for pitch: PitchDefinition in recipes():
		result.append(String(pitch.id))
	return result


static func known_ids() -> Array[String]:
	var result: Array[String] = ids()
	if result.is_empty():
		return []
	for id: String in WorkingPitchCatalog.RETIRED_PATHS:
		result.append(id)
	return result


static func get_recipe(id: String) -> PitchDefinition:
	if WorkingPitchCatalog.RETIRED_PATHS.has(id):
		var old: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
		return detached_recipe(old)
	for pitch: PitchDefinition in recipes():
		if String(pitch.id) == id:
			return pitch
	return null


static func lesson_price(id: String) -> int:
	# Descriptive price only; this provider grants no learning or ownership.
	if WorkingPitchCatalog.supports(id):
		return WorkingPitchCatalog.lesson_price(id)
	if id in ["pitch.submarine_two_seam", "pitch.submarine_curveball"]:
		return 10 if get_recipe(id) != null else -1
	return -1


static func mastered(id: String, level: int) -> PitchDefinition:
	# Detached preview calibration, never a mastery grant or saved progression.
	if level < 1 or level > SeasonDevelopment.PITCH_CAP:
		return null
	if WorkingPitchCatalog.supports(id):
		var old: PitchDefinition = WorkingPitchCatalog.mastered(id, level)
		return detached_recipe(old)
	if id not in ["pitch.submarine_two_seam", "pitch.submarine_curveball"]:
		return null
	var result: PitchDefinition = get_recipe(id)
	if result == null:
		return null
	result.command_only_quality = true
	result.mastery_level = level
	var movement_steps: int = int(level >= 2) + int(level >= 4)
	var amplitude_steps: int = int(level >= 3) + int(level >= 5)
	if result.category == PitchDefinition.Category.FASTBALL:
		result.mastery_movement_scale += PitchMastery.MOVEMENT_STEP * movement_steps
		result.nominal_velocity_mps *= 1.0 + PitchMastery.VELOCITY_STEP * amplitude_steps
	else:
		result.mastery_late_bias = PitchMastery.LATE_STEP * movement_steps
		result.mastery_movement_scale += PitchMastery.AMPLITUDE_STEP * amplitude_steps
	return result


static func signature() -> String:
	if WorkingPitchCatalog.VERSION != 5 or WorkingPitchCatalog.signature() != LEGACY_SIGNATURE:
		return ""
	var manifest: ContentManifest = load(MANIFEST_PATH) as ContentManifest
	if manifest == null or recipes().size() != 43:
		return ""
	var parts: Array[String] = ["working-pitch-isolated-preview-v6", LEGACY_SIGNATURE]
	for path: String in [MANIFEST_PATH,
		"res://src/gameplay/pitching/working_pitch_catalog_v6.gd",
		"res://src/gameplay/pitching/working_pitch_catalog_registry.gd",
		"res://src/content/manifest/content_manifest.gd",
		"res://src/gameplay/pitching/pitch_mastery.gd",
		"res://src/gameplay/season/season_development.gd",
		"res://src/gameplay/season/season_player_catalog.gd",
		"res://src/content/content_db.gd",
		"res://src/content/manifest/content_manifest.tres",
		"res://src/content/definitions/definition_base.gd",
		"res://src/core/ids/content_id.gd"]:
		var digest: String = FileAccess.get_sha256(path)
		if digest.is_empty():
			return ""
		parts.append(digest)
	for pitch: PitchDefinition in manifest.pitches:
		var resource_digest: String = FileAccess.get_sha256(pitch.resource_path)
		var delivery_digest: String = FileAccess.get_sha256(pitch.delivery_profile.resource_path)
		if resource_digest.is_empty() or delivery_digest.is_empty():
			return ""
		parts.append(resource_digest)
		parts.append(delivery_digest)
		parts.append(str(lesson_price(String(pitch.id))))
	return "|".join(parts).sha256_text()
