extends "res://src/tests/season_opponents_test.gd"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_allocation_contracts()
	_infeasible_draft()
	for format_version in [1, 2]:
		_roundtrip(format_version)
	await _roles_ui()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro opponent draft checks passed: seeded clubs, legal arms, history and roles."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _allocation_contracts() -> void:
	var catalog: Array[String] = SeasonPlayerCatalog.ids()
	var arms: Array[String] = []
	for id: String in catalog:
		if SeasonPlayerCatalog.profile(id).stats.pitching >= 2:
			arms.append(id)
	_check(catalog.size() - 4 >= 20 and arms.size() - 4 >= 10, "any human four leaves legal arms")
	var orders: Dictionary = {}
	var selected: Dictionary = {}
	for seed_value in range(128):
		var human: SeasonState = SeasonState.create(seed_value)
		for pick in range(4):
			human.choose_player(human.offers()[(seed_value + pick) % 3])
		var available: Array[String] = human.draft_pool.duplicate()
		for id: String in human.picks:
			available.erase(id)
		var original: Array[String] = available.duplicate()
		var allocation: Dictionary = SeasonOpponentDraft.allocate(seed_value, available)
		_check(not allocation.is_empty(), "every sampled draft has a feasible allocation")
		if allocation.is_empty():
			continue
		_check(available == original, "allocation does not mutate the source pool")
		available.reverse()
		_check(
			allocation == SeasonOpponentDraft.allocate(seed_value, available),
			"seeded replay is independent of caller array ordering"
		)
		var sorted_order: Array = allocation.order.duplicate()
		sorted_order.sort()
		_check(sorted_order == [1, 2, 3, 4, 5], "each club selects exactly once per round")
		orders[str(allocation.order)] = true
		var used: Array[String] = []
		for team in range(1, 6):
			var roster: Array = allocation.rosters[team]
			_check(roster.size() == 4, "four actual named players per opponent")
			for slot in range(4):
				var id: String = roster[slot]
				_check(original.has(id) and not used.has(id), "twenty distinct non-human players")
				used.append(id)
				selected[id] = true
				if slot < 2:
					_check(SeasonPlayerCatalog.profile(id).stats.pitching >= 2, "two usable arms")
		_check(used.size() == 20, "all clubs filled")
	_check(
		orders.size() > 1 and selected.size() == catalog.size(),
		"seed varies clubs and all identities"
	)
	var minimum: Array[String] = catalog.slice(0, 20)
	_check(
		not SeasonOpponentDraft.allocate(42, minimum).is_empty(), "exactly twenty legal candidates"
	)
	minimum[1] = minimum[0]
	_check(SeasonOpponentDraft.allocate(42, minimum).is_empty(), "duplicate candidates fail closed")
	minimum[1] = "player.missing"
	_check(SeasonOpponentDraft.allocate(42, minimum).is_empty(), "unknown candidates fail closed")
	print("OPPONENT_DRAFT seeds=128 orders=", orders.size(), " identities=", selected.size())


func _infeasible_draft() -> void:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.draft_pool.resize(23)
	for pick in range(3):
		_check(season.choose_player(season.offers()[0]), "initial picks before feasibility gate")
	var before: Dictionary = season.build.to_data()
	var teams: Array = season.teams.duplicate(true)
	var picks: Array = season.picks.duplicate()
	_check(not season.choose_player(season.offers()[0]), "insufficient pool refuses final pick")
	_check(
		(
			season.picks == picks
			and season.teams == teams
			and season.build.to_data() == before
			and season.opponents.clubs.is_empty()
			and season.opponents.draft_order.is_empty()
			and season.phase == SeasonState.Phase.DRAFT
		),
		"infeasible allocation leaves complete draft state untouched"
	)


func _roundtrip(format_version: int) -> void:
	SeasonSave.path = "user://opponent-draft-%d-%d.json" % [format_version, OS.get_process_id()]
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = format_version
	season.career = ClubCareer.new()
	_check(season.career.start(season), "career starts before opponent allocation")
	var human: SeasonState = SeasonState.create(42, false, true)
	for pick in range(2):
		_check(season.offers() == human.offers(), "opponent policy cannot change human offers")
		season.choose_player(season.offers()[0])
		human.choose_player(human.offers()[0])
	_check(SeasonSave.save(season), "partial draft checkpoint")
	var partial: SeasonState = SeasonSave.restore()
	_check(partial != null, "partial draft restores")
	if partial == null:
		return
	_check(
		partial.opponents._format == format_version, "restore selects allocator before last pick"
	)
	for pick in range(2):
		partial.choose_player(partial.offers()[0])
		season.choose_player(season.offers()[0])
		human.choose_player(human.offers()[0])
	for team in range(6):
		for field: String in ["roster", "strength", "name"]:
			_check(
				partial.teams[team][field] == season.teams[team][field],
				"resumed club %d retains exact %s" % [team, field]
			)
		_check(
			absf(partial.teams[team].draw - season.teams[team].draw) < 1.0e-15,
			"draft save retains standings draw within JSON round-trip precision"
		)
	_check(season.picks == human.picks, "unchanged human roster")
	_check(
		(
			season.teams.map(func(row: Dictionary) -> float: return row.draw)
			== human.teams.map(func(row: Dictionary) -> float: return row.draw)
		),
		"separate RNG preserves standings draws"
	)
	for team in range(1, 6):
		var club: Dictionary = season.opponents.clubs[str(team)]
		var build: SeasonBuild = club.build
		_check(build.cash() == 0 and build.revision() == 0, "no starting grants or hidden growth")
		for id: String in build.roster():
			_check(
				build.player(id).stats == SeasonPlayerCatalog.profile(id).stats,
				"ordinary player rows"
			)
		if format_version == 1:
			_check(
				season.teams[team].roster == human.teams[team].roster,
				"legacy contiguous allocation"
			)
		else:
			_check(build.player(club.roles.pitcher).stats.pitching >= 2, "actual starter is usable")
			_check(
				build.player(club.roles.secondary).stats.pitching >= 2, "actual reserve is usable"
			)
			_check(club.roles.pitcher != club.roles.secondary, "distinct actual pitching options")
	var original_rosters: Array = season.teams.map(
		func(row: Dictionary) -> Array: return row.roster.duplicate()
	)
	for game in range(12):
		if season.phase == SeasonState.Phase.COMPLETE:
			break
		_record(season)
		_check(SeasonSave.save(season), "every played round checkpoints")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null, "every played round restores")
		if restored == null:
			return
		_check(
			restored.opponents.to_data() == season.opponents.to_data(), "exact paid journal replay"
		)
		_check(restored.results == season.results, "same offscreen results and playoff bracket")
		_check(
			ClubCareer.same(restored.career.to_data(), season.career.to_data()),
			"career proof matches"
		)
		season = restored
	_check(season.phase == SeasonState.Phase.COMPLETE, "full season reaches championship result")
	_check(
		season.teams.map(func(row: Dictionary) -> Array: return row.roster) == original_rosters,
		"playoff opponents retain their original named instances"
	)
	_audit(season)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	_forgery(saved, format_version)
	if format_version == 1:
		var history: ClubCareer = season.career.fork()
		var proof: Dictionary = history.runs[-1].proof.duplicate(true)
		_check(history.close(season), "close old completed season without changing its proof")
		var next: SeasonState = SeasonState.create(43, false, true, true)
		next.career = history
		_check(next.career.start(next), "new allocation starts on the next Working season")
		for pick in range(4):
			next.choose_player(next.offers()[0])
		_check(
			SeasonSave.save(next) and SeasonSave.restore().opponents._format == 2,
			"old career safely starts new-policy opponents"
		)
		_check(
			ClubCareer.same(next.career.runs[0].proof, proof), "prior season history stays intact"
		)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)


func _forgery(saved: Dictionary, format_version: int) -> void:
	for target: String in ["policy", "order", "roster", "unknown"]:
		var bad: Dictionary = saved.duplicate(true)
		match target:
			"policy":
				bad.opponents.policy = 2 if format_version == 1 else 1
			"order":
				bad.opponents["draft_order"] = [1, 1, 2, 3, 4]
			"roster":
				bad.opponents.clubs["1"].roles.pitcher = saved.picks[0]
			"unknown":
				bad.opponents.hidden_bonus = 1
		_check(SeasonSave._decode(bad) == null, "reject forged allocation " + target)
	if format_version == 2:
		var missing: Dictionary = saved.duplicate(true)
		missing.opponents.erase("draft_order")
		_check(SeasonSave._decode(missing) == null, "current policy requires persisted order")
		var reversed: Dictionary = saved.duplicate(true)
		reversed.opponents.draft_order.reverse()
		_check(SeasonSave._decode(reversed) == null, "reject different legal club permutation")
	else:
		_check(not saved.opponents.has("draft_order"), "old representation remains byte-shaped")


func _roles_ui() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = _opponent_season(42)
	app.menu.show_lineup()
	await _frames()
	await _menu_bounds(app, "opponent-draft-roles")
	var fixture: Dictionary = app.season.pending_fixture()
	var index: int = fixture.away if fixture.home == 0 else fixture.home
	var roles: Dictionary = app.season.opponents.summary(index).roles
	for id: String in app.season.teams[index].roster:
		var player: PlayerDefinition = app.season.player_definition(id)
		var found: bool = false
		for node: Node in app.menu._body.find_children("*", "Label", true, false):
			if node.text.begins_with(player.display_name + " • "):
				found = node.text.contains(SeasonOpponentUI.role_names(roles, id))
		_check(found, "pregame shows every actual player's stable roles")
	app.queue_free()
	await _frames()
