class_name SeasonOpponentDraft
extends RefCounted
## Working Base allocation v1 and additive Standard d2 fitting draft v1.
## Separate RNGs leave human offers and schedule draws untouched.

const D2_RULE: String = "standard-d2-fit-draft-v1"
const D2_ROUND_STATS: Array[String] = ["pitching", "fielding", "power", "contact"]


static func allocate(
	seed_value: int, available: Array[String], rules: Dictionary = {}
) -> Dictionary:
	if (
		not rules.is_empty()
		and (not LeagueRules.scramble(rules) or not LeagueRules.season_matches(rules, seed_value))
	):
		return {}
	var remaining: Array[String] = available.duplicate()
	remaining.sort()
	var arms: int = 0
	for index in range(remaining.size()):
		var profile: Dictionary = (
			SeasonScramble.profile(remaining[index], rules)
			if not rules.is_empty()
			else SeasonPlayerCatalog.profile(remaining[index])
		)
		if profile.is_empty() or (index > 0 and remaining[index] == remaining[index - 1]):
			return {}
		arms += int(profile.stats.pitching >= 2)
	# The first ten selections all require an arm. Later rounds have no role restriction.
	# Reject infeasible content before mutating a roster or consuming a human draft pick.
	if remaining.size() < 20 or arms < 10:
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (seed_value + 15485863) & 0x7fffffff
	var order: Array[int] = [1, 2, 3, 4, 5]
	for index in range(order.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[other]
		order[other] = held
	var rosters: Dictionary = {1: [], 2: [], 3: [], 4: [], 5: []}
	for round_index in range(4):
		var sequence: Array[int] = order.duplicate()
		if round_index % 2 == 1:
			sequence.reverse()
		for team: int in sequence:
			var eligible: Array[String] = []
			for id: String in remaining:
				if (
					round_index >= 2
					or (
						(
							(
								SeasonScramble.profile(id, rules)
								if not rules.is_empty()
								else SeasonPlayerCatalog.profile(id)
							)
							. stats
							. pitching
						)
						>= 2
					)
				):
					eligible.append(id)
			var selected: String = eligible[rng.randi_range(0, eligible.size() - 1)]
			rosters[team].append(selected)
			remaining.erase(selected)
	return {"order": order, "rosters": rosters}


static func allocate_d2(
	seed_value: int, available: Array[String], rules: Dictionary = {}
) -> Dictionary:
	if (
		not rules.is_empty()
		and (not LeagueRules.scramble(rules) or not LeagueRules.season_matches(rules, seed_value))
	):
		return {}
	var remaining: Array[String] = available.duplicate()
	remaining.sort()
	# Capture each starting profile once. Empty rules preserve the authored d2 path;
	# Scramble uses its frozen season permutation for both eligibility and role fit.
	var profiles: Dictionary = {}
	var arms: int = 0
	for index in range(remaining.size()):
		var profile: Dictionary = (
			SeasonScramble.profile(remaining[index], rules)
			if not rules.is_empty()
			else SeasonPlayerCatalog.profile(remaining[index])
		)
		if profile.is_empty() or (index > 0 and remaining[index] == remaining[index - 1]):
			return {}
		profiles[remaining[index]] = profile
		arms += int(profile.stats.pitching >= 2)
	if remaining.size() < 20 or arms < 10:
		return {}
	# Preserve the legacy club order exactly; candidate sampling has its own stream.
	var order_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	order_rng.seed = (seed_value + 15485863) & 0x7fffffff
	var order: Array[int] = [1, 2, 3, 4, 5]
	for index in range(order.size() - 1, 0, -1):
		var other: int = order_rng.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[other]
		order[other] = held
	var candidate_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	candidate_rng.seed = (seed_value + 32452843) & 0x7fffffff
	var rosters: Dictionary = {1: [], 2: [], 3: [], 4: [], 5: []}
	for round_index in range(4):
		var sequence: Array[int] = order.duplicate()
		if round_index % 2 == 1:
			sequence.reverse()
		for team: int in sequence:
			var eligible: Array[String] = []
			for id: String in remaining:
				if round_index >= 2 or profiles[id].stats.pitching >= 2:
					eligible.append(id)
			# A sole eligible card consumes no candidate draw and keeps minimum pools legal.
			var selected: String = eligible[0]
			if eligible.size() > 1:
				var first: int = candidate_rng.randi_range(0, eligible.size() - 1)
				selected = eligible[first]
				eligible.remove_at(first)
				var challenger: String = eligible[candidate_rng.randi_range(0, eligible.size() - 1)]
				var stat: String = D2_ROUND_STATS[round_index]
				var selected_stat: int = profiles[selected].stats[stat]
				var challenger_stat: int = profiles[challenger].stats[stat]
				if (
					challenger_stat > selected_stat
					or (challenger_stat == selected_stat and challenger < selected)
				):
					selected = challenger
			rosters[team].append(selected)
			# The losing candidate stays available for every later turn.
			remaining.erase(selected)
	return {"order": order, "rosters": rosters}
