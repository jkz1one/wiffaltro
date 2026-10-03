extends "res://src/tests/season_physical_playoffs_test.gd"
## The full real bracket with policy3; the original policy2 benchmark stays separate.


func _new(physical: bool) -> SeasonState:
	var fixtures: Node = preload("res://src/tests/season_opponent_gear_test.gd").new()
	var season: SeasonState = fixtures._new(physical)
	_check(fixtures._failures == 0, "new Gear policy fixture is valid")
	fixtures.free()
	return season


func _wait_round(app: SeasonApp) -> void:
	await super._wait_round(app)
	var purchases: int = 0
	for club: Dictionary in app.season.opponents.clubs.values():
		var build: SeasonBuild = club.build
		_check(build._market == 2 and build._format == 41, "new opponent format persists")
		var spent: int = 0
		var earned: int = 0
		for row: Dictionary in club.decisions:
			spent += int(row.paid)
			purchases += 1 if row.stat == "gear" else 0
		for event: Dictionary in build.to_data().events:
			if event.op == "reroll":
				spent += 4
			elif event.op == "reward":
				earned += 18 if event.win else 12
		_check(build.cash() == earned - spent, "full season's shared competing wallet reconciles")
	_check(app.season.opponents._format == 3, "whole Gear bracket retains its selected policy")
	print("NPC_GEAR_SEASON round=", app.season.round_index, " gear_purchases=", purchases)
