extends "res://src/tests/season_physical_playoffs_test.gd"
## Full real policy6 bracket, with exact wallets and paid learned-effect observation.


var _probe: OpponentAbilityProbe = OpponentAbilityProbe.new()
var _observed_app: SeasonApp


func _new(physical: bool) -> SeasonState:
	var fixture: Node = preload("res://src/tests/season_opponent_abilities_test.gd").new()
	var season: SeasonState = fixture._new(physical)
	_check(fixture._failures == 0, "new ability policy fixture valid")
	fixture.free()
	return season


func _wait_round(app: SeasonApp) -> void:
	_observed_app = app
	await super._wait_round(app)
	var abilities: int = 0
	var used: int = _probe.count_swings + _probe.sky_launches + _probe.ground_samples
	for club: Dictionary in app.season.opponents.clubs.values():
		var build: SeasonBuild = club.build
		_check(build._market == 5 and build._format == 41, "ability format persists")
		var spent: int = 0
		var earned: int = 0
		for row: Dictionary in club.decisions:
			spent += int(row.paid)
			if row.stat != "ability":
				continue
			abilities += 1
			_check(row.paid == SeasonAbilities.ITEMS[row.item].price
				and build.definition(row.player).season_abilities.has(row.item),
				"exact legal paid role ability")
		for event: Dictionary in build.to_data().events:
			if event.op == "reroll":
				spent += 4
			elif event.op == "pack_skip":
				spent += 8 # Opening payment remains spent when no objective matches the reveal.
			elif event.op == "reward":
				earned += 18 if event.win else 12
		_check(build.cash() == earned - spent, "whole season one-wallet paid ledger reconciles")
	_check(app.season.opponents._format == 6, "whole ability bracket keeps selected policy")
	if app.season.phase == SeasonState.Phase.COMPLETE:
		_check(abilities > 0 and used > 0, "actual physical AI play exercises paid learned effects")
	print("NPC_ABILITY_SEASON round=", app.season.round_index, " abilities=", abilities,
		" effect_samples=", used, " observed=", _probe.summary())


func _process(_delta: float) -> void:
	if is_instance_valid(_observed_app):
		_probe.observe(_observed_app.round_ui.runner._lab, _check)
