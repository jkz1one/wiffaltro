extends "res://src/tests/stadium_physical_test.gd"
## Synthetic earning fixture funds real saved purchases; both repeated matches run actual physics.


func _begin(app: SeasonApp) -> void:
	var helper: Node = load("res://src/tests/club_career_test.gd").new()
	var completed: SeasonState = helper._new(443)
	helper._finish(completed, "champion")
	_check(helper._failures == 0 and SeasonSave.save(completed), "synthetic funding receipt validated")
	helper.free()
	app.season = completed
	app.begin_season(443, true, true, true, _complete_boundary())
	_check(ClubPlayers.assets(app.season.career).revision() == 1
		and ClubPlayers.assets(app.season.career).to_data().events[0].op == "stadium_pennant",
		"one legitimate championship award precedes paid-copy receipts")
	for id: String in ["ST-001", "ST-003", "ST-079"]:
		var revision: int = ClubPlayers.assets(app.season.career).revision()
		var paid: Dictionary = ClubConstruction.buy_copy(app.season, id, revision)
		_check(paid.ok, "real paid exact copy " + id + ": " + paid.error)
	_check(app.season.career.balance() == 100, "exact 120-CB construction debit")


func _layout() -> Dictionary:
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "purchase:stadium-buy:3:0"
	layout.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "purchase:stadium-buy:1:0", "site": "O-L2", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90},
		{"copy": "purchase:stadium-buy:2:0", "site": "O-R2", "yaw": 270}]
	return layout
