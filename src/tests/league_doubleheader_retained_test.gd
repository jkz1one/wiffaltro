extends Node
## Reuse completed actual pair artifacts. No new physical game or synthetic result.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _read(name: String) -> Dictionary:
	var file: FileAccess = FileAccess.open("user://" + name, FileAccess.READ)
	return {} if file == null else JSON.parse_string(file.get_as_text())


func _ready() -> void:
	var data: Dictionary = _read("completed-pair-1.json")
	var pending: Dictionary = _read("pending-pair-1.json")
	check(not data.is_empty() and not pending.is_empty(), "actual pair artifacts exist")
	if data.is_empty() or pending.is_empty():
		get_tree().quit(1)
		return
	var season: SeasonState = SeasonSave._decode(data)
	check(
		season != null and season.results.size() == 6 and season.round_index == 2,
		"actual completed pair cold"
	)
	if season == null:
		get_tree().quit(1)
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var bad: Dictionary = data.duplicate(true)
	bad.version = 76
	check(SeasonSave._decode(bad) == null, "no old envelope downgrade")
	bad = data.duplicate(true)
	var id: String = bad.checkpoint.results[0].doubleheader_evidence[0].proof.remaining.keys()[0]
	bad.checkpoint.results[0].doubleheader_evidence[0].proof.remaining[id] += 1.0
	check(SeasonSave._decode(bad) == null, "tampered human first remaining rejected")
	bad = data.duplicate(true)
	bad.checkpoint.results[1].doubleheader_evidence[0].pair.debt.clear()
	check(SeasonSave._decode(bad) == null, "cleared paired debt rejected")
	bad = data.duplicate(true)
	bad.checkpoint.results[1].doubleheader_evidence[0].pair.first = -1
	check(SeasonSave._decode(bad) == null, "forged fresh paired fixture rejected")
	bad = data.duplicate(true)
	for event: Dictionary in bad.checkpoint.build.events:
		if event.op == "reward":
			event.doubleheader_workload.pair.game = 31
			break
	check(SeasonSave._decode(bad) == null, "human reward proof fixture mismatch rejected")
	bad = data.duplicate(true)
	bad.checkpoint.physical.reports[0].report.workload[0].events[0].paid += 1.0
	check(SeasonSave._decode(bad) == null, "offscreen cost mutation rejected")
	bad = data.duplicate(true)
	bad.checkpoint.physical.reports[0].report.erase("workload")
	check(SeasonSave._decode(bad) == null, "stripped workload report rejected")
	bad = pending.duplicate(true)
	bad.checkpoint.physical.pending.human[13][0].pair.debt.clear()
	check(SeasonSave._decode(bad) == null, "cold pending cannot erase carry")
	bad = pending.duplicate(true)
	bad.checkpoint.physical.pending.human[13].pop_back()
	check(SeasonSave._decode(bad) == null, "cold pending must include both workloads")
	bad = pending.duplicate(true)
	bad.checkpoint.physical.pending.human[12].base.erase("final")
	check(SeasonSave._decode(bad) == null, "incomplete game proof cannot pay")
	check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"negative projections leave owner unchanged"
	)
	var original: Dictionary = season.results[0].doubleheader_evidence[0].duplicate(true)
	season.results[0].doubleheader_evidence[0].proof.remaining[id] += 1.0
	# Explicitly reconstruct the second leg, not the fresh next pair.
	var paired: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		if fixture.id == 3:
			paired = fixture
	check(
		SeasonPhysicalFixtures.match_for(season, paired) == null,
		"runtime changed first result cannot authorize carry"
	)
	season.results[0].doubleheader_evidence[0] = original.duplicate(true)
	check(
		ClubCareer.same(before, SeasonSave.snapshot(season)),
		"runtime probe restored exact original"
	)
	var spent: String = original.proof.events[0].player
	season.results[0].doubleheader_evidence[0].proof.remaining[spent] += 0.000000001
	var historical: Dictionary = SeasonDoubleheader._historical_team(season, 0, 0)
	check(
		(
			not historical.is_empty()
			and SeasonDoubleheader._matches_result(season.results[0], 0, historical)
		),
		"tiny balance change remains within documented chronology tolerance"
	)
	check(
		SeasonPhysicalFixtures.match_for(season, paired) == null,
		"exact paid-first envelope bind rejects otherwise tolerated alteration"
	)
	season.results[0].doubleheader_evidence[0] = original.duplicate(true)
	check(
		ClubCareer.same(before, SeasonSave.snapshot(season)), "tiny mutation restored exact owner"
	)
	check(
		ClubCareer.same(season.results[0].doubleheader_evidence[0], original),
		"runtime envelope restored without alias"
	)
	print("Doubleheader retained checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
