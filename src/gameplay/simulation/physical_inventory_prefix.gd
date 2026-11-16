class_name PhysicalInventoryPrefix
extends RefCounted
## Explicit completed-PA prefix authority for inventory-v1 Field Supply resale only.
## Not a physical match report, terminal result, arbitrary partial-play validator or cash ledger.
# gdlint: disable=max-returns,max-file-lines

const VERSION: int = 1
const RESOLVER: String = "inventory-completed-pa-prefix-v1"


static func capture(state: MatchState, own: TeamMatchState, anchor: Dictionary) -> Dictionary:
	if (
		state == null
		or own == null
		or state.away_team == null
		or state.home_team == null
		or own not in [state.away_team, state.home_team]
		or not state.between_batters
		or (
			state.phase
			not in [
				MatchState.Phase.PRE_PITCH,
				MatchState.Phase.PLAY_DEAD,
				MatchState.Phase.INNING_TRANSITION
			]
		)
		or not state.sure_shot.current(state).is_empty()
		or not PhysicalLeagueReport.capture_context_valid(state)
		or not _anchor(anchor)
	):
		return {}
	var completed: int = state.plate_appearance_number - 1
	if (
		completed < 0
		or state.base_flow.results.size() != completed
		or state.base_flow.ready.size() < completed
	):
		return {}
	for release: Dictionary in state.sure_shot.releases:
		if release.pa > completed:
			return {}
	for action: Dictionary in own.tactics.consumed:
		if action.pa > completed:
			return {}
	var rosters: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var ids: Array = []
		for player: PlayerMatchState in team.roster:
			if player == null or player.definition == null:
				return {}
			ids.append(String(player.definition.id))
		rosters.append(ids)
	return {
		"version": VERSION,
		"resolver": RESOLVER,
		"inventory_rule": SeasonInventoryResale.RULE,
		"league_rules": state.league_rules.duplicate(true),
		"anchor": anchor.duplicate(true),
		"own_index": 0 if own == state.away_team else 1,
		"rosters": rosters,
		"completed": completed,
		"base":
		{
			"ready": state.base_flow.ready.slice(0, completed).duplicate(true),
			"results": state.base_flow.results.duplicate(true),
			"tags": state.base_flow.tags.duplicate(true),
			"advances": state.base_flow.advances.duplicate(true)
		},
		"performance": state.performance.snapshot(state),
		"releases": state.sure_shot.releases.duplicate(true),
		"field_state": SeasonFieldSales.capture(state, own),
		"held": own.tactics.held.duplicate(true)
	}


static func matches(
	proof: Variant,
	own: TeamMatchState,
	opponent: Array,
	game: int,
	anchor: Dictionary,
	initial_ownership: Dictionary,
	sales: Array,
	own_index: int,
	retired_before_attempt: bool,
	pitch_catalog: String = ""
) -> bool:
	return not (
		authenticated(
			proof,
			own,
			opponent,
			game,
			anchor,
			initial_ownership,
			sales,
			own_index,
			retired_before_attempt, pitch_catalog
		)
		. is_empty()
	)


static func authenticated(
	proof: Variant,
	own: TeamMatchState,
	opponent: Array,
	game: int,
	anchor: Dictionary,
	initial_ownership: Dictionary,
	sales: Array,
	own_index: int,
	retired_before_attempt: bool,
	pitch_catalog: String = ""
) -> Dictionary:
	var context: Dictionary = _context(
		proof, own, opponent, game, anchor, initial_ownership, own_index, pitch_catalog
	)
	if (
		context.is_empty()
		or retired_before_attempt
		or context.retired_before
		or int(proof.completed) < 1
	):
		return {}
	var field: Dictionary = proof.field_state
	var bag: Dictionary = _bag(proof, own, context.wallet, sales, own_index, game)
	if (
		bag.is_empty()
		or not ClubCareer.same(field.grant, bag.grant)
		or bag.grant.get("outcome") != "granted"
		or not ClubCareer.same(proof.held, bag.held)
	):
		return {}
	var receipt: String = SeasonFieldGrant.receipt(game)
	if field.uses.any(func(action: Dictionary) -> bool: return action.receipt == receipt) \
		or not proof.held.any(func(copy: Dictionary) -> bool: return copy.id == receipt):
		return {}
	return {"field_state": field.duplicate(true), "receipt": receipt,
		"after_pa": int(bag.grant.after_pa),
		"consumed": field.uses.map(func(action: Dictionary) -> String: return action.receipt)}


## Ordinary initial owned supplies only. Runtime Field Tape still requires authenticated().
## A zero-completed-PA prefix is accepted only with empty chronology and zero performance.
static func unused_receipt(
	proof: Variant,
	own: TeamMatchState,
	opponent: Array,
	game: int,
	anchor: Dictionary,
	initial_ownership: Dictionary,
	sales: Array,
	own_index: int,
	retired_before_attempt: bool,
	receipt: String,
	pitch_catalog: String = ""
) -> Dictionary:
	var context: Dictionary = _context(
		proof, own, opponent, game, anchor, initial_ownership, own_index, pitch_catalog
	)
	if context.is_empty() or context.retired_before != retired_before_attempt:
		return {}
	var copy: Dictionary = SeasonOwnership._owned(context.wallet, receipt)
	if copy.get("kind") != "held" or not SeasonTacticalCatalog.catalog().has(copy.get("item")):
		return {}
	var bag: Dictionary = _bag(
		proof, own, context.wallet, sales, own_index, game, false, retired_before_attempt
	)
	if bag.is_empty() or not ClubCareer.same(proof.field_state.grant, bag.grant) \
		or not ClubCareer.same(proof.held, bag.held) \
		or not bag.held.any(func(row: Dictionary) -> bool: return row.id == receipt) \
		or proof.field_state.uses.any(func(action: Dictionary) -> bool: return action.receipt == receipt):
		return {}
	return {"field_state": proof.field_state.duplicate(true), "receipt": receipt,
		"consumed": proof.field_state.uses.map(func(action: Dictionary) -> String: return action.receipt)}


static func _context(
	proof: Variant,
	own: TeamMatchState,
	opponent: Array,
	game: int,
	anchor: Dictionary,
	initial_ownership: Dictionary,
	own_index: int,
	pitch_catalog: String = ""
) -> Dictionary:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return {}
	if (
		own == null
		or own.roster.size() != 4
		or opponent.size() != 4
		or own_index not in [0, 1]
		or not _anchor(anchor)
		or int(anchor.game) != game
		or not proof is Dictionary
		or not SeasonOwnership._keys(
			proof,
			[
				"version",
				"resolver",
				"inventory_rule",
				"league_rules",
				"anchor",
				"own_index",
				"rosters",
				"completed",
				"base",
				"performance",
				"releases",
				"field_state",
				"held"
			]
		)
		or not SeasonOwnership._whole(proof.version, VERSION, VERSION)
		or proof.resolver != RESOLVER
		or proof.inventory_rule != SeasonInventoryResale.RULE
		or not ClubCareer.same(proof.anchor, anchor)
		or not SeasonOwnership._whole(proof.own_index, own_index, own_index)
		or not ClubCareer.same(proof.league_rules, own.league_rules)
		or not SeasonOwnership._whole(proof.completed, 0, 9999)
	):
		return {}
	var bank: SeasonOwnership = SeasonOwnership.from_data(
		initial_ownership, SeasonSponsorCatalog.ownership_catalog()
	)
	if (
		bank == null
		or not SeasonInventoryResale.enabled(bank)
		or not bank.league_rules_valid()
		or not ClubCareer.same(bank._league_rules, own.league_rules)
	):
		return {}
	var ids: Array = []
	var definitions: Dictionary = {}
	for player: PlayerMatchState in own.roster:
		if player == null or player.definition == null:
			return {}
		ids.append(String(player.definition.id))
		definitions[String(player.definition.id)] = player.definition
	var teams: Array = [ids, opponent] if own_index == 0 else [opponent, ids]
	if not ClubCareer.same(proof.rosters, teams) or not _teams(teams):
		return {}
	if not _prefix(proof, teams, definitions, pitch_catalog) or not _fielding(proof, ids, own_index):
		return {}
	var field: Variant = proof.field_state
	if (
		not field is Dictionary
		or not SeasonOwnership._keys(field, ["pa", "boundary", "grant", "uses", "fielding"])
		or not SeasonOwnership._whole(field.pa, int(proof.completed) + 1, int(proof.completed) + 1)
		or not SeasonOwnership._whole(field.boundary, int(proof.completed), int(proof.completed))
		or not field.uses is Array
		or not proof.held is Array
	):
		return {}
	return {
		"wallet": bank.view(), "retired_before": SeasonInventoryResale.field_retired(bank, game)
	}


static func _anchor(value: Dictionary) -> bool:
	return (
		SeasonOwnership._keys(value, ["id", "rev", "game"])
		and value.id is String
		and not value.id.is_empty()
		and SeasonOwnership._whole(value.rev, 0, 1000000)
		and SeasonOwnership._whole(value.game, 0, 32)
	)


static func _teams(teams: Array) -> bool:
	var seen: Array = []
	for roster: Array in teams:
		for id: Variant in roster:
			if not id is String or not SeasonPlayerCatalog.ids().has(id) or seen.has(id):
				return false
			seen.append(id)
	return true


static func _prefix(proof: Dictionary, teams: Array, definitions: Dictionary,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	if (
		not proof.base is Dictionary
		or not SeasonOwnership._keys(proof.base, ["ready", "results", "tags", "advances"])
		or not proof.releases is Array
		or proof.releases.size() > 99999
		or not SeasonPerformance.valid(proof.performance, teams[0] + teams[1])
	):
		return false
	for key: String in ["ready", "results", "tags", "advances"]:
		if not proof.base[key] is Array or proof.base[key].size() > int(proof.completed):
			return false
	if (
		proof.base.ready.size() != int(proof.completed)
		or proof.base.results.size() != int(proof.completed)
	):
		return false
	var replay: PhysicalBaseFlow = PhysicalBaseFlow.new()
	replay.rosters = teams
	for id: String in teams[0] + teams[1]:
		replay.stats.players[id] = MatchPerformance.empty_line()
	var tags: Dictionary = PhysicalBaseFlow._indexed(proof.base.tags)
	var advances: Dictionary = PhysicalBaseFlow._indexed(proof.base.advances, true)
	if tags.size() != proof.base.tags.size() or advances.size() != proof.base.advances.size():
		return false
	for index in range(int(proof.completed)):
		if replay.ended or not replay._snapshot(proof.base.ready[index]):
			return false
		if advances.has(replay.pa):
			if not replay._advance(advances[replay.pa], proof.performance) or replay.ended:
				return false  # A supply-only terminal PA is not a completed batting prefix.
			advances.erase(replay.pa)
		if not replay._result(proof.base.results[index], tags.get(replay.pa)):
			return false
		tags.erase(replay.pa)
		replay.batting[replay.half % 2] += 1
		replay.pa += 1
		if not replay.ended and replay.outs == MatchState.OUTS_PER_HALF:
			replay.ended = replay._half_end()
			if not replay.ended:
				replay.half += 1
				replay.outs = 0
				replay.bases.clear()
				if replay.half >= MatchState.REGULATION_INNINGS * 2:
					replay.bases.second = StringName(
						(
							"extra_runner.%s.%d"
							% ["away" if replay.half % 2 == 0 else "home", int(replay.half / 2) + 1]
						)
					)
	if replay.ended or not tags.is_empty() or not advances.is_empty():
		return false
	var counts: Dictionary = {}
	var last: Dictionary = {}
	var previous: int = 0
	for row: Variant in proof.releases:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["pa", "half", "player", "recipe"]) \
			or not SeasonOwnership._whole(row.pa, maxi(1, previous), int(proof.completed)) \
			or not SeasonOwnership._whole(row.half, 0, 9999) \
			or not row.player is String or not row.recipe is String or \
				PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) == null:
			return false
		var result: Dictionary = proof.base.results[int(row.pa) - 1]
		if row.half != result.half or not teams[1 - int(result.half) % 2].has(row.player):
			return false
		if definitions.has(row.player) and not definitions[row.player].starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe):
			return false
		previous = int(row.pa)
		counts[row.player] = counts.get(row.player, 0) + 1
		last[int(row.pa)] = row.player
	for result: Dictionary in proof.base.results:
		if last.get(int(result.pa)) != result.pitcher:
			return false
	for id: String in proof.performance:
		for key: String in MatchPerformance.KEYS:
			var expected: int = (
				counts.get(id, 0) if key == "pitches" else replay.stats.players[id][key]
			)
			if proof.performance[id][key] != expected:
				return false
	return true


static func _fielding(proof: Dictionary, ids: Array, own_index: int) -> bool:
	if (
		not proof.field_state is Dictionary
		or not proof.field_state.get("fielding") is Array
		or not PhysicalMatchEvidence._fielding(proof.field_state.fielding, ids, 1 - own_index)
	):
		return false
	var seen: Dictionary = {}
	for row: Dictionary in proof.field_state.fielding:
		if int(row.pa) > int(proof.completed):
			return false
		var result: Dictionary = proof.base.results[int(row.pa) - 1]
		if (
			result.outcome != "out"
			or row.half != result.half
			or row.pitcher != result.pitcher
			or (not row.primary and row.player != row.pitcher)
		):
			return false
		seen[int(row.pa)] = row
	for result: Dictionary in proof.base.results:
		if (
			int(result.half) % 2 == 1 - own_index
			and result.outcome == "out"
			and not seen.has(int(result.pa))
		):
			return false
	for tag: Dictionary in proof.base.tags:
		if int(tag.half) % 2 == 1 - own_index:
			var row: Dictionary = seen.get(int(tag.pa), {})
			if not row.get("air", false) or row.get("player") != tag.defender:
				return false
	for row: Dictionary in proof.field_state.fielding:
		if row.air and proof.base.ready[int(row.pa) - 1].outs < 2 \
			and not proof.base.tags.any(func(tag: Dictionary) -> bool: return tag.pa == row.pa):
			return false
	return true


static func _bag(
	proof: Dictionary,
	own: TeamMatchState,
	wallet: Dictionary,
	sales: Array,
	own_index: int,
	game: int,
	require_field: bool = true,
	retired_before_attempt: bool = false
) -> Dictionary:
	var field: Dictionary = proof.field_state
	var initial: Array = wallet.held.duplicate(true)
	var receipt: String = SeasonFieldGrant.receipt(game)
	if initial.any(func(copy: Dictionary) -> bool: return copy.id == receipt):
		return {}
	var active: bool = not retired_before_attempt and wallet.sponsors.any(func(copy: Dictionary) -> \
		bool: return copy.item == "B01")
	if (
		(require_field and not active)
		or sales.size() > 9999
		or field.uses.size() > initial.size() + 1
	):
		return {}
	var current_wallet: Dictionary = wallet
	var through: int = 99999
	var previous_pa: int = 0
	var previous_boundary: int = -1
	var removals: Array = []
	var retired_current: bool = false
	for sale: Variant in sales:
		if not sale is Dictionary or not SeasonOwnership._keys(sale,
			["pa", "boundary", "discard", "capacity", "retired", "sold_receipt", "before", "after", \
				"uses", "field_state"]) \
			or not SeasonOwnership._whole(sale.pa, maxi(1, previous_pa), int(proof.completed) + 1) \
			or not SeasonOwnership._whole(sale.boundary, int(sale.pa) - 1, int(sale.pa)) \
			or sale.boundary < previous_boundary or sale.boundary > proof.completed \
			or not sale.discard is Array or not sale.uses is Array or not sale.sold_receipt is String or \
				sale.sold_receipt.is_empty() \
			or not sale.retired is bool or not sale.before is Dictionary or not sale.after is Dictionary \
			or not ClubCareer.same(sale.before, current_wallet) \
			or not sale.after.get("held") is Array or not sale.after.get("sponsors") is Array \
			or not sale.after.get("capacity") is Dictionary \
			or not SeasonOwnership._whole(sale.capacity, 0, 100) or sale.after.capacity.get("held") != \
				sale.capacity:
			return {}
		var accepted_field: Variant = sale.field_state
		if not accepted_field is Dictionary or not SeasonOwnership._keys(accepted_field,
			["pa", "boundary", "grant", "uses", "fielding"]) \
			or accepted_field.pa != sale.pa or accepted_field.boundary != sale.boundary \
			or not accepted_field.grant is Dictionary or not accepted_field.fielding is Array \
			or not ClubCareer.same(accepted_field.uses, sale.uses) \
			or not ClubCareer.same(accepted_field.fielding, field.fielding.filter(
				func(row: Dictionary) -> bool: return row.pa < sale.pa)):
			return {}
		var removed: Array = []
		for copy: Dictionary in sale.before.held:
			if not sale.after.held.any(func(row: Dictionary) -> bool: return row.id == copy.id):
				if copy.id != sale.sold_receipt and not sale.discard.has(copy.id):
					return {}
				removed.append(copy.id)
		for copy: Variant in sale.after.held:
			if not copy is Dictionary or not sale.before.held.any(
				func(row: Dictionary) -> bool: return ClubCareer.same(row, copy)):
				return {} # No live acquisition or hidden replacement can create capacity provenance.
		var retired: bool = sale.before.sponsors.any(func(copy: Dictionary) -> bool:
			return copy.item == "B01" and not sale.after.sponsors.any(
				func(row: Dictionary) -> bool: return row.id == copy.id))
		if retired != sale.retired:
			return {}
		if retired:
			through = mini(through, int(sale.boundary))
		if sale.sold_receipt == receipt or sale.discard.has(receipt):
			if require_field:
				return {} # The current earned copy cannot pay twice.
			retired_current = true
		removals.append({"pa": int(sale.pa), "ids": removed})
		previous_pa = int(sale.pa)
		previous_boundary = int(sale.boundary)
		current_wallet = sale.after
	var clean: Array = field.fielding.filter(func(row: Dictionary) -> bool:
		return row.clean and row.pa <= through)
	if require_field and clean.size() < 3:
		return {}
	var earned_pa: int = int(clean[2].pa) if active and clean.size() >= 3 else 0
	var grant: Dictionary = {} if earned_pa == 0 else {"after_pa": earned_pa, "outcome": "granted"}
	var known: Dictionary = {}
	for copy: Dictionary in initial:
		known[copy.id] = copy
	known[receipt] = SeasonFieldGrant.copy(game)
	var used: Array = []
	var recovered: Array = []
	var actions_by_pa: Dictionary = {}
	var combo_used: bool = false
	previous_pa = 0
	for action: Variant in field.uses:
		if not action is Dictionary or not action.get("receipt") is String \
			or used.has(action.receipt) or not known.has(action.receipt) \
			or not SeasonOwnership._whole(action.get("pa"), maxi(1, previous_pa), int(proof.completed)):
			return {}
		var copy: Dictionary = known[action.receipt]
		if action.receipt == receipt and (earned_pa == 0 or action.pa <= earned_pa):
			return {}
		for sale: Dictionary in sales:
			if sale.sold_receipt == action.receipt:
				return {} # Paid resale is unused-only, unlike an explicit consumed discard.
		for removal: Dictionary in removals:
			if removal.ids.has(action.receipt):
				if removal.pa < action.pa:
					return {}
				if removal.pa == action.pa:
					var accepted: bool = false
					for sale: Dictionary in sales:
						if int(sale.pa) == removal.pa and sale.discard.has(action.receipt):
							accepted = accepted or sale.uses.any(func(use: Variant) -> bool:
								return _same_use(action, use))
					if not accepted:
						return {}
		if not _action(action, copy, proof, own, own_index, recovered) \
			or (action.get("insured", false) and not _sponsor_at(wallet, sales, "E04", int(action.pa))):
			return {}
		var pa: int = int(action.pa)
		if not actions_by_pa.has(pa):
			actions_by_pa[pa] = []
		actions_by_pa[pa].append(action)
		used.append(action.receipt)
		previous_pa = pa
	for pa: int in actions_by_pa:
		var actions: Array = actions_by_pa[pa]
		if actions.size() == 1:
			if actions[0].has("combo"):
				return {}
		elif actions.size() == 2 and not combo_used:
			if (
				not actions[0].get("combo", false)
				or not actions[1].get("combo", false)
				or known[actions[0].receipt].item != "A10"
				or known[actions[1].receipt].item != "C03"
				or actions[0].player != actions[1].player
				or not _sponsor_at(wallet, sales, "E07", pa)
			):
				return {}
			combo_used = true
		else:
			return {}
	for sale: Dictionary in sales:
		for accepted: Variant in sale.uses:
			if not field.uses.any(func(action: Dictionary) -> bool: return _same_use(action, accepted)):
				return {}
		for action: Dictionary in field.uses:
			if action.pa < sale.pa and not sale.uses.any(func(accepted: Variant) -> bool:
				return _same_use(action, accepted)):
				return {}
	if not PhysicalBaseEvidence.human({"base": proof.base}, field.uses, own_index):
		return {}
	var at_delivery: Array = initial.duplicate(true)
	var capacity: int = int(wallet.capacity.held)
	for sale: Dictionary in sales:
		if sale.pa <= earned_pa and sale.boundary <= earned_pa:
			capacity = int(sale.capacity)
	for removal: Dictionary in removals:
		if removal.pa <= earned_pa:
			at_delivery = at_delivery.filter(func(copy: Dictionary) -> bool: return not \
				removal.ids.has(copy.id))
	for action: Dictionary in field.uses:
		if action.pa <= earned_pa:
			at_delivery = at_delivery.filter(func(copy: Dictionary) -> bool: return copy.id != \
				action.receipt)
	if earned_pa > 0 and at_delivery.size() >= capacity:
		if require_field:
			return {}  # Full at the third clean out forfeits; later room never queues a grant.
		grant.outcome = "full"
	if (
		(grant.get("outcome") != "granted" and used.has(receipt))
		or (retired_current and grant.get("outcome") != "granted")
	):
		return {}
	for sale: Dictionary in sales:
		var visible_grant: Dictionary = grant if earned_pa > 0 and earned_pa < sale.pa else {}
		if not ClubCareer.same(sale.field_state.grant, visible_grant):
			return {}
	var held: Array = initial.duplicate(true)
	for removal: Dictionary in removals:
		held = held.filter(func(copy: Dictionary) -> bool: return not removal.ids.has(copy.id))
	held = held.filter(func(copy: Dictionary) -> bool: return not used.has(copy.id))
	if grant.get("outcome") == "granted" and not used.has(receipt) and not retired_current:
		held.append(SeasonFieldGrant.copy(game))
	if held.size() > int(current_wallet.capacity.held):
		return {}
	return {"grant": grant, "held": held.filter(func(copy: Dictionary) -> bool:
		return SeasonTacticalCatalog.catalog().has(copy.item))}


static func _sponsor_at(wallet: Dictionary, sales: Array, item: String, pa: int) -> bool:
	var copies: Array = wallet.sponsors.filter(func(copy: Dictionary) -> bool: return copy.item == \
		item)
	if copies.is_empty():
		return false
	for sale: Dictionary in sales:
		if sale.boundary < pa and not sale.after.sponsors.any(func(copy: Dictionary) -> bool:
			return copies.any(func(original: Dictionary) -> bool: return original.id == copy.id)):
			return false
	return true


static func _action(
	action: Dictionary,
	copy: Dictionary,
	proof: Dictionary,
	own: TeamMatchState,
	own_index: int,
	recovered: Array
) -> bool:
	if not SeasonTacticalCatalog.catalog().has(copy.item) or not action.get("player") is String:
		return false
	var keys: Array = ["receipt", "player", "pa", "swing"]
	for key: String in ["combo", "insured", "walked"]:
		if action.has(key):
			keys.append(key)
			if not action[key] is bool or action[key] != true:
				return false
	if copy.item == SeasonTacticalCatalog.BASE:
		keys.append("advance")
	if not SeasonOwnership._keys(action, keys):
		return false
	var ready: Dictionary = proof.base.ready[int(action.pa) - 1]
	var result: Dictionary = proof.base.results[int(action.pa) - 1]
	var defensive: bool = copy.item in ["C02", SeasonTacticalCatalog.HEAT]
	if (
		(int(result.half) % 2 != (1 - own_index if defensive else own_index))
		or action.player != (ready.pitcher if defensive else ready.player)
	):
		return false
	if copy.item == "C03":
		if action.swing not in ["swing.contact", "swing.power"]:
			return false
	elif action.swing != "":
		return false
	if action.has("walked") and (copy.item not in ["A10", "C03"] or result.outcome != "walk"):
		return false
	if action.has("insured") and own.tactics.insured_receipt != action.receipt:
		return false
	if copy.item == "C02":
		if recovered.has(action.player):
			return false
		var player: PlayerMatchState
		for candidate: PlayerMatchState in own.roster:
			if String(candidate.definition.id) == action.player:
				player = candidate
		# The only other refund is B03: at most25% of this PA's paid costs.
		# Positive catalog releases therefore cannot return an initially full pitcher
		# to full before their first C02. No gear sale changes game stamina capacity.
		if player == null or (player.stamina_remaining >= player.stamina_max \
			and not proof.releases.any(func(row: Dictionary) -> bool:
				return row.player == action.player and row.pa < action.pa)):
			return false
		recovered.append(action.player)
	if copy.item == SeasonTacticalCatalog.BASE:
		if not proof.base.advances.any(func(row: Dictionary) -> bool:
			return row.receipt == action.receipt and row.after.pa == action.pa \
				and ClubCareer.same(row.advance, action.advance)):
			return false
	return true


static func _same_use(current: Dictionary, accepted: Variant) -> bool:
	if not accepted is Dictionary:
		return false
	var normalized: Dictionary = current.duplicate(true)
	# A live sale during the PA precedes the later settled walk marker.
	if not accepted.has("walked"):
		normalized.erase("walked")
	return ClubCareer.same(normalized, accepted)
