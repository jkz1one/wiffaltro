class_name SeasonMatchSales
extends RefCounted
## Ownership saves immediately; the runtime copy retires only at a safe PA boundary.

var pending: Dictionary = {}


static func available(app: SeasonApp) -> bool:
	return (
		app.lab != null
		and app._season_game
		and app.season.build != null
		and app.season.build._format >= 22
		and app.lab._match_state.phase != MatchState.Phase.GAME_END
	)


static func command(app: SeasonApp, receipt: String) -> Dictionary:
	var build: SeasonBuild = app.season.build
	var usage: MatchGearUsage = app.lab._match_state.gear_usage
	return {
		"id": "live-sale:%d" % build.revision(),
		"rev": build.revision(),
		"op": "match_sell",
		"game": app._fixture_id,
		"receipt": receipt,
		"first_pitch": usage.first_pitch.duplicate() if usage.started else null
	}


func sell(app: SeasonApp, request: Dictionary) -> bool:
	if not available(app):
		app.notice = "This match is no longer available for sales."
		return false
	var previous: SeasonBuild = app.season.build
	var receipt: Dictionary = SeasonOwnership._owned(previous.view().wallet, request.receipt)
	if receipt.is_empty():
		app.notice = "This copy was already sold."
		return false
	var next: SeasonBuild = previous.candidate(request)
	if next == null:
		app.notice = previous.last_error
		return false
	app.season.build = next
	if not app._checkpoint():
		app.season.build = previous
		return false
	pending[receipt.id] = receipt.duplicate(true)
	apply_pending(app)
	return true


func apply_pending(app: SeasonApp) -> void:
	if app.lab == null or pending.is_empty():
		return
	var state: MatchState = app.lab._match_state
	if not state.can_change_defense():
		return
	var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
	var wallet: Dictionary = app.season.build.view().wallet
	for player: PlayerMatchState in own.roster:
		player.definition = SeasonGearCatalog.equip(player.definition, wallet.gear)
		for receipt: Dictionary in pending.values():
			if receipt.kind == "sponsor":
				player.definition.season_sponsors.erase(receipt.item)
	app.loadout.match_snapshot.gear = wallet.gear.duplicate(true)
	app.loadout.match_snapshot.sponsors = wallet.sponsors.duplicate(true)
	app.loadout.match_snapshot.capacity = wallet.capacity.duplicate(true)
	if not state.gear_usage.started:
		state.gear_usage.equipped = SeasonReclamation.receipts(wallet)
	pending.clear()
