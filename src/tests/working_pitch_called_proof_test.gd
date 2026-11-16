extends Node
## Synthetic domain fixtures, not earned gameplay, owner progress or unlocks.
const ROSTER: Array[String] = ["player.alex_finch", "player.ari_banks", "player.ash_cole", "player.rowan_chase"]
var failures: int = 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var build: SeasonBuild = SeasonBuild.new(614, ROSTER)
	check(build.enable_pitch_catalog(), "catalog3 admission")
	var pitching: Dictionary = {"releases": [], "calls": [], "strikeouts": []}
	var proof: Dictionary = {"version": 2, "pitching": pitching.duplicate(true), "called_strikeouts": []}
	var stats: Dictionary = {}
	for id: String in ROSTER:
		stats[id] = MatchPerformance.empty_line()
	var reward: Dictionary = {"id": "fixture:reward", "rev": 0, "op": "reward", "game": 0,
		"win": true, "performance": stats, "pitching": pitching, "pitching_current": proof}
	var historical: SeasonBuild = SeasonBuild.new(614, ROSTER)
	check(not historical.commit(reward).ok and historical.cash() == 0,
		"historical reward rejects current sidecar atomically")
	var malformed: Dictionary = reward.duplicate(true)
	malformed.pitching_current.called_strikeouts.append({"pa": 1, "half": 0, "player": ROSTER[0]})
	check(not build.commit(malformed).ok and build.cash() == 0, "invented K fails without payment")
	check(build.commit(reward).ok, "synthetic current reward retained")
	var cash: int = build.cash()
	check(build.commit(reward).replayed and build.cash() == cash, "same retry never pays twice")
	var restored: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(build.to_data())), 614, ROSTER)
	check(restored != null, "current reward actual JSON cold replay")
	if restored != null:
		check(WorkingPitchCalledProof.same_retained(restored._events[0], reward), "cold sidecar exact")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(build.to_data()))
	wire.events[0].pitching_current.called_strikeouts.append({"pa": 1, "half": 0, "player": ROSTER[0]})
	check(SeasonBuild.from_data(wire, 614, ROSTER) == null, "tampered cold reward rejects")
	var stripped: Dictionary = reward.duplicate(true)
	stripped.erase("pitching_current")
	check(not WorkingPitchCalledProof.same_retained(reward, stripped), "stripped result rejects")
	check(not WorkingPitchCalledProof.same_retained(stripped, reward), "stripped reward rejects")
	check(not WorkingPitchCalledProof.same_retained(reward, malformed), "mismatched sidecar rejects")
	check(WorkingPitchCalledProof.same_retained(stripped, stripped), "historical absence stays unknown")
	var human: Array = [0, 0, 1, stats, [], [], {}, [], [], pitching, {}, []]
	check(WorkingPitchCalledProof.install_human(build, human, proof) and human[9] == proof
		and human[10] == {} and human[8] == [], "stable human packet pitching slot9 only")
	check(not WorkingPitchCalledProof.install_human(historical, human, proof), "old human packet rejects")
	var state: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "Fixture home", "Fixture away")
	var team: TeamMatchState = state.defensive_team()
	check(state.sure_shot.evidence_current(team).is_empty(), "no inferred historical proof")
	check(state.sure_shot.enable_current_evidence(), "prospective enablement")
	state.strikes = 2
	state.record_strike(false)
	check(state.sure_shot.evidence_current(team).called_strikeouts.size() == 1, "called K captured")
	state.strikes = 2
	state.record_strike(true)
	check(state.sure_shot.evidence_current(team).called_strikeouts.size() == 1, "swinging K not called")
	_result_fixture()
	print("Working prospective proof fixture failures: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _result_fixture() -> void:
	# Domain-only fixture: ordinary public result API and real atomic reward path.
	# No physical-match/accepted-game assertion is made by this synthetic score.
	var season: SeasonState = SeasonState.create(615, false, true, false)
	check(season.build.enable_pitch_catalog(), "result fixture catalog admission")
	for _pick in range(4):
		check(season.choose_player(season.offers()[0]), "result fixture draft")
	var fixture: Dictionary = season.pending_fixture()
	var stats: Dictionary = {}
	for team_index: int in [fixture.away, fixture.home]:
		for id: String in season.teams[team_index].roster:
			stats[id] = MatchPerformance.empty_line()
	var pitching: Dictionary = {"releases": [], "calls": [], "strikeouts": []}
	var proof: Dictionary = {"version": 2, "pitching": pitching, "called_strikeouts": []}
	check(season.record_player_result(fixture.id, 0, 1, stats, [], [], {}, [], [], proof),
		"human version2 packet reaches completed result and atomic reward")
	if season.player_results.is_empty():
		return
	var reward: Dictionary = season.build._events[0]
	check(WorkingPitchCalledProof.same_retained(reward, season.player_results[0]),
		"completed result retains exact atomic reward proof")
	var restored: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(season.build.to_data())),
		season.season_seed, season.build._initial_roster, season.draft_pool, season.recruit_blocked())
	check(restored != null, "completed-result build cold replay")
	if restored != null:
		check(SeasonSave.Operations3._build_history_valid(season, restored), "cold reward/result equality")
		season.player_results[0].erase("pitching_current")
		check(not SeasonSave.Operations3._build_history_valid(season, restored), "stripped cold result rejects")
