extends "res://src/tests/stadium_complete_physical_test.gd"
## Two actual games at Club grounds with both larger owned assemblies.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/stadium_bleachers_ui_test.gd").new()
	var completed: SeasonState = helper._fund_bleachers()
	_check(helper._failures == 0, "synthetic advanced seating funding validates")
	helper.free()
	app.season = completed
	app.begin_season(443, true)
	_check(ClubConstruction.buy_land(app.season, "expanded", 20).ok, "actual Expanded purchase")
	_check(ClubConstruction.buy_land(app.season, "club", 21).ok, "actual Club purchase")
	_check(ClubConstruction.buy_copy(app.season, "ST-028", 22).ok, "actual aluminum purchase")
	_check(ClubConstruction.buy_copy(app.season, "ST-075", 23).ok, "actual roofed purchase")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumBleacherItems.upgrade(super._layout())
	layout.bleachers = [{"copy": "purchase:stadium-buy:22:0", "site": "SIDE-SEAT-L"},
		{"copy": "purchase:stadium-buy:23:0", "site": "SIDE-SEAT-R"}]
	return layout
