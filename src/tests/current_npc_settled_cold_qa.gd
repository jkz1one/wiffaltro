extends Node
## Cold read-only final acceptance of actual settled round; creates no app/lab/game.

## Additions are read-only guards around the original 11 checks; no app/lab/game is created.
const CurrentPublicChecks = preload("res://src/tests/stadium_npc_base_public_seed301_checks.gd")
const MAX_INPUT_BYTES: int = 8 * 1024 * 1024
const MAX_CONTEXT_BYTES: int = 64 * 1024
const EXPECTED_ORIGINAL_CHECKS: int = 11
const EXPECTED_ADDED_CHECKS: int = 17
const INPUT_NAMES: Array[String] = ["context.json", "pending.json", "settled.json"]
const PRODUCER_FILES: Array[String] = [
	"base-public-predraft.json",
	"base-public-pending.json",
	"base-public-report17.json",
	"base-public-human-evidence.json",
	"base-public-ai-0.json",
	"base-public-ai-1.json",
	"base-public-final-save.json",
	"base-public-round-summary.json"
]
const FRESH_CONTEXT: Dictionary = {
	"season_seed": 301,
	"run": 1,
	"venue_ordinal": 0,
	"league": "standard",
	"tier": 0,
	"difficulty": 1,
	"initial_cash": 0,
	"initial_bank_events": 0,
	"initial_build_events": 0,
	"initial_sponsors": 0,
	"initial_picks": 0,
	"initial_results": 0
}
# These are expected journal commands, never committed or assigned into loaded state.
# Initial context has zero events; the genuine pending human game follows this exact prefix.
const PENDING_BUILD_EVENTS: Array[Dictionary] = [
	{"id": "pregame:0", "rev": 0, "op": "pregame", "game": 0},
	{"id": "attempt:1", "rev": 1, "op": "match_inventory", "game": 0}
]
const ADDED_IDS: Array[String] = [
	"external_context_inputs",
	"nested_pending_settled_shape",
	"primary_pending_restore",
	"exact_pending_snapshot",
	"pending_seed301_run1_ordinal0",
	"pending_unsettled_stage",
	"pending_human_bound",
	"fresh_base_reward_context",
	"stripped_human_rejected",
	"primary_settled_restore",
	"settled_fixed_context",
	"retained_human_binding",
	"settled_preserves_home_assignment_assets",
	"ai_fixture1_report17",
	"ai_fixture2_report17",
	"all_input_bytes_and_names_unchanged",
	"installed_source_digest_unchanged"
]
var added_checks: int = 0
var checks: int = 0
var failures: Array[String] = []

var _expected_source_sha256: String = ""
var _expected_producer_sha256: String = ""
var _expected_helper_sha256: String = ""
var _expected_producer_bootstrap_sha256: String = ""
var _context: Dictionary = {}
var _input_hashes: Dictionary = {}
var _input_sizes: Dictionary = {}
var _original_outcomes: Array[Dictionary] = []
var _added_outcomes: Dictionary = {}
var _restored_pending: SeasonState



func _ready() -> void:
	var folder: String = OS.get_environment("NPC_COLD_INPUT")
	var output: String = OS.get_environment("NPC_COLD_OUTPUT")
	if not folder.is_absolute_path() or not output.is_absolute_path():
		get_tree().quit(2)
		return
	if not _extra(_input_context_bound(folder, output), "external_context_inputs"):
		get_tree().quit(1)
		return
	if not _extra(_safe_shapes(folder), "nested_pending_settled_shape"):
		get_tree().quit(1)
		return
	var path: String = folder.path_join("settled.json")
	var before_hash: String = FileAccess.get_sha256(path)
	SeasonSave.path = path
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var pending: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(folder.path_join("pending.json"))
	)
	if not _verify_pending(pending, folder):
		get_tree().quit(1)
		return
	SeasonSave.path = path
	var season: SeasonState = SeasonSave.restore()
	_check(season != null, "fresh-process decode of actual final save")
	if not _verify_settled(season, pending):
		get_tree().quit(1)
		return
	if season != null:
		_check(
			ClubCareer.same(expected, SeasonSave.snapshot(season)), "exact decoded settled state"
		)
		_check(
			season.results.size() == 3 and season.player_results.size() == 1,
			"one round three genuine results"
		)
		_check(
			season.physical.pending.is_empty() and season.physical.reports.size() == 2,
			"both opponent reports and no pending game"
		)
		_check(season.round_index == 1, "round advanced exactly once")
		var result: Dictionary = season.player_results[0]
		_check(
			ClubCareer.same(result.yard_evidence, pending.physical.pending.human[16]),
			"original genuine human terminal evidence retained"
		)
		_check(
			season.cash() == (18 if SeasonState._winner(result) == 0 else 12),
			"ordinary reward exactly once"
		)
		for row: Dictionary in season.physical.reports:
			var helper_bound: bool = CurrentPublicChecks.report_bound(
				row.report, season, int(row.fixture)
			)
			var fixture_whole: bool = SeasonOwnership._whole(row.fixture, 1, 2)
			var legacy_membership: bool = row.fixture in [1, 2]
			print(
				"NPC_PUBLIC_SEED301_COLD_R4_AI_DIAGNOSTIC ",
				JSON.stringify(
					{
						"fixture": row.fixture,
						"fixture_type": typeof(row.fixture),
						"report_bound": helper_bound,
						"fixture_whole": fixture_whole,
						"legacy_membership": legacy_membership
					}
				)
			)
			_extra(helper_bound and fixture_whole, "ai_fixture%d_report17" % int(row.fixture))
			var fixture: Dictionary = SeasonVenues.fixture_for_id(season, int(row.fixture))
			_check(
				(
					PhysicalMatchReport.valid(row.report)
					and PhysicalStadiumReport.matches(
						row.report, StadiumLayoutSnapshot.for_fixture(season, fixture)
					)
				),
				"actual opponent report binds assigned venue"
			)
		_check(
			(
				not season.record_player_result(
					result.id,
					result.away_runs,
					result.home_runs,
					result.performance,
					[],
					[],
					{},
					[],
					[],
					{},
					{},
					[],
					{},
					[],
					result.property,
					null,
					result.yard_evidence
				)
				and ClubCareer.same(expected, SeasonSave.snapshot(season))
			),
			"cold duplicate result cannot pay again"
		)
	_check(FileAccess.get_sha256(path) == before_hash, "original settled bytes unchanged")
	_extra(_inputs_unchanged(folder), "all_input_bytes_and_names_unchanged")
	_extra(
		StadiumPoolPartyAssetIntegrity.source_sha256() == _expected_source_sha256,
		"installed_source_digest_unchanged"
	)
	if (
		checks != EXPECTED_ORIGINAL_CHECKS
		or added_checks != EXPECTED_ADDED_CHECKS
		or _original_outcomes.size() != EXPECTED_ORIGINAL_CHECKS
		or _added_outcomes.size() != EXPECTED_ADDED_CHECKS
	):
		failures.append("exact original and added check accounting")
		push_error("exact original and added check accounting")
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(
		JSON.stringify(
			{
				"schema": "NPC-PUBLIC-SEED301-COLD-SUPPLEMENT-v1",
				"checks": checks,
				"added_checks": added_checks,
				"total_checks": checks + added_checks,
				"original_outcomes": _original_outcomes,
				"added_outcomes": _added_outcomes,
				"input_hashes": _input_hashes,
				"input_sizes": _input_sizes,
				"source_sha256": _expected_source_sha256,
				"execution": _context.execution,
				"nonce": _context.nonce,
				"producer_pid": _context.producer_pid,
				"producer_audit_sha256": _context.producer_audit_sha256,
				"producer_controller_sha256": _context.producer_controller_sha256,
				"original_default_credit": false,
				"failures": failures,
				"input_sha256": before_hash,
				"new_games": 0,
				"new_live_authority": false
			}
		)
	)
	file.close()
	print("CURRENT_NPC_SETTLED_COLD checks=", checks, " failures=", failures.size())
	print(
		(
			(
				"NPC_PUBLIC_SEED301_COLD_R4_SUPPLEMENT original_checks=%d added_checks=%d "
				+ "total_checks=%d failures=%d"
			)
			% [checks, added_checks, checks + added_checks, failures.size()]
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	_original_outcomes.append({"index": checks, "label": message, "ok": ok})
	if not ok:
		failures.append(message)
		push_error(message)


func _extra(ok: bool, identity: String) -> bool:
	added_checks += 1
	if _added_outcomes.has(identity) or not ADDED_IDS.has(identity):
		ok = false
	_added_outcomes[identity] = ok
	if not ok:
		failures.append("supplement: " + identity)
		push_error("supplement: " + identity)
	return ok


func _hex(value: Variant, width: int) -> bool:
	if not value is String or value.length() != width:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _read_dictionary(path_value: String, cap: int) -> Dictionary:
	var file_value: FileAccess = FileAccess.open(path_value, FileAccess.READ)
	if file_value == null:
		return {}
	var size: int = file_value.get_length()
	if size < 1 or size > cap:
		file_value.close()
		return {}
	var bytes: PackedByteArray = file_value.get_buffer(size)
	file_value.close()
	if bytes.size() != size:
		return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	return parsed if parsed is Dictionary else {}


func _input_listing(folder: String) -> bool:
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		return false
	directory.include_hidden = true
	if not directory.get_directories().is_empty():
		return false
	var names: PackedStringArray = directory.get_files()
	names.sort()
	if names != PackedStringArray(INPUT_NAMES):
		return false
	for name: String in INPUT_NAMES:
		if directory.is_link(name):
			return false
	return true


func _summary_valid(value: Variant) -> bool:
	if not value is Dictionary or not value.get("terminal") is Dictionary:
		return false
	return (
		value.get("schema") == "BASE-PUBLIC-ROUND-R1-v1"
		and value.get("pid") == _context.get("producer_pid")
		and value.get("runtime") == _expected_source_sha256
		and value.get("execution") == _context.get("execution")
		and value.get("nonce") == _context.get("nonce")
		and value.get("checks") == 35
		and value.get("failures") == 0
		and value.get("failed") == []
		and value.get("season_seed") == 301
		and value.get("fixture") == 0
		and value.get("assigned_owner") == 5
		and value.get("venue_ordinal") == 0
		and value.get("assignment_version") == 3
		and value.get("family_ids") == ["AY-01", "AE-01", "AC-01"]
		and value.get("round_reports") == 3
		and value.get("human_starts") == 1
		and value.get("ai_reports") == 2
		and value.terminal.get("report_version") == 17
		and value.get("settled") == true
		and value.get("five_park_allocation_complete") == true
		and value.get("manual_input_qualified") == false
		and value.get("performance_qualified") == false
		and value.get("independent_seed47_replay") == false
	)


func _input_context_bound(folder: String, output: String) -> bool:
	# Values come only from the independently reviewed external controller manifest.
	# Never infer expected identity from current bytes or from the input context.
	_expected_source_sha256 = OS.get_environment("NPC_COLD_EXPECTED_SOURCE_SHA256")
	_expected_producer_sha256 = OS.get_environment("NPC_COLD_EXPECTED_PRODUCER_SHA256")
	_expected_helper_sha256 = OS.get_environment("NPC_COLD_EXPECTED_HELPER_SHA256")
	_expected_producer_bootstrap_sha256 = OS.get_environment(
		"NPC_COLD_EXPECTED_PRODUCER_BOOTSTRAP_SHA256"
	)
	for expected: String in [
		_expected_source_sha256,
		_expected_producer_sha256,
		_expected_helper_sha256,
		_expected_producer_bootstrap_sha256
	]:
		if not _hex(expected, 64):
			return false
	if (
		(
			FileAccess.get_sha256("res://src/tests/stadium_npc_base_public_round_test.gd")
			!= _expected_producer_sha256
		)
		or (
			FileAccess.get_sha256("res://src/tests/stadium_npc_base_public_seed301_checks.gd")
			!= _expected_helper_sha256
		)
	):
		return false
	# The admitted controller MUST first prove regular files with owned O_NOFOLLOW
	# descriptors and copy exact bytes. FileAccess/DirAccess do not replace that proof.
	if (
		folder.simplify_path() != folder
		or output.simplify_path() != output
		or output == folder
		or output.begins_with(folder + "/")
		or FileAccess.file_exists(output)
		or not _input_listing(folder)
	):
		return false
	var wanted: String = OS.get_environment("NPC_COLD_CONTEXT_SHA256")
	if not _hex(wanted, 64) or FileAccess.get_sha256(folder.path_join("context.json")) != wanted:
		return false
	_context = _read_dictionary(folder.path_join("context.json"), MAX_CONTEXT_BYTES)
	if (
		not SeasonOwnership._keys(
			_context,
			[
				"schema",
				"source_sha256",
				"execution",
				"nonce",
				"producer_pid",
				"producer_sha256",
				"helper_sha256",
				"producer_bootstrap_sha256",
				"producer_controller_sha256",
				"producer_audit_sha256",
				"files",
				"fresh_context",
				"audit",
				"producer_summary"
			]
		)
		or _context.get("schema") != "NPC-PUBLIC-SEED301-COLD-CONTEXT-v1"
		or _context.get("source_sha256") != _expected_source_sha256
		or not _hex(_context.get("execution"), 64)
		or not _hex(_context.get("nonce"), 32)
		or _context.execution != OS.get_environment("NPC_COLD_EXECUTION")
		or _context.nonce != OS.get_environment("NPC_COLD_NONCE")
		or not SeasonOwnership._whole(_context.get("producer_pid"), 2, 2147483647)
		or _context.get("producer_sha256") != _expected_producer_sha256
		or _context.get("helper_sha256") != _expected_helper_sha256
		or _context.get("producer_bootstrap_sha256") != _expected_producer_bootstrap_sha256
		or not _hex(_context.get("producer_controller_sha256"), 64)
		or (
			_context.producer_controller_sha256
			!= OS.get_environment("NPC_PRODUCER_CONTROLLER_SHA256")
		)
		or not _hex(_context.get("producer_audit_sha256"), 64)
		or _context.producer_audit_sha256 != OS.get_environment("NPC_PRODUCER_AUDIT_SHA256")
		or not _context.get("files") is Dictionary
		or not ClubCareer.same(_context.get("fresh_context"), FRESH_CONTEXT)
		or not ClubCareer.same(
			_context.get("audit"),
			{
				"natural_exit": 0,
				"producer_group_empty": true,
				"descendant_groups_empty": true,
				"source_guard": true,
				"cache_guard": true,
				"output_audit": true,
				"error_lines": 0,
				"timed_out": false,
				"size_stopped": false
			}
		)
		or not _summary_valid(_context.get("producer_summary"))
	):
		return false
	return _input_context_file_set(folder, wanted)


func _input_context_file_set(folder: String, wanted: String) -> bool:
	var names: Array = _context.files.keys()
	names.sort()
	var required: Array = PRODUCER_FILES.duplicate()
	required.sort()
	if names != required:
		return false
	for name: String in PRODUCER_FILES:
		var record: Variant = _context.files[name]
		if (
			not record is Dictionary
			or not SeasonOwnership._keys(record, ["bytes", "sha256"])
			or not SeasonOwnership._whole(record.get("bytes"), 1, MAX_INPUT_BYTES)
			or not _hex(record.get("sha256"), 64)
		):
			return false
	return _input_context_files(folder, wanted)


func _input_context_files(folder: String, wanted: String) -> bool:
	for name: String in INPUT_NAMES:
		var file_value: FileAccess = FileAccess.open(folder.path_join(name), FileAccess.READ)
		if file_value == null:
			return false
		var size: int = file_value.get_length()
		file_value.close()
		if size < 1 or size > (MAX_CONTEXT_BYTES if name == "context.json" else MAX_INPUT_BYTES):
			return false
		_input_sizes[name] = size
		_input_hashes[name] = FileAccess.get_sha256(folder.path_join(name))
		if not _hex(_input_hashes[name], 64):
			return false
		if name != "context.json":
			var original: String = (
				"base-public-pending.json"
				if name == "pending.json"
				else "base-public-final-save.json"
			)
			if (
				_input_hashes[name] != _context.files[original].sha256
				or size != _context.files[original].bytes
			):
				return false
	return (
		_input_hashes["context.json"] == wanted
		and StadiumPoolPartyAssetIntegrity.source_sha256() == _expected_source_sha256
	)


func _safe_shapes(folder: String) -> bool:
	var pending_value: Dictionary = _read_dictionary(
		folder.path_join("pending.json"), MAX_INPUT_BYTES
	)
	var settled_value: Dictionary = _read_dictionary(
		folder.path_join("settled.json"), MAX_INPUT_BYTES
	)
	for raw: Dictionary in [pending_value, settled_value]:
		if (
			raw.get("version") != 63
			or raw.get("seed") != 301
			or not raw.get("results") is Array
			or not raw.get("physical") is Dictionary
			or not raw.physical.get("reports") is Array
			or not raw.physical.get("pending") is Dictionary
			or not raw.get("build") is Dictionary
			or not raw.get("career") is Dictionary
			or not raw.get("npc_venues") is Dictionary
			or not raw.get("final_venue") is Dictionary
		):
			return false
	# Explicit shape gates precede EVERY human[16] and settled result index in this derivative.
	var stage: Dictionary = pending_value.physical.pending
	if (
		not stage.get("human") is Array
		or stage.human.size() != 17
		or not stage.human[16] is Dictionary
		or not stage.human[16].get("property") is Dictionary
		or not SeasonRoundSettlement._shape(stage, true, true, false, true)
		or not pending_value.results.is_empty()
		or not pending_value.physical.reports.is_empty()
		or not stage.reports.is_empty()
		or settled_value.results.size() != 1
		or not settled_value.results[0] is Dictionary
		or not settled_value.results[0].get("yard_evidence") is Dictionary
		or not settled_value.results[0].get("performance") is Dictionary
		or not settled_value.results[0].get("property") is String
		or not settled_value.physical.pending.is_empty()
		or settled_value.physical.reports.size() != 2
	):
		return false
	for index: int in range(2):
		var row: Variant = settled_value.physical.reports[index]
		if not SeasonPhysicalFixtures.envelope(row) or row.fixture != index + 1:
			return false
	return true


func _fixed_context(season: SeasonState) -> bool:
	return (
		season != null
		and CurrentPublicChecks.assignment(season)
		and season.difficulty == 1
		and season.career != null
		and season.career.current == 1
		and season.career.runs.size() == 1
		and season.career.active_tier() == 0
		and season.league_rules.is_empty()
		and season.inventory_rules.is_empty()
		and CurrentPublicChecks.ordinary_final(season)
		and season.owned_surface_night.is_empty()
		and season.build != null
		and season.build._bank != null
		and season.build._pricing_rule.is_empty()
		and season.build._sponsor_rule.is_empty()
		and season.build._bank.view().sponsors.is_empty()
	)


func _verify_pending(pending: Dictionary, folder: String) -> bool:
	SeasonSave.path = folder.path_join("pending.json")
	_restored_pending = SeasonSave.restore()
	if (
		(
			not _extra(
					(
						_restored_pending != null
						and not SeasonSave.dynasty_owner_bound()
						and SeasonSave.last_error.is_empty()
					),
					"primary_pending_restore"
				)
		)
		or (
			not _extra(
					ClubCareer.same(pending, SeasonSave.snapshot(_restored_pending)), "exact_pending_snapshot"
				)
		)
		or (
			not _extra(_fixed_context(_restored_pending), "pending_seed301_run1_ordinal0")
		)
	):
		return false
	var season: SeasonState = _restored_pending
	if not _extra(
		(
			season.results.is_empty()
			and season.player_results.is_empty()
			and season.round_index == 0
			and season.physical != null
			and season.physical.reports.is_empty()
			and season.physical.pending.reports.is_empty()
			and season.pending_fixture() == {"id": 0, "round": 0, "away": 0, "home": 5}
		),
		"pending_unsettled_stage"
	):
		return false
	var human: Array = pending.physical.pending.human
	if (
		(
			not _extra(
					(
						StadiumNpcYardTwoHumanEvidence.pending_valid(season, human)
						and CurrentPublicChecks.binding(human[16].property, season, 0)
						and (
							PhysicalStadiumReport.npc_resolver(human[16].property)
							== StadiumNpcPublicReport.RESOLVER
						)
					),
					"pending_human_bound"
				)
		)
		or (
			not _extra(
					(
						ClubCareer.same(_context.fresh_context, FRESH_CONTEXT)
						and season.cash() == 0
						and season.build.revision() == PENDING_BUILD_EVENTS.size()
						and ClubCareer.same(season.build.to_data().get("events"), PENDING_BUILD_EVENTS)
						and season.build._bank.revision() == 0
						and season.build._bank.view().sponsors.is_empty()
						and season.build._bank.view().rewards.is_empty()
					),
					"fresh_base_reward_context"
				)
		)
	):
		return false
	var forged: Dictionary = pending.duplicate(true)
	forged.physical.pending.human[16].clear()
	return _extra(SeasonSave._decode(forged) == null, "stripped_human_rejected")


func _verify_settled(season: SeasonState, pending: Dictionary) -> bool:
	if not _extra(
		(
			season != null
			and not SeasonSave.dynasty_owner_bound()
			and SeasonSave.last_error.is_empty()
		),
		"primary_settled_restore"
	):
		return false
	if not _extra(_fixed_context(season), "settled_fixed_context"):
		return false
	if not _extra(
		(
			season.player_results.size() == 1
			and CurrentPublicChecks.binding(pending.physical.pending.human[16].property, season, 0)
			and ClubCareer.same(
				season.player_results[0].yard_evidence, pending.physical.pending.human[16]
			)
			and (
				season.player_results[0].property
				== StadiumLayoutSnapshot.key(pending.physical.pending.human[16].property)
			)
		),
		"retained_human_binding"
	):
		return false
	return _extra(
		(
			ClubCareer.same(_restored_pending.npc_venues, season.npc_venues)
			and ClubCareer.same(_restored_pending.final_venue, season.final_venue)
			and ClubCareer.same(_restored_pending.home_property, season.home_property)
			and ClubCareer.same(
				ClubPlayers.assets(_restored_pending.career).to_data(),
				ClubPlayers.assets(season.career).to_data()
			)
		),
		"settled_preserves_home_assignment_assets"
	)


func _inputs_unchanged(folder: String) -> bool:
	if not _input_listing(folder):
		return false
	for name: String in INPUT_NAMES:
		var path_value: String = folder.path_join(name)
		var file_value: FileAccess = FileAccess.open(path_value, FileAccess.READ)
		if file_value == null:
			return false
		var size: int = file_value.get_length()
		file_value.close()
		if size != _input_sizes[name] or FileAccess.get_sha256(path_value) != _input_hashes[name]:
			return false
	return true
