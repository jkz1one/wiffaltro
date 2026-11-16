extends Node
## Retained cold controls and explicitly synthetic installed capture equivalence.
## No physics frames, new game, settlement, award, or genuine terminal evidence.

const BASELINE = preload("res://src/tests/stadium_waterfall_report_capture_baseline.gd")
const ORIGINAL_MANIFEST: String = "776b0a06aaf714047b73e7d138f59edeca64082c95bbf42ab017aca7e46c8718"


class PerformanceProbe:
	extends MatchPerformance
	var action: Callable
	var fired: bool = false

	func snapshot(state: MatchState) -> Dictionary:
		var result: Dictionary = super.snapshot(state)
		if not fired:
			fired = true
			if action.is_valid():
				action.call()
		return result


class RecoveryProbe:
	extends MatchRecoveryFlow
	var action: Callable
	var fired: bool = false

	func evidence(state: MatchState, team: TeamMatchState) -> Dictionary:
		var result: Dictionary = super.evidence(state, team)
		if not fired:
			fired = true
			if action.is_valid():
				action.call()
		return result


class ColdDuplicateProbe:
	extends RefCounted
	var rows: Array = []
	var action: Callable
	var fired: bool = false

	func duplicate(_deep: bool = false) -> Array:
		if not fired:
			fired = true
			if action.is_valid():
				action.call()
		return rows.duplicate(true)


var checks: int = 0
var failures: Array[String] = []
var profiles: Array[Dictionary] = []
var input_hashes: Dictionary = {}
var stages: Array[Dictionary] = []
var source_rows: Array = []
var source_path: String = ""
var source_sha: String = ""
var clock_ticks: int = 100


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode: String = _arg("mode", "cold")
	var output: String = _arg("output")
	clock_ticks = int(_arg("clock-ticks", "100"))
	_check(mode in ["cold", "capture"] and clock_ticks > 0, "explicit bounded test mode")
	_check(
		output.is_absolute_path() and not FileAccess.file_exists(output),
		"fresh absolute result file"
	)
	_eligibility_bound_controls()
	_load_sources()
	_load_retained()
	if failures.is_empty():
		for index in range(profiles.size()):
			var profile: Dictionary = profiles[index]
			if mode == "cold":
				_cold_controls(profile)
			else:
				_capture_pair(profile, index)
				# Four destructive controls total, not a cross-product matrix.
				for mutation: String in (
					["owner", "ledger"] if index == 0 else ["native", "snapshot"]
				):
					_callback_control(profile, mutation)
	for path: String in input_hashes:
		_check(
			FileAccess.get_sha256(path) == input_hashes[path], "retained bytes unchanged: " + path
		)
	_verify_sources()
	var summary: Dictionary = {
		"schema": "waterfall47-report-local-reuse-v1",
		"mode": mode,
		"checks": checks,
		"failures": failures,
		"passed": failures.is_empty(),
		"new_games": 0,
		"synthetic_capture_fixture": mode == "capture",
		"genuine_terminal_capture": false,
		"settlement_or_award": false,
		"native_art_or_target_hardware_qualification": false,
		"source_manifest_sha256": source_sha,
		"original_manifest_sha256": ORIGINAL_MANIFEST,
		"input_sha256": input_hashes,
		"stages": stages,
		"timing_scope":
		(
			"One baseline and one candidate call per synthetic installed fixture; inclusive "
			+ "CPU/wall, no historical 38-second speedup claim."
		)
	}
	if output.is_absolute_path() and not FileAccess.file_exists(output):
		var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
		_check(file != null, "open result file")
		if file != null:
			file.store_string(JSON.stringify(summary, "\t", true, true))
			file.flush()
			_check(file.get_error() == OK, "persist result file")
			file.close()
	print(
		(
			"WATERFALL47_REPORT_REUSE_RESULT "
			+ JSON.stringify(
				{
					"mode": mode,
					"checks": checks,
					"failures": failures,
					"new_games": 0,
					"output": output
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _eligibility_bound_controls() -> void:
	_check(
		PhysicalMatchReport._animation_capture_data_closed({"valid": [1, true, "text", 0.5]}),
		"bounded primitive data eligibility"
	)
	_check(
		not PhysicalMatchReport._animation_capture_data_closed(RefCounted.new()),
		"Object data falls back"
	)
	_check(
		not PhysicalMatchReport._animation_capture_data_closed(func() -> void: pass),
		"Callable data falls back"
	)
	var oversized: Array = []
	oversized.resize(65536)
	oversized.fill(0)
	_check(
		not PhysicalMatchReport._animation_capture_data_closed(oversized),
		"65536-value total budget includes container root"
	)
	var deep: Variant = 0
	for index in range(18):
		deep = [deep]
	_check(
		not PhysicalMatchReport._animation_capture_data_closed(deep),
		"depth limit falls back without recursion"
	)
	var cycle: Array = []
	cycle.append(cycle)
	_check(
		not PhysicalMatchReport._animation_capture_data_closed(cycle),
		"cyclic container falls back within depth bound"
	)
	cycle.clear()


func _load_sources() -> void:
	source_path = _arg("source-manifest")
	source_sha = _arg("source-sha256")
	_check(
		(
			source_path.is_absolute_path()
			and source_sha.length() == 64
			and FileAccess.get_sha256(source_path) == source_sha
		),
		"explicit exact candidate source manifest"
	)
	if not failures.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	_check(parsed is Array and not parsed.is_empty(), "candidate manifest rows")
	if parsed is Array:
		source_rows = parsed
	_verify_sources()


func _verify_sources() -> void:
	if source_rows.is_empty():
		return
	_check(FileAccess.get_sha256(source_path) == source_sha, "candidate manifest unchanged")
	for row: Dictionary in source_rows:
		var path: String = row.get("path", "")
		if (
			path.is_empty()
			or path.is_absolute_path()
			or path.contains("..")
			or FileAccess.get_sha256("res://" + path) != row.get("sha256")
		):
			_check(false, "candidate source differs: " + path)
			return
	_check(true, "all candidate manifest files match")


func _load_retained() -> void:
	var config_path: String = _arg("retained-config")
	_check(config_path.is_absolute_path(), "explicit retained input configuration")
	if not failures.is_empty():
		return
	var config: Dictionary = _read(config_path)
	_check(
		(
			config.get("source_manifest_sha256") == ORIGINAL_MANIFEST
			and FileAccess.get_sha256(config.get("source_manifest_path", "")) == ORIGINAL_MANIFEST
		),
		"original retained source remains distinct from candidate source"
	)
	for spec: Dictionary in config.get("profiles", []):
		var inputs: Dictionary = {}
		for name: String in spec.files:
			var path: String = spec.evidence_dir.path_join(name)
			input_hashes[path] = spec.files[name]
			_check(
				FileAccess.get_sha256(path) == spec.files[name],
				"pinned actual input: " + spec.id + ":" + name
			)
			inputs[name] = _read(path)
		if not failures.is_empty():
			return
		var request: Dictionary = inputs["request.json"]
		var terminal: Dictionary = inputs["terminal-raw.json"]
		_check(
			(
				request.identity.source.manifest_sha256 == ORIGINAL_MANIFEST
				and request.identity.run_id == spec.id
				and request.identity.profile == spec.profile
			),
			"original run/profile/source identity"
		)
		_check(
			(
				terminal.natural_game_end
				and terminal.label == "natural_game_end"
				and ClubCareer.same(terminal.snapshot, request.snapshot)
				and ClubCareer.same(terminal.ledger, request.ledger)
			),
			"retained genuine game origin"
		)
		_check(
			(
				ClubCareer.same(inputs["candidate-raw.json"], inputs["final-report.json"])
				and ClubCareer.same(inputs["final-report.json"].surfaces, terminal.contacts)
			),
			"retained exact report/contact equality"
		)
		profiles.append(
			{
				"id": spec.id,
				"request": request,
				"core": inputs["core-raw.json"],
				"report": inputs["final-report.json"],
				"contacts": terminal.contacts
			}
		)
	_check(profiles.size() == 2, "both exact live45 and decorative46 profiles")


func _cold_controls(profile: Dictionary) -> void:
	var report: Dictionary = profile.report
	var core: Dictionary = profile.core
	var snapshot: Dictionary = profile.request.snapshot
	var paid: ClubAssetLedger = _paid(profile.request)
	_check(
		paid != null and StadiumWaterfallAnimationSnapshot.matches(snapshot, paid),
		"cold exact paid prefix: " + profile.id
	)
	_check(
		PhysicalMatchReport.valid(core) and PhysicalMatchReport.valid(report),
		"retained core/public cold validity: " + profile.id
	)
	_check(
		ClubCareer.same(PhysicalStadiumReport.wrap(core, snapshot, profile.contacts), report),
		"unchanged retained public wrap: " + profile.id
	)
	_check(
		ClubCareer.same(PhysicalStadiumReport.core(report), core),
		"unchanged retained core: " + profile.id
	)
	var cases: Array[String] = [
		"ownership", "motion", "base", "seed", "contact_index", "contact_source", "contact_position"
	]
	if snapshot.layout.animation_base == 46:
		cases.append("low_owner")
	for change: String in cases:
		var bad: Dictionary = report.duplicate(true)
		match change:
			"ownership":
				bad.property.inventory.copies.erase(snapshot.layout.waterfall_motion[0])
			"motion":
				bad.property.layout.waterfall_motion = ["foreign-unowned-copy"]
			"base":
				bad.property.layout.animation_base = (
					46 if snapshot.layout.animation_base == 45 else 45
				)
			"seed":
				bad.seed = int(bad.seed) + 1
			"contact_index":
				bad.surfaces[0].play = -1
			"low_owner":
				bad.property.wall_piece_inventory.stock.copies.erase(
					snapshot.layout.low_wall.copies[0]
				)
			"contact_source", "contact_position":
				var found: bool = false
				for row: Dictionary in bad.surfaces:
					if not row.events.is_empty():
						if change == "contact_source":
							row.events[0].source = "foreign-source"
						else:
							row.events[0].position = [999, 999, 999]
						found = true
						break
				_check(found, "retained natural contact exists for " + change)
		_check(PhysicalMatchReport.valid(report), "cold valid before invalid: " + change)
		_check(not PhysicalMatchReport.valid(bad), "fresh public invalid refusal: " + change)
		_check(
			(
				PhysicalStadiumReport
				. wrap(PhysicalStadiumReport._core_validated(bad), bad.property, bad.surfaces)
				. is_empty()
			),
			"fresh public wrap invalid refusal: " + change
		)
		_check(
			PhysicalMatchReport.valid(report) and PhysicalStadiumReport.matches(report, snapshot),
			"cold valid after invalid: " + change
		)
		if change in ["ownership", "motion", "base", "low_owner"]:
			_check(
				(
					StadiumWaterfallAnimationSnapshot.normalized(bad.property).is_empty()
					and not StadiumWaterfallAnimationSnapshot.matches(bad.property, paid)
				),
				"public snapshot entry points fresh refusal: " + change
			)


func _capture_pair(profile: Dictionary, order: int) -> void:
	var runner: PhysicalMatchRunner = _installed_fixture(profile)
	if runner == null:
		return
	var lab: PitchBatLab = runner._lab
	var before: PackedByteArray = _authority_bytes(lab)
	var baseline: Dictionary
	var candidate: Dictionary
	if order == 0:
		baseline = _measure(
			profile.id, "baseline_capture", func() -> Dictionary: return BASELINE.capture(lab)
		)
		candidate = _measure(
			profile.id,
			"candidate_capture",
			func() -> Dictionary: return PhysicalMatchReport.capture(lab)
		)
	else:
		candidate = _measure(
			profile.id,
			"candidate_capture",
			func() -> Dictionary: return PhysicalMatchReport.capture(lab)
		)
		baseline = _measure(
			profile.id, "baseline_capture", func() -> Dictionary: return BASELINE.capture(lab)
		)
	_check(
		not baseline.is_empty() and PhysicalMatchReport.valid(baseline),
		"known-valid synthetic baseline wrapper: " + profile.id
	)
	_check(
		ClubCareer.same(baseline, profile.report) and ClubCareer.same(candidate, baseline),
		"same installed fixture exact A/B report equality: " + profile.id
	)
	_check(
		(
			before == _authority_bytes(lab)
			and StadiumWaterfallAnimationInstall.installed_bound(lab, lab._match_state.stadium)
		),
		"A/B leaves exact current authority unchanged: " + profile.id
	)
	var original: MatchPerformance = lab._match_state.performance
	var harmless: PerformanceProbe = PerformanceProbe.new()
	harmless.players = original.players.duplicate(true)
	harmless.track_fielding = original.track_fielding
	harmless.fielding_players = original.fielding_players.duplicate(true)
	lab._match_state.performance = harmless
	_check(
		not PhysicalMatchReport._animation_capture_is_closed(lab),
		"harmless subclass explicitly uses fallback"
	)
	_check(
		ClubCareer.same(PhysicalMatchReport.capture(lab), baseline) and harmless.fired,
		"fallback preserves supported harmless helper output"
	)
	lab._match_state.performance = original
	var oversized: Array = []
	oversized.resize(65536)
	oversized.fill(0)
	lab._match_state.cold.appearances["unused-proof-budget-control"] = oversized
	_check(
		(
			not PhysicalMatchReport._animation_capture_is_closed(lab)
			and ClubCareer.same(PhysicalMatchReport.capture(lab), baseline)
		),
		"over-budget unused evidence falls back without denying valid report"
	)
	lab._match_state.cold.appearances.erase("unused-proof-budget-control")
	_check(
		(
			PhysicalMatchReport._animation_capture_is_closed(lab)
			and ClubCareer.same(PhysicalMatchReport.capture(lab), candidate)
		),
		"fresh call returns to exact optimized path"
	)
	runner.cancel()
	runner.free()


func _callback_control(profile: Dictionary, mutation: String) -> void:
	var runner: PhysicalMatchRunner = _installed_fixture(profile)
	if runner == null:
		return
	var lab: PitchBatLab = runner._lab
	_check(
		ClubCareer.same(PhysicalMatchReport.capture(lab), profile.report),
		"valid wrapper before callback mutation: " + mutation
	)
	var action: Callable = func() -> void: _mutate_authority(lab, profile.request, mutation)
	var probe: Object
	if mutation == "ledger":
		var cold: ColdDuplicateProbe = ColdDuplicateProbe.new()
		var id: String = String(lab._match_state.away_team.roster[0].definition.id)
		cold.rows = lab._match_state.cold.appearances[id].duplicate(true)
		cold.action = action
		lab._match_state.cold.appearances[id] = cold
		probe = cold
	elif mutation == "native":
		var team: TeamMatchState = lab._match_state.away_team
		_check(not team.ai_recovery_pitcher.is_empty(), "nested recovery callback is reachable")
		var recovery: RecoveryProbe = RecoveryProbe.new()
		recovery.initial = team.recovery.initial.duplicate(true)
		recovery.ready.assign(team.recovery.ready.duplicate(true))
		recovery.costs.assign(team.recovery.costs.duplicate(true))
		recovery.refunds.assign(team.recovery.refunds.duplicate(true))
		recovery.refunders.assign(team.recovery.refunders.duplicate())
		recovery.action = action
		team.recovery = recovery
		probe = recovery
	else:
		var performance: PerformanceProbe = PerformanceProbe.new()
		performance.players = lab._match_state.performance.players.duplicate(true)
		performance.action = action
		lab._match_state.performance = performance
		probe = performance
	_check(
		not PhysicalMatchReport._animation_capture_is_closed(lab),
		"callback path retains full final proof: " + mutation
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty() and probe.get("fired") == true,
		"callback actually fires and public capture refuses stale proof: " + mutation
	)
	_check(
		PhysicalMatchReport.capture(lab).is_empty(),
		"later invocation cannot borrow earlier success: " + mutation
	)
	runner.cancel()
	runner.free()


func _mutate_authority(lab: PitchBatLab, request: Dictionary, mutation: String) -> void:
	match mutation:
		"owner":
			StadiumWaterfallAnimationRuntime.current(lab).retired = true
		"ledger":
			lab._stadium_ledger = _paid(request)
		"snapshot":
			lab._match_state.stadium = lab._match_state.stadium.duplicate(true)
		"native":
			var property: Node = StadiumWaterfallAnimationRuntime.property_claim(lab)
			var shapes: Array[Node] = property.get_node("BoundaryGraph").find_children(
				"*", "CollisionShape3D", true, false
			)
			_check(not shapes.is_empty(), "native shape mutation target exists")
			if not shapes.is_empty():
				(shapes[0] as CollisionShape3D).disabled = true


func _installed_fixture(profile: Dictionary) -> PhysicalMatchRunner:
	var request: Dictionary = profile.request
	var season: SeasonState = SeasonState.create(int(request.season_seed), false, true, true)
	season.opponents._format = int(request.opponent_format)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	state.stadium = request.snapshot.duplicate(true)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	if not _check(
		runner.start(state, int(request.identity.seed), PitchBatLab.FIELD_ID, _paid(request)),
		"ordinary paid fixture startup: " + profile.id
	):
		runner.cancel()
		runner.free()
		return null
	var lab: PitchBatLab = runner._lab
	_check(
		lab._play_records.is_empty() and lab._match_state.phase != MatchState.Phase.GAME_END,
		"fresh startup before synthetic hydration"
	)
	_hydrate_report_only(lab, profile.core, profile.contacts)
	_check(
		ClubCareer.same(PhysicalMatchReport._capture_core(lab), profile.core),
		"synthetic exact standard-helper core equality"
	)
	_check(
		ClubCareer.same(PhysicalStadiumContacts.capture(lab._play_records), profile.contacts),
		"synthetic exact contact equality"
	)
	_check(
		PhysicalMatchReport._animation_capture_is_closed(lab),
		"positive installed fixture uses optimized exact-helper path"
	)
	_check(
		StadiumWaterfallAnimationInstall.installed_bound(lab, lab._match_state.stadium),
		"hydration preserves exact paid/native owner authority"
	)
	return runner


func _hydrate_report_only(lab: PitchBatLab, core: Dictionary, contacts: Array) -> void:
	# Synthetic schema fixture only: copy retained report operands into exact standard
	# evidence classes. No physics advances; cancel the ordinary runner synchronously.
	var state: MatchState = lab._match_state
	state.phase = MatchState.Phase.GAME_END
	state.elapsed_seconds = float(core.elapsed)
	state.inning = int(core.inning)
	state.top_half = core.top
	state.performance.players = core.performance.duplicate(true)
	state.ai_choice_events.assign(core.choices.events.duplicate(true))
	state.base_flow.ready.assign(core.tactics.base.ready.duplicate(true))
	state.base_flow.results.assign(core.tactics.base.results.duplicate(true))
	state.base_flow.tags.assign(core.tactics.base.tags.duplicate(true))
	state.base_flow.advances.assign(core.tactics.base.advances.duplicate(true))
	var last: Dictionary = core.tactics.base.final
	state.plate_appearance_number = int(last.pa)
	state.outs = int(last.outs)
	state.bases.first = StringName(last.bases[0])
	state.bases.second = StringName(last.bases[1])
	state.bases.third = StringName(last.bases[2])
	state.sides.rows.clear()
	state.clean_outs.rows.clear()
	state.cold.appearances.clear()
	for field: String in ["releases", "calls", "strikeouts"]:
		state.sure_shot.set(field, [])
	lab._automation.releases.assign(core.releases.duplicate(true))
	for index in range(2):
		var team: TeamMatchState = state.away_team if index == 0 else state.home_team
		var row: Dictionary = core.teams[index]
		var tactics: Dictionary = core.tactics.teams[index]
		team.display_name = row.name
		team.runs = int(core.away_runs if index == 0 else core.home_runs)
		team.ai_tactical_initial.assign(tactics.initial.duplicate(true))
		team.tactics.consumed.assign(tactics.consumed.duplicate(true))
		team.tactics.held.assign(tactics.remaining.duplicate(true))
		team.ai_budget = tactics.budget.duplicate(true)
		team.recovery.initial = tactics.recovery.initial.duplicate(true)
		team.recovery.ready.assign(tactics.recovery.ready.duplicate(true))
		team.recovery.costs.assign(tactics.recovery.costs.duplicate(true))
		team.recovery.refunds.assign(tactics.recovery.refunds.duplicate(true))
		team.recovery.refunders.assign(tactics.recovery.refunders.duplicate())
		state.cold.appearances.merge(row.batting.duplicate(true), true)
		state.sides.rows.append_array(row.stances.duplicate(true))
		state.clean_outs.rows.append_array(row.fielding.duplicate(true))
		for field: String in ["releases", "calls", "strikeouts"]:
			state.sure_shot.get(field).append_array(row.pitching[field].duplicate(true))
		for player_index in range(team.roster.size()):
			var player: PlayerMatchState = team.roster[player_index]
			var id: String = String(player.definition.id)
			var workload: Dictionary = row.workload[id]
			player.stamina_max = float(workload.capacity)
			player.stamina_remaining = float(workload.remaining)
			player.pitch_count = int(workload.pitches)
			player.pitching_finished = workload.retired
			lab._automation.initial[id] = workload.initial
			if id == last.player:
				team.batting_index = player_index
			if id == last.pitcher:
				team.pitcher_index = player_index
	lab._play_records.clear()
	for index in range(core.plays.size()):
		var row: Dictionary = core.plays[index]
		var play: PlayRecord = PlayRecord.new()
		play.inning = int(int(row.half) / 2) + 1
		play.top_half = int(row.half) % 2 == 0
		play.batter_id = StringName(row.batter)
		play.pitcher_id = StringName(row.pitcher)
		play.pitch_id = StringName(row.recipe)
		play.ai_decision_recorded = row.read
		play.ai_swung = row.swung
		play.contact_outcome = int(row.contact)
		play.exit_speed_mps = float(row.exit_speed)
		play.result = StringName(row.result)
		play.resolution_reason = StringName(contacts[index].reason)
		play.stadium_contacts.assign(contacts[index].events.duplicate(true))
		lab._play_records.append(play)


func _paid(request: Dictionary) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(
		request.ledger, int(request.ledger_seed), request.credits, request.progress
	)


func _authority_bytes(lab: PitchBatLab) -> PackedByteArray:
	var property: StadiumWaterfallAnimationProperty = (
		StadiumWaterfallAnimationRuntime.property_claim(lab) as StadiumWaterfallAnimationProperty
	)
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
	return var_to_bytes(
		[
			lab._match_state.stadium,
			lab._stadium_ledger.to_data(),
			lab._match_state.get_instance_id(),
			lab._stadium_ledger.get_instance_id(),
			property.get_instance_id(),
			owner.get_instance_id(),
			owner._lease.phase,
			lab._ball_play_resolver.segment_observer.get_object().get_instance_id(),
			String(lab._ball_play_resolver.segment_observer.get_method()),
			lab._primary_fielder.stadium_boundary_clip.get_object().get_instance_id(),
			String(lab._primary_fielder.stadium_boundary_clip.get_method())
		]
	)


func _measure(profile: String, label: String, operation: Callable) -> Dictionary:
	print("WATERFALL47_REUSE_BEGIN " + profile + " " + label)
	var cpu_before: int = _cpu_us()
	var before: int = Time.get_ticks_usec()
	var result: Dictionary = operation.call()
	var elapsed: int = Time.get_ticks_usec() - before
	var cpu_after: int = _cpu_us()
	var row: Dictionary = {
		"profile": profile,
		"stage": label,
		"wall_us": elapsed,
		"process_cpu_us":
		cpu_after - cpu_before if cpu_before >= 0 and cpu_after >= cpu_before else -1,
		"synthetic_capture": true,
		"result_sha256": JSON.stringify(result, "", true, true).sha256_text(),
		"nonempty": not result.is_empty()
	}
	stages.append(row)
	print("WATERFALL47_REUSE_END " + JSON.stringify(row))
	return result


func _cpu_us() -> int:
	var file: FileAccess = FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return -1
	var raw: String = file.get_line()
	file.close()
	var fields: PackedStringArray = raw.substr(raw.rfind(")") + 1).strip_edges().split(" ", false)
	return (
		int((int(fields[11]) + int(fields[12])) * 1000000.0 / clock_ticks)
		if fields.size() >= 13
		else -1
	)


func _read(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(value is Dictionary, "read retained JSON: " + path)
	return value if value is Dictionary else {}


func _arg(name: String, fallback: String = "") -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--" + name + "="):
			return argument.trim_prefix("--" + name + "=")
	return fallback


func _check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WATERFALL47_REPORT_REUSE " + label)
	return ok
