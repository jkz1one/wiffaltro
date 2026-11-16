class_name PhysicalInventoryPaused
extends RefCounted
## Separate paused-current-PA inventory authority. No unfinished PA becomes a result.
## Not a physical match report, terminal result, arbitrary partial-play validator or cash ledger.
# gdlint: disable=max-returns,max-file-lines

const VERSION: int = 1
const RESOLVER: String = "inventory-paused-prefix-v1"


static func capture(lab: PitchBatLab, own: TeamMatchState, anchor: Dictionary) -> Dictionary:
	if (
		lab == null
		or not lab._debug_paused
		or lab._release_controller == null
		or lab._release_controller.active
	):
		return {}
	var state: MatchState = lab._match_state
	if (
		state == null
		or own == null
		or state.away_team == null
		or state.home_team == null
		or own not in [state.away_team, state.home_team]
		or state.phase not in [MatchState.Phase.PRE_PITCH, MatchState.Phase.PLAY_DEAD]
		or not PhysicalLeagueReport.capture_context_valid(state)
		or not _anchor(anchor)
	):
		return {}
	var completed: int = state.plate_appearance_number - 1
	if (
		completed < 0
		or state.base_flow.results.size() != completed
		or state.base_flow.ready.size() != completed + 1
	):
		return {}
	var rosters: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var ids: Array = []
		for player: PlayerMatchState in team.roster:
			if player == null or player.definition == null:
				return {}
			ids.append(String(player.definition.id))
		rosters.append(ids)
	var current: Dictionary = {"ready": state.base_flow.ready[-1].duplicate(true),
		"snapshot": MatchBaseFlow.snapshot(state), "phase": int(state.phase),
		"between_batters": state.between_batters,
		"balls": state.balls, "strikes": state.strikes, "call": state.sure_shot.current(state),
		"committed": own.tactics.consumed.filter(func(row: Dictionary) -> bool:
			return row.pa == state.plate_appearance_number).map(func(row: Dictionary) -> String: return \
				row.receipt)}
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
		"held": own.tactics.held.duplicate(true),
		"current": current,
		"roles": own.inventory_actions.duplicate(true),
		"calls": state.sure_shot.calls.duplicate(true)
	}


## Called only by successful activation, before any Base Advance changes occupancy.
## Recorder presence grants no authority: every consumer must replay initial bank capability.
static func record_activation(state: MatchState, team: TeamMatchState, receipt: String) -> void:
	if team.league_ownership.is_empty():
		return
	var bank: SeasonOwnership = SeasonOwnership.from_data(
		team.league_ownership, SeasonSponsorCatalog.ownership_catalog()
	)
	if not SeasonInventoryResale.enabled(bank):
		return
	team.inventory_actions.append(
		{
			"receipt": receipt,
			"snapshot": MatchBaseFlow.snapshot(state),
			"release_count": state.sure_shot.releases.size()
		}
	)


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


## Inactive purchased development cards occupy the shared bag but have no live activation.
## This separate path never broadens tactical use eligibility or completed-prefix admission.
static func unused_inactive_receipt(
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
	if (
		copy.get("kind") != "held"
		or not DevelopmentShopCatalog.ownership_catalog().has(copy.get("item"))
	):
		return {}
	var bank: SeasonOwnership = SeasonOwnership.from_data(
		initial_ownership, SeasonSponsorCatalog.ownership_catalog()
	)
	var quote: Dictionary = SeasonInventoryResale.quote(bank, receipt)
	if not quote.get("ok", false) or quote.get("source") != "purchased":
		return {}
	var bag: Dictionary = _bag(
		proof, own, context.wallet, sales, own_index, game, false, retired_before_attempt
	)
	if bag.is_empty() or not ClubCareer.same(proof.field_state.grant, bag.grant) \
		or not ClubCareer.same(proof.held, bag.held) \
		or not bag.all_held.any(func(row: Dictionary) -> bool: return ClubCareer.same(row, copy)) \
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
				"held",
				"current",
				"roles",
				"calls"
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
	if (
		not _prefix(proof, teams, definitions, pitch_catalog)
		or not _fielding(proof, ids, own_index)
		or not _roles(proof, teams)
		or not _calls(proof, teams, definitions, pitch_catalog)
	):
		return {}
	var field: Variant = proof.field_state
	if (
		not field is Dictionary
		or not SeasonOwnership._keys(field, ["pa", "boundary", "grant", "uses", "fielding"])
		or not SeasonOwnership._whole(field.pa, int(proof.completed) + 1, int(proof.completed) + 1)
		or not SeasonOwnership._whole(
			field.boundary, int(proof.completed), int(proof.completed) + 1
		)
		or not field.uses is Array
		or not proof.held is Array
		or (
			int(field.boundary)
			!= (
				int(proof.completed)
				+ (0 if proof.current.between_batters and proof.current.call.is_empty() else 1)
			)
		)
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
		if (
			not proof.base[key] is Array
			or proof.base[key].size() > int(proof.completed) + (1 if key == "advances" else 0)
		):
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
	if (
		replay.ended
		or not tags.is_empty()
		or not proof.current is Dictionary
		or not SeasonOwnership._keys(
			proof.current,
			[
				"ready",
				"snapshot",
				"phase",
				"between_batters",
				"balls",
				"strikes",
				"committed",
				"call"
			]
		)
		or not SeasonOwnership._whole(proof.current.phase, 0, 99)
		or int(proof.current.phase) not in [MatchState.Phase.PRE_PITCH, MatchState.Phase.PLAY_DEAD]
		or not proof.current.between_batters is bool
		or not proof.current.committed is Array
		or not proof.current.call is Dictionary
		or not SeasonOwnership._whole(proof.current.balls, 0, 3)
		or not SeasonOwnership._whole(proof.current.strikes, 0, 2)
		or not replay._snapshot(proof.current.ready)
	):
		return false
	if advances.has(replay.pa):
		if not replay._advance(advances[replay.pa], proof.performance) or replay.ended:
			return false
		advances.erase(replay.pa)
	if not advances.is_empty() or not replay._snapshot(proof.current.snapshot):
		return false
	var counts: Dictionary = {}
	var last: Dictionary = {}
	var previous: int = 0
	for row: Variant in proof.releases:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["pa", "half", "player", "recipe"]) \
			or not SeasonOwnership._whole(row.pa, maxi(1, previous), int(proof.completed) + 1) \
			or not SeasonOwnership._whole(row.half, 0, 9999) \
			or not row.player is String or not row.recipe is String or \
				PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) == null:
			return false
		var result: Dictionary = proof.current.snapshot if int(row.pa) == int(proof.completed) + 1 else \
			proof.base.results[int(row.pa) - 1]
		if row.half != result.half or not teams[1 - int(result.half) % 2].has(row.player) \
			or (int(row.pa) == int(proof.completed) + 1 and (proof.current.between_batters or row.player \
				!= result.pitcher)):
			return false
		if definitions.has(row.player) and not definitions[row.player].starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe):
			return false
		previous = int(row.pa)
		counts[row.player] = counts.get(row.player, 0) + 1
		last[int(row.pa)] = row.player
	var current_count: int = proof.releases.filter(func(row: Dictionary) -> bool: return int(row.pa) \
		== int(proof.completed) + 1).size()
	if (
		int(proof.current.balls) + int(proof.current.strikes) > current_count
		or (current_count == 0 and not proof.current.between_batters)
	):
		return false
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
		var result: Dictionary = (
			proof.current.snapshot
			if int(row.pa) == int(proof.completed) + 1
			else proof.base.results[int(row.pa) - 1]
		)
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
			or sale.boundary < previous_boundary or sale.boundary > int(proof.completed) + 1 \
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
			or not SeasonOwnership._whole(action.get("pa"), maxi(1, previous_pa), int(proof.completed) + 1):
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
	return {"grant": grant, "all_held": held.duplicate(true), "held": held.filter(func(copy: \
		Dictionary) -> bool:
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
	var current: bool = int(action.pa) == int(proof.completed) + 1
	var ready: Dictionary = proof.current.ready if current else proof.base.ready[int(action.pa) - 1]
	var result: Dictionary = (
		proof.current.snapshot if current else proof.base.results[int(action.pa) - 1]
	)
	var roles: Array = proof.roles.filter(func(row: Dictionary) -> bool: return row.receipt == \
		action.receipt)
	if roles.size() != 1:
		return false
	var role: Dictionary = roles[0].snapshot
	var defensive: bool = copy.item in ["C02", SeasonTacticalCatalog.HEAT]
	if (
		(int(result.half) % 2 != (1 - own_index if defensive else own_index))
		or action.player != (role.pitcher if defensive else ready.player)
	):
		return false
	if copy.item == "C03":
		if action.swing not in ["swing.contact", "swing.power"]:
			return false
	elif action.swing != "":
		return false
	if (
		action.has("walked")
		and (copy.item not in ["A10", "C03"] or current or result.outcome != "walk")
	):
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


static func _roles(proof: Dictionary, teams: Array) -> bool:
	if (
		not proof.roles is Array
		or not proof.field_state is Dictionary
		or not proof.field_state.get("uses") is Array
	):
		return false
	var uses: Array = proof.field_state.uses
	if proof.roles.size() != uses.size():
		return false
	for index in range(uses.size()):
		var action: Variant = uses[index]
		var role: Variant = proof.roles[index]
		if not action is Dictionary or not action.get("receipt") is String or not \
			SeasonOwnership._whole(action.get("pa"), 1, int(proof.completed) + 1) \
			or not role is Dictionary or not SeasonOwnership._keys(role, ["receipt", "snapshot", \
				"release_count"]) \
			or role.receipt != action.get("receipt") or not role.snapshot is Dictionary \
			or not SeasonOwnership._whole(role.release_count, 0, proof.releases.size()):
			return false
		var ready: Dictionary = proof.current.ready if int(action.pa) == int(proof.completed) + 1 else \
			proof.base.ready[int(action.pa) - 1]
		var normalized: Dictionary = role.snapshot.duplicate(true)
		if not normalized.get("pitcher") is String or not teams[1 - int(ready.half) % \
			2].has(normalized.pitcher):
			return false
		normalized.pitcher = ready.pitcher
		var position_matches: bool = ClubCareer.same(normalized, ready)
		for advance: Dictionary in proof.base.advances:
			if int(advance.after.pa) == int(action.pa):
				var after: Dictionary = advance.after.duplicate(true)
				after.pitcher = ready.pitcher
				position_matches = position_matches or ClubCareer.same(normalized, after)
		if not position_matches:
			return false
		var prior: int = proof.releases.filter(func(row: Dictionary) -> bool: return row.pa < \
			action.pa).size()
		if int(role.release_count) != prior:
			return false # All supply activations occur before the first release of their PA.
	var committed: Array = uses.filter(func(row: Dictionary) -> bool:
		return int(row.pa) == int(proof.completed) + 1).map(func(row: Dictionary) -> String: return \
			row.receipt)
	return ClubCareer.same(committed, proof.current.committed)


## The caller validates both contracts first. Full results supply normalized actual
## {base, releases (SureShot rows), calls, roles, field_state}; no terminal row is invented.
static func frontier_matches(earlier: Dictionary, later: Dictionary) -> bool:
	if (
		earlier.get("resolver") != RESOLVER
		or not earlier.get("current") is Dictionary
		or not earlier.get("field_state") is Dictionary
		or not later.get("field_state") is Dictionary
		or not later.field_state.get("uses") is Array
		or not earlier.get("base") is Dictionary
		or not later.get("base") is Dictionary
	):
		return false
	for key: String in ["releases", "roles", "calls"]:
		if (
			not earlier.get(key) is Array
			or not later.get(key) is Array
			or not ClubCareer.same(earlier[key], later[key].slice(0, earlier[key].size()))
		):
			return false
	for key: String in ["ready", "results", "tags", "advances"]:
		if (
			not earlier.base.get(key) is Array
			or not later.base.get(key) is Array
			or not ClubCareer.same(
				earlier.base[key], later.base[key].slice(0, earlier.base[key].size())
			)
		):
			return false
	var pa: int = int(earlier.completed) + 1
	var later_ready: Dictionary = {}
	if later.base.ready.size() >= pa:
		later_ready = later.base.ready[pa - 1]
	elif later.get("current") is Dictionary:
		later_ready = later.current.get("ready", {})
	if not ClubCareer.same(earlier.current.ready, later_ready):
		return false
	for action: Dictionary in earlier.field_state.uses:
		if not later.field_state.uses.any(func(row: Variant) -> bool:
			return row is Dictionary and _same_use(row, action)):
			return false
	if later.has("anchor") and not ClubCareer.same(earlier.anchor, later.anchor):
		return false
	if not later.field_state.get("fielding") is Array or not ClubCareer.same(
		earlier.field_state.fielding, later.field_state.fielding.filter(func(row: Dictionary) -> bool: \
			return row.pa < pa)):
		return false
	if (
		not earlier.field_state.grant.is_empty()
		and not ClubCareer.same(earlier.field_state.grant, later.field_state.get("grant"))
	):
		return false
	return true


static func _calls(proof: Dictionary, teams: Array, definitions: Dictionary,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	if not proof.calls is Array or proof.calls.size() > 4:
		return false
	var seen: Array = []
	var counts: Array[int] = [0, 0]
	var current: Dictionary = {}
	var previous: int = 0
	for row: Variant in proof.calls:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["pa", "half", "player", "recipe", \
			"time"]) \
			or not SeasonOwnership._whole(row.pa, maxi(1, previous), int(proof.completed) + 1) \
			or seen.has(int(row.pa)) or not SeasonOwnership._whole(row.half, 0, 9999) \
			or not row.player is String or not row.recipe is String or \
				PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) == null \
			or not (row.time is int or row.time is float) or not is_finite(float(row.time)) or \
				float(row.time) < 0.0:
			return false
		var ready: Dictionary = proof.current.ready if int(row.pa) == int(proof.completed) + 1 else \
			proof.base.ready[int(row.pa) - 1]
		var side: int = 1 - int(ready.half) % 2
		if row.half != ready.half or not teams[side].has(row.player):
			return false
		counts[side] += 1
		if counts[side] > 2 or (definitions.has(row.player) and not \
			definitions[row.player].starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe)):
			return false
		for release: Dictionary in proof.releases:
			if release.pa == row.pa and (release.player != row.player or release.recipe != row.recipe):
				return false
		if int(row.pa) == int(proof.completed) + 1:
			if row.player != proof.current.snapshot.pitcher:
				return false
			current = row
		seen.append(int(row.pa))
		previous = int(row.pa)
	return ClubCareer.same(proof.current.call, current)


## Independent terminal structural join. This calls the unchanged terminal BaseFlow validator;
## it never converts final evidence into a paused proof. Caller binds fixture/opponent authority,
## paid sales/consumption and SureShot entitlement separately.
static func validate_final_frontier(
	value: Variant, own: TeamMatchState, performance: Dictionary,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	if (
		own == null
		or own.roster.size() != 4
		or not value is Dictionary
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"rosters",
				"own_index",
				"base",
				"releases",
				"calls",
				"roles",
				"field_state",
				"pitching"
			]
		)
		or not SeasonOwnership._whole(value.version, 1, 1)
		or not SeasonOwnership._whole(value.own_index, 0, 1)
		or not value.rosters is Array
		or value.rosters.size() != 2
		or not value.rosters[0] is Array
		or not value.rosters[1] is Array
		or value.rosters[0].size() != 4
		or value.rosters[1].size() != 4
		or not _teams(value.rosters)
		or not value.releases is Array
		or value.releases.size() > 99999
		or not value.calls is Array
		or value.calls.size() > 4
		or not value.roles is Array
		or not value.field_state is Dictionary
		or not SeasonOwnership._keys(
			value.field_state, ["pa", "boundary", "grant", "uses", "fielding"]
		)
		or not value.field_state.uses is Array
		or not value.field_state.grant is Dictionary
		or not value.pitching is Dictionary
		or not value.pitching.get("releases") is Array
		or not value.pitching.get("calls") is Array
		or not PhysicalBaseFlow.valid(value.base, value.rosters, performance)
	):
		return false
	var ids: Array = []
	var definitions: Dictionary = {}
	for player: PlayerMatchState in own.roster:
		if player == null or player.definition == null:
			return false
		ids.append(String(player.definition.id))
		definitions[String(player.definition.id)] = player.definition
	if (
		not ClubCareer.same(ids, value.rosters[int(value.own_index)])
		or not SeasonOwnership._whole(
			value.field_state.pa, int(value.base.final.pa), int(value.base.final.pa)
		)
		or not SeasonOwnership._whole(
			value.field_state.boundary, int(value.field_state.pa) - 1, int(value.field_state.pa)
		)
	):
		return false
	var counts: Dictionary = {}
	var last: Dictionary = {}
	var previous: int = 0
	for row: Variant in value.releases:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["pa", "half", "player", "recipe"]) \
			or not SeasonOwnership._whole(row.pa, maxi(1, previous), value.base.results.size()) \
			or not SeasonOwnership._whole(row.half, 0, 9999) or not row.player is String \
			or not row.recipe is String or PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) == null:
			return false
		var result: Dictionary = value.base.results[int(row.pa) - 1]
		if row.half != result.half or not value.rosters[1 - int(result.half) % 2].has(row.player) \
			or (definitions.has(row.player) and not definitions[row.player].starting_pitches.any(
				func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe)):
			return false
		previous = int(row.pa)
		counts[row.player] = counts.get(row.player, 0) + 1
		last[int(row.pa)] = row.player
	for row: Dictionary in value.base.results:
		if last.get(int(row.pa)) != row.pitcher:
			return false
	for id: String in performance:
		if int(performance[id].pitches) != counts.get(id, 0):
			return false
	if not ClubCareer.same(value.pitching.releases, value.releases.filter(func(row: Dictionary) -> \
		bool: return ids.has(row.player))) \
		or not ClubCareer.same(value.pitching.calls, value.calls.filter(func(row: Variant) -> bool: \
			return row is Dictionary and ids.has(row.get("player")))):
		return false
	var seen: Array = []
	var call_counts: Array[int] = [0, 0]
	previous = 0
	for row: Variant in value.calls:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(row, ["pa", "half", "player", "recipe", "time"])
			or not SeasonOwnership._whole(row.pa, maxi(1, previous), value.base.ready.size())
			or seen.has(int(row.pa))
			or not SeasonOwnership._whole(row.half, 0, 9999)
			or not row.player is String
			or not row.recipe is String
			or PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) == null
			or not (row.time is int or row.time is float)
			or not is_finite(float(row.time))
			or float(row.time) < 0.0
		):
			return false
		var ready: Dictionary = value.base.ready[int(row.pa) - 1]
		var side: int = 1 - int(ready.half) % 2
		if row.half != ready.half or not value.rosters[side].has(row.player):
			return false
		call_counts[side] += 1
		if call_counts[side] > 2:
			return false
		for release: Dictionary in value.releases:
			if (
				release.pa == row.pa
				and (release.player != row.player or release.recipe != row.recipe)
			):
				return false
		seen.append(int(row.pa))
		previous = int(row.pa)
	if not _final_roles(value, own):
		return false
	var field_view: Dictionary = {
		"completed": value.base.results.size(), "base": value.base, "field_state": value.field_state
	}
	return _fielding(field_view, ids, int(value.own_index))


static func _final_roles(value: Dictionary, own: TeamMatchState) -> bool:
	var uses: Array = value.field_state.uses
	if value.roles.size() != uses.size() or uses.size() > 100:
		return false
	var seen: Array = []
	for index in range(uses.size()):
		var action: Variant = uses[index]
		var role: Variant = value.roles[index]
		if not action is Dictionary or not action.get("receipt") is String or seen.has(action.receipt) \
			or not action.get("player") is String or not SeasonOwnership._whole(action.get("pa"), 1, \
				value.base.ready.size()) \
			or not role is Dictionary or not SeasonOwnership._keys(role, ["receipt", "snapshot", \
				"release_count"]) \
			or role.receipt != action.receipt or not role.snapshot is Dictionary \
			or not SeasonOwnership._whole(role.release_count, 0, value.releases.size()):
			return false
		var ready: Dictionary = value.base.ready[int(action.pa) - 1]
		var normalized: Dictionary = role.snapshot.duplicate(true)
		if not normalized.get("pitcher") is String or not value.rosters[1 - int(ready.half) % \
			2].has(normalized.pitcher):
			return false
		var actor: String = normalized.pitcher
		normalized.pitcher = ready.pitcher
		var matches_position: bool = ClubCareer.same(normalized, ready)
		for advance: Dictionary in value.base.advances:
			if int(advance.after.pa) == int(action.pa):
				var after: Dictionary = advance.after.duplicate(true)
				after.pitcher = ready.pitcher
				matches_position = matches_position or ClubCareer.same(normalized, after)
		if not matches_position or int(role.release_count) != value.releases.filter(func(row: \
			Dictionary) -> bool: return row.pa < action.pa).size():
			return false
		var copies: Array = own.tactics.held.filter(func(copy: Dictionary) -> bool: return copy.id == \
			action.receipt)
		var item: String = str(copies[0].item) if copies.size() == 1 else ""
		if item.is_empty() and action.receipt == own.field_supply.receipt:
			item = "A10"
		if item.is_empty():
			return false
		var defensive: bool = item in ["C02", SeasonTacticalCatalog.HEAT]
		if int(ready.half) % 2 != (1 - int(value.own_index) if defensive else int(value.own_index)) \
			or action.player != (actor if defensive else ready.player):
			return false
		seen.append(action.receipt)
	return true
