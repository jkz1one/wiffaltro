extends "res://src/tests/stadium_complete_physical_test.gd"
## Real owned seating and full perimeter, with two actual matching physical reports.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_seating_ui_test.gd").new()
	var completed: SeasonState = helper._fund_seating()
	_check(helper._failures == 0, "synthetic funding history validated")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubPlayers.assets(app.season.career).revision() == 4,
		"four earned pennants precede two exact seating purchases")
	for id: String in ["ST-080", "ST-027"]:
		var revision: int = ClubPlayers.assets(app.season.career).revision()
		var bought: Dictionary = ClubConstruction.buy_copy(app.season, id, revision)
		_check(bought.ok, "exact owned seating purchase " + id + ": " + bought.error)

	_check(app.season.career.balance() == 215
		and ClubPlayers.assets(app.season.career).revision() == 6,
		"chair190 plus bleacher400 spend exactly590 without duplicating earned awards")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumHomeLayout.upgrade(super._layout())
	layout.seating = [{"copy": "purchase:stadium-buy:4:0", "site": "SC-R1"},
		{"copy": "purchase:stadium-buy:5:0", "site": "SIDE-SEAT-L"}]
	return layout
