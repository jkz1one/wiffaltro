extends "res://src/tests/season_physical_playoffs_test.gd"
## Full real policy5 bracket, with exact wallets and paid learned-recipe release evidence.


func _new(physical: bool) -> SeasonState:
	var fixture: Node = preload("res://src/tests/season_opponent_lessons_test.gd").new()
	var season: SeasonState = fixture._new(physical)
	_check(fixture._failures == 0, "new lesson policy fixture valid")
	fixture.free()
	return season


func _wait_round(app: SeasonApp) -> void:
	await super._wait_round(app)
	var lessons: int = 0
	var used: int = 0
	for club: Dictionary in app.season.opponents.clubs.values():
		var build: SeasonBuild = club.build
		_check(build._market == 4 and build._format == 41, "lesson format persists")
		var spent: int = 0
		var earned: int = 0
		for row: Dictionary in club.decisions:
			spent += int(row.paid)
			if row.stat != "lesson":
				continue
			lessons += 1
			_check(row.player == club.roles.secondary and row.paid == 10
				and build.player(row.player).active.has(row.pitch), "exact legal paid secondary lesson")
			for saved: Dictionary in app.season.physical.reports:
				for release: Dictionary in saved.report.releases:
					if release.player == row.player and release.recipe == row.pitch:
						used += 1
		for event: Dictionary in build.to_data().events:
			if event.op == "reroll":
				spent += 4
			elif event.op == "pack_skip":
				spent += 8 # Opening payment remains spent when no objective matches the reveal.
			elif event.op == "reward":
				earned += 18 if event.win else 12
		_check(build.cash() == earned - spent, "whole season one-wallet paid ledger reconciles")
	_check(app.season.opponents._format == 5, "whole lesson bracket keeps selected policy")
	if app.season.phase == SeasonState.Phase.COMPLETE:
		_check(lessons > 0 and used > 0, "actual physical AI releases use paid learned recipes")
	print("NPC_LESSON_SEASON round=", app.season.round_index, " lessons=", lessons,
		" learned_releases=", used)
