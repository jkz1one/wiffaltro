extends "res://src/tests/stadium_complete_physical_test.gd"
## Actual paid target and two full physical-game replays with exact frozen surfaces.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_target_ui_test.gd").new()
	var completed: SeasonState = helper._fund_target()
	_check(helper._failures == 0, "synthetic closed K funding validates")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_copy(app.season, "ST-026", 2).ok, "actual earned target purchase")

	_check(app.season.career.balance() == 115
		and ClubPlayers.assets(app.season.career).revision() == 3,
		"target300 debit follows two earned pennants exactly once")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumTargetItems.upgrade(super._layout())
	layout.receiver = ""
	layout.target = "purchase:stadium-buy:2:0"
	return layout
