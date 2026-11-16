class_name SeasonMatchSales
extends RefCounted
## Ownership saves immediately; the runtime copy retires only at a safe PA boundary.

var pending: Dictionary = {}
var _through_pa: int = 0


static func available(app: SeasonApp) -> bool:
	return (
		app.lab != null
		and app._season_game
		and app.season.build != null
		and app.season.build._format >= 22
		and app.lab._match_state.phase != MatchState.Phase.GAME_END
		and (
			not SeasonInventoryResale.enabled(app.season.build._bank)
			or (
				app.lab._match_state.phase
				not in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]
			)
		)
	)


static func copy_for(app: SeasonApp, receipt: String) -> Dictionary:
	if app == null or app.season == null or app.season.build == null:
		return {}
	var owned: Dictionary = SeasonOwnership._owned(app.season.build._bank.view(), receipt)
	if not owned.is_empty():
		return owned
	if (
		app.lab == null
		or not app._season_game
		or not SeasonInventoryResale.enabled(app.season.build._bank)
		or receipt != SeasonFieldGrant.receipt(app._fixture_id)
	):
		return {}
	var state: MatchState = app.lab._match_state
	var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
	for copy: Dictionary in own.tactics.held:
		if copy.id == receipt:
			return copy.duplicate(true)
	return {}


static func command(app: SeasonApp, receipt: String) -> Dictionary:
	var build: SeasonBuild = app.season.build
	var usage: MatchGearUsage = app.lab._match_state.gear_usage
	var result: Dictionary = {
		"id": "live-sale:%d" % build.revision(),
		"rev": build.revision(),
		"op": "match_sell",
		"game": app._fixture_id,
		"receipt": receipt,
		"first_pitch": usage.first_pitch.duplicate() if usage.started else null
	}
	if build._format >= 34:
		var state: MatchState = app.lab._match_state
		var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
		result["field_state"] = SeasonFieldSales.capture(state, own)
		result.field_state.boundary = maxi(result.field_state.boundary, app.sales._through_pa)
		if (
			SeasonInventoryResale.enabled(build._bank)
			and copy_for(app, receipt).get("kind") == "held"
		):
			var proof: Dictionary = PhysicalInventoryPaused.capture(
				app.lab, own, SeasonInventoryRules.anchor(build, app._fixture_id)
			)
			if proof.is_empty():
				proof = PhysicalInventoryPrefix.capture(
					state, own, SeasonInventoryRules.anchor(build, app._fixture_id)
				)
			if proof.is_empty():
				return {}
			result.op = "match_supply_sell"
			result["inventory_prefix"] = proof
			result.field_state = proof.field_state.duplicate(true)
	return result


func sell(app: SeasonApp, request: Dictionary) -> bool:
	if not available(app):
		app.notice = "This match is no longer available for sales."
		return false
	var previous: SeasonBuild = app.season.build
	var receipt: Dictionary = copy_for(app, request.receipt)
	if receipt.is_empty():
		app.notice = "This copy was already sold."
		return false
	if request.get("op") == "match_supply_sell":
		var fresh: Dictionary = command(app, request.receipt)
		if (
			fresh.is_empty()
			or not ClubCareer.same(fresh.get("inventory_prefix"), request.get("inventory_prefix"))
			or not ClubCareer.same(fresh.get("first_pitch"), request.get("first_pitch"))
		):
			app.notice = "The play changed. Review the unused supply again."
			return false
	var next: SeasonBuild = previous.candidate(request)
	if next == null:
		app.notice = previous.last_error
		return false
	app.season.build = next
	if not app._checkpoint():
		app.season.build = previous
		return false
	for old: Dictionary in previous.view().wallet.sponsors + previous.view().wallet.gear.values():
		if not old.is_empty() and SeasonOwnership._owned(next.view().wallet, old.id).is_empty():
			pending[old.id] = old.duplicate(true)
	if request.has("field_state"):
		_through_pa = maxi(_through_pa, int(request.field_state.boundary))
	if SeasonInventoryResale.enabled(next._bank):
		# The inactive receipt has no deferred gameplay effect or active-use snapshot.
		app.loadout.match_snapshot["spare"] = next._bank.view().get("spare", {}).duplicate(true)
	# Remove explicitly discarded unused copies immediately; active effects survive.
	var state: MatchState = app.lab._match_state
	var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
	if SeasonInventoryResale.enabled(next._bank):
		# Immediate inactive-card removals do not retire deferred sponsor capacity.
		var wallet: Dictionary = next._bank.view()
		own.field_supply.reserved = wallet.held.size() - SeasonTacticalCatalog.held(wallet).size()
	var removed: Array = request.get("discard", []).duplicate()
	if request.get("op") == "match_supply_sell":
		removed.append(request.receipt)
	for index in range(own.tactics.held.size() - 1, -1, -1):
		if removed.has(own.tactics.held[index].id):
			own.tactics.held.remove_at(index)
	var consumed: Array = own.tactics.consumed.map(
		func(action: Dictionary) -> String: return action.receipt
	)
	var held: Array = app.loadout.match_snapshot.get("held", [])
	for index in range(held.size() - 1, -1, -1):
		if removed.has(held[index].id) and not consumed.has(held[index].id):
			held.remove_at(index)
	apply_pending(app)
	return true


func reset() -> void:
	pending.clear()
	_through_pa = 0


func apply_pending(app: SeasonApp) -> void:
	if app.lab == null or pending.is_empty():
		return
	var state: MatchState = app.lab._match_state
	if (
		state.plate_appearance_number <= _through_pa
		or not state.between_batters
		or state.phase in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]
		or not state.sure_shot.current(state).is_empty()
	):
		return
	var own: TeamMatchState = state.home_team if app.lab._player_home else state.away_team
	var wallet: Dictionary = app.season.build.view().wallet
	for player: PlayerMatchState in own.roster:
		player.definition = SeasonGearCatalog.equip(player.definition, wallet.gear)
		player.definition.season_abilities = app.season.build._abilities.ids(
			String(player.definition.id)
		)
		for receipt: Dictionary in pending.values():
			if receipt.kind == "sponsor":
				player.definition.season_sponsors.erase(receipt.item)
	app.loadout.match_snapshot.gear = wallet.gear.duplicate(true)
	app.loadout.match_snapshot.sponsors = wallet.sponsors.duplicate(true)
	app.loadout.match_snapshot.capacity = wallet.capacity.duplicate(true)
	MatchFieldSupply.sync_capacity(own, wallet)
	if not state.gear_usage.started:
		state.gear_usage.equipped = SeasonReclamation.receipts(wallet)
	reset()
