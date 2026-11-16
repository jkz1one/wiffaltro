extends "res://src/tests/season_same_save_night_test.gd"
## Entire legacy title/funding prefix is synthetic, not played physical evidence.
## Paid layout is then obtained through existing public purchase/draft/apply paths.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
var destination: String = ""
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--night-funded-output="):
			destination = arg.trim_prefix("--night-funded-output=")
	if not destination.is_absolute_path() or destination != destination.simplify_path() \
		or DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		push_error("Fresh absolute synthetic funding output required; no work performed")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	SeasonSave.path = destination.path_join("public-purchase-working.json")
	var source: SeasonState = _qualified_funding()
	_check(source != null, "new synthetic qualifying history, no edits to retained paid career")
	if source != null:
		var ledger: ClubAssetLedger = _public_purchases(source)
		_check(ledger != null, "new fixture public purchases and layout Apply")
		if ledger != null:
			var snapshot: Dictionary = SeasonSave.snapshot(source)
			var authority: Dictionary = Authority.create(snapshot, "night-fixture-audit")
			_check(not authority.is_empty() and "dynasty" in Authority.available_leagues(authority),
				"validated synthetic tier3 history actually admits Dynasty")
			_check(SeasonSave._decode(JSON.parse_string(JSON.stringify(snapshot, "", true, true))) != null,
				"entire paid source cold-decodes before handoff")
			if _failures == 0:
				var file: FileAccess = FileAccess.open(destination.path_join("paid-dynasty-qualified-fixture.json"), FileAccess.WRITE)
				_check(file != null, "source fixture output writable")
				if file != null:
					file.store_string(JSON.stringify(snapshot, "", true, true))
	print("NIGHT_SYNTHETIC_FUNDING checks=%d failures=%d physical_games=0 synthetic_titles=true" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
func _qualified_funding() -> SeasonState:
	var titles: Array = []
	for tier in range(4):
		titles.append({"league": "dugout", "tier": tier})
	for index in range(20):
		titles.append({"league": "standard", "tier": 0})
	var club: ClubCareer = Fixture.prefix(titles)
	if club == null:
		return null
	var source: SeasonState = SeasonState.create(38109, false, true, true)
	source.career = club
	if not club.start(source):
		return null
	for pick in range(4):
		if source.offers().is_empty() or not source.choose_player(source.offers()[0]):
			return null
	while source.phase != SeasonState.Phase.COMPLETE:
		var fixture: Dictionary = source.pending_fixture()
		if fixture.is_empty() or not source.record_player_result(int(fixture.id),
			0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0):
			return null
	return source if SeasonSave.save(source) else null
