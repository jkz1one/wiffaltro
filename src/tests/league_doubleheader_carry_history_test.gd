extends "res://src/tests/league_doubleheader_build_test.gd"
## Controlled completed workloads fund real generated offers and paid Build journals.
## No claim that these synthetic statistics are played physical games.

const ORIGINAL: Array[String] = [
	"player.alex_finch", "player.ari_banks", "player.ash_cole", "player.bailey_quinn"
]
const NEWCOMER: String = "player.gray_west"


func _ready() -> void:
	_paid_capacity()
	_paid_recruit_history()
	print("Doubleheader carry/history checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _new_candidate(seed_value: int, pool: Array[String] = []) -> SeasonBuild:
	roster.assign(ORIGINAL)
	var build: SeasonBuild = SeasonBuild.new(seed_value, ORIGINAL, pool)
	check(
		build.enable_league_rules(LeagueRules.capture("doubleheader")),
		"closed controlled workload fixture"
	)
	return build


func _workload(
	build: SeasonBuild, game: int, pitcher_id: String = "", count: int = 0
) -> Dictionary:
	roster.assign(build.roster())
	return _reward(build, game, roster.find(pitcher_id) if not pitcher_id.is_empty() else -1, count)


func _restore_exact(build: SeasonBuild) -> SeasonBuild:
	return SeasonBuild.from_data(
		cold(build.to_data()), build._seed, build._initial_roster, build._pool, build._blocked
	)


func _paid_capacity() -> void:
	var exercised: bool = false
	for seed_value in range(128):
		var build: SeasonBuild = _new_candidate(seed_value)
		var first: Dictionary = _workload(build, 0, ORIGINAL[0], 4)
		check(build.commit(first).ok, "synthetic first workload earns ordinary18")
		var original_capacity: float = (
			first.doubleheader_workload.proof.initial[ORIGINAL[0]].capacity
		)
		var debt_before: Dictionary = SeasonDoubleheaderBuild.pair_for(build, 3).debt.duplicate(
			true
		)
		check(
			build.commit(SeasonOpponentPolicy.command(build, "open")).ok,
			"open actual first-leg shop"
		)
		var offer: String = ""
		for key: String in build._visit.offers:
			if build._visit.offers[key] == "development.pitching":
				offer = key
				break
		if offer.is_empty():
			continue
		var previous_rating: int = build.player(ORIGINAL[0]).stats.pitching
		var buy: Dictionary = SeasonOpponentPolicy.command(
			build,
			"buy",
			{"offer": offer, "mode": "use", "player": ORIGINAL[0], "pitch": "", "replace": ""}
		)
		var cash_before: int = build.cash()
		check(
			build.commit(buy).ok and build.cash() == cash_before - 6,
			"genuine generated Bullpen Coach purchase debits6"
		)
		check(
			build.player(ORIGINAL[0]).stats.pitching == previous_rating + 1,
			"paid Pitching actually increases rating"
		)
		var second: Dictionary = _workload(build, 3)
		var row: Dictionary = second.doubleheader_workload.proof.initial[ORIGINAL[0]]
		check(
			PhysicalRecoveryFlow.near(row.capacity, original_capacity + 18.0 * 1.08),
			"new capacity reflects genuine paid stat upgrade"
		)
		check(
			ClubCareer.same(second.doubleheader_workload.pair.debt, debt_before),
			"capacity gain leaves exact absolute debt unchanged"
		)
		check(
			PhysicalRecoveryFlow.near(row.initial, row.capacity - debt_before[ORIGINAL[0]]),
			"second leg subtracts absolute debt from new capacity"
		)
		check(
			not PhysicalRecoveryFlow.near(
				row.initial / row.capacity,
				(original_capacity - debt_before[ORIGINAL[0]]) / original_capacity
			),
			"no percentage-fatigue rescaling"
		)
		var before: Dictionary = build.to_data()
		var wrong: Dictionary = second.duplicate(true)
		wrong.doubleheader_workload.proof.initial[ORIGINAL[0]].capacity = original_capacity
		wrong.doubleheader_workload.proof.initial[ORIGINAL[0]].initial = (
			original_capacity - debt_before[ORIGINAL[0]]
		)
		wrong.doubleheader_workload.proof.remaining[ORIGINAL[0]] = (
			original_capacity - debt_before[ORIGINAL[0]]
		)
		check(
			not build.commit(wrong).ok and ClubCareer.same(build.to_data(), before),
			"coherent stale-capacity proof rejects after paid upgrade"
		)
		var restored: SeasonBuild = _restore_exact(build)
		check(
			(
				restored != null
				and ClubCareer.same(SeasonDoubleheaderBuild.pair_for(restored, 3).debt, debt_before)
			),
			"paid upgrade and first-leg debt cold replay before return leg"
		)
		check(
			build.commit(second).ok and build.cash() == 36,
			"upgraded second-leg reward pays normal sweep"
		)
		restored = _restore_exact(build)
		check(
			restored != null and ClubCareer.same(restored.to_data(), build.to_data()),
			"paid capacity change and second-leg proof cold replay"
		)
		_reset_contexts(build)
		print("Doubleheader paid capacity fixture: generated shop seed ", seed_value)
		exercised = true
		break
	check(exercised, "generated paid capacity-change path exercised")


func _paid_recruit_history() -> void:
	var pool: Array[String] = ORIGINAL.duplicate()
	pool.append(NEWCOMER)
	var exercised: bool = false
	for seed_value in range(256):
		var build: SeasonBuild = _new_candidate(seed_value, pool)
		var original_profile: Dictionary = build.player(ORIGINAL[0]).duplicate(true)
		check(
			build.commit(_workload(build, 0, ORIGINAL[0], 8)).ok,
			"first-leg actual identity workload fixture"
		)
		var pair_before: Dictionary = SeasonDoubleheaderBuild.pair_for(build, 3)
		check(
			build.commit(SeasonOpponentPolicy.command(build, "open")).ok,
			"generated first-leg recruitment visit"
		)
		var offer: Dictionary = build._visit.get("recruit", {})
		if offer.is_empty():
			continue
		check(
			offer.player == NEWCOMER and offer.price == 18 and not offer.returning,
			"normal unused early recruit quote"
		)
		check(
			(
				build
				. commit(
					SeasonOpponentPolicy.command(
						build, "sign", {"offer": offer.id, "replace": ORIGINAL[0]}
					)
				)
				. ok
			),
			"pay full generated recruit price to release tired player"
		)
		check(
			(
				build.cash() == 0
				and build.roster().has(NEWCOMER)
				and not build.roster().has(ORIGINAL[0])
			),
			"release earns no refund and exact owned roster changes"
		)
		var second: Dictionary = _workload(build, 3)
		var new_row: Dictionary = second.doubleheader_workload.proof.initial[NEWCOMER]
		check(
			ClubCareer.same(second.doubleheader_workload.pair, pair_before),
			"release does not discard absent player's exact debt"
		)
		check(
			(
				second.doubleheader_workload.pair.debt.get(NEWCOMER, 0.0) == 0.0
				and PhysicalRecoveryFlow.near(new_row.initial, new_row.capacity)
			),
			"unused new recruit starts with zero workload debt"
		)
		check(
			(
				second.doubleheader_workload.pair.debt[ORIGINAL[0]] > 0.0
				and not second.doubleheader_workload.proof.initial.has(ORIGINAL[0])
			),
			"released identity remains history, not an active reserve"
		)
		var restored: SeasonBuild = _restore_exact(build)
		check(
			(
				restored != null
				and ClubCareer.same(SeasonDoubleheaderBuild.pair_for(restored, 3), pair_before)
			),
			"released-player debt survives cold replay before leg two"
		)
		check(
			build.commit(second).ok and build.cash() == 24,
			"new roster completes second leg with derived sweep"
		)
		check(
			build.commit(SeasonOpponentPolicy.command(build, "open")).ok,
			"generated second recruitment visit"
		)
		offer = build._visit.get("recruit", {})
		if offer.is_empty():
			continue
		check(
			offer.player == ORIGINAL[0] and offer.returning and offer.price == 22,
			"normal returning original contract quote"
		)
		check(
			(
				build
				. commit(
					SeasonOpponentPolicy.command(
						build, "sign", {"offer": offer.id, "replace": NEWCOMER}
					)
				)
				. ok
			),
			"pay complete returning contract without release refund"
		)
		check(
			(
				build.cash() == 2
				and build.roster().has(ORIGINAL[0])
				and not build.roster().has(NEWCOMER)
			),
			"paid original returns to exact active roster"
		)
		check(
			build.player(ORIGINAL[0]) == original_profile,
			"return retains original profile without fresh recruit catchup"
		)
		# One recruit offer exists per postgame visit. A normal return therefore
		# follows leg two; preserve the old pair's debt as history, then reset the
		# new pair. Do not fabricate a release-and-return within one shop visit.
		check(
			ClubCareer.same(SeasonDoubleheaderBuild.pair_for(build, 3), pair_before),
			"returned identity preserves exact historical pair debt"
		)
		restored = _restore_exact(build)
		check(
			(
				restored != null
				and ClubCareer.same(restored.to_data(), build.to_data())
				and ClubCareer.same(SeasonDoubleheaderBuild.pair_for(restored, 3), pair_before)
			),
			"paid release/return and historical debt cold replay"
		)
		_reset_contexts(build)
		print("Doubleheader paid recruitment/return fixture: generated shop seed ", seed_value)
		exercised = true
		break
	check(exercised, "normal paid release and returning-player path exercised")


func _reset_contexts(build: SeasonBuild) -> void:
	for game in [6, 30, 31, 32]:
		var branch: SeasonBuild = build._fork()
		var command: Dictionary = _workload(branch, game)
		check(
			command.doubleheader_workload.pair == {"game": game, "first": -1, "debt": {}},
			"new pair/playoff has exact empty carry context"
		)
		for row: Dictionary in command.doubleheader_workload.proof.initial.values():
			check(
				PhysicalRecoveryFlow.near(row.initial, row.capacity),
				"new pair/playoff restores full capacity"
			)
		check(
			branch.commit(command).ok and branch.cash() == build.cash() + 18,
			"independent reset fixture pays ordinary18 without sweep"
		)
		# Minimal controlled season shell exercises the production team constructor,
		# without claiming a complete season or fabricated playoff participation.
		var shell: SeasonState = SeasonState.new()
		shell.league_rules = build._league_rules.duplicate(true)
		shell.build = build
		shell.teams.append({"name": "Controlled reset context", "roster": build.roster()})
		var old_team: TeamMatchState = shell._make_team(0, game)
		check(old_team != null, "controlled production team construction")
		if old_team == null:
			continue
		old_team.roster[0].pitch_count = 19
		old_team.roster[0].first_batter_completed = true
		old_team.roster[0].pitching_finished = true
		old_team.tactics._recovered.append(String(old_team.roster[0].definition.id))
		old_team.strikecraft_uses = 2
		var fresh: TeamMatchState = shell._make_team(0, game)
		check(
			(
				fresh != null
				and fresh != old_team
				and fresh.league_pair == command.doubleheader_workload.pair
			),
			"new fixture creates independent reset team"
		)
		if fresh == null:
			continue
		for player: PlayerMatchState in fresh.roster:
			check(
				(
					player.pitch_count == 0
					and not player.first_batter_completed
					and not player.pitching_finished
					and PhysicalRecoveryFlow.near(player.stamina_remaining, player.stamina_max)
				),
				"new fixture resets pitcher flags and full stamina"
			)
		check(
			(
				fresh.tactics._recovered.is_empty()
				and fresh.tactics.consumed.is_empty()
				and fresh.strikecraft_uses == 0
				and fresh.recovery.workload_events.is_empty()
			),
			"new fixture resets Recovery/refund/usage flags"
		)
