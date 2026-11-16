extends Node
var checks: int = 0
var failures: Array[String] = []
var completed_season: SeasonState


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	_run()
	print(
		(
			"LOW_WALL_SAVE_RESULT "
			+ JSON.stringify(
				{"checks": checks, "failures": failures, "synthetic_score_progression": true}
			)
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var career: ClubCareer = ClubCareer.new()
	var season: SeasonState
	for index in range(45):
		season = StadiumPennantRewardRebuildChecks._new(career)
		if (
			season == null
			or not StadiumPennantRewardRebuildChecks._finish(season)
			or not career.sync(season)
		):
			check(false, "authored score fixture funding")
			return
		if index < 44 and not career.close(season):
			check(false, "authored season closure")
			return
	season.career = ClubCareer.from_data(
		JSON.parse_string(JSON.stringify(career.to_data(), "", true, true))
	)
	check(season.career != null and season.career.matches(season), "cold synthetic career exact")
	if season.career == null:
		return
	SeasonSave.path = "user://low-wall-full-save.json"
	check(SeasonSave.save(season), "initial season save")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var bought: Dictionary = ClubConstruction.buy_walls(season, "ST-024", 23, ledger.revision())
	check(bought.ok, "public standard panel purchase: " + bought.error)
	if not bought.ok:
		return
	ledger = ClubPlayers.assets(season.career)
	var prior: Dictionary = season.career.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	SeasonSave.path = "user://missing-low-wall-directory/fail.json"
	var failed: Dictionary = ClubConstruction.buy_wall_pieces(
		season, "ST-024-L", 23, ledger.revision()
	)
	check(
		(
			not failed.ok
			and failed.error.begins_with("Could not save season.")
			and ClubCareer.same(prior, season.career.to_data())
		),
		"failed write rolls back exact low ownership and wallet"
	)
	SeasonSave.path = "user://low-wall-full-save.json"
	check(
		FileAccess.get_file_as_string(SeasonSave.path) == bytes,
		"failed transaction preserves prior save bytes"
	)
	bought = ClubConstruction.buy_wall_pieces(season, "ST-024-L", 23, ledger.revision())
	check(bought.ok, "public exact low panel purchase: " + bought.error)
	if not bought.ok:
		return
	for profile: String in StadiumLowWallRecipes.PROFILES:
		ledger = ClubPlayers.assets(season.career)
		var layout: Dictionary = StadiumLowWallLayout.upgrade(
			(
				StadiumLowWallLayout.base(ledger.view().stadium_active)
				if StadiumLowWallLayout.is_family(ledger.view().stadium_active)
				else ledger.view().stadium_active
			),
			ledger.surface_owned()
		)
		var suggestion: Dictionary = StadiumLowWallManifest.suggest(
			profile, "ST-024", ledger.construction(), ledger.wall_pieces().stock
		)
		check(suggestion.ok, "exact owned suggestion " + profile)
		if not suggestion.ok:
			continue
		layout.low_wall = suggestion.manifest
		var draft: Dictionary = ClubConstruction.save_draft(season, layout, ledger.revision())
		check(draft.ok, "public full-ownership draft: " + draft.error)
		if not draft.ok:
			continue
		var apply: Dictionary = ClubConstruction.apply_draft(
			season, layout, ClubPlayers.assets(season.career).revision()
		)
		check(apply.ok, "public full-ownership apply: " + apply.error)
		var cold: SeasonState = SeasonSave._decode(
			JSON.parse_string(JSON.stringify(SeasonSave.snapshot(season), "", true, true))
		)
		check(cold != null, "cold full SeasonSave envelope " + profile)
		if cold != null:
			var live_ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
			var cold_ledger: ClubAssetLedger = ClubPlayers.assets(cold.career)
			check(
				ClubCareer.same(live_ledger.to_data(), cold_ledger.to_data()),
				"cold exact journal and ownership " + profile
			)
			var snapshot: Dictionary = StadiumLayoutSnapshot.capture(cold_ledger)
			check(
				(
					StadiumLayoutSnapshot.valid(snapshot)
					and StadiumLayoutSnapshot.matches(snapshot, cold_ledger)
				),
				"cold complete entry32 validates " + profile
			)
			check(
				StadiumLayoutSnapshot.valid(StadiumLowWallSnapshot.fixture(snapshot, 194, 1)),
				"cold fixture33 dispatch " + profile
			)

	completed_season = season
