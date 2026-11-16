extends Node
## Requires separately captured, exact-source golden fixtures in an isolated project.
## Never creates fixture data, rewrites signatures, binds an owner or saves progress.
var failures: int = 0
var seen: Dictionary = {}


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--legacy-replay-fixture="):
			path = argument.trim_prefix("--legacy-replay-fixture=")
	if not path.begins_with("res://src/tests/fixtures/") or path.contains(".."):
		push_error("Required isolated golden fixture absent; no compatibility pass")
		get_tree().quit(1)
		return
	var fixture: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not fixture is Dictionary or fixture.get("status") != "captured_exact_legacy_source" \
		or fixture.get("catalog_signature") != WorkingPitchCatalog.signature() \
		or not fixture.get("cases") is Array or fixture.cases.is_empty():
		push_error("Invalid or empty exact-source golden fixture")
		get_tree().quit(1)
		return
	var original_digest: String = FileAccess.get_sha256(path)
	for row: Variant in fixture.cases:
		if not row is Dictionary or not row.get("kind") is String \
			or not row.get("input_json") is String or not row.get("input_sha256") is String:
			check(false, "Malformed golden row")
			continue
		check(row.input_json.sha256_text() == row.input_sha256, "exact saved input bytes")
		var data: Variant = JSON.parse_string(row.input_json)
		if not data is Dictionary:
			check(false, "Malformed saved payload")
			continue
		seen[row.kind] = true
		match row.kind:
			"career":
				var career: ClubCareer = ClubCareer.from_data(data)
				check(career != null, "unchanged current career loads")
				if career != null:
					check(ClubCareer.same(career.to_data(), row.expected_data), "exact career/history replay")
			"development", "shop":
				var book: SeasonDevelopment = SeasonDevelopment.from_data(data, row.season_key,
					row.get("rules", {}), row.get("start", {}))
				check(book != null, "unchanged development loads")
				if book == null:
					continue
				check(ClubCareer.same(book.to_data(), row.expected_data), "exact development replay")
				if row.kind == "shop":
					_shop(row, book)
			"save97", "save98", "save99":
				check(int(data.get("version", -1)) == int(row.kind.trim_prefix("save")), "exact save wrapper")
				var season: SeasonState = SeasonSave._decode_public(data)
				check(season != null, "public old save decoder accepts")
				if season != null:
					check(ClubCareer.same(SeasonSave.snapshot(season), row.expected_data), "exact save replay")
			"reject100", "reject101":
				check(int(data.get("version", -1)) == int(row.kind.trim_prefix("reject")), "exact owner wrapper")
				check(SeasonSave._decode_public(data) == null, "standalone file never supplies owner authority")
			_:
				check(false, "Unknown golden case")
		check(JSON.parse_string(row.input_json) == data, "decoder leaves golden input unchanged")
	for required: String in ["career", "development", "shop", "save97", "save98", "save99", "reject100", "reject101"]:
		check(seen.has(required), "required golden case: " + required)
	check(FileAccess.get_sha256(path) == original_digest, "golden fixture never changed")
	print("Legacy golden replay failures: %d; owner/physical qualification remains separate" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _shop(row: Dictionary, book: SeasonDevelopment) -> void:
	# Decimal strings preserve all signed 64-bit RNG state bits across JSON.
	if not row.get("rng_seed_decimal") is String or not row.rng_seed_decimal.is_valid_int() \
		or not row.get("rng_state_before_decimal") is String or not row.rng_state_before_decimal.is_valid_int() \
		or not row.get("rng_state_after_decimal") is String or not row.rng_state_after_decimal.is_valid_int() \
		or not row.get("roster") is Array or not row.get("expected_offers") is Dictionary \
		or not row.get("expected_prices") is Dictionary:
		check(false, "Malformed shop golden state")
		return
	var roster: Array[String] = []
	for id: Variant in row.roster:
		if not id is String:
			check(false, "Malformed fixture roster")
			return
		roster.append(id)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(row.rng_seed_decimal)
	rng.state = int(row.rng_state_before_decimal)
	var before: Dictionary = book.to_data()
	var offers: Dictionary = DevelopmentShopCatalog.offers(book, roster, rng, row.prefix)
	check(ClubCareer.same(offers, row.expected_offers), "exact old generated offers and order")
	check(str(rng.state) == row.rng_state_after_decimal, "exact old RNG consumption")
	check(ClubCareer.same(book.to_data(), before), "sampling does not change development")
	for item_id: String in row.expected_prices:
		var item: Dictionary = DevelopmentShopCatalog.item(item_id, book._pitch_catalog_version)
		check(item.get("price") == row.expected_prices[item_id], "exact old offered price")
