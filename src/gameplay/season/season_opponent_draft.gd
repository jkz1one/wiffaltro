class_name SeasonOpponentDraft
extends RefCounted
## Working Base allocation v1. Separate RNG leaves human offers and schedule draws untouched.


static func allocate(seed_value: int, available: Array[String]) -> Dictionary:
	var remaining: Array[String] = available.duplicate()
	remaining.sort()
	var arms: int = 0
	for index in range(remaining.size()):
		var profile: Dictionary = SeasonPlayerCatalog.profile(remaining[index])
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
				if round_index >= 2 or SeasonPlayerCatalog.profile(id).stats.pitching >= 2:
					eligible.append(id)
			var selected: String = eligible[rng.randi_range(0, eligible.size() - 1)]
			rosters[team].append(selected)
			remaining.erase(selected)
	return {"order": order, "rosters": rosters}
