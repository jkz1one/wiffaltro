extends "res://src/tests/stadium_complete_physical_test.gd"
## Actual field displays and two exact physical-game replays; funding history is synthetic.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_seating_ui_test.gd").new()
	var completed: SeasonState = helper._fund_seating()
	_check(helper._failures == 0, "synthetic funding history validated")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_copy(app.season, "ST-039", 4).ok, "actual scoreboard purchase")
	_check(ClubConstruction.buy_copy(app.season, "ST-041", 5).ok, "actual sign purchase")

	_check(app.season.career.balance() == 240
		and ClubPlayers.assets(app.season.career).revision() == 6,
		"board440 and first sign125 spend exactly565 after four earned pennants")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumClubItems.upgrade(super._layout())
	layout.displays = [{"copy": "purchase:stadium-buy:4:0", "site": "SCORE-SMALL"},
		{"copy": "purchase:stadium-buy:5:0", "site": "SIGN-GROUND-L"}]
	return layout
