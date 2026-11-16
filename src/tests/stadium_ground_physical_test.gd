extends "res://src/tests/stadium_complete_physical_test.gd"
## Actual treated home field and two matching physical replay reports.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_seating_ui_test.gd").new()
	var completed: SeasonState = helper._fund_seating()
	_check(helper._failures == 0, "synthetic career funding validates")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_style(app.season, "ST-063f", 4).ok, "actual clay purchase")
	_check(ClubConstruction.buy_style(app.season, "ST-063b", 5).ok == false,
		"future checkerboard gate cannot be bypassed")
	_check(ClubConstruction.buy_style(app.season, "ST-063a", 5).ok, "actual grass purchase")

	_check(app.season.career.balance() == 335
		and ClubPlayers.assets(app.season.career).revision() == 6,
		"clay270 and grass200 debit exactly470 after four earned awards")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumGroundStyles.upgrade(super._layout())
	layout.ground = "ST-063f"
	layout.styles.grass = "ST-063a"
	return layout
