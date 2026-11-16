extends "res://src/tests/stadium_owned_waterfall_test.gd"


## Reuses the already-verified synthetic41-season file and its exact historical pre-waterfall
## prefix.
## Public save/purchase/draft/apply routes only after fixture setup. No invented income or real
## games.
func _ready() -> void:
	_full_file_case()
	print(
		(
			"LIGHTING_KIT_FULL_SAVE_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_score_fixture": true,
					"physical_games": 0,
					"night_qualified": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _full_file_case() -> void:
	var input: String = "res://src/tests/lighting_audit_verified_season_fixture.json"
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	var season: SeasonState = SeasonSave._decode(fixture)
	check(season != null, "retained full synthetic waterfall fixture cold-loads unchanged")
	if season == null:
		return
	var legacy: ClubAssetLedger = ClubPlayers.assets(season.career)
	var prefix: ClubAssetLedger = legacy.prefix(44)
	check(
		(
			prefix != null
			and legacy.to_data().events[44].op == "stadium_buy"
			and legacy.to_data().events[44].item == "ST-046"
		),
		"exact retained pre-waterfall prefix selected, no fabricated funding"
	)
	if prefix == null:
		return
	fixture.career.assets = prefix.to_data()
	season = SeasonSave._decode(fixture)
	check(season != null, "full synthetic season validates exact historical land/pennant prefix")
	if season == null:
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	check(ledger.balance() >= 500, "validated existing historical wallet affords two kit copies")
	if ledger.balance() < 500:
		return
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://lighting-kit-audit-save.json"
	check(SeasonSave.save(season), "actual pre-purchase save file writes")
	var before: Dictionary = season.career.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = "user://lighting-kit-missing-directory/blocked.json"
	var failed: Dictionary = ClubConstruction.buy_copy(season, "ST-111", ledger.revision(), 2)
	check(
		(
			not failed.ok
			and failed.error.begins_with("Could not save season.")
			and ClubCareer.same(before, season.career.to_data())
		),
		"failed real file write rolls back kit debit/stock/journal"
	)
	SeasonSave.path = "user://lighting-kit-audit-save.json"
	check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes,
		"failed purchase preserves prior exact disk bytes"
	)
	var balance: int = ledger.balance()
	var old_revision: int = ledger.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(season, "ST-111", old_revision, 2)
	check(bought.ok, "ordinary public kit purchase persists: " + bought.error)
	if not bought.ok:
		SeasonSave.path = original_path
		return
	ledger = ClubPlayers.assets(season.career)
	check(
		(
			ledger.balance() == balance - 500
			and ledger.to_data().version == 52
			and ledger.construction().to_data().version == 6
		),
		"public dispatch uses kit price33 and52/6 history"
	)
	var copy: String = "purchase:stadium-buy:%d:0" % old_revision
	var spare: String = "purchase:stadium-buy:%d:1" % old_revision
	var inventory: Dictionary = ledger.construction().to_data()
	for pattern: String in ["PARALLEL", "ZIGZAG", "PERIMETER", "MIXED_EDGE", ""]:
		ledger = ClubPlayers.assets(season.career)
		var layout: Dictionary = StadiumLightingKitItems.place(
			ledger.view().stadium_draft,
			ledger.construction(),
			copy,
			pattern,
			0,
			ledger.surface_owned()
		)
		var draft: Dictionary = ClubConstruction.save_draft(season, layout, ledger.revision())
		check(draft.ok, "public draft writes exact pattern " + pattern + ": " + draft.error)
		if not draft.ok:
			continue
		ledger = ClubPlayers.assets(season.career)
		var applied: Dictionary = ClubConstruction.apply_draft(season, layout, ledger.revision())
		check(applied.ok, "public Apply writes exact pattern " + pattern + ": " + applied.error)
		if not applied.ok:
			continue
		var cold: SeasonState = SeasonSave._decode(
			JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
		)
		check(cold != null, "actual disk file cold-decodes " + pattern)
		if cold == null:
			continue
		ledger = ClubPlayers.assets(season.career)
		var cold_ledger: ClubAssetLedger = ClubPlayers.assets(cold.career)
		check(
			(
				ClubCareer.same(cold_ledger.view(), ledger.view())
				and ClubCareer.same(cold_ledger.construction().to_data(), inventory)
				and cold_ledger.balance() == balance - 500
			),
			"disk reload preserves wallet/stock/draft/active " + pattern
		)
		check(
			cold_ledger.construction().copies.has(spare),
			"exact paid spare survives actual disk reload " + pattern
		)
		season = cold
	SeasonSave.path = original_path
