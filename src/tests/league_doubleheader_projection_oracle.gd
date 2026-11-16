extends RefCounted
## Workload authority lives inside the atomic Build journal, never a second carry blob.
# gdlint: disable=max-returns


static func validate(build: SeasonBuild, command: Dictionary) -> String:
	if not LeagueRules.doubleheader(build._league_rules):
		return ""
	if (
		not SeasonOwnership._whole(command.get("game"), 0, 32)
		or not command.get("performance") is Dictionary
		or not command.get("pitching") is Dictionary
		or not command.get("tactics") is Array
	):
		return "Doubleheader rewards require exact completed-game workload evidence."
	var game: int = int(command.game)
	var start: Dictionary = context(build, game)
	if start.is_empty():
		return "The Doubleheader match-start ownership or sale history changed."
	var appearances: int = 0
	for line: Variant in command.performance.values():
		if not line is Dictionary or not SeasonOwnership._whole(line.get("pa"), 0, 99999):
			return "Doubleheader workload requires exact completed appearances."
		appearances += int(line.pa)
	for index in range(build._events.size() - 1, -1, -1):
		var event: Dictionary = build._events[index]
		if event.get("op") == "match_inventory" and event.get("game") == game:
			break
		if (
			event.get("op") == "match_sell"
			and event.get("game") == game
			and int(event.field_state.pa) > appearances + 1
		):
			return "A Doubleheader sale cannot occur after the completed game's final appearance."
	var pair: Dictionary = pair_for(build, game)
	if pair.is_empty():
		return "Complete and validate the exact first Doubleheader fixture first."
	var players: Array[PlayerDefinition] = []
	for id: String in start.build.roster():
		var definition: PlayerDefinition = start.build.definition(id)
		if definition == null:
			return "The Doubleheader starting roster changed."
		players.append(definition)
	var team: TeamMatchState = TeamMatchState.create("Doubleheader workload", players)
	team.league_rules = build._league_rules.duplicate(true)
	team.league_ownership = start.build._bank.to_data()
	team.league_pair = pair
	for player: PlayerMatchState in team.roster:
		player.stamina_remaining = maxf(
			0.0, player.stamina_max - float(pair.debt.get(String(player.definition.id), 0.0))
		)
	if not PhysicalWorkloadEvidence.human_matches(
		command.get("doubleheader_workload"),
		team,
		command.performance,
		command.pitching,
		command.tactics,
		start.refund_through,
		start.cost_context
	):
		return "The Doubleheader workload does not match this paid roster and fixture."
	return ""


static func pair_for(build: SeasonBuild, game: int) -> Dictionary:
	if not LeagueRules.doubleheader(build._league_rules) or not SeasonOwnership._whole(game, 0, 32):
		return {}
	var first: int = SeasonDoubleheaderRules.first(game)
	var debt: Dictionary = {}
	if first >= 0:
		var found: Dictionary = {}
		for event: Dictionary in build._events:
			if event.get("op") == "reward" and event.get("game") == first:
				if not found.is_empty():
					return {}
				found = event
		if (
			found.is_empty()
			or not found.get("win") is bool
			or build._bank.view().rewards.get(str(first)) != found.win
		):
			return {}
		var envelope: Variant = found.get("doubleheader_workload")
		if (
			not envelope is Dictionary
			or not SeasonOwnership._keys(envelope, ["version", "pair", "proof"])
			or not SeasonOwnership._whole(
				envelope.version, PhysicalWorkloadEvidence.VERSION, PhysicalWorkloadEvidence.VERSION
			)
			or not PhysicalWorkloadEvidence.pair_valid(envelope.pair)
			or envelope.pair.game != first
			or envelope.pair.first != -1
			or not envelope.proof is Dictionary
			or not envelope.proof.get("initial") is Dictionary
			or not envelope.proof.get("events") is Array
		):
			return {}
		# Every earlier Build event has already passed this validator during live commit
		# or ordered cold replay. The exact paid partner, not caller flags, supplies debt.
		debt = PhysicalWorkloadEvidence.net_debt(envelope.proof, envelope.pair.debt)
	return {"game": game, "first": first, "debt": debt}


static func context(build: SeasonBuild, game: int) -> Dictionary:
	# Input must be the validated Build immediately BEFORE this game's reward.
	# Historical callers restore that prefix once; this helper never restores Build
	# rewards recursively. Only the independent paid ownership journal is replayed.
	if (
		build == null
		or not build.league_context_valid()
		or not LeagueRules.doubleheader(build._league_rules)
		or not SeasonOwnership._whole(game, 0, 32)
		or build.roster().size() != 4
		or build._bank.view().rewards.has(str(game))
	):
		return {}
	var attempt: int = -1
	var pregame: int = -1
	for index in range(build._events.size()):
		var event: Dictionary = build._events[index]
		if event.get("op") == "reward" and event.get("game") == game:
			return {}
		if event.get("op") == "match_inventory" and event.get("game") == game:
			attempt = index
		if event.get("op") == "pregame" and event.get("game") == game:
			pregame = index
	var sales: Array[Dictionary] = []
	if attempt >= 0:
		if build._market != 0 or build._match_inventory.get("game") != game:
			return {}
		for event: Dictionary in build._events.slice(attempt + 1):
			if event.get("op") != "match_sell" or event.get("game") != game:
				return {}  # No development/roster change can contaminate start definitions.
			sales.append(event)
	elif not build._match_inventory.is_empty():
		return {}
	var bank_events: Array[Dictionary] = build._bank._events
	var budget: bool = false
	if build._market == 12:
		if attempt >= 0 or not sales.is_empty():
			return {}
		if build._pregames.has(str(game)):
			if pregame != build._events.size() - 1:
				return {}
			budget = build._pregames[str(game)].get("outcome") == "granted"
		elif pregame >= 0:
			return {}
	var prefix_size: int = bank_events.size() - sales.size() - (1 if budget else 0)
	if prefix_size < 0:
		return {}
	var wallet: SeasonOwnership = build._bank.empty_fork()
	for event: Dictionary in bank_events.slice(0, prefix_size):
		var paid: Dictionary = wallet.commit(event)
		if not paid.ok or paid.replayed:
			return {}
	# This is a read-only definition/ownership projection, NOT a separately saved
	# Build. Raw ratings and recipes cannot change during accepted sales. A Double Major
	# sale may forget a Fielding ability; do not reuse this for ability history.
	var initial: SeasonBuild = build._fork()
	initial._bank = wallet.fork()
	var through: int = 99999 if _strikecraft(wallet.view()) else -1
	var transitions: Array = []
	var last_boundary: int = -1
	var last_pa: int = 0
	for index in range(sales.size()):
		var sale: Dictionary = sales[index]
		var field: Variant = sale.get("field_state")
		if (
			not field is Dictionary
			or not SeasonOwnership._whole(field.get("pa"), 1, 99999)
			or not SeasonOwnership._whole(field.get("boundary"), int(field.pa) - 1, int(field.pa))
			or int(field.boundary) < last_boundary
			or int(field.pa) < last_pa
		):
			return {}
		var expected: Dictionary = _sale_command(wallet, sale, game)
		var actual: Dictionary = bank_events[prefix_size + index]
		if expected.is_empty() or not ClubCareer.same(actual, expected):
			return {}
		var had_strikecraft: bool = _strikecraft(wallet.view())
		var paid: Dictionary = wallet.commit(actual)
		if not paid.ok or paid.replayed:
			return {}
		last_boundary = int(field.boundary)
		last_pa = int(field.pa)
		if had_strikecraft and not _strikecraft(wallet.view()):
			through = mini(through, last_boundary)
		var after: SeasonBuild = initial._fork()
		after._bank = wallet.fork()
		var definitions: Dictionary = {}
		for id: String in after.roster():
			definitions[id] = after.definition(id)
		var transition: Dictionary = {"after": last_boundary, "definitions": definitions}
		# Equal cutoffs retire together; distinct earlier cutoffs remain distinct.
		if not transitions.is_empty() and transitions[-1].after == last_boundary:
			transitions[-1] = transition
		else:
			transitions.append(transition)
	if budget:
		var expected: Dictionary = {
			"id": "budget:%d" % game, "rev": wallet.revision(), "op": "budget_grant"
		}
		if not ClubCareer.same(bank_events[-1], expected):
			return {}
		var paid: Dictionary = wallet.commit(bank_events[-1])
		if not paid.ok or paid.replayed:
			return {}
	if not ClubCareer.same(wallet.to_data(), build._bank.to_data()):
		return {}
	return {"build": initial, "refund_through": through, "cost_context": transitions}


static func _sale_command(wallet: SeasonOwnership, sale: Dictionary, game: int) -> Dictionary:
	if (
		not sale.get("receipt") is String
		or not SeasonOwnership._whole(sale.get("rev"), 0, SeasonBuild.MAX_EVENTS)
	):
		return {}
	var owned: Dictionary = SeasonOwnership._owned(wallet.view(), sale.receipt)
	if owned.get("kind") not in ["gear", "sponsor"]:
		return {}
	if owned.kind == "sponsor" and (sale.has("sales") or sale.has("discard")):
		if not sale.get("sales", []) is Array or not sale.get("discard", []) is Array:
			return {}
		var selected: Array = [sale.receipt]
		selected.append_array(sale.get("sales", []))
		var discarded: Array = sale.get("discard", []).filter(
			func(id: Variant) -> bool: return id != SeasonFieldGrant.receipt(game)
		)
		return {
			"id": "sponsor-group:%d" % int(sale.rev),
			"rev": wallet.revision(),
			"op": "sponsor_set",
			"sales": selected,
			"purchases": [],
			"discard": discarded
		}
	return {
		"id": "match-sale:%d" % int(sale.rev),
		"rev": wallet.revision(),
		"op": "sell",
		"receipt": sale.receipt,
		"discard": []
	}


static func _strikecraft(wallet: Dictionary) -> bool:
	return wallet.sponsors.any(func(receipt: Dictionary) -> bool: return receipt.item == "B03")


static func recoveries(envelope: Dictionary) -> Dictionary:
	# Call only after validate succeeds, and keep this transient map out of journals.
	var result: Dictionary = {}
	for event: Dictionary in envelope.proof.events:
		if event.kind == "recovery":
			result[event.receipt] = {"player": event.player, "pa": int(event.pa)}
	return result
