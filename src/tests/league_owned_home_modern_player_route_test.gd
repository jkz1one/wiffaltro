extends "res://src/tests/league_owned_home_player_route_test.gd"
## Synthetic unlock evidence; genuine production new_club geometry and inventory.
func _source_career() -> ClubCareer:
	var club: ClubCareer = Fixture.nonphysical_dynasty_source()
	var prior: ClubAssetLedger = ClubPlayers.assets(club)
	club._assets = ClubAssetLedger.new_club(prior._seed, prior._credits,
		prior._progress, prior._championships).to_data()
	return club

func _run(app: SeasonApp, original: String) -> void:
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	check(preload("res://src/gameplay/season/dynasty_league_home_live.gd").modern_origin(
		StadiumLayoutSnapshot.capture(paid, true)), "genuine constructor origin8/40 before enrollment")
	await super._run(app, original)
	if app.season != null:
		check(preload("res://src/gameplay/season/dynasty_league_home_live.gd").modern_origin(app.season.home_property),
			"carried next generation retains exact modern origin")
