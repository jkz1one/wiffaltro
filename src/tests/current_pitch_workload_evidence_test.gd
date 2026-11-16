extends "res://src/tests/doubleheader_workload_proof_test.gd"
## Native numerical replay gate, not executed by source-only validation.


func _ready() -> void:
	roster = SeasonPlayerCatalog.ids().slice(0, 4)
	bank = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(bank.enable_league_rules(LeagueRules.capture("doubleheader")), "Doubleheader context")
	wallet = bank.view()
	var catalog: String = WorkingPitchCatalog.signature()
	var empty: Dictionary = _empty_case({"game": 0, "first": -1, "debt": {}})
	check(_current(empty, catalog), "empty valid context")
	check(not _current(empty, "wrong"), "empty proof wrong context fails closed")
	for id: String in WorkingPitchCatalog.new_ids():
		var row: Dictionary = empty.duplicate(true)
		var pitch: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
		var paid: float = MatchLabSupport.stamina_cost(pitch, 1.0)
		var event: Dictionary = {"kind": "release", "pa": 1, "half": 0,
			"player": roster[0], "recipe": id, "paid": paid, "before": 100.0,
			"after": 100.0 - paid, "effort": 1.0, "overdrive": 0.0,
			"base_cost": pitch.stamina_cost, "gear_scale": 1.0, "sponsor_scale": 1.0}
		row.proof.events.append(event)
		row.proof.remaining[roster[0]] = 100.0 - paid
		row.performance[roster[0]] = {"pa": 1, "pitches": 1, "p_k": 0}
		row.pitching.releases.append(_release_row(event))
		check(_current(row, catalog), "new workload " + id)
		check(not _valid(row), "new workload not historical " + id)
		check(not _current(row, "wrong"), "wrong workload catalog " + id)
		check(_current(JSON.parse_string(JSON.stringify(row, "", true, true)), catalog),
			"workload JSON " + id)
		row.proof.events[0].paid += 0.5
		check(not _current(row, catalog), "workload paid tamper " + id)
	print("Current workload checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _current(row: Dictionary, catalog: String) -> bool:
	return PhysicalWorkloadEvidence.valid(row.proof, roster, row.performance, row.pitching,
		row.tactics, wallet, row.pair, 99999, catalog)
