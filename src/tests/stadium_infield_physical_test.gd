extends "res://src/tests/stadium_lights_physical_test.gd"
## Paid full infield, raised markers and actual seeded night games through exact report replay.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_infield_ui_test.gd").new()
	var completed: SeasonState = helper._fund_infield()
	_check(helper._failures == 0, "synthetic closed infield funding validates")
	helper.free()
	app.season = completed
	app.begin_season(96, true)
	_light_receipt_start = 20
	_check(ClubPlayers.assets(app.season.career).revision() == _light_receipt_start,
		"paid night poles follow the full twenty-award prefix")
	for index in range(4):
		_check(ClubConstruction.buy_copy(app.season, "ST-037", _light_receipt_start + index).ok,
			"separately paid night poles")
	for id: String in ["ST-062d", "ST-063h", "ST-063b", "ST-062b"]:
		_check(ClubConstruction.buy_style(app.season, id,
			ClubPlayers.assets(app.season.career).revision()).ok, "exact owned style " + id)


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumInfieldStyles.upgrade(super._layout())
	layout.bases = "ST-062d"
	layout.ground = "ST-063h"
	layout.styles = {"line": "ST-062b", "grass": "ST-063b"}
	return layout
