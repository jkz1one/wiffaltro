extends Node
# gdlint: disable=max-returns
## Retained Yard regression and actual default-home history; isolated reordered matcher only.

const INPUT_SHA: String = "777fcfdbc3e228f9d521afd61663efe60801f555388abaa22218809b527425b6"
const INPUT_BYTES: int = 626931
const CANDIDATE_SHA: String = "461d6d656f5a6defe94e3272b13da29ec74012037a0974dfaa2522aa95298762"
const CANDIDATE_BYTES: int = 646054

const HOME_SHA: String = "a16b61a7aa065e518e4a38becd6262ead3730408607c89da33d97203a6d2a0f9"
const HOME_BYTES: int = 922796

var _actual_pending: SeasonState
var _actual_candidate: SeasonState
var _actual_expected: Dictionary
var _checks: int = 0
var _failed: Array[String] = []
var _output: String
var _proofs: Dictionary = {}
var _refused: Array[String] = []
var _equalities: Dictionary = {}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_usec()
	_output = _arg("output")
	_probe()
	if _failed.is_empty():
		_home_probe()
	var summary: Dictionary = {
		"schema": "STANDARD-BASE-HOME-ORDER-v1",
		"runtime": _arg("runtime"), "execution": _arg("execution"),
		"nonce": _arg("nonce"), "pid": OS.get_process_id(),
		"input_sha256": _arg("input-sha"), "input_bytes": INPUT_BYTES,
		"candidate_sha256": CANDIDATE_SHA, "candidate_bytes": CANDIDATE_BYTES,
		"input_path": _arg("input"), "candidate_path": _arg("candidate"),
		"home_path": _arg("home"), "home_sha256": HOME_SHA, "home_bytes": HOME_BYTES,
		"home_control": "actual default-home history; isolated reordered away-proof matcher only",
		"checks": _checks, "failures": _failed.size(), "failed": _failed,
		"completed_games": 0, "live_season_written": false,
		"proofs": _proofs, "refused": _refused, "equalities": _equalities,
		"two_order_control": "isolated helper; no two-game history claim",
		"wall_seconds": float(Time.get_ticks_usec() - started) / 1000000.0
	}
	_write("summary.json", summary)
	print("STANDARD_BASE_HOME_ORDER ", JSON.stringify(summary, "", true, true))
	get_tree().quit(0 if _failed.is_empty() else 1)


func _probe() -> void:
	var input: String = _arg("input")
	var candidate_path: String = _arg("candidate")
	if not _check(input.is_absolute_path() and candidate_path.is_absolute_path()
		and _output.is_absolute_path() and input != candidate_path and input != _output
		and DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty()
		and DirAccess.get_directories_at(_output).is_empty(), "fresh copied-input arguments"):
		return
	if not _check(FileAccess.get_sha256(input) == INPUT_SHA and _arg("input-sha") == INPUT_SHA
		and FileAccess.get_file_as_bytes(input).size() == INPUT_BYTES, "exact pending input"):
		return
	if not _check(FileAccess.get_sha256(candidate_path) == CANDIDATE_SHA
		and FileAccess.get_file_as_bytes(candidate_path).size() == CANDIDATE_BYTES,
		"exact retained refused candidate"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(input))
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate_path))
	if not _check(data is Dictionary and expected is Dictionary and data.version == 63
		and data.seed == 7 and data.results.is_empty() and data.physical.pending.reports.size() == 2
		and expected.results.size() == 1 and expected.physical.reports.size() == 2
		and expected.physical.pending.is_empty(), "actual three-game retained operands"):
		return
	var restored: SeasonState = SeasonSave._decode(data)
	if not _check(restored != null, "retained pending decode"):
		return
	if not _equal("pending_restore", SeasonSave.snapshot(restored), data) \
		or not _retain("restored.json", SeasonSave.snapshot(restored)):
		return
	var projection: Dictionary = SeasonRoundSettlement.project(restored)
	var candidate: SeasonState = projection.get("candidate")
	if not _check(not projection.has("error") and not projection.has("fixture")
		and candidate != null and candidate.results.size() == 3, "ordinary complete projection"):
		return
	var proposed: Dictionary = SeasonSave.snapshot(candidate).duplicate(true)
	if not _equal("projected_candidate", proposed, expected) \
		or not _retain("candidate.json", proposed):
		return
	var decoded: SeasonState = SeasonSave._decode(proposed)
	if not _check(decoded != null, "actual candidate now fully decodes"):
		return
	_actual_pending = restored
	_actual_candidate = decoded
	_actual_expected = proposed.duplicate(true)
	if not _equal("decoded_candidate", SeasonSave.snapshot(decoded), proposed) \
		or not _retain("decoded.json", SeasonSave.snapshot(decoded)):
		return
	var canonical: Variant = JSON.parse_string(JSON.stringify(proposed, "", true, true))
	if not _check(SeasonSave._decode(canonical) != null, "full precision canonical candidate decode"):
		return
	var historical: Array = proposed.build.roster.duplicate()
	var recorded: Array = proposed.results[0].yard_evidence.teams[0].duplicate()
	if not _check(recorded != historical and recorded == data.lineup
		and proposed.results[0].away == 0 and proposed.results[0].away_runs == 0
		and proposed.results[0].home_runs == 8, "real reordered historical batting order"):
		return
	# Only current legal order changes; the one actual historical result remains byte-equivalent.
	var alternate: Dictionary = proposed.duplicate(true)
	var first: Variant = alternate.lineup[0]
	alternate.lineup[0] = alternate.lineup[1]
	alternate.lineup[1] = first
	var alternate_decoded: SeasonState = SeasonSave._decode(alternate)
	if not _check(alternate_decoded != null, "different legal current order still restores history"):
		return
	if not _equal("alternate_current", SeasonSave.snapshot(alternate_decoded), alternate) \
		or not _retain("alternate.json", alternate):
		return
	if not _equal("historical_result_preserved", alternate.results, proposed.results):
		return
	# Synthetic helper operands only. These are never decoded or committed as a season history.
	var second: Array = recorded.duplicate()
	second.reverse()
	var first_control: Dictionary = {"yard_evidence": {"teams": [recorded, historical]}}
	var second_control: Dictionary = {"yard_evidence": {"teams": [historical, second]}}
	var first_order: Array = SeasonSave._yard_replay_roster(first_control, historical, false)
	var second_order: Array = SeasonSave._yard_replay_roster(second_control, historical, true)
	if not _check(first_order == recorded and second_order == second and first_order != second_order,
		"isolated two-result order selection never uses final current lineup"):
		return
	second_control.yard_evidence.teams[1][0] = "unit-mutated"
	if not _check(second_order[0] != "unit-mutated" and first_order == recorded,
		"separate historical orders do not alias source or each other"):
		return
	var invalid: Dictionary = proposed.duplicate(true)
	invalid.results[0].yard_evidence.teams[0][1] = invalid.results[0].yard_evidence.teams[0][0]
	_reject(invalid, "duplicate_historical_player")
	invalid = proposed.duplicate(true)
	invalid.results[0].yard_evidence.teams[0][0] = "player.unknown"
	_reject(invalid, "unknown_historical_player")
	invalid = proposed.duplicate(true)
	invalid.results[0].yard_evidence.teams[0].pop_back()
	_reject(invalid, "missing_historical_player")
	invalid = proposed.duplicate(true)
	invalid.results[0].yard_evidence.teams[0].reverse()
	_reject(invalid, "order_disagrees_with_complete_evidence")
	invalid = proposed.duplicate(true)
	invalid.starter = invalid.fielder
	_reject(invalid, "same_current_roles")
	invalid = proposed.duplicate(true)
	invalid.starter = 4
	_reject(invalid, "out_of_range_starter")
	invalid = proposed.duplicate(true)
	invalid.fielder = -1
	_reject(invalid, "out_of_range_fielder")
	_check(FileAccess.get_sha256(input) == INPUT_SHA
		and FileAccess.get_sha256(candidate_path) == CANDIDATE_SHA
		and ClubCareer.same(proposed, expected), "both inputs and retained candidate remain exact")


func _home_probe() -> void:
	var home_path: String = _arg("home")
	if not _check(home_path.is_absolute_path() and home_path != _arg("input")
		and home_path != _arg("candidate") and home_path != _output, "independent old-home input"):
		return
	if not _check(FileAccess.get_sha256(home_path) == HOME_SHA
		and FileAccess.get_file_as_bytes(home_path).size() == HOME_BYTES,
		"exact accepted old-home input"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(home_path))
	if not _check(data is Dictionary and data.version == 63 and data.seed == 6
		and data.results.size() == 2 and data.physical.reports.size() == 4
		and data.results[1].id == 3 and data.results[1].home == 0
		and data.results[1].away_runs == 12 and data.results[1].home_runs == 4
		and not data.results[1].has("yard_evidence") and not data.results[1].has("pool_evidence")
		and data.results[1].ai_tactics["4"].opposition.roster == data.build.roster,
		"actual default-order home result, not manufactured reordered-home history"):
		return
	var decoded: SeasonState = SeasonSave._decode(data)
	if not _check(decoded != null, "actual old default-home history fully decodes"):
		return
	if not _equal("home_restore", SeasonSave.snapshot(decoded), data) \
		or not _retain("home-restored.json", SeasonSave.snapshot(decoded)):
		return
	var alternate: Dictionary = data.duplicate(true)
	var first: Variant = alternate.lineup[0]
	alternate.lineup[0] = alternate.lineup[1]
	alternate.lineup[1] = first
	var alternate_decoded: SeasonState = SeasonSave._decode(alternate)
	if not _check(alternate_decoded != null, "legal current order does not replace old home order"):
		return
	if not _equal("home_alternate_current", SeasonSave.snapshot(alternate_decoded), alternate) \
		or not _retain("home-alternate.json", alternate):
		return
	if not _equal("home_history_preserved", alternate.results, data.results):
		return
	# This uses the actual new AWAY proof as an isolated matcher operand, not a home result.
	var actual: Dictionary = _actual_expected.results[0]
	var proof: Dictionary = actual.ai_tactics["5"].duplicate(true)
	var historical: Array = _actual_expected.build.roster.duplicate()
	var ordered: Array = SeasonSave._home_replay_roster(proof, historical)
	if not _check(ordered == actual.yard_evidence.teams[0] and ordered != historical,
		"isolated helper selects actual reordered four-player evidence"):
		return
	_actual_pending._heat_replay_team = PhysicalHeatEvidence.replay_team(
		_actual_candidate.build, int(actual.id), ordered)
	if not _check(_actual_pending._heat_replay_team != null
		and PhysicalTacticalEvidence.human_matches(_actual_pending, _actual_pending.pending_fixture(),
			proof, actual.performance, actual.get("tactics", [])),
		"actual reordered away proof retains complete Base Heat and stance matcher"):
		return
	proof.opposition.roster[0] = "unit-mutated"
	if not _check(ordered[0] != "unit-mutated"
		and actual.ai_tactics["5"].opposition.roster == ordered,
		"home order reconstruction never aliases evidence"):
		return
	var invalid: Dictionary = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].opposition.roster[1] = \
		invalid.results[1].ai_tactics["4"].opposition.roster[0]
	_reject(invalid, "home_duplicate_historical_player")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].opposition.roster[0] = "player.unknown"
	_reject(invalid, "home_unknown_historical_player")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].opposition.roster.pop_back()
	_reject(invalid, "home_missing_historical_player")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].opposition.roster.reverse()
	_reject(invalid, "home_order_disagrees_with_actual_stances")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].version = {}
	_reject(invalid, "home_dictionary_proof_version")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].version = []
	_reject(invalid, "home_array_proof_version")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].version = "5"
	_reject(invalid, "home_string_proof_version")
	invalid = data.duplicate(true)
	invalid.results[1].ai_tactics["4"].opposition = []
	_reject(invalid, "home_wrong_opposition_type")
	_check(FileAccess.get_sha256(home_path) == HOME_SHA
		and FileAccess.get_sha256(_arg("input")) == INPUT_SHA
		and FileAccess.get_sha256(_arg("candidate")) == CANDIDATE_SHA,
		"all three retained input files remain unchanged")


func _equal(label: String, a: Variant, b: Variant) -> bool:
	var same: bool = ClubCareer.same(a, b)
	_equalities[label] = same
	return _check(same, label)


func _reject(value: Dictionary, label: String) -> void:
	var refused: bool = SeasonSave._decode(value) == null
	if refused:
		_refused.append(label)
	_check(refused, "refuse " + label)


func _arg(key: String) -> String:
	var prefix: String = "--decode-" + key + "="
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with(prefix):
			return value.substr(prefix.length())
	return ""


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failed.append(label)
		push_error(label)
	return condition


func _retain(name: String, value: Dictionary) -> bool:
	var ok: bool = _write(name, value)
	if ok:
		_proofs[name] = FileAccess.get_sha256(_output.path_join(name))
	return _check(ok, "retain " + name)


func _write(name: String, value: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "", true, true))
	file.close()
	return true
