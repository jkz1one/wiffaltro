extends Node
## Pure allocator coverage only. No season, save, title, or physical game is created.
## The captured Scramble context supplies stats; tier admission belongs to its caller.

const SEEDS: Array[int] = [0, 7, 42, 2147483647]
var checks: int = 0
var failures: int = 0


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	var catalog_before: String = SeasonPlayerCatalog.signature()
	_standard_unchanged()
	_scramble_allocations()
	_boundaries()
	_check(SeasonPlayerCatalog.signature() == catalog_before, "authored catalog stays unchanged")
	print("Scramble d2 allocator checks: %d, failures: %d, physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _standard_unchanged() -> void:
	for seed_value: int in [0, 42, -42, 2147483647]:
		var pool: Array[String] = SeasonPlayerCatalog.ids().slice(4)
		var expected: Dictionary = _reference(seed_value, pool, {})
		var actual: Dictionary = SeasonOpponentDraft.allocate_d2(seed_value, pool)
		_check(actual == expected.allocation, "legacy authored d2 trace remains exact")
		_check(actual == SeasonOpponentDraft.allocate_d2(seed_value, pool, {}),
			"omitted and empty rules are identical")


func _scramble_allocations() -> void:
	var differing: int = 0
	for seed_value: int in SEEDS:
		var rules: Dictionary = LeagueRules.capture("scramble", 0, seed_value)
		var rules_before: Dictionary = rules.duplicate(true)
		var pool: Array[String] = SeasonPlayerCatalog.ids().slice(4)
		var before: Array[String] = pool.duplicate()
		var actual: Dictionary = SeasonOpponentDraft.allocate_d2(seed_value, pool, rules)
		_check(not actual.is_empty(), "Scramble pool is feasible")
		if actual.is_empty():
			continue
		var expected: Dictionary = _reference(seed_value, pool, rules)
		_check(actual == expected.allocation, "Scramble role-fit matches independent trace")
		_check(expected.ties > 0, "Scramble trace exercises stable-ID ties")
		_check(pool == before and rules == rules_before, "inputs remain unchanged")
		_check(actual.order == SeasonOpponentDraft.allocate(seed_value, pool, rules).order,
			"Base and d2 keep the same independent club-order stream")
		var selected: Array[String] = []
		for team: int in range(1, 6):
			_check(actual.rosters[team].size() == 4, "four players per opponent")
			for index: int in range(4):
				var id: String = actual.rosters[team][index]
				_check(pool.has(id) and not selected.has(id), "available unique identity")
				selected.append(id)
				if index < 2:
					_check(_stats(id, rules).pitching >= 2, "first two picks are scrambled arms")
		pool.reverse()
		_check(actual == SeasonOpponentDraft.allocate_d2(seed_value, pool, rules),
			"input order and repeated selection cannot reroll allocation")
		var transported: Dictionary = JSON.parse_string(JSON.stringify(rules))
		_check(actual == SeasonOpponentDraft.allocate_d2(seed_value, pool, transported),
			"transported captured rules replay the same allocation")
		differing += int(actual != SeasonOpponentDraft.allocate_d2(seed_value, pool))
	_check(differing > 0, "Scramble selection is not the authored-stat allocator")


func _boundaries() -> void:
	var rules: Dictionary = LeagueRules.capture("scramble", 0, 7)
	var arms: Array[String] = []
	var others: Array[String] = []
	for id: String in SeasonPlayerCatalog.ids():
		if _stats(id, rules).pitching >= 2:
			arms.append(id)
		else:
			others.append(id)
	_check(arms.size() >= 10 and others.size() >= 11, "authored seed7 supports boundary fixtures")
	if arms.size() < 10 or others.size() < 11:
		return
	var minimum: Array[String] = arms.slice(0, 10)
	minimum.append_array(others.slice(0, 10))
	var expected: Dictionary = _reference(7, minimum, rules)
	_check(SeasonOpponentDraft.allocate_d2(7, minimum, rules) == expected.allocation,
		"exactly20 cards and10 scrambled arms complete")
	_check(expected.sole > 0, "minimum pool exercises sole-candidate no-draw path")
	var insufficient: Array[String] = arms.slice(0, 9)
	insufficient.append_array(others.slice(0, 11))
	_check(not SeasonOpponentDraft.allocate_d2(7, insufficient).is_empty(),
		"nine-scrambled-arm fixture is feasible under authored stats")
	_refused(insufficient, rules, 7, "nine scrambled arms refused")
	_refused(minimum.slice(0, 19), rules, 7, "nineteen cards refused")
	_refused(minimum, rules, 8, "wrong root season seed refused")
	_refused(minimum, LeagueRules.capture("dugout"), 7, "other League context refused")
	var malformed: Dictionary = rules.duplicate(true)
	malformed.profile += "-changed"
	_refused(minimum, malformed, 7, "changed profile refused")
	var duplicate: Array[String] = minimum.duplicate()
	duplicate[1] = duplicate[0]
	_refused(duplicate, rules, 7, "duplicate identity refused")
	var unknown: Array[String] = minimum.duplicate()
	unknown[1] = "player.missing"
	_refused(unknown, rules, 7, "unknown identity refused")


func _refused(pool: Array[String], rules: Dictionary, seed_value: int, message: String) -> void:
	var before: Array[String] = pool.duplicate()
	var rules_before: Dictionary = rules.duplicate(true)
	_check(SeasonOpponentDraft.allocate_d2(seed_value, pool, rules).is_empty(), message)
	_check(pool == before and rules == rules_before, "refusal does not mutate inputs")


func _stats(id: String, rules: Dictionary) -> Dictionary:
	return (
		SeasonPlayerCatalog.profile(id).stats
		if rules.is_empty()
		else SeasonScramble.profile(id, rules).stats
	)


func _reference(seed_value: int, pool: Array[String], rules: Dictionary) -> Dictionary:
	# Independent turn-index trace. Draw the second candidate by skipping the first
	# index, rather than removing it as production does. No production allocator call.
	var remaining: Array[String] = pool.duplicate()
	remaining.sort()
	var order: Array[int] = [1, 2, 3, 4, 5]
	var order_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	order_rng.seed = (seed_value + 15485863) & 0x7fffffff
	for index: int in range(4, 0, -1):
		var second: int = order_rng.randi_range(0, index)
		var saved: int = order[second]
		order[second] = order[index]
		order[index] = saved
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (seed_value + 32452843) & 0x7fffffff
	var rosters: Dictionary = {1: [], 2: [], 3: [], 4: [], 5: []}
	var ties: int = 0
	var sole: int = 0
	for turn: int in range(20):
		var round_number: int = floori(float(turn) / 5.0)
		var team: int = order[turn % 5 if round_number % 2 == 0 else 4 - turn % 5]
		var eligible: Array[String] = []
		for id: String in remaining:
			if round_number >= 2 or _stats(id, rules).pitching >= 2:
				eligible.append(id)
		var selected: String = eligible[0]
		if eligible.size() == 1:
			sole += 1
		else:
			var first: int = rng.randi_range(0, eligible.size() - 1)
			var second: int = rng.randi_range(0, eligible.size() - 2)
			if second >= first:
				second += 1
			var stat: String = ["pitching", "fielding", "power", "contact"][round_number]
			var a: String = eligible[first]
			var b: String = eligible[second]
			var a_stat: int = _stats(a, rules)[stat]
			var b_stat: int = _stats(b, rules)[stat]
			if a_stat == b_stat:
				ties += 1
				var sorted: Array[String] = [a, b]
				sorted.sort()
				selected = sorted[0]
			else:
				selected = a if a_stat > b_stat else b
		rosters[team].append(selected)
		remaining.erase(selected)
	return {"allocation": {"order": order, "rosters": rosters}, "ties": ties, "sole": sole}
