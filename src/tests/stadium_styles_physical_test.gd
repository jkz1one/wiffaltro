extends "res://src/tests/stadium_complete_physical_test.gd"
## Two actual styled-home games and exact physical proof replay.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_seating_ui_test.gd").new()
	var completed: SeasonState = helper._fund_seating()
	_check(helper._failures == 0, "synthetic funding validated")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_style(app.season, "ST-062a", 4).ok, "exact chalk entitlement")
	_check(ClubConstruction.buy_style(app.season, "ST-063a", 5).ok, "exact striped-grass entitlement")

	_check(app.season.career.balance() == 490
		and ClubPlayers.assets(app.season.career).revision() == 6
		and ClubPlayers.assets(app.season.career).construction().copies.size() == 7,
		"chalk115 plus grass200 debit exactly315 without adding or removing copies")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumFieldStyles.upgrade(super._layout())
	layout.styles = {"line": "ST-062a", "grass": "ST-063a"}
	return layout
