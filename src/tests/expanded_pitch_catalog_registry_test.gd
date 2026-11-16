extends "res://src/tests/working_pitch_catalog_registry_test.gd"
## Successor regression for the reviewed standalone-season integration.
## The historical registry test and audit document remain frozen and still report
## their original byte-only expectations. No assertion is skipped or intercepted.
## This test reuses their unchanged rejection/alias helpers and repeats every
## semantic assertion, while verifying the six exact reviewed source transitions.

const HISTORICAL_TEST_PATH: String = "res://src/tests/working_pitch_catalog_registry_test.gd"
const HISTORICAL_TEST_SHA: String = "bc78aa1eeb87fe9be9be7176e276b398b0d26e5d6850d00bd9d2430f70bc8273"
const HISTORICAL_PINS_PATH: String = "res://docs/pitches/catalog_v5_registration_pins.json"
const HISTORICAL_PINS_SHA: String = "40d5ddc9299712291eed4dfc59aff22f771f5e54c9dac3a74c75eea7e8a3fb62"
const REVIEWED_TRANSITIONS: Dictionary = {
	"src/gameplay/season/club_career.gd": {
		"before": "04462daa225a1c1a17a54f1026e20b217e7fde8d3a7e95e38c795da57e7241f3",
		"after": "9e3383237c052862d9cf92614e6893f810b304c155e6a765e27ad3d2dd9ac118"
	},
	"src/gameplay/season/development_shop_catalog.gd": {
		"before": "c193d21a7438f4d6da10f037e78c32fd5ea47b7a21d73d48bc2393602fcfad32",
		"after": "567308d0471994f9d767bc8f87da2714042c7228e75e28f30618a158b1ed5138"
	},
	"src/gameplay/season/season_build.gd": {
		"before": "a4de4e440b4fac3f56369f38e30a6b288cea03317a894920bb1de4048dbe0fbf",
		"after": "2b66d7c0e1e71c20477ae36db67acf2187b71618363c461a47b9c686774aec99"
	},
	"src/gameplay/season/season_development.gd": {
		"before": "a04fcc06d0d0fa0b9cb03206b9ccece74e42ab8e51974f2140983217c6769ce1",
		"after": "11ad6cbce2ddd79a4511f9da92f5a51a74f846ad1865ffdd022be6cec31f26b3"
	},
	"src/gameplay/season/season_physical_fixtures.gd": {
		"before": "e64958fb833c453a4ceaf06a9d0ecc370db3864c7252dbb3fda7fcb1ae32a3fb",
		"after": "5a498a7ead2748e136d1b15ab225b8a6b4296f406487eed70e73cc3430b79ecb"
	},
	"src/gameplay/season/season_save.gd": {
		"before": "9e1d30d842a0a88475fdb4d7eebe53dce364a0cd29b7c199164300963ad0efeb",
		"after": "6198db7fa0d00b2886e4f16142d1d38219e4d369f4d8f911981a393cd2003d01"
	}
}


func _ready() -> void:
	var pins: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://docs/pitches/catalog_v5_registration_pins.json"))
	if not pins is Dictionary:
		push_error("Missing frozen baseline pins; no registry checks ran")
		get_tree().quit(1)
		return
	var old: Dictionary = Registry.default_preview_context()
	var next: Dictionary = Registry.context_for_use(6, Registry.PREVIEW)
	check(Registry.valid_context(old) and Registry.valid_context(next), "two explicit preview contexts")
	if old.is_empty() or next.is_empty():
		get_tree().quit(1)
		return
	check(old.version == 5 and old.signature == pins.signature, "default is exact v5")
	check(WorkingPitchCatalog.signature() == pins.signature, "original signature unchanged")
	check(next.version == 6 and next.signature != old.signature, "v6 has distinct identity")
	_audit_expanded_source_transition(pins)
	check(Registry.ids(old).size() == 41 and Registry.known_ids(old).size() == 44, "v5 counts")
	check(Registry.ids(next).size() == 43 and Registry.known_ids(next).size() == 46, "v6 counts")
	for index in range(pins.ordered.size()):
		var row: Dictionary = pins.ordered[index]
		check(Registry.ids(old)[index] == row.id and Registry.ids(next)[index] == row.id, "stable pool order")
		check(Registry.lesson_price(old, row.id) == row.price and
			Registry.lesson_price(next, row.id) == row.price, "stable price")
	var conventional: int = 0
	var exotic: int = 0
	for pitch: PitchDefinition in Registry.recipes(next):
		conventional += int(pitch.exotic_shape.is_empty())
		exotic += int(not pitch.exotic_shape.is_empty())
	check(conventional == 40 and exotic == 3, "40 conventional and three unique Exotics")
	for id: String in ["pitch.submarine_two_seam", "pitch.submarine_curveball"]:
		check(Registry.get_recipe(old, id) == null and Registry.lesson_price(old, id) == -1, "v5 excludes new recipe")
		check(Registry.lesson_price(next, id) == 10, "new conventional preview price")
		for level in range(1, 6):
			var recipe: PitchDefinition = Registry.mastered(next, id, level)
			check(recipe != null, "new mastery preview exists")
			if recipe == null:
				continue
			check(String(recipe.id) == id and recipe.mastery_level == level and recipe.command_only_quality,
				"new mastery keeps exact identity")
			var steps: int = int(level >= 2) + int(level >= 4)
			var amplitudes: int = int(level >= 3) + int(level >= 5)
			var expected_scale: float = 1.0 + (0.06 if id.ends_with("two_seam") else 0.08) * (steps if id.ends_with("two_seam") else amplitudes)
			check(is_equal_approx(recipe.mastery_movement_scale, expected_scale), "mastery scale")
			check(is_equal_approx(recipe.mastery_late_bias, 0.0 if id.ends_with("two_seam") else 0.18 * steps), "mastery timing")
			check(is_equal_approx(recipe.nominal_velocity_mps, 25.40 * (1.0 + 0.025 * amplitudes) if id.ends_with("two_seam") else 19.70), "mastery velocity")
		check(Registry.mastered(next, id, 0) == null and Registry.mastered(next, id, 6) == null, "mastery bounds")
		check(Registry.mastered(old, id, 1) == null, "no mastery crosses context")
		check(Registry.get_recipe(next, id).mastery_level == 1, "authored mastery stays neutral")
	_rejections(old, next)
	_alias_isolation(old, next, "pitch.submarine_riser")
	_alias_isolation(old, next, "pitch.submarine_two_seam")
	check(WorkingPitchCatalog.signature() == pins.signature, "terminal v5 signature")
	check(Registry.default_preview_context() == old, "v6 never changes default")
	print("Expanded registry checks: %d; failures: %d; preview semantics and explicit source transitions only" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _audit_expanded_source_transition(pins: Dictionary) -> void:
	check(FileAccess.get_sha256(HISTORICAL_TEST_PATH) == HISTORICAL_TEST_SHA,
		"historical registry test remains byte-identical")
	check(FileAccess.get_sha256(HISTORICAL_PINS_PATH) == HISTORICAL_PINS_SHA,
		"historical audit document remains byte-identical")
	check(pins.original_bytes.size() == 78 and pins.signature_inputs.size() == 59,
		"complete frozen source and signature-input inventories")
	var changed: Array[String] = []
	for path: String in pins.original_bytes:
		var actual: String = FileAccess.get_sha256("res://" + path)
		if actual != pins.original_bytes[path]:
			changed.append(path)
		if REVIEWED_TRANSITIONS.has(path):
			var transition: Dictionary = REVIEWED_TRANSITIONS[path]
			check(pins.original_bytes[path] == transition.before,
				"reviewed transition starts at exact historical source: " + path)
			check(actual == transition.after and actual != transition.before,
				"reviewed transition ends at exact integrated source: " + path)
		else:
			check(actual == pins.original_bytes[path], "unchanged audited source: " + path)
	var expected: Array[String] = []
	for path: String in REVIEWED_TRANSITIONS:
		expected.append(path)
		check(pins.original_bytes.has(path), "transition is present in the frozen audit")
		check(not pins.signature_inputs.has(path), "transition does not change any v5 signature input")
	changed.sort()
	expected.sort()
	check(changed == expected and changed.size() == 6,
		"exactly six reviewed audited-source changes and no additional changed original paths")
	for path: String in pins.signature_inputs:
		check(pins.original_bytes.has(path) and FileAccess.get_sha256("res://" + path) == pins.original_bytes.get(path, ""),
			"exact frozen v5 recipe signature input: " + path)
	check("|".join(pins.signature_parts).sha256_text() == pins.signature,
		"frozen signature parts reproduce the original v5 identity")
