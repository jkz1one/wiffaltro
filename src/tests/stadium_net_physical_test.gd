extends "res://src/tests/stadium_complete_physical_test.gd"
## Separately paid target/net pair through two actual complete physical-game replays.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_net_ui_test.gd").new()
	var completed: SeasonState = helper._fund_net()
	_check(helper._failures == 0, "synthetic closed paired funding validates")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_copy(app.season, "ST-026", 4).ok, "separately earned target purchase")
	_check(ClubConstruction.buy_copy(app.season, "ST-025", 5).ok, "separately earned net purchase")

	_check(app.season.career.balance() == 115
		and ClubPlayers.assets(app.season.career).revision() == 6,
		"separate target300 and net390 debit exactly690 after four earned pennants")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumNetItems.upgrade(super._layout())
	layout.receiver = ""
	layout.target = "purchase:stadium-buy:4:0"
	layout.net = "purchase:stadium-buy:5:0"
	return layout
