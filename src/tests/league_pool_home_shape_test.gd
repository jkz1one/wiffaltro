extends Node
## Unmodified retained Pool evidence exercises only composed structure/comparison.
## Workload/inventory additions are shape-only controls, never accepted games or rewards.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/tests/fixtures/ay02_public_pool60_accepted.json"))
	var result: Dictionary = {}
	for row: Dictionary in source.results:
		if row.has("pool_evidence"): result = row.duplicate(true)
	if not check(not result.is_empty() and StadiumPoolOwnedHumanEvidence.valid(result.pool_evidence), "unchanged retained Pool evidence remains valid"):
		get_tree().quit(1)
		return
	var first: Array = [int(result.id), int(result.away_runs), int(result.home_runs)]
	for key: String in ["performance", "used_gear", "tactics", "batting", "stances", "fielding", "pitching", "field_supply", "frozen"]:
		first.append(result.get(key, [] if key in ["used_gear", "tactics", "stances", "fielding", "frozen"] else {}))
	first.append(result.ai_tactics[str(int(result.away))])
	for doubleheader: bool in [false, true]:
		for inventory: bool in [false, true]:
			var human: Array = first.duplicate(true)
			var settled: Dictionary = result.duplicate(true)
			if doubleheader:
				human.append([{}, {}])
				settled.doubleheader_evidence = human[-1].duplicate(true)
			if inventory:
				human.append({"shape_only": true})
				settled.inventory_final = human[-1].duplicate(true)
			human.append_array([[], result.property, result.pool_evidence.duplicate(true)])
			check(LeagueHomeResult.shape(human, [], doubleheader, true), "exact composed Pool tail")
			check(not LeagueHomeResult.shape(human, [], doubleheader, false), "Pool cannot masquerade as ordinary field tail")
			check(not LeagueHomeResult.shape(human, [], not doubleheader, true), "wrong League workload grammar")
			check(Live._human_matches(human, settled), "exact retained evidence continuation comparison")
			for index in range(human.size()):
				var bad: Array = human.duplicate(true)
				bad[index] = null
				check(not LeagueHomeResult.shape(bad, [], doubleheader, true), "null argument " + str(index))
			var altered: Dictionary = settled.duplicate(true)
			altered.pool_evidence.request = "0".repeat(64)
			check(not Live._human_matches(human, altered), "changed valid-shape Pool evidence cannot replace accepted operands")
			altered = settled.duplicate(true)
			altered.erase("pool_evidence")
			check(not Live._human_matches(human, altered), "Pool evidence cannot disappear")
			for key: String in ["night_evidence", "yard_evidence"]:
				altered = settled.duplicate(true)
				altered[key] = {}
				check(not Live._human_matches(human, altered), "no mixed " + key)
			var bad: Array = human.duplicate(true)
			bad[-3] = [{}]
			check(not LeagueHomeResult.shape(bad, [], doubleheader, true), "reserved historical argument remains empty")
			bad = human.duplicate(true)
			bad[-1].pool.copy = "foreign"
			check(not LeagueHomeResult.shape(bad, [], doubleheader, true), "original Pool evidence validator retained")
			if doubleheader or inventory:
				check(not SeasonRoundSettlement._shape({"human": human, "reports": []}, true, true, true), "ordinary Pool positions remain unchanged")
	check(not LeagueHomeResult.pending_valid(null, []), "no context grants pending authority")
	check(not LeagueHomeResult.record(null, []), "no context grants game authority")
	print("LEAGUE_POOL_HOME_SHAPE checks=", checks, " failures=", failures, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
