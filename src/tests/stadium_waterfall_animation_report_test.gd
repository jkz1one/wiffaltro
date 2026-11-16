extends "res://src/tests/stadium_owned_waterfall_animation_test.gd"
## One genuine fixture35 game OR one cold verification per invocation.
## Synthetic paid funding; no phase, score, contact, award, or outcome injection.

const RETAINING_RUNNER = preload(
	"res://src/tests/stadium_waterfall_animation_report_retaining_runner.gd"
)
const PROFILES: Array[String] = ["live47-base45", "decorative47-base46-low_flanks"]
const WATER_COPY: String = "purchase:report-water:0"
const PLAZA_COPY: String = "purchase:report-plaza:0"
const LEDGER_SEED: int = 216
const SEASON_SEED: int = 42
const ARTIFACTS: Array[String] = [
	"request.json",
	"candidate-raw.json",
	"core-raw.json",
	"terminal-raw.json",
	"terminal-diagnostics.json",
	"final-report.json",
	"run-result.json",
	"cold-result.json"
]

var mode: String = ""
var profile: String = ""
var run_id: String = ""
var output_dir: String = ""
var manifest_path: String = ""
var manifest_sha256: String = ""
var match_seed: int = 216
var max_frames: int = 200000
var wall_seconds: int = 3600
var source_identity: Dictionary = {}
var request: Dictionary = {}
var result_details: Dictionary = {}
var cold_result_name: String = "cold-result.json"


func _ready() -> void:
	if not _configure():
		await _finish(false)
		return
	if mode == "run":
		await _run_game()
	else:
		_verify_cold()
	await _finish(true)


func _configure() -> bool:
	mode = _arg("mode", "run")
	profile = _arg("profile")
	run_id = _arg("run-id")
	output_dir = _arg("output-dir")
	manifest_path = _arg("source-manifest")
	manifest_sha256 = _arg("source-sha256").to_lower()
	cold_result_name = _arg("cold-result-name", "cold-result.json")
	check(mode in ["run", "cold"], "mode is run or cold")
	check(profile in PROFILES, "select exactly one supported report profile")
	check(not run_id.is_empty() and run_id.length() <= 120, "explicit run identity required")
	check(output_dir.is_absolute_path(), "explicit absolute output directory required")
	check(manifest_path.is_absolute_path(), "explicit absolute source-manifest path required")
	check(
		manifest_sha256.length() == 64 and manifest_sha256.is_valid_hex_number(),
		"explicit SHA256 source identity required"
	)
	check(
		(
			cold_result_name.begins_with("cold-result")
			and cold_result_name.ends_with(".json")
			and cold_result_name.get_file() == cold_result_name
			and not cold_result_name.contains("..")
		),
		"cold result is a safe new basename"
	)
	for field: String in ["seed", "max-frames", "wall-seconds"]:
		check(
			(
				_arg(field, {"seed": "216", "max-frames": "200000", "wall-seconds": "3600"}[field])
				. is_valid_int()
			),
			"integer " + field
		)
	if not failures.is_empty():
		return false
	match_seed = int(_arg("seed", "216"))
	max_frames = int(_arg("max-frames", "200000"))
	wall_seconds = int(_arg("wall-seconds", "3600"))
	check(match_seed >= 0 and match_seed <= 2147483647, "bounded match seed")
	check(max_frames > 0 and wall_seconds > 0, "positive finite observation limits")
	check(
		(
			FileAccess.file_exists(manifest_path)
			and FileAccess.get_sha256(manifest_path) == manifest_sha256
		),
		"source manifest bytes match explicit SHA256"
	)
	if not failures.is_empty():
		return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(manifest is Array and not manifest.is_empty(), "source manifest contains file rows")
	if not failures.is_empty():
		return false
	var verified: int = _verify_source_files(manifest)
	source_identity = {
		"manifest_path": manifest_path,
		"manifest_sha256": manifest_sha256,
		"verified_files": verified,
		"project_path": ProjectSettings.globalize_path("res://"),
		"test_script_sha256":
		FileAccess.get_sha256("res://src/tests/stadium_waterfall_animation_report_test.gd"),
		"retainer_script_sha256":
		FileAccess.get_sha256(
			"res://src/tests/stadium_waterfall_animation_report_retaining_runner.gd"
		)
	}
	if mode == "run":
		check(
			DirAccess.make_dir_recursive_absolute(output_dir) == OK, "output directory is writable"
		)
		for name: String in ARTIFACTS:
			check(
				not FileAccess.file_exists(output_dir.path_join(name)),
				"fresh run refuses old evidence: " + name
			)
	else:
		check(
			not FileAccess.file_exists(output_dir.path_join(cold_result_name)),
			"cold retry uses a new result name instead of overwriting evidence"
		)
	return failures.is_empty()


func _run_game() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(LEDGER_SEED, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				paid
				. commit(
					{
						"id": "report-land-" + tier,
						"rev": paid.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 40,
						"progress_through": 40,
						"price_version": 1
					}
				)
				. ok
			),
			"paid land " + tier
		)
	_buy(paid, "report-water", "ST-046", 1, "stadium_buy", 32)
	var layout: Dictionary
	if profile == PROFILES[0]:
		layout = StadiumWaterfallLiveItems.place(
			paid.view().stadium_draft,
			paid.construction(),
			WATER_COPY,
			"WF-LIVE-LF",
			0,
			paid.surface_owned()
		)
	else:
		_buy(paid, "report-plaza", "ST-112", 1, "stadium_buy", 34)
		_buy(paid, "report-standard", "ST-024", 23, "stadium_buy", 8)
		_buy(paid, "report-low", "ST-024-L", 23, "stadium_wall_piece", 1)
		layout = StadiumOutfieldPlazaItems.place(
			paid.view().stadium_draft,
			paid.construction(),
			PLAZA_COPY,
			"promenade_court",
			paid.surface_owned()
		)
		layout = StadiumOutfieldPlazaItems.place_occupant(layout, WATER_COPY, "PLAZA-W")
		layout = StadiumLowWallLayout.upgrade(layout, paid.surface_owned())
		var suggested: Dictionary = StadiumLowWallManifest.suggest(
			"low_flanks", "ST-024", paid.construction(), paid.wall_pieces().stock
		)
		check(suggested.ok, "exact paid low_flanks manifest")
		if not suggested.ok:
			return
		layout.low_wall = suggested.manifest
	layout = StadiumWaterfallAnimationLayout.select(layout, WATER_COPY, true)
	check(_valid(paid, layout).ok, "complete owned animation47 layout")
	if not failures.is_empty() or not _apply(paid, layout, profile):
		return
	var snapshot: Dictionary = StadiumWaterfallAnimationSnapshot.fixture(
		StadiumLayoutSnapshot.capture(paid), match_seed, 1
	)
	check(
		StadiumLayoutSnapshot.valid(snapshot) and StadiumLayoutSnapshot.matches(snapshot, paid),
		"exact paid fixture35"
	)
	check(_profile_matches(snapshot), "fixture belongs to selected profile")
	if not failures.is_empty():
		return
	var season: SeasonState = SeasonState.create(SEASON_SEED, false, true, true)
	season.opponents._format = 13
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	state.stadium = snapshot
	var identity: Dictionary = {
		"run_id": run_id,
		"profile": profile,
		"source": source_identity,
		"seed": match_seed,
		"snapshot_key": StadiumLayoutSnapshot.key(snapshot)
	}
	request = {
		"schema": 1,
		"identity": identity,
		"synthetic_paid_funding": true,
		"ledger_seed": LEDGER_SEED,
		"credits": credits,
		"progress": progress,
		"ledger": paid.to_data(),
		"snapshot": snapshot,
		"season_seed": SEASON_SEED,
		"opponent_format": 13,
		"away_roster": _roster(state.away_team),
		"home_roster": _roster(state.home_team),
		"max_frames": max_frames,
		"wall_seconds": wall_seconds,
		"output_dir": output_dir,
		"gameplay_injection": false,
		"target_hardware_qualification": false
	}
	_write("request.json", request)
	if not failures.is_empty():
		return
	var runner = RETAINING_RUNNER.new()
	runner.output_dir = output_dir
	runner.identity = identity.duplicate(true)
	add_child(runner)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	runner.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started: bool = runner.start(state, match_seed, PitchBatLab.FIELD_ID, paid)
	check(started, "normal PhysicalMatchRunner starts exact paid fixture35")
	var start_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	if started:
		check(
			StadiumWaterfallAnimationInstall.installed_bound(runner._lab, snapshot),
			"normal complete animation47 installer"
		)
		for frame in range(max_frames):
			await get_tree().physics_frame
			frames = frame + 1
			if not reports.is_empty() or not errors.is_empty():
				break
			if Time.get_ticks_msec() - start_ms >= wall_seconds * 1000:
				break
			if frames % 600 == 0 and is_instance_valid(runner._lab):
				print(
					(
						"WATERFALL47_REPORT_PROGRESS "
						+ JSON.stringify(
							{
								"run_id": run_id,
								"profile": profile,
								"frames": frames,
								"wall_elapsed_ms": Time.get_ticks_msec() - start_ms,
								"simulated_seconds": runner._elapsed,
								"phase": runner._lab._match_state.phase,
								"inning": runner._lab._match_state.inning,
								"top": runner._lab._match_state.top_half,
								"plate_appearance": runner._lab._match_state.plate_appearance_number
							}
						)
					)
				)
	if reports.is_empty() and errors.is_empty() and started:
		runner.retain("harness_observation_bound")
	check(
		reports.size() == 1 and errors.is_empty(),
		"genuine completed game, not a partial or forced result: " + str(errors)
	)
	check(
		runner.retained and runner.retention_errors.is_empty(),
		"raw candidate and core retained before cleanup: " + str(runner.retention_errors)
	)
	result_details = {
		"frames": frames,
		"wall_elapsed_ms": Time.get_ticks_msec() - start_ms,
		"runner_elapsed_seconds": runner._elapsed,
		"reports": reports.size(),
		"runner_errors": errors,
		"retention_errors": runner.retention_errors.duplicate(),
		"complete_game": reports.size() == 1
	}
	if reports.size() == 1:
		_write("final-report.json", reports[0])
		_verify_artifacts(false)
	runner.cancel()
	runner.queue_free()
	await get_tree().process_frame
	check(
		FileAccess.get_sha256(manifest_path) == manifest_sha256,
		"source manifest remained unchanged during the game"
	)
	if FileAccess.get_sha256(manifest_path) == manifest_sha256:
		_verify_source_files(JSON.parse_string(FileAccess.get_file_as_string(manifest_path)))


func _verify_cold() -> void:
	request = _read("request.json")
	var prior: Dictionary = _read("run-result.json")
	check(
		(
			prior.get("complete_game") == true
			and prior.get("reports") == 1
			and prior.get("runner_errors") == []
		),
		"cold input came from a genuine runner-emitted complete game"
	)
	if not failures.is_empty():
		return
	for name: String in prior.get("artifact_sha256", {}):
		check(
			prior.artifact_sha256[name] == _hash(name),
			"cold input bytes match game result: " + name
		)
	_verify_artifacts(true)
	result_details["complete_game"] = failures.is_empty()
	result_details["cold_process"] = true
	result_details["prior_run_passed"] = prior.get("passed", false)


func _verify_artifacts(cold_process: bool) -> void:
	var final_report: Dictionary = _read("final-report.json")
	var candidate: Dictionary = _read("candidate-raw.json")
	var core: Dictionary = _read("core-raw.json")
	var terminal: Dictionary = _read("terminal-raw.json")
	if not failures.is_empty():
		return
	var identity: Dictionary = request.get("identity", {})
	check(
		(
			identity.get("run_id") == run_id
			and identity.get("profile") == profile
			and identity.get("seed") == match_seed
		),
		"no unrelated run, profile, or seed reused"
	)
	check(
		ClubCareer.same(identity.get("source", {}), source_identity),
		"exact current source and harness identity"
	)
	check(
		ClubCareer.same(terminal.get("identity", {}), identity),
		"terminal capture belongs to this request"
	)
	check(
		terminal.get("natural_game_end") == true and terminal.get("label") == "natural_game_end",
		"retained natural GAME_END before cleanup"
	)
	check(
		(
			terminal.get("candidate_sha256") == _hash("candidate-raw.json")
			and terminal.get("core_sha256") == _hash("core-raw.json")
		),
		"untouched retained candidate/core bytes"
	)
	check(
		(
			request.get("synthetic_paid_funding") == true
			and request.get("gameplay_injection") == false
		),
		"funding and gameplay disclosure retained"
	)
	var snapshot: Dictionary = request.get("snapshot", {})
	check(
		(
			_profile_matches(snapshot)
			and StadiumLayoutSnapshot.key(snapshot) == identity.get("snapshot_key")
		),
		"exact selected immutable fixture identity"
	)
	var paid: ClubAssetLedger = ClubAssetLedger.from_data(
		request.get("ledger", {}),
		LEDGER_SEED,
		request.get("credits", []),
		request.get("progress", [])
	)
	check(
		paid != null and StadiumLayoutSnapshot.matches(snapshot, paid),
		"cold paid ledger reconstructs exact fixture authority"
	)
	check(
		(
			ClubCareer.same(terminal.get("snapshot", {}), snapshot)
			and ClubCareer.same(terminal.get("ledger", {}), request.get("ledger", {}))
		),
		"game retained original immutable snapshot and paid journal"
	)
	check(PhysicalMatchReport.valid(core), "raw core validates through normal report validator")
	check(
		PhysicalMatchReport.valid(candidate),
		"raw public capture validates through normal report validator"
	)
	check(
		PhysicalMatchReport.valid(final_report),
		"final JSON validates through normal report validator"
	)
	check(
		PhysicalStadiumReport.matches(final_report, snapshot),
		"normal report matcher binds exact fixture35"
	)
	check(
		ClubCareer.same(final_report, candidate),
		"runner-emitted final equals untouched pre-cleanup public capture"
	)
	check(
		ClubCareer.same(PhysicalStadiumReport.core(final_report), core),
		"normal unwrap preserves raw baseball core"
	)
	check(
		PhysicalStadiumContacts.valid(
			terminal.get("contacts", []), core.get("plays", []), snapshot
		),
		"raw contacts validate against original core and selected base"
	)
	if not failures.is_empty():
		return
	check(
		(
			final_report.version == 9
			and final_report.property.version == 35
			and final_report.property.layout.version == 47
		),
		"report9 and fixture35 carry animation47"
	)
	check(
		(
			final_report.seed == match_seed
			and ClubCareer.same(final_report.teams[0].roster, request.away_roster)
			and ClubCareer.same(final_report.teams[1].roster, request.home_roster)
		),
		"seed and original team rosters retained"
	)
	check(
		ClubCareer.same(final_report.surfaces, terminal.contacts),
		"final cold contacts equal untouched runtime contacts"
	)
	var before: Dictionary = {}
	for name: String in [
		"request.json",
		"candidate-raw.json",
		"core-raw.json",
		"terminal-raw.json",
		"final-report.json"
	]:
		before[name] = _hash(name)
	var bad: Dictionary = final_report.duplicate(true)
	bad.property.inventory.copies.erase(WATER_COPY)
	check(not PhysicalMatchReport.valid(bad), "tamper copy: missing exact paid waterfall refused")
	bad = final_report.duplicate(true)
	bad.property.layout.animation_base = 46 if profile == PROFILES[0] else 45
	check(not PhysicalMatchReport.valid(bad), "tamper copy: swapped retained base refused")
	bad = final_report.duplicate(true)
	bad.seed = (match_seed + 1) % 2147483648
	check(not PhysicalMatchReport.valid(bad), "tamper copy: foreign seed refused")
	bad = final_report.duplicate(true)
	bad.surfaces[0].play = -1
	check(
		not PhysicalMatchReport.valid(bad), "tamper copy: foreign contact-to-play identity refused"
	)
	if profile == PROFILES[1]:
		bad = final_report.duplicate(true)
		bad.property.wall_piece_inventory.stock.copies.erase(snapshot.layout.low_wall.copies[0])
		check(
			not PhysicalMatchReport.valid(bad), "tamper copy: missing exact low-wall owner refused"
		)
	var contact_counts: Dictionary = {}
	var source_control: bool = false
	for row_index in range(final_report.surfaces.size()):
		for event_index in range(final_report.surfaces[row_index].events.size()):
			var event: Dictionary = final_report.surfaces[row_index].events[event_index]
			var key: String = str(event.source) + ":" + str(event.role)
			contact_counts[key] = int(contact_counts.get(key, 0)) + 1
			if not source_control:
				bad = final_report.duplicate(true)
				bad.surfaces[row_index].events[event_index].source = "report-test-invalid-source"
				check(
					not PhysicalMatchReport.valid(bad),
					"tamper copy: naturally observed contact source refused"
				)
				source_control = true
	for name: String in before:
		check(
			before[name] == _hash(name), "tamper controls left source artifact unchanged: " + name
		)
	result_details.merge(
		{
			"cold_process": cold_process,
			"json_round_trip_verified": true,
			"snapshot_key": identity.snapshot_key,
			"observed_contacts": contact_counts,
			"natural_contact_source_control_exercised": source_control,
			"trap_or_specific_contact_coverage_claimed": false,
			"artifact_sha256": before
		},
		true
	)


func _profile_matches(snapshot: Dictionary) -> bool:
	if not StadiumWaterfallAnimationSnapshot.valid(snapshot) or snapshot.version != 35:
		return false
	var layout: Dictionary = snapshot.layout
	if layout.waterfall_motion != [WATER_COPY]:
		return false
	if profile == PROFILES[0]:
		return (
			layout.animation_base == 45
			and layout.live_waterfalls == [{"copy": WATER_COPY, "site": "WF-LIVE-LF"}]
		)
	return (
		layout.animation_base == 46
		and layout.live_waterfalls.is_empty()
		and layout.low_wall.profile == "low_flanks"
		and layout.outfield_plaza.size() == 1
		and layout.outfield_plaza[0].copy == PLAZA_COPY
		and layout.outfield_plaza[0].recipe == "promenade_court"
		and layout.outfield_plaza[0].occupants == [{"copy": WATER_COPY, "site": "PLAZA-W"}]
	)


func _verify_source_files(manifest: Array) -> int:
	var verified: int = 0
	for row: Variant in manifest:
		if (
			not row is Dictionary
			or not row.get("path") is String
			or not row.get("sha256") is String
		):
			check(false, "source manifest has a malformed row")
			return verified
		var path: String = row.path
		if path.is_absolute_path() or path.contains(".."):
			check(false, "source manifest paths must stay in this project")
			return verified
		if FileAccess.get_sha256("res://" + path) != row.sha256:
			check(false, "source differs from declared manifest: " + path)
			return verified
		verified += 1
	return verified


func _buy(
	paid: ClubAssetLedger, id: String, item: String, quantity: int, op: String, version: int
) -> void:
	var purchased: Dictionary = paid.commit(
		{
			"id": id,
			"rev": paid.revision(),
			"op": op,
			"item": item,
			"quantity": quantity,
			"price_version": version,
			"through": 40,
			"progress_through": 40
		}
	)
	check(purchased.ok, "synthetically funded exact purchase " + item + ": " + str(purchased.error))


func _roster(team: TeamMatchState) -> Array[String]:
	var ids: Array[String] = []
	for player: PlayerMatchState in team.roster:
		ids.append(String(player.definition.id))
	return ids


func _arg(name: String, fallback: String = "") -> String:
	var prefix: String = "--" + name + "="
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.trim_prefix(prefix)
	return fallback


func _hash(name: String) -> String:
	return FileAccess.get_sha256(output_dir.path_join(name))


func _read(name: String) -> Dictionary:
	var value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(output_dir.path_join(name))
	)
	check(value is Dictionary, "read JSON object " + name)
	return value if value is Dictionary else {}


func _write(name: String, value: Variant) -> void:
	var path: String = output_dir.path_join(name)
	check(not FileAccess.file_exists(path), "never overwrite evidence " + name)
	if FileAccess.file_exists(path):
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "open output " + name)
	if file == null:
		return
	file.store_string(JSON.stringify(value, "", true, true))
	file.flush()
	check(file.get_error() == OK, "persist output " + name)
	file.close()


func _finish(write_result: bool) -> void:
	var summary: Dictionary = {
		"schema": 1,
		"mode": mode,
		"run_id": run_id,
		"profile": profile,
		"source": source_identity,
		"seed": match_seed,
		"checks": checks,
		"failures": failures.duplicate(),
		"passed": failures.is_empty(),
		"complete_game": false,
		"synthetic_paid_funding": true,
		"gameplay_injection": false,
		"output_dir": output_dir,
		"target_hardware_qualification": false
	}
	summary.merge(result_details, true)
	if write_result:
		_write("run-result.json" if mode == "run" else cold_result_name, summary)
	summary.checks = checks
	summary.failures = failures.duplicate()
	summary.passed = failures.is_empty()
	print("WATERFALL47_REPORT_RESULT " + JSON.stringify(summary))
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)
