extends "res://src/tests/season_tactical_live_test.gd"

const Earned = preload("res://src/tests/season_earned_sponsor_test.gd")
var _paid_return: bool = false
var _change_stage: int = 0
var _first_index: int = -1


func _ready() -> void:
	var fixture: Node = Earned.new()
	var pair: Array[String] = ["E05", "G05"]
	var full_hits: Array[String] = ["single", "double", "triple", "hr"]
	var empty_hits: Array[String] = []
	for paid: bool in [false, true]:
		_paid_return = paid
		_season = fixture._paid(pair) if paid else fixture._new_club(51)
		if paid:
			fixture._result(_season, full_hits, 2)
		else:
			fixture._result(_season, empty_hits, 0)
		while _season.pending_fixture().home != 0:
			fixture._result(_season, empty_hits, 0)
		_check(fixture._failures == 0, "source-supported earned sponsor fixture")
		SeasonSave.path = "user://earned-sponsor-live-%s-%d.json" % [paid, OS.get_process_id()]
		_check(SeasonSave.save(_season), "save paid or prospective pregame")
		var before: Dictionary = _season.build.view()
		var game: Dictionary = _season.pending_fixture()
		_change_stage = 0
		_first_index = -1
		_observed_swings = 0
		await _run_match(67)
		_check(_change_stage == (2 if paid else 1), "complete legal pitching changes")
		var stats: Dictionary = _played_state.performance.snapshot(_played_state)
		var pitchers: int = 0
		for player: PlayerMatchState in _played_state.home_team.roster:
			if stats[String(player.definition.id)].p_k > 0:
				pitchers += 1
		_check(pitchers >= 2, "physical game credits two distinct pitchers with strikeouts")
		if paid:
			_check(_played_state.home_team.encore_used, "paid return consumed exactly once")
			_check(_observed_swings > 0, "actual Contact swings receive four completed stamps")
		await _settlement_retry(game, before)
		var restored: SeasonState = SeasonSave.restore()
		var progress: SeasonSponsorProgress = restored.build._sponsor_progress
		_check(progress.games[-1].multi_k, "actual strikeout feat survives save replay")
		if not paid:
			_check(
				(
					progress.eligible().has("G05")
					== (_played_state.home_team.runs > _played_state.away_team.runs)
				),
				"only a winning physical result earns Encore"
			)
			_check(
				progress.eligible().has("E05") == (progress.state().hits.size() >= 3),
				"actual credited hit types determine career access"
			)
		else:
			var receipt: Dictionary = SeasonSchoolSponsors.active(restored.build, "E05")
			_check(
				restored.build._legends[receipt.id].size() == 4, "retries never duplicate stamps"
			)
		for suffix: String in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(SeasonSave.path + suffix)
	fixture.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro live earned sponsor checks passed: two physical games, feats, stamps and return."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _observe_live_frame(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.home_team
	if _first_index < 0:
		_first_index = team.pitcher_index
	if state.defensive_team() == team and state.can_change_defense():
		var current: PlayerMatchState = team.current_pitcher()
		var line: Dictionary = state.performance.players.get(String(current.definition.id), {})
		if line.get("p_k", 0) > 0 and _change_stage == 0:
			_check(team.select_pitcher((_first_index + 1) % 4), "ordinary legal removal")
			_change_stage = 1
			_refresh_pitcher(lab)
		elif line.get("p_k", 0) > 0 and _change_stage == 1 and _paid_return:
			var first: PlayerMatchState = team.roster[_first_index]
			var stamina: float = first.stamina_remaining
			var pitches: int = first.pitch_count
			var opening: bool = first.first_batter_completed
			_check(SeasonEncore.return_pitcher(state, _first_index), "legal paid physical return")
			_check(
				(
					team.current_pitcher() == first
					and first.stamina_remaining == stamina
					and first.pitch_count == pitches
					and first.first_batter_completed == opening
				),
				"physical return retains the exact player and spent resources"
			)
			_change_stage = 2
			_refresh_pitcher(lab)
	if _paid_return and state.batting_team() == team and lab._swing_tracker != null:
		if lab._swing_tracker.active and lab._swing_tracker.profile.id == &"swing.contact":
			_check(
				is_equal_approx(lab._swing_tracker.profile.gear_fair_exit_scale, 1.04),
				"physical Contact swing uses prior-game Local Legends stamps"
			)
			_observed_swings += 1


func _refresh_pitcher(lab: PitchBatLab) -> void:
	lab._selected_pitch_index = 0
	lab._last_ai_pitch_index = -1
	lab._ai_pitch_preselected = false
	lab._apply_defensive_assignment()
	lab._refresh_config()


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await super._check_outro_and_restart(lab)
	_check(not lab._match_state.home_team.encore_used, "fresh match resets return allowance")
	for player: PlayerMatchState in lab._match_state.home_team.roster:
		_check(
			player.stamina_remaining == player.stamina_max, "fresh match restores pregame stamina"
		)
