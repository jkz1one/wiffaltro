class_name SeasonInventoryRules
extends RefCounted

const CLOSE_OP: String = "inventory_close_v1"
## Closed staging admission. Existing in-progress seasons retain their old contract.


static func header() -> Dictionary:
	return {"version": 1, "rule": SeasonInventoryResale.RULE, "completed_rounds": 0}


static func valid(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._keys(value, ["version", "rule", "completed_rounds"])
		and SeasonOwnership._whole(value.version, 1, 1)
		and value.rule == SeasonInventoryResale.RULE
		and SeasonOwnership._whole(value.completed_rounds, 0, 0)
	)


static func build_enable(build: SeasonBuild, command: Dictionary) -> String:
	if (
		not build._keys(command, [])
		or command.id != "inventory-rules-v1"
		or not build._events.is_empty()
		or not build._bank._events.is_empty()
		or build._format not in [SeasonBuild.LEAGUE_VERSION, SeasonBuild.LEAGUE_TIER_VERSION]
		or not build.league_context_valid()
		or build.roster().size() != 4
		or not build._bank.view().rewards.is_empty()
		or not build._pregames.is_empty()
		or not build._match_inventory.is_empty()
		or build.pack_pending()
		or SeasonInventoryResale.enabled(build._bank)
	):
		return "Inventory sale rules require a fresh, fully drafted closed season."
	var result: Dictionary = build._bank.commit(
		{
			"id": "inventory-rules-v1",
			"rev": build._bank.revision(),
			"op": SeasonInventoryResale.ENABLE_OP
		}
	)
	return "" if result.ok else result.error


static func enable(season: SeasonState) -> bool:
	if (
		not season.inventory_rules.is_empty()
		or not season.league_context_consistent()
		or season.league_rules.is_empty()
		or not season.league_live
		or season.picks.size() != 4
		or not season.results.is_empty()
		or season.physical == null
		or not season.physical.pending.is_empty()
		or not season.physical.reports.is_empty()
		or season.opponents.clubs.size() != 5
	):
		return false
	var builds: Array[SeasonBuild] = [season.build]
	for club: Dictionary in season.opponents.clubs.values():
		builds.append(club.build)
	var candidates: Array[SeasonBuild] = []
	for build: SeasonBuild in builds:
		var next: SeasonBuild = build.candidate(
			{
				"id": "inventory-rules-v1",
				"rev": build.revision(),
				"op": SeasonInventoryResale.ENABLE_OP
			}
		)
		if next == null:
			return false
		candidates.append(next)
	season.build = candidates[0]
	var index: int = 1
	for club: Dictionary in season.opponents.clubs.values():
		club.build = candidates[index]
		index += 1
	season.inventory_rules = header()
	return true


static func consistent(season: SeasonState) -> bool:
	var enabled: bool = not season.inventory_rules.is_empty()
	if (
		enabled
		and (
			not valid(season.inventory_rules)
			or season.league_rules.is_empty()
			or not season.league_live
			or season.picks.size() != 4
		)
	):
		return false
	var builds: Array = [season.build]
	if season.opponents != null:
		for club: Variant in season.opponents.clubs.values():
			if not club is Dictionary or not club.get("build") is SeasonBuild:
				return false
			builds.append(club.build)
	for build: Variant in builds:
		if build != null and (not build is SeasonBuild or not build_consistent(build, enabled)):
			return false
	return true


static func build_consistent(build: SeasonBuild, enabled: bool) -> bool:
	if SeasonInventoryResale.enabled(build._bank) != enabled:
		return false
	var migrations: int = 0
	for event: Dictionary in build._events:
		if event.get("op") == SeasonInventoryResale.ENABLE_OP:
			migrations += 1
		if not enabled and event.get("op") in ["inventory_sell", "match_supply_sell", CLOSE_OP]:
			return false
	if not enabled:
		if migrations != 0:
			return false
		for event: Dictionary in build._bank._events:
			if (
				event.get("op")
				in [
					SeasonInventoryResale.ENABLE_OP,
					SeasonInventoryResale.SALE_OP,
					SeasonInventoryResale.FIELD_OP,
					CLOSE_OP
				]
			):
				return false
		return true
	if migrations != 1 or build._events.is_empty() or build._bank._events.is_empty():
		return false
	var expected: Dictionary = {
		"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP
	}
	return (
		ClubCareer.same(build._events[0], expected)
		and ClubCareer.same(build._bank._events[0], expected)
	)


static func contains(value: Variant) -> bool:
	if value is Dictionary:
		if (
			value.has("inventory_rules")
			or (
				value.get("op")
				in [
					SeasonInventoryResale.ENABLE_OP,
					SeasonInventoryResale.SALE_OP,
					SeasonInventoryResale.FIELD_OP,
					CLOSE_OP
				]
			)
		):
			return true
		for child: Variant in value.values():
			if contains(child):
				return true
	elif value is Array:
		for child: Variant in value:
			if contains(child):
				return true
	return false


static func closed(build: SeasonBuild) -> bool:
	if (
		build == null
		or not SeasonInventoryResale.enabled(build._bank)
		or build._match_inventory.is_empty()
	):
		return false
	var current: Dictionary = anchor(build, int(build._match_inventory.get("game", -1)))
	for index in range(build._events.size() - 1, -1, -1):
		var event: Dictionary = build._events[index]
		if event.get("op") == "match_inventory":
			return false
		if event.get("op") == CLOSE_OP and ClubCareer.same(event.get("attempt"), current):
			return true
	return false


static func close_attempt(build: SeasonBuild, command: Dictionary) -> String:
	if (
		not SeasonInventoryResale.enabled(build._bank)
		or build._market != 0
		or not build._keys(command, ["game", "attempt"])
		or not SeasonOwnership._whole(command.game, 0, 32)
		or build._match_inventory.is_empty()
		or build._match_inventory.get("game") != command.game
		or build._bank.view().rewards.has(str(int(command.game)))
		or closed(build)
		or not command.attempt is Dictionary
		or not ClubCareer.same(command.attempt, anchor(build, int(command.game)))
	):
		return "This match attempt cannot be closed."
	build._match_inventory["closed"] = true
	return ""


static func menu_available(build: SeasonBuild) -> bool:
	if between_games(build):
		return true
	if build == null or build.pack_pending() or not closed(build):
		return false
	var game: String = str(int(build._match_inventory.game))
	for pending: String in build._pregames:
		if not build._bank.view().rewards.has(pending) and pending != game:
			return false
	return true


static func between_games(build: SeasonBuild) -> bool:
	if (
		build == null
		or not SeasonInventoryResale.enabled(build._bank)
		or build.pack_pending()
		or not build._match_inventory.is_empty()
	):
		return false
	for game: String in build._pregames:
		if not build._bank.view().rewards.has(game):
			return false
	return true


static func sell(build: SeasonBuild, command: Dictionary) -> String:
	var fields: Array = ["receipt"]
	for optional: String in ["sales", "discard"]:
		if command.has(optional):
			fields.append(optional)
	if (
		not menu_available(build)
		or not build._keys(command, fields)
		or not command.receipt is String
	):
		return "Review an owned item between games."
	var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
	if owned.is_empty():
		return "This copy is no longer owned."
	if owned.kind == "sponsor":
		var translated: Dictionary = command.duplicate(true)
		translated.op = "sponsor_sell"
		return SeasonSponsorPurchase.commit(build, translated)
	if command.has("sales") or command.has("discard"):
		return "Extra removals only accompany a sponsor sale."
	var result: Dictionary = build._bank.commit(
		{
			"id": "inventory-sale:%d" % build.revision(),
			"rev": build._bank.revision(),
			"op": SeasonInventoryResale.SALE_OP,
			"receipt": command.receipt
		}
	)
	if not result.ok:
		return result.error
	if owned.kind == "gear" and build._visit.get("open", false):
		SeasonReclamation.sold(build, owned)
	else:
		build._used_gear.erase(command.receipt)
	return ""


static func anchor(build: SeasonBuild, game: int) -> Dictionary:
	for index in range(build._events.size() - 1, -1, -1):
		var event: Dictionary = build._events[index]
		if event.get("op") == "match_inventory" and event.get("game") == game:
			return {"id": event.id, "rev": int(event.rev), "game": game}
	return {}


static func live_supply(build: SeasonBuild, command: Dictionary) -> String:
	if (
		not SeasonInventoryResale.enabled(build._bank)
		or not build._keys(
			command, ["game", "receipt", "first_pitch", "field_state", "inventory_prefix"]
		)
		or not command.receipt is String
		or not command.inventory_prefix is Dictionary
	):
		return "Review an unused supply at a safe break."
	var proof: Dictionary = command.inventory_prefix
	if (
		not proof.get("rosters") is Array
		or proof.rosters.size() != 2
		or not SeasonOwnership._whole(proof.get("own_index"), 0, 1)
	):
		return "The live inventory roster changed."
	var side: int = int(proof.own_index)
	var order: Variant = proof.rosters[side]
	if not order is Array or order.size() != 4 or not proof.rosters[1 - side] is Array:
		return "The live inventory roster changed."
	var members: Array = order.duplicate()
	members.sort()
	var expected: Array = build.roster()
	expected.sort()
	if members != expected:
		return "The live inventory roster changed."
	var source: Dictionary = SeasonDoubleheaderBuild.context(build, int(command.game))
	if source.is_empty() or source.get("anchor", {}).is_empty():
		return "The live attempt could not be reconstructed."
	var definitions: Array[PlayerDefinition] = []
	for id: String in order:
		definitions.append(source.definitions[id])
	var own: TeamMatchState = TeamMatchState.create("Inventory proof", definitions)
	own.league_rules = build._league_rules.duplicate(true)
	own.league_ownership = source.ownership.duplicate(true)
	var insurance: Dictionary = build._insurance.get(str(int(command.game)), {})
	if insurance.get("outcome")=="pending" and source.initial_wallet.sponsors.any(func(row: \
		Dictionary) -> bool:
		return row.item=="E04" and row.id==insurance.get("sponsor")):
		own.tactics.insured_receipt=insurance.receipt
	if LeagueRules.doubleheader(build._league_rules):
		var pair: Dictionary = SeasonDoubleheaderBuild.pair_for(build, int(command.game))
		if pair.is_empty():
			return "The paired game's workload changed."
		own.league_pair = pair
		for player: PlayerMatchState in own.roster:
			player.stamina_remaining = maxf(
				0.0, player.stamina_max - float(pair.debt.get(String(player.definition.id), 0.0))
			)
	var owned: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
	var generated: bool = (
		owned.is_empty() and command.receipt == SeasonFieldGrant.receipt(int(command.game))
	)
	var checked: Dictionary
	var paused: bool = proof.get("resolver") == PhysicalInventoryPaused.RESOLVER
	for earlier: Dictionary in source.inventory_prefixes:
		if (
			earlier.get("resolver") == PhysicalInventoryPaused.RESOLVER
			and not PhysicalInventoryPaused.frontier_matches(earlier, proof)
		):
			return "An accepted sale's play history changed."
	var pitch_catalog: String = build.pitch_catalog_signature()
	if paused and generated:
		checked = PhysicalInventoryPaused.authenticated(
			proof,
			own,
			proof.rosters[1 - side],
			int(command.game),
			source.anchor,
			source.ownership,
			source.inventory_sales,
			side,
			source.retired_before, pitch_catalog
		)
	elif (
		paused
		and owned.get("kind") == "held"
		and DevelopmentShopCatalog.CARDS.has(owned.get("item"))
	):
		checked = PhysicalInventoryPaused.unused_inactive_receipt(
			proof,
			own,
			proof.rosters[1 - side],
			int(command.game),
			source.anchor,
			source.ownership,
			source.inventory_sales,
			side,
			source.retired_before,
			command.receipt, pitch_catalog
		)
	elif paused and owned.get("kind") == "held":
		checked = PhysicalInventoryPaused.unused_receipt(
			proof,
			own,
			proof.rosters[1 - side],
			int(command.game),
			source.anchor,
			source.ownership,
			source.inventory_sales,
			side,
			source.retired_before,
			command.receipt, pitch_catalog
		)
	elif generated:
		checked = PhysicalInventoryPrefix.authenticated(
			proof,
			own,
			proof.rosters[1 - side],
			int(command.game),
			source.anchor,
			source.ownership,
			source.inventory_sales,
			side,
			source.retired_before, pitch_catalog
		)
	elif owned.get("kind") == "held":
		checked = PhysicalInventoryPrefix.unused_receipt(
			proof,
			own,
			proof.rosters[1 - side],
			int(command.game),
			source.anchor,
			source.ownership,
			source.inventory_sales,
			side,
			source.retired_before,
			command.receipt, pitch_catalog
		)
	if checked.is_empty() or not ClubCareer.same(checked.field_state, command.field_state):
		return "The supply is used, unavailable, or its completed-play evidence changed."
	var before: Dictionary = build._bank.view()
	var sale: Dictionary = {
		"id": "live-supply-sale:%d" % build.revision(),
		"rev": build._bank.revision(),
		"op": SeasonInventoryResale.FIELD_OP if generated else SeasonInventoryResale.SALE_OP
	}
	if generated:
		sale["game"] = int(command.game)
	else:
		sale["receipt"] = command.receipt
	var result: Dictionary = build._bank.commit(sale)
	if not result.ok:
		return result.error
	var removal: Dictionary = command.duplicate(true)
	removal["discard"] = [command.receipt]
	var error: String = SeasonFieldSales.finish(build, removal, before)
	if not error.is_empty():
		return error
	build._match_inventory.first_pitch = (
		command.first_pitch.duplicate() if command.first_pitch is Array else null
	)
	return ""


static func fixture_prefixes(
	build: SeasonBuild, game: int, opponent: Array, own_index: int, final_own: Array = []
) -> bool:
	if not SeasonInventoryResale.enabled(build._bank):
		return true
	var latest: Dictionary = {} if closed(build) else anchor(build, game)
	for event: Dictionary in build._events:
		if event.get("op") != "match_supply_sell" or event.get("game") != game:
			continue
		var proof: Variant = event.get("inventory_prefix")
		if (
			not proof is Dictionary
			or not proof.get("rosters") is Array
			or proof.rosters.size() != 2
			or not SeasonOwnership._whole(proof.get("own_index"), own_index, own_index)
			or not ClubCareer.same(proof.rosters[1 - own_index], opponent)
		):
			return false
		if (
			not final_own.is_empty()
			and ClubCareer.same(proof.get("anchor"), latest)
			and not ClubCareer.same(proof.rosters[own_index], final_own)
		):
			return false
	return true


static func paused_sales(build: SeasonBuild, game: int) -> Array:
	if closed(build):
		return []
	var current: Dictionary = anchor(build, game)
	if current.is_empty():
		return []
	return build._events.filter(func(event: Dictionary)->bool:
		return event.get("op")=="match_supply_sell" and event.get("game")==game \
			and event.get("inventory_prefix",{}).get("resolver")==PhysicalInventoryPaused.RESOLVER \
			and ClubCareer.same(event.inventory_prefix.get("anchor"),current))


static func capture_final(
	build: SeasonBuild, game: int, state: MatchState, own: TeamMatchState
) -> Dictionary:
	if (
		paused_sales(build, game).is_empty()
		or state == null
		or state.phase != MatchState.Phase.GAME_END
		or own not in [state.away_team, state.home_team]
	):
		return {}
	var rosters: Array = []
	for team: TeamMatchState in [state.away_team,state.home_team]:
		rosters.append(team.roster.map(func(player: PlayerMatchState)->String: return \
			String(player.definition.id)))
	return {
		"version": 1,
		"rosters": rosters,
		"own_index": 0 if own == state.away_team else 1,
		"base": state.base_flow.evidence(state),
		"releases": state.sure_shot.releases.duplicate(true),
		"calls": state.sure_shot.calls.duplicate(true),
		"roles": own.inventory_actions.duplicate(true),
		"field_state": SeasonFieldSales.capture(state, own),
		"pitching": state.sure_shot.evidence(own)
	}


static func final_reward(build: SeasonBuild, command: Dictionary) -> String:
	var accepted: Array = paused_sales(build, int(command.get("game", -1)))
	if accepted.is_empty():
		return "Unexpected inventory result evidence." if command.has("inventory_final") else ""
	var value: Variant = command.get("inventory_final")
	if (
		not value is Dictionary
		or not value.get("rosters") is Array
		or value.rosters.size() != 2
		or not SeasonOwnership._whole(value.get("own_index"), 0, 1)
	):
		return "The completed inventory history is missing."
	var source: Dictionary = SeasonDoubleheaderBuild.context(build, int(command.game))
	if source.is_empty():
		return "The completed inventory attempt changed."
	var side: int = int(value.own_index)
	var order: Variant = value.rosters[side]
	if not order is Array or order.size() != 4:
		return "The completed inventory roster changed."
	var sorted: Array = order.duplicate()
	sorted.sort()
	var expected: Array = build.roster()
	expected.sort()
	if sorted != expected:
		return "The completed inventory roster changed."
	var definitions: Array[PlayerDefinition] = []
	for id: String in order:
		definitions.append(source.definitions[id])
	var own: TeamMatchState = TeamMatchState.create("Completed inventory authority", definitions)
	own.league_rules = build._league_rules.duplicate(true)
	own.league_ownership = source.ownership.duplicate(true)
	own.tactics.held = SeasonTacticalCatalog.held(source.initial_wallet)
	own.field_supply.receipt = SeasonFieldGrant.receipt(int(command.game))
	if (
		not PhysicalInventoryPaused.validate_final_frontier(
			value, own, command.get("performance", {}),
			build.pitch_catalog_signature()
		)
		or not SeasonSureShot.valid(build, value.get("pitching"), command.get("performance", {}))
	):
		return "The completed inventory play history changed."
	if not ClubCareer.same(value.field_state.uses, command.get("tactics", [])):
		return "The completed supply-use history changed."
	if (
		not ClubCareer.same(value.field_state.grant, command.get("field_supply", {}))
		or (
			command.has("fielding")
			and not ClubCareer.same(value.field_state.fielding, command.fielding)
		)
		or (command.has("pitching") and not ClubCareer.same(value.pitching, command.pitching))
	):
		return "The completed inventory evidence disagrees with its reward."
	for event: Dictionary in accepted:
		if not PhysicalInventoryPaused.frontier_matches(event.inventory_prefix, value):
			return "An accepted sale's play history changed."
	return ""


static func final_fixture(
	build: SeasonBuild,
	game: int,
	evidence: Variant,
	ai_tactics: Dictionary,
	own_index: int,
	own_order: Array,
	opponent_order: Array
) -> bool:
	var accepted: Array = paused_sales(build, game)
	if accepted.is_empty():
		return evidence == null or (evidence is Dictionary and evidence.is_empty())
	if (
		not evidence is Dictionary
		or evidence.get("own_index") != own_index
		or not ClubCareer.same(
			evidence.get("rosters"),
			[own_order, opponent_order] if own_index == 0 else [opponent_order, own_order]
		)
		or not ClubCareer.same(evidence.get("base"), ai_tactics.get("base"))
		or not evidence.get("releases") is Array
	):
		return false
	return ClubCareer.same(evidence.releases.filter(func(row: Dictionary)->bool: return \
		opponent_order.has(row.player)),ai_tactics.get("pitching"))


static func replay_inventory_result(
	season: SeasonState,
	full: SeasonBuild,
	result: Dictionary,
	performance: Dictionary,
	ai_tactics: Dictionary,
	replayed_tactics: Array
) -> bool:
	var prefix: SeasonBuild = SeasonBuildRestore.restore(
		full.to_data(), full._seed, full._initial_roster, full._pool, full._blocked, int(result.id)
	)
	if prefix == null:
		return false
	var reward: Dictionary = {}
	for event: Dictionary in full._events:
		if event.get("op") == "reward" and event.get("game") == result.id:
			reward = event
			break
	if (
		reward.is_empty()
		or not ClubCareer.same(reward.get("inventory_final"), result.get("inventory_final"))
	):
		return false
	season.build = prefix
	return season._record_player_result(
		int(result.id),
		int(result.away_runs),
		int(result.home_runs),
		performance,
		reward.get("used_gear", []),
		reward.get("tactics", []),
		reward.get("batting", {}),
		reward.get("stances", []),
		reward.get("fielding", []),
		reward.get("pitching", {}),
		reward.get("field_supply", {}),
		reward.get("frozen", []),
		ai_tactics,
		replayed_tactics,
		"",
		null,
		null,
		null,
		result.get("doubleheader_evidence"),
		{},
		result.inventory_final
	)
