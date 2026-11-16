extends Node
## Future finite registry checks. No season creation, saves, fixtures or owner writes.
const Registry = preload("res://src/gameplay/pitching/working_pitch_catalog_registry.gd")
const V6 = preload("res://src/gameplay/pitching/working_pitch_catalog_v6.gd")
var failures: int = 0
var checks: int = 0


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)


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
	for path: String in pins.original_bytes:
		check(FileAccess.get_sha256("res://" + path) == pins.original_bytes[path], "original bytes: " + path)
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
	print("Catalog registry checks: %d; failures: %d; no persistence or gameplay admission" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _rejections(old: Dictionary, next: Dictionary) -> void:
	for bad_version: Variant in [true, false, 5.0, 6.0, 5.5, NAN, INF, "6", null, -1, 0, 4, 7]:
		var bad: Dictionary = next.duplicate(true)
		bad.version = bad_version
		check(not Registry.valid_context(bad), "noninteger/unknown version rejected")
		check(Registry.context_for_use(bad_version, Registry.PREVIEW).is_empty(), "factory does not coerce")
		check(Registry.ids(bad).is_empty() and Registry.mastered(bad, "pitch.submarine_two_seam", 1) == null,
			"invalid context cannot read recipes")
	for purpose: Variant in ["save", "season", "career", "shop", "dynasty", "proof", "", true, 6.0, null]:
		check(Registry.context_for_use(6, purpose).is_empty(), "unsupported persistent purpose rejected")
		check(not Registry.valid_context(next, purpose), "preview cannot authorize another purpose")
		var bad: Dictionary = next.duplicate(true)
		bad.purpose = purpose
		check(not Registry.valid_context(bad), "purpose mutation rejected")
	var mixed: Dictionary = next.duplicate(true)
	mixed.signature = old.signature
	check(not Registry.valid_context(mixed), "v6 with v5 signature rejected")
	mixed = old.duplicate(true)
	mixed.signature = next.signature
	check(not Registry.valid_context(mixed), "v5 with v6 signature rejected")
	for field: String in ["version", "signature", "purpose"]:
		var missing: Dictionary = next.duplicate(true)
		missing.erase(field)
		check(not Registry.valid_context(missing), "missing field rejected")
	var extra: Dictionary = next.duplicate(true)
	extra["save_version"] = 101
	check(not Registry.valid_context(extra), "extra field rejected")
	for signature: Variant in ["", "unknown", true, 6, 6.0, null]:
		var bad: Dictionary = next.duplicate(true)
		bad.signature = signature
		check(not Registry.valid_context(bad), "malformed signature rejected")
	for value: Variant in [null, [], "6", true, 6, 6.0]:
		check(not Registry.valid_context(value), "malformed context rejected")


func _view(recipe: PitchDefinition) -> Dictionary:
	if recipe == null:
		return {}
	return {"id": String(recipe.id), "velocity": recipe.nominal_velocity_mps,
		"mastery": recipe.mastery_level, "scale": recipe.mastery_movement_scale,
		"delivery": String(recipe.delivery_profile.id),
		"release": recipe.delivery_profile.release_offset_pitcher_frame_m}


func _alias_isolation(old: Dictionary, next: Dictionary, id: String) -> void:
	var earlier: PitchDefinition = Registry.get_recipe(next, id)
	var old_view: PitchDefinition = Registry.get_recipe(old, id)
	var before: Dictionary = _view(earlier)
	var old_before: Dictionary = _view(old_view)
	var shared_v5: PitchDefinition = Registry.get_recipe(old, "pitch.submarine_riser")
	var shared_before: Dictionary = _view(shared_v5)
	var manifest: ContentManifest = load(V6.MANIFEST_PATH) as ContentManifest
	var source_recipe: PitchDefinition = null
	for candidate: PitchDefinition in manifest.pitches:
		if String(candidate.id) == id:
			source_recipe = candidate
	var source_before: Dictionary = _view(source_recipe)
	var price: int = Registry.lesson_price(next, id)
	var changed: PitchDefinition = Registry.get_recipe(next, id)
	changed.nominal_velocity_mps += 100.0
	changed.mastery_level = 5
	changed.delivery_profile.release_offset_pitcher_frame_m += Vector3(9, 9, 9)
	changed.delivery_profile.id = &"delivery.invalid_mutation"
	check(_view(earlier) == before and _view(old_view) == old_before, "earlier views isolated")
	check(_view(source_recipe) == source_before, "cached source recipe and nested delivery isolated")
	check(_view(shared_v5) == shared_before and
		_view(Registry.get_recipe(old, "pitch.submarine_riser")) == shared_before, "shared Submarine delivery stays isolated across versions")
	check(_view(Registry.get_recipe(next, id)) == before, "fresh v6 view isolated")
	check(_view(Registry.get_recipe(old, id)) == old_before, "fresh v5 view isolated")
	check(Registry.lesson_price(next, id) == price, "price unaffected by preview mutation")
	check(Registry.valid_context(old) and Registry.valid_context(next), "signatures remain exact")
