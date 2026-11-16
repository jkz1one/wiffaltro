extends "res://src/tests/stadium_complete_physical_test.gd"
## Real expanded property, third spectator socket and two exact physical report replays.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_seating_ui_test.gd").new()
	var completed: SeasonState = helper._fund_seating()
	_check(helper._failures == 0, "synthetic funding career validated")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_land(app.season, "expanded", 4).ok, "real expanded land purchase")
	_check(ClubConstruction.buy_copy(app.season, "ST-080", 5).ok, "exact third-site chair purchased")

	_check(app.season.career.balance() == 15
		and ClubPlayers.assets(app.season.career).revision() == 6,
		"four earned awards plus land600 and chair190 debit exactly790")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumHomeLayout.upgrade(super._layout())
	layout.seating = [{"copy": "purchase:stadium-buy:5:0", "site": "SC-L3"}]
	return layout
