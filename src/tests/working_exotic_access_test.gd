extends Node
## Synthetic finite domain fixtures only, never earned human gameplay or owner saves.
const ROSTER: Array[String] = ["player.alex_finch", "player.ari_banks", "player.ash_cole", "player.rowan_chase"]
var failures: int = 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	check(not WorkingExoticAccess.matches(null, null), "null authority rejects")
	check(not WorkingExoticAccess.current_matches(null), "null season rejects")
	check(not WorkingExoticAccess.current_matches(SeasonState.new()), "missing build rejects")
	check(WorkingExoticAccess.finalized_candidate(null, [], {}) == null, "null candidate rejects")
	var selected: SeasonBuild = null
	var offer: String = ""
	for seed_value in range(128):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		check(build.enable_pitch_catalog(), "fresh catalog5")
		check(not build._book.lesson_supported("pitch.switchback"), "fresh club has no free access")
		var reward: Dictionary = fixture_reward()
		var staged: SeasonBuild = build.candidate(reward)
		check(staged != null, "synthetic validated reward candidate")
		if staged == null:
			break
		var result: Dictionary = fixture_result(reward)
		var tampered: Dictionary = result.duplicate(true)
		tampered.pitching_current.called_strikeouts = []
		var before: Dictionary = build.to_data()
		check(WorkingExoticAccess.finalized_candidate(staged, [], tampered) == null,
			"mismatched proposed result fails admission")
		check(ClubCareer.same(before, build.to_data()) and build.cash() == 0,
			"failed reward/admission leaves original journal and wallet unchanged")
		var admitted: SeasonBuild = WorkingExoticAccess.finalized_candidate(staged, [], result)
		check(admitted != null, "exact result/reward enables admission")
		if admitted == null:
			break
		check(admitted.cash() == 18 and admitted._book.lesson_supported("pitch.switchback")
			and not admitted._book.lesson_supported("pitch.sidearm_switchback"),
			"one unique earned design, no retired duplicate, ordinary cash only")
		check(not admitted._book.lesson_supported("pitch.trapdoor"), "one called K cannot grant Trapdoor")
		var retained: Array = [admitted._book._exotic_current.duplicate(true)]
		var later: SeasonBuild = SeasonBuild.new(seed_value + 1000, ROSTER)
		check(later.enable_pitch_catalog() and later._book.install_exotic_start(retained), "synthetic prior-run admission")
		check(later._book.lesson_supported("pitch.switchback") and later.cash() == 0
			and not later.player(ROSTER[0]).active.has("pitch.switchback"), "permanent access grants neither recipe nor cash")
		var later_cold: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(later.to_data())), seed_value + 1000, ROSTER)
		check(later_cold != null and later_cold._book.lesson_supported("pitch.switchback"), "prior proof cold retention")
		var prior: Dictionary = admitted._book._exotic_current.duplicate(true)
		var changed: Dictionary = prior.duplicate(true)
		changed.games[0].strikeouts[0].called = false
		check(not WorkingExoticAccess.proof_prefix(prior, changed), "committed called-K prefix immutable")

		check(admitted.commit(reward).replayed and admitted.cash() == 18, "reward retry never repays")
		var last: Dictionary = admitted._events[-1]
		check(admitted.commit(last).replayed, "admission retry idempotent")
		var cold: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(admitted.to_data())), seed_value, ROSTER)
		check(cold != null and cold._book.lesson_supported("pitch.switchback"), "cold admission rederives access")
		var wire: Dictionary = admitted.to_data()
		wire.events[-1].proof.games[0].strikeouts[0].finish = "pitch.drop"
		check(SeasonBuild.from_data(wire, seed_value, ROSTER) == null, "forged admission rejects")
		wire = admitted.to_data()
		wire.version = 47
		check(SeasonBuild.from_data(wire, seed_value, ROSTER) == null, "Build47 cannot accept successor")
		check(admitted.commit(cmd(admitted, "open")).ok, "ordinary postgame shop")
		for candidate: String in admitted._visit.offers.values():
			check(not WorkingPitchCatalog.RETIRED_ALIASES.has(candidate.trim_prefix("lesson.")),
				"retired Exotic variants never appear as new offers")
		for key: String in admitted._visit.offers:
			if admitted._visit.offers[key] == "lesson.pitch.switchback":
				selected = admitted
				offer = key
				break
		if selected != null:
			break
	check(selected != null, "bounded real generation contains earned paid lesson")
	if selected != null:
		var item: String = selected._visit.offers[offer]
		var target: Dictionary = selected.targets(item)[0]
		var buy: Dictionary = cmd(selected, "buy", {"offer": offer, "mode": "use",
			"player": target.player, "pitch": target.pitch, "replace": target.replace})
		check(selected.preview(buy).ok and selected.cash() == 18, "preview inert")
		check(selected.commit(buy).ok and selected.cash() == 0, "exact18 charged")
		check(selected.commit(buy).replayed and selected.cash() == 0, "paid retry no double charge")
		var restored: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(selected.to_data())), selected._seed, ROSTER)
		check(restored != null and restored.player(target.player).active.has(item.trim_prefix("lesson.")), "paid lesson cold replay")
		check(SeasonDevelopment.from_data(JSON.parse_string(JSON.stringify(selected._book.to_data())), selected._book._season_key) != null,
			"Development5 current evidence cold replay")
	print("Synthetic Exotic access fixture failures: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


static func cmd(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "%s:%d" % [op, build.revision()], "rev": build.revision(), "op": op}
	result.merge(fields)
	return result


static func fixture_reward() -> Dictionary:
	var stats: Dictionary = {}
	for id: String in ROSTER:
		stats[id] = MatchPerformance.empty_line()
	stats[ROSTER[0]].pitches = 3
	stats[ROSTER[0]].p_k = 1
	stats[ROSTER[0]].outs = 1
	stats[ROSTER[1]].pa = 1
	stats[ROSTER[1]].k = 1
	var releases: Array = []
	for recipe: String in ["pitch.overhand_sinker", "pitch.overhand_slider", "pitch.overhand_slider"]:
		releases.append({"pa": 1, "half": 0, "player": ROSTER[0], "recipe": recipe})
	var strikeouts: Array = [{"pa": 1, "half": 0, "player": ROSTER[0]}]
	var pitching: Dictionary = {"releases": releases, "calls": [], "strikeouts": strikeouts}
	return {"id": "fixture:reward", "rev": 0, "op": "reward", "game": 0, "win": true,
		"performance": stats, "pitching": pitching, "pitching_current": {"version": 2,
		"pitching": pitching.duplicate(true), "called_strikeouts": strikeouts.duplicate(true)}}


static func fixture_result(reward: Dictionary) -> Dictionary:
	return {"id": 0, "club_roster": ROSTER.duplicate(), "performance": reward.performance.duplicate(true),
		"pitching": reward.pitching.duplicate(true), "pitching_current": reward.pitching_current.duplicate(true)}
