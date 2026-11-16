extends "res://src/tests/inventory_live_build_test.gd"
## Actual physics and live Build sale/settlement. Acquisition eligibility/funding are controlled,
## replayable synthetic preparation, not earned season progression or save78 UI qualification.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("dugout"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "generated-sale physical roster draft")
	var ids: Array[String] = []
	ids.assign(season.teams[0].roster)
	var build: SeasonBuild = _paid_build(ids)
	if build == null:
		get_tree().quit(1)
		return
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 2})).ok,
		"actual accepted Build attempt journal"
	)
	var own: TeamMatchState = _build_team(build)
	var source: MatchState = MatchState.create(season._make_team(1, 2), own)
	source.league_rules = build._league_rules.duplicate(true)
	own.field_supply.receipt = SeasonFieldGrant.receipt(2)
	var initial: Dictionary = build.to_data()
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started: bool = runner.start(source, 443)
	check(started, "actual physical generated-sale game starts")
	var sale_done: bool = false
	var accepted_sale: Dictionary = {}
	var sale_pa: int = -1
	var frames: int = 0
	var started_ms: int = Time.get_ticks_msec()
	var played: MatchState
	if started:
		played = runner._lab._match_state
		for frame in range(300000):
			await get_tree().physics_frame
			frames += 1
			if not report.is_empty() or not errors.is_empty():
				break
			if sale_done or played.home_team.field_supply.evidence().get("outcome") != "granted":
				continue
			if (
				played.phase != MatchState.Phase.PRE_PITCH
				or played.between_batters
				or runner._lab._release_controller.active
				or not played.sure_shot.releases.any(
					func(row: Dictionary) -> bool: return row.pa == played.plate_appearance_number
				)
			):
				continue
			runner._lab._debug_paused = true
			var proof: Dictionary = PhysicalInventoryPaused.capture(
				runner._lab, played.home_team, SeasonInventoryRules.anchor(build, 2)
			)
			if proof.is_empty():
				runner._lab._debug_paused = false
				continue
			var opponent: Array = source.away_team.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			)
			check(
				PhysicalInventoryPaused.matches(
					proof,
					own,
					opponent,
					2,
					SeasonInventoryRules.anchor(build, 2),
					own.league_ownership,
					[],
					1,
					false
				),
				"actual prefix independently binds source roster/orientation and paid bank"
			)
			var command: Dictionary = SeasonOpponentPolicy.command(
				build,
				"match_supply_sell",
				{
					"game": 2,
					"receipt": SeasonFieldGrant.receipt(2),
					"first_pitch":
					(
						played.gear_usage.first_pitch.duplicate()
						if played.gear_usage.started
						else null
					),
					"field_state": proof.field_state.duplicate(true),
					"inventory_prefix": proof
				}
			)
			var before: Dictionary = build.to_data()
			var cash: int = build.cash()
			var held_before: Array = played.home_team.tactics.held.duplicate(true)
			check(
				(
					build.candidate(command) != null
					and ClubCareer.same(before, build.to_data())
					and ClubCareer.same(held_before, played.home_team.tactics.held)
				),
				"cancelled real-prefix sale preview changes neither Build nor runtime held copy"
			)
			var outcome: Dictionary = build.commit(command)
			check(outcome.ok, "real earned-prefix Build sale commits: " + str(outcome.get("error")))
			if not outcome.ok:
				break
			# Match production ordering: remove only after the durable transaction succeeds.
			for index in range(played.home_team.tactics.held.size() - 1, -1, -1):
				if played.home_team.tactics.held[index].id == command.receipt:
					played.home_team.tactics.held.remove_at(index)
			accepted_sale = command.duplicate(true)
			sale_done = true
			runner._lab._debug_paused = false
			sale_pa = int(proof.completed)
			check(
				build.cash() == cash + 1 and SeasonInventoryResale.field_retired(build._bank, 2),
				"actual runtime Tape pays half normal3 exactly once"
			)
			check(
				not played.home_team.tactics.held.any(
					func(copy: Dictionary) -> bool: return copy.id == command.receipt
				),
				"sold runtime copy removed after successful commit"
			)
			check(
				build.commit(command).get("replayed", false) and build.cash() == cash + 1,
				"same exact live request retries without a second payout"
			)
			var cold: SeasonBuild = SeasonBuild.from_data(
				JSON.parse_string(JSON.stringify(build.to_data(), "", true, true)), build._seed, ids
			)
			check(
				cold != null and ClubCareer.same(cold.to_data(), build.to_data()),
				"real earned prefix and cash transaction cold-replay before game completion"
			)
			print(
				"PAUSED_GENERATED_SALE_COMMITTED completed_pa=",
				sale_pa,
				" releases=",
				proof.releases.size(),
				" grant=",
				proof.field_state.grant,
				" refund=",
				build.cash() - cash
			)
	check(sale_done, "actual earned generated copy sold before terminal boundary")
	check(
		errors.is_empty() and not report.is_empty(),
		"actual game continues and completes after sale: " + str(errors)
	)
	if not report.is_empty() and played != null:
		check(
			played.phase == MatchState.Phase.GAME_END and PhysicalMatchReport.valid(report),
			"separate full-game physical report remains valid after unused-copy removal"
		)
		check(
			PhysicalLeagueReport.matches(report, source),
			"completed report binds immutable original physical request"
		)
		var performance: Dictionary = played.performance.snapshot(played)
		var settlement: Dictionary = SeasonOpponentPolicy.command(
			build,
			"reward",
			{
				"game": 2,
				"win": played.home_team.runs > played.away_team.runs,
				"performance": performance,
				"fielding": played.clean_outs.evidence(played.home_team),
				"field_supply": played.home_team.field_supply.evidence(),
				"tactics": played.home_team.tactics.consumed.duplicate(true)
			}
		)
		settlement["inventory_final"] = SeasonInventoryRules.capture_final(
			build, 2, played, played.home_team
		)
		var missing: Dictionary = settlement.duplicate(true)
		missing.erase("inventory_final")
		var before_final: Dictionary = build.to_data()
		check(
			not build.commit(missing).ok and ClubCareer.same(before_final, build.to_data()),
			"paused sale cannot settle without final history"
		)
		var changed: Dictionary = settlement.duplicate(true)
		changed.inventory_final.releases.pop_front()
		check(
			not build.commit(changed).ok and ClubCareer.same(before_final, build.to_data()),
			"final history cannot omit an accepted pitch"
		)
		var outcome: Dictionary = build.commit(settlement)
		check(
			outcome.ok,
			"real completed game settles after live generated sale: " + str(outcome.get("error"))
		)
		check(
			not build._bank.view().held.any(
				func(copy: Dictionary) -> bool: return copy.id == SeasonFieldGrant.receipt(2)
			),
			"real completion never regrants retired generated identity"
		)
		check(
			SeasonInventoryResale.field_retired(build._bank, 2),
			"retirement survives actual settlement"
		)
		var settled: Dictionary = build.to_data()
		var cold: SeasonBuild = SeasonBuild.from_data(
			JSON.parse_string(JSON.stringify(settled, "", true, true)), build._seed, ids
		)
		check(
			cold != null and ClubCareer.same(cold.to_data(), settled),
			"actual prefix, sale, full settlement and no-regrant cold-replay exactly"
		)
		print(
			"PAUSED_GENERATED_SALE_LIVE wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			played.sure_shot.releases.size(),
			" score=",
			played.away_team.runs,
			"-",
			played.home_team.runs,
			" sale_completed_pa=",
			sale_pa,
			" consumed=",
			played.home_team.tactics.consumed,
			" final_held=",
			build._bank.view().held
		)
	_export_optional(
		{
			"version": 1,
			"scope": "controlled paid acquisition; actual physical earned sale and completion",
			"physics_seed": 443,
			"build_seed": build._seed,
			"initial_build": initial,
			"accepted_sale": accepted_sale,
			"physical_report": report,
			"final_build": build.to_data(),
			"physics_frames": frames,
			"sale_completed_pa": sale_pa,
			"failures": failures
		}
	)
	check(not initial.is_empty(), "controlled initial replayable Build retained")
	runner.queue_free()
	await get_tree().process_frame
	print("Inventory paused generated sale live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _paid_build(ids: Array[String]) -> SeasonBuild:
	var probe: SeasonBuild = SeasonBuild.new(0, ids)
	probe.enable_league_rules(LeagueRules.capture("dugout"))
	probe._field_start = true
	probe._jump_start = false
	probe._visit.number = 2
	var seed_value: int = -1
	for value in range(10000):
		probe._seed = value
		if probe._offers(0).values().has("B01"):
			seed_value = value
			break
	check(seed_value >= 0, "replayable actual seeded B01 shop found")
	if seed_value < 0:
		return null
	var build: SeasonBuild = SeasonBuild.new(seed_value, ids)
	build.enable_league_rules(LeagueRules.capture("dugout"))
	build._field_start = true
	build._jump_start = false
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"explicit inventory-v1 fixture admission"
	)
	for game in range(2):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"controlled synthetic funding, not earned-season claim"
		)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "replayable seeded shop opens"
	)
	var offer: String = ""
	for key: String in build._visit.offers:
		if build._visit.offers[key] == "B01":
			offer = key
	check(not offer.is_empty(), "actual B01 offer reproduced")
	if offer.is_empty():
		return null
	check(
		(
			build
			. commit(
				SeasonOpponentPolicy.command(build, "sponsor_buy", {"offer": offer, "replace": ""})
			)
			. ok
		),
		"real paid B01 journal acquisition"
	)
	print("PAUSED_GENERATED_SALE_SETUP controlled_shop_seed=", seed_value, " roster=", ids)
	return build


func _export_optional(evidence: Dictionary) -> void:
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-dir="):
			directory = argument.trim_prefix("--evidence-dir=")
	if directory.is_empty():
		return
	var created: Error = DirAccess.make_dir_recursive_absolute(directory)
	check(created == OK, "optional artifact directory is writable")
	if created != OK:
		return
	var path: String = directory.path_join(
		"generated-sale-%d-%d.json" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	)
	if FileAccess.file_exists(path):
		check(false, "optional evidence export never overwrites retained evidence")
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "optional full-precision artifact opens")
	if file == null:
		return
	file.store_string(JSON.stringify(evidence, "", true, true))
	file.flush()
	var written: bool = file.get_error() == OK
	file.close()
	check(
		(
			written
			and ClubCareer.same(JSON.parse_string(FileAccess.get_file_as_string(path)), evidence)
		),
		"optional physical report/sale/Build artifact cold-verifies"
	)
	if written:
		print("PAUSED_GENERATED_SALE_ARTIFACT ", path)
