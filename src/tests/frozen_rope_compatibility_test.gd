extends "res://src/tests/season_frozen_rope_test.gd"
## Retained historical fixture and explicitly disclosed name-only compatibility variant.
var _compat_checks: int = 0

func _ready() -> void:
	SeasonSave.path = "user://frozen-compatibility-%d.json" % OS.get_process_id()
	_frozen_contract()
	_frozen_migration()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/tests/fixtures/frozen_v40.json"))
	var historical: String = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/tests/fixtures/frozen_signature40.json"))["40"]
	var renamed: String = historical.left(historical.length() - 64) \
		+ "3294846d71f111102f795fabdf71b234fc29d44fbb920fcea467782f1550fcaf"
	var compatibility: Dictionary = raw.duplicate(true)
	compatibility.build.catalog = renamed
	_check(SeasonSave._decode(compatibility) != null,
		"name-only transitional Build40 remains readable")
	_check(SeasonGearCatalog.item(GAP).name == "Gap Finder",
		"current display name is unchanged")
	print("FROZEN_SIGNATURES ", JSON.stringify({"40": SeasonBuild._signature(40),
		"41": SeasonBuild._signature(41), "current": SeasonBuild._signature()}))
	_check(SeasonBuild._signature(41).sha256_text()
		== "5e7d590ad7430771b4ddc39ef9d01c2d5d38c9a304ae870b7f81426b352a62d8",
		"Build41 and current catalog identity remain byte exact")
	var old_state: SeasonState = SeasonSave._decode(raw)
	var renamed_state: SeasonState = SeasonSave._decode(compatibility)
	_check(old_state != null and renamed_state != null,
		"both exact historical and renamed representations decode")
	if old_state != null and renamed_state != null:
		print("FROZEN_PAID_WALLET ", JSON.stringify(old_state.build.view().wallet))
		_check(old_state.build.view().wallet.gear.get("bat", {}).get("item") == GAP,
			"original quoted paid fixture retains its actual Gap bat")
		_check(ClubCareer.same(old_state.build.view(), renamed_state.build.view()),
			"name-only migration preserves exact wallet, stock and receipts")
		var raw_build: SeasonBuild = SeasonBuild.from_data(compatibility.build,
			int(raw.seed), old_state.picks, old_state.draft_pool, old_state.recruit_blocked())
		_check(raw_build != null and raw_build._format == 40
			and raw_build.to_data().catalog == historical,
			"direct transitional Build40 replay retains original canonical signature")
		_check(renamed_state.build._format == 41 and old_state.build._format == 41
			and renamed_state.build.to_data().catalog == SeasonBuild._signature(41),
			"normal season migration still promotes both forms to unchanged Build41")
		_check(old_state.build.view().wallet.gear.bat.paid == 16
			and old_state.build.view().wallet.gear.bat.id == "purchase:3",
			"original paid Gap price and receipt identity remain exact")
		var before: Dictionary = SeasonSave.snapshot(renamed_state)
		_check(not before.is_empty() and SeasonSave.save(renamed_state),
			"transitional representation saves durably")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "transitional representation restores")
		if restored != null:
			_check(ClubCareer.same(before, SeasonSave.snapshot(restored)),
				"complete durable snapshot remains exact after roundtrip")
	for replacement: Variant in ["", true, false, 40, 40.5, null, [], {},
		historical + ":extra", historical.replace("8f9418", "8f9419"),
		renamed.replace("329484", "329485")]:
		var bad: Dictionary = raw.duplicate(true)
		bad.build.catalog = replacement
		_check(SeasonSave._decode(bad) == null, "invalid catalog signature rejects")
	for signature: String in [historical, renamed]:
		for version: int in [41, 45]:
			_check(not SeasonBuildRestore._catalog_valid(
				{"version": version, "catalog": signature}),
				"Build40 compatibility cannot admit an unrelated format")
		var bad: Dictionary = raw.duplicate(true)
		bad.build.catalog = signature
		bad.build.events[0].rev = 1
		_check(SeasonSave._decode(bad) == null,
			"both accepted signatures still enforce event chronology")
		bad = raw.duplicate(true)
		bad.build.catalog = signature
		bad.build.events[0].fabricated_cash = 100
		_check(SeasonSave._decode(bad) == null,
			"both accepted signatures reject invented event currency")
	_check(not SeasonBuildRestore._catalog_valid(
		{"version": 40, "catalog": SeasonBuild._signature(41)}),
		"newer complete signature cannot enter Build40")
	print("FROZEN_COMPATIBILITY_RESULT checks=", _compat_checks, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	_compat_checks += 1
	super._check(ok, message)
