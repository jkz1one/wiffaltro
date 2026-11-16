extends "res://src/tests/season_expanded_tactical_test.gd"
## Event-driven extra-inning boundary units, not full physical-game or balance evidence.


func _ready() -> void:
	for home: bool in [false, true]:
		_automatic_runner(home)
	_base_contract()
	_source_boundary()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro automatic-runner Base checks passed: canonical context and no fabricated RBI.")
	get_tree().quit(0 if _failures == 0 else 1)


func _strikeout(state: MatchState) -> void:
	state.base_flow.prepare(state)
	for strike in range(3):
		_check(state.begin_pitch(), "scripted boundary pitch starts legally")
		state.pitcher().spend_stamina(1.0)
		state.note_pitch_released()
		state.record_strike(false)
		state.continue_after_dead_ball()


func _automatic_runner(home: bool) -> void:
	var state: MatchState = _fixture()
	state.away_team.track_bases = true
	state.home_team.track_bases = true
	for appearance in range(30):
		_strikeout(state)
	_check(state.inning == 6 and state.top_half and state.bases.second == &"extra_runner.away.6",
		"ordinary tied regulation creates the canonical sixth-inning runner")
	if home:
		for appearance in range(3):
			_strikeout(state)
	var team: TeamMatchState = state.batting_team()
	var roster: Array = team.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id))
	state.base_flow.prepare(state)
	_check(state.begin_pitch(), "extra-inning tag unit begins real state transition")
	state.pitcher().spend_stamina(1.0)
	state.note_pitch_released()
	state.begin_ball_in_play()
	var position: Vector3 = Vector3(30.0, 0.0, 30.0)
	state.base_flow.tag(state, position, 2, 1.0, 1.0, String(state.fielder().definition.id))
	var tag: TagAdvanceResult = TagAdvanceResolver.resolve(state.bases, position, 2)
	_check(tag.advanced_from_second and tag.runs_scored == 0,
		"shared tag rules put the automatic runner alone on third")
	state.record_ball_in_play_out(tag.runs_scored, tag.description)
	state.continue_after_dead_ball()
	var before: Dictionary = state.performance.snapshot(state)
	var appearance: int = state.plate_appearance_number
	_supply(team, BASE)
	_check(team.tactics.activate(state, team, "copy"), "legal automatic runner scores through Base")
	var action: Dictionary = team.tactics.consumed[0]
	_check(state.plate_appearance_number == appearance
		and ClubCareer.same(before, state.performance.snapshot(state)),
		"supply run fabricates no completed PA, hit, walk or RBI")
	_check(action.advance.context.half == (11 if home else 10)
		and action.advance.from == 3 and action.advance.to == 4,
		"exact half, occupied bases and ghost identity are recorded")
	_check(TacticalBaseAdvance.valid(action.advance, roster, before),
		"valid automatic-runner evidence")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(action.advance))
	_check(TacticalBaseAdvance.valid(restored, roster, before),
		"canonical automatic-runner proof survives JSON")
	for field: String in ["side", "inning", "half", "bases", "blocked", "missing", "first", "outs"]:
		var changed: Dictionary = action.advance.duplicate(true)
		var stats: Dictionary = before.duplicate(true)
		match field:
			"side": changed.runner = "extra_runner.%s.6" % ("away" if home else "home")
			"inning": changed.runner = "extra_runner.%s.7" % ("home" if home else "away")
			"half": changed.context.half -= 2
			"bases": changed.context.bases[2] = ""
			"blocked": changed.context.bases[0] = roster[0]
			"missing": changed.erase("context")
			"first":
				changed.context.bases = [changed.runner, "", ""]
				changed.from = 1
				changed.to = 2
			"outs":
				for row: Dictionary in stats.values():
					row.outs = 0
		_check(not TacticalBaseAdvance.valid(changed, roster, stats),
			"altered automatic-runner " + field + " rejects")
	_check(not team.tactics.activate(state, team, "copy"), "consumed Base never scores twice")
	if home:
		_check(state.phase == MatchState.Phase.GAME_END and state.home_team.runs == 1,
			"extra-inning walk-off is immediate")
		_terminal_context(state, action, before)
	else:
		while state.phase != MatchState.Phase.GAME_END:
			_strikeout(state)
		_check(state.away_team.runs == 1 and state.home_team.runs == 0,
			"away automatic-runner score survives the completed extra inning")
	_settle_context(roster, action, state.performance.snapshot(state))
	var proof: Dictionary = state.base_flow.evidence(state)
	var teams: Array = []
	for side: TeamMatchState in [state.away_team, state.home_team]:
		teams.append(side.roster.map(func(player: PlayerMatchState) -> String:
			return String(player.definition.id)))
	var final: Dictionary = state.performance.snapshot(state)
	_check(PhysicalBaseFlow.valid(proof, teams, final), "whole occupancy chronology replays")
	_check(PhysicalBaseFlow.valid(JSON.parse_string(JSON.stringify(proof)), teams, final),
		"whole occupancy chronology survives JSON")
	for field: String in ["rbi", "score", "runner", "tag", "readiness", "final", "duplicate"]:
		var changed: Dictionary = proof.duplicate(true)
		match field:
			"rbi": changed.results[-1].rbi += 1
			"score": changed.advances[0].after.home += 1
			"runner": changed.advances[0].advance.runner = roster[0]
			"tag": changed.tags.clear()
			"readiness": changed.ready.pop_front()
			"final": changed.final.pa += 1
			"duplicate": changed.advances.append(changed.advances[0].duplicate(true))
		_check(not PhysicalBaseFlow.valid(changed, teams, final),
			"altered occupancy " + field + " rejects")
	_check(proof.advances.size() == 1 and proof.tags.size() == 1,
		"new tracker records actual transitions without adding events")
	_check(SeasonPerformance.valid(state.performance.snapshot(state), before.keys()),
		"completed performance remains internally balanced")


func _source_boundary() -> void:
	for key: String in ["ready", "results", "tags", "advances"]:
		var state: MatchState = _fixture()
		state.away_team.track_bases = true
		_check(PhysicalMatchRequest.capture(state) != null, "fresh tracked source captures")
		state.base_flow.get(key).append({"pa": 1})
		_check(PhysicalMatchRequest.capture(state) == null,
			"already-started occupancy " + key + " rejects")
	var state: MatchState = _fixture()
	for appearance in range(30):
		_strikeout(state)
	var team: TeamMatchState = state.batting_team()
	_supply(team, BASE)
	_check(team.tactics.activate(state, team, "copy"), "automatic runner may legally reach third")
	var action: Dictionary = team.tactics.consumed[0]
	var roster: Array = team.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id))
	_check(action.advance.from == 2 and action.advance.to == 3
		and TacticalBaseAdvance.valid(JSON.parse_string(JSON.stringify(action.advance)),
			roster, state.performance.snapshot(state)), "second-to-third context validates after JSON")


func _terminal_context(state: MatchState, action: Dictionary, performance: Dictionary) -> void:
	var home: Array = state.home_team.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id))
	var away: Array = state.away_team.roster.map(func(player: PlayerMatchState) -> String:
		return String(player.definition.id))
	var order: Array = state.sides.rows.duplicate(true)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pa < b.pa)
	var row: Dictionary = {"opposition": {"roster": home,
		"stances": state.sides.evidence(state.home_team)}, "terminal": {
			"pa": action.pa, "half": 11, "player": action.player,
			"pitcher": String(state.pitcher().definition.id), "base_receipt": action.receipt,
			"advance": action.advance.duplicate(true)}}
	_check(PhysicalRecoveryEvidence.terminal(row, away, performance, 0, order),
		"automatic-runner terminal binds the actual home half")
	row.terminal.advance.context.half = 10
	row.terminal.advance.runner = "extra_runner.away.6"
	row.terminal.advance.context.bases[2] = "extra_runner.away.6"
	_check(TacticalBaseAdvance.valid(row.terminal.advance, home, performance),
		"structural boundary alone does not establish fixture side")
	_check(not PhysicalRecoveryEvidence.terminal(row, away, performance, 0, order),
		"terminal rejects other-half automatic runner even with valid structural context")


func _settle_context(roster: Array, action: Dictionary, performance: Dictionary) -> void:
	var owned: Array[String] = []
	owned.assign(roster)
	for seed_value in range(512):
		var build: SeasonBuild = SeasonBuild.new(seed_value, owned)
		build.commit(_command(build, "reward", {"game": 0, "win": false}))
		build.commit(_command(build, "open"))
		for offer: String in build._visit.offers:
			if build._visit.offers[offer] != BASE:
				continue
			_check(build.commit(_command(build, "tactical_buy", {"offer": offer})).ok,
				"boundary fixture pays for genuinely generated Base stock")
			var consumed: Dictionary = action.duplicate(true)
			consumed.receipt = build._bank.view().held[0].id
			var reward: Dictionary = _command(build, "reward", {"game": 1, "win": true,
				"performance": performance, "tactics": [consumed]})
			var bad: Dictionary = reward.duplicate(true)
			bad.tactics[0].advance.context.bases[2] = ""
			var before: Dictionary = build.to_data()
			_check(not build.commit(bad).ok and ClubCareer.same(before, build.to_data()),
				"bad automatic-runner reward rolls back the paid wallet")
			_check(build.commit(reward).ok and build._bank.view().held.is_empty(),
				"valid automatic-runner reward consumes exactly the paid copy")
			var restored: SeasonBuild = SeasonBuild.from_data(
				JSON.parse_string(JSON.stringify(build.to_data())), build._seed, owned)
			_check(restored != null and ClubCareer.same(restored.to_data(), build.to_data()),
				"generated purchase and automatic-runner reward replay after JSON")
			return
	_check(false, "bounded generated-stock search finds a Base copy")
