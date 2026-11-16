extends "res://src/tests/ac02_public_round_test.gd"
## One actual human lifetime. No synthetic phase, issuer, ticket or save result.
## Resume initializes the next in-process job; ordinary cancellation precedes any await.

const TRACE = preload("res://src/diagnostics/ac02_passive_attribution.gd")
const REFUSAL: String = ("The completed AC-02 game lost its settlement owner. The save was not " \
	+ "attempted.")
const OPEN_FAILURE: String = "Could not save season. Your current session is still available."
const PROBES: Array[String] = [
	"foreign_equal_career",
	"ticket_issue",
	"pending_identity",
	"ticket_human",
	"ticket_fixture",
	"property_generation"
]
var _warm_initial: Dictionary = {}
var _warm_queue: Dictionary = {}
var _warm_resume: Dictionary = {}
var _warm_cleanup: Dictionary = {}
var _warm_probes: Array[String] = []
var _warm_complete: bool = false
var _trace_started: bool = false
var _issue_ref: WeakRef
var _property_ref: WeakRef
var _original_refs: Array[WeakRef] = []
var _adopt_holder: Node
var _adopted_ref: WeakRef
var _adopted_id: int = 0
var _durable: Dictionary = {}


static func _id(value: Variant) -> int:
	return value.get_instance_id() if value is Object and is_instance_valid(value) else 0


static func _raw(career: ClubCareer) -> Array:
	return (
		[
			career.current,
			career.runs.duplicate(true),
			career._assets.duplicate(true),
			career._pennants.duplicate(true),
			career._plaques.duplicate(true)
		]
		if career != null
		else []
	)


func _owner() -> Dictionary:
	var issue: StadiumNpcAc02IssuedStateV1 = _issue_ref.get_ref() if _issue_ref != null else null
	var property: StadiumNpcPublicProperty = (
		_property_ref.get_ref() if _property_ref != null else null
	)
	if issue == null or not is_instance_valid(property):
		return {"missing_owner": true}
	var lab: PitchBatLab = issue._bindings.lab
	var ticket: Dictionary = _app._ac02_settlement_ticket
	return {
		"issue_id": issue.get_instance_id(),
		"state": issue.state,
		"generation": issue.generation,
		"lab_id": _id(lab),
		"match_id": _id(lab._match_state),
		"season_id": _id(lab._npc_season),
		"property_id": _id(property),
		"physical_id": _id(_app.season.physical),
		"app_lab_id": _id(_app.lab),
		"app_season_id": _id(_app.season),
		"lab_owner_id": _id(lab._ac02_issued_owner),
		"cleanup_automation_id": _id(issue._cleanup_automation),
		"ball_id": _id(lab._batted_ball),
		"reason": issue.reason,
		"history": lab._ac02_issued_history,
		"interrupted": lab.has_meta("stadium_npc_runtime_interrupted"),
		"saving": issue._settlement_saving,
		"lost": issue._settlement_save_lost,
		"restored": issue._restored,
		"original_restore_pending": issue._original_restore_pending,
		"property_generation": property._ac02_generation,
		"current_career": _id(_app.season.career),
		"bound_career": _id(issue._bindings.career),
		"cleanup_career": _id(issue._cleanup_career),
		"raw": _raw(_app.season.career),
		"bound_raw": _raw(issue._bindings.career),
		"cleanup_raw": _raw(issue._cleanup_career),
		"ticket_issue": _id(ticket.get("issue")),
		"ticket_empty": ticket.is_empty(),
		"ticket_human": ticket.get("human", []).duplicate(true),
		"ticket_fixture": ticket.get("fixture", {}).duplicate(true),
		"pending": _app.season.physical.pending.duplicate(true),
		"pending_exact": is_same(_app.season.physical.pending, ticket.get("pending"))
	}


func _capture_warm_initial(lab: PitchBatLab) -> bool:
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	var property: StadiumNpcPublicProperty = issue._bindings.property
	_issue_ref = weakref(issue)
	_property_ref = weakref(property)
	_warm_initial = _owner()
	return (
		_write("warm-initial-owner.json", _warm_initial)
		and _check(
			(
				_warm_initial.issue_id == _initial_issue_id
				and _warm_initial.state == 2
				and _warm_initial.generation == 1
				and _warm_initial.reason.is_empty()
				and _warm_initial.current_career == _warm_initial.bound_career
				and _warm_initial.cleanup_career == _warm_initial.current_career
			),
			"fresh actual issuer binds original career before natural gameplay"
		)
	)


func _hash_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		_io_failed = true
		_check(false, "hash actual raw bytes")
		return ""
	return context.finish().hex_encode()
func _path_info(path: String) -> Dictionary:
	if DirAccess.dir_exists_absolute(path):
		return {
			"kind": "directory",
			"entries":
			DirAccess.get_files_at(path).size() + DirAccess.get_directories_at(path).size()
		}
	if not FileAccess.file_exists(path):
		return {"kind": "absent"}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_io_failed = true
		_check(false, "read file observation " + path.get_file())
		return {"kind": "unreadable"}
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		_io_failed = true
		_check(false, "complete file observation " + path.get_file())
		return {"kind": "truncated"}
	return {"kind": "file", "bytes": length, "sha256": _hash_bytes(bytes)}


func _files() -> Dictionary:
	return {
		"primary": _path_info(SeasonSave.path),
		"backup": _path_info(SeasonSave.path + ".bak"),
		"temp": _path_info(SeasonSave.path + ".tmp")
	}


func _write_raw(name: String, bytes: PackedByteArray) -> bool:
	var path: String = _output.path_join(name)
	if (
		_io_failed
		or bytes.is_empty()
		or bytes.size() > MAX_JSON_BYTES
		or FileAccess.file_exists(path)
	):
		_io_failed = true
		return _check(false, "bounded fresh raw output " + name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_io_failed = true
		return _check(false, "open raw output " + name)
	file.store_buffer(bytes)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_io_failed = true
		return _check(false, "open raw readback " + name)
	ok = ok and file.get_length() == bytes.size() and file.get_buffer(bytes.size()) == bytes
	file.close()
	if not ok:
		_io_failed = true
		_check(false, "raw write/readback " + name)
	return ok


func _copy_durable(label: String) -> bool:
	var record: Dictionary = {"label": label, "files": _files(), "copies": {}}
	if _io_failed:
		return false
	for suffix: String in ["", ".bak"]:
		var source: String = SeasonSave.path + suffix
		if not FileAccess.file_exists(source):
			return _check(false, "actual durable primary and backup exist before " + label)
		var input: FileAccess = FileAccess.open(source, FileAccess.READ)
		if input == null:
			_io_failed = true
			return _check(false, "open durable source " + label)
		var length: int = input.get_length()
		var bytes: PackedByteArray = input.get_buffer(length)
		input.close()
		if bytes.size() != length:
			_io_failed = true
			return _check(false, "complete durable source " + label)
		var name: String = "warm-%s-%s.json" % [label, "primary" if suffix.is_empty() else "backup"]
		if not _write_raw(name, bytes):
			return false
		record.copies[name] = {"bytes": bytes.size(), "sha256": _hash_bytes(bytes)}
	_durable[label] = record
	return _write("warm-%s-durable.json" % label, record)


func _copy_pregame_durable() -> bool:
	# play_season_game has committed the actual pregame checkpoint; no game frame has run.
	var input: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.READ)
	if input == null:
		_io_failed = true
		return _check(false, "open actual pregame durable primary")
	var length: int = input.get_length()
	if length <= 0 or length > MAX_JSON_BYTES:
		input.close()
		_io_failed = true
		return _check(false, "bounded actual pregame durable primary")
	var bytes: PackedByteArray = input.get_buffer(length)
	input.close()
	if bytes.size() != length:
		_io_failed = true
		return _check(false, "complete actual pregame durable primary")
	return _write_raw("warm-pregame-durable.json", bytes)


static func _counts() -> Dictionary:
	var counts: Dictionary = {"snapshot": 0, "decode": 0}
	for row: Dictionary in TRACE.snapshot().rows:
		if row.label == "season_save.snapshot":
			counts.snapshot += int(row.calls)
		elif row.label == "season_save._decode":
			counts.decode += int(row.calls)
	return counts


static func _profile_ok() -> bool:
	var profile: Dictionary = TRACE.snapshot()
	return (
		TRACE._active
		and profile.errors.is_empty()
		and profile.open_scopes == 0
		and profile.entries == profile.completed
	)


static func _same(left: Variant, right: Variant) -> bool:
	return StadiumNpcAc02IssuedStateV1._same_plain(left, right)


func _failed_resume() -> bool:
	var before: Dictionary = _owner()
	var files: Dictionary = _files()
	var counts: Dictionary = _counts()
	if _io_failed:
		return false
	var ticket: Dictionary = _app._ac02_settlement_ticket
	var pending: Dictionary = _app.season.physical.pending
	var lab: PitchBatLab = _app.lab
	var obstruction: String = SeasonSave.path + ".tmp"
	if (
		(
			not _check(
					(
						not FileAccess.file_exists(obstruction)
						and not DirAccess.dir_exists_absolute(obstruction)
						and DirAccess.make_dir_absolute(obstruction) == OK
					),
					"fresh owned temp-open obstruction after queue success"
				)
		)
		or (
			not _write(
					"warm-failed-resume-start.json",
					{"owner": before, "files": files, "counts": counts, "obstruction": _path_info(obstruction)}
				)
		)
	):
		return false
	var returned_bool: bool = _app._commit_result()
	var after: Dictionary = _owner()
	var after_files: Dictionary = _files()
	var after_counts: Dictionary = _counts()
	var result: Dictionary = {
		"returned_bool": returned_bool,
		"error": SeasonSave.last_error,
		"owner": after,
		"files": after_files,
		"counts": after_counts,
		"same_lab": _app.lab == lab,
		"same_ticket": is_same(ticket, _app._ac02_settlement_ticket),
		"same_pending": is_same(pending, _app.season.physical.pending),
		"no_runner":
		(
			not _app.round_ui._working
			and _app.round_ui.runner._lab == null
			and not _app.round_ui.process_runner.running
		),
		"ai_reports": _ai_reports.size()
	}
	if (
		(
			not _write("warm-failed-resume-return.json", result) or not _copy_durable("failed-resume")
		)
		or (
			not _check(
					(
						not returned_bool
						and result.error == OPEN_FAILURE
						and _same(before, after)
						and _same(files.primary, after_files.primary)
						and _same(files.backup, after_files.backup)
						and after_files.temp.kind == "directory"
						and after_files.temp.entries == 0
						and after_counts.snapshot == counts.snapshot + 2
						and after_counts.decode > counts.decode
						and result.same_lab
						and result.same_ticket
						and result.same_pending
						and result.no_runner
						and result.ai_reports == 0
						and _profile_ok()
					),
					"actual warm resume temp-open failure preserves durable queue and exact retryable owner"
				)
		)
		or (
			not _check(
					(
						DirAccess.get_files_at(obstruction).is_empty()
						and DirAccess.get_directories_at(obstruction).is_empty()
						and DirAccess.remove_absolute(obstruction) == OK
						and _same(files, _files())
					),
					"remove only the empty test obstruction and retain the original durable checkpoint"
				)
		)
	):
		return false
	return _write(
		"warm-failed-resume-unblocked.json",
		{"owner": _owner(), "files": _files(), "counts": _counts()}
	)


func _restore_probe(
	label: String, previous: Variant, ticket: Dictionary, property: StadiumNpcPublicProperty
) -> void:
	match label:
		"foreign_equal_career":
			_app.season.career = previous
		"ticket_issue":
			ticket.issue = previous
		"pending_identity":
			_app.season.physical.pending = previous
		"ticket_human":
			ticket.human = previous
		"ticket_fixture":
			ticket.fixture = previous
		"property_generation":
			property._ac02_generation = previous


func _precondition_probe(label: String) -> bool:
	var issue: StadiumNpcAc02IssuedStateV1 = _issue_ref.get_ref()
	var property: StadiumNpcPublicProperty = _property_ref.get_ref()
	var ticket: Dictionary = _app._ac02_settlement_ticket
	var baseline: Dictionary = _owner()
	var files: Dictionary = _files()
	var counts: Dictionary = _counts()
	if _io_failed:
		return false
	var previous: Variant
	match label:
		"foreign_equal_career":
			previous = _app.season.career
			var foreign: ClubCareer = previous.fork()
			if not _check(
				(
					foreign != previous
					and foreign.get_script() == ClubCareer
					and _same(_raw(foreign), _raw(previous))
				),
				"foreign probe is exact-native raw-equal but distinct"
			):
				return false
			_app.season.career = foreign
		"ticket_issue":
			previous = ticket.issue
			ticket.issue = null
		"pending_identity":
			previous = _app.season.physical.pending
			_app.season.physical.pending = previous.duplicate(true)
		"ticket_human":
			previous = ticket.human
			var human: Array = previous.duplicate(true)
			human[1] += 1
			ticket.human = human
		"ticket_fixture":
			previous = ticket.fixture
			var fixture: Dictionary = previous.duplicate(true)
			fixture["id"] += 1
			ticket.fixture = fixture
		"property_generation":
			previous = property._ac02_generation
			property._ac02_generation += 1
		_:
			return _check(false, "unknown warm precondition probe")
	var injected: Dictionary = _owner()
	if not _write(
		"warm-probe-%s-start.json" % label,
		{
			"label": label,
			"baseline": baseline,
			"injected": injected,
			"files": files,
			"counts": counts
		}
	):
		_restore_probe(label, previous, ticket, property)
		return false
	return _warm_probe_save_outcome(
		label, issue, property, ticket, baseline, files, counts, previous, injected
	)


func _warm_probe_save_outcome(
	label: String, issue: StadiumNpcAc02IssuedStateV1, property: StadiumNpcPublicProperty,
	ticket: Dictionary, baseline: Dictionary, files: Dictionary, counts: Dictionary,
	previous: Variant, injected: Dictionary
) -> bool:
	var saved: bool = _app._ac02_save_settlement()
	var returned: Dictionary = _owner()
	var after_files: Dictionary = _files()
	var after_counts: Dictionary = _counts()
	if not _write(
		"warm-probe-%s-return.json" % label,
		{
			"label": label,
			"saved": saved,
			"error": SeasonSave.last_error,
			"owner": returned,
			"files": after_files,
			"counts": after_counts
		}
	):
		return false
	# Unexpected success or recorded loss is terminal. Never restore it into a positive continuation.
	if not _check(
		(
			not saved
			and SeasonSave.last_error == REFUSAL
			and _same(injected, returned)
			and _same(files, after_files)
			and _same(counts, after_counts)
			and _profile_ok()
			and issue.state == 3
			and issue.generation == 2
			and issue.reason == "settlement begins"
			and not issue._settlement_saving
			and not issue._settlement_save_lost
		),
		(
			label
			+ " is only a pre-save refusal with no file, cleanup, lifetime or snapshot/decode mutation"
		)
	):
		_copy_durable("unexpected-" + label)
		return false
	_restore_probe(label, previous, ticket, property)
	var restored: Dictionary = _owner()
	if not _write(
		"warm-probe-%s-restored.json" % label,
		{"label": label, "owner": restored, "files": _files(), "counts": _counts()}
	):
		return false
	if not _check(
		_same(baseline, restored) and _same(files, _files()) and _same(counts, _counts()),
		label + " restores exact original inputs, never a lost authority"
	):
		return false
	_warm_probes.append(label)
	return true


func _prepare_adopted_original() -> bool:
	var issue: StadiumNpcAc02IssuedStateV1 = _issue_ref.get_ref()
	var selected: Node
	for node: Node in issue._owned_originals:
		if not _check(
			is_instance_valid(node) and node.get_parent() == null,
			"actual issued original remains detached before ordinary disposal"
		):
			return false
		_original_refs.append(weakref(node))
		if selected == null and node.get_script() == null:
			selected = node
	if not _check(
		selected != null and _original_refs.size() > 1,
		"actual detached native original is available for adoption"
	):
		return false
	_adopt_holder = Node.new()  # Outside the lab and outside the SceneTree; no entered-tree callback.
	_adopt_holder.add_child(selected)
	_adopted_ref = weakref(selected)
	_adopted_id = selected.get_instance_id()
	return _write(
		"warm-adopted-original.json",
		{
			"id": _adopted_id,
			"original_count": _original_refs.size(),
			"parent_id": _adopt_holder.get_instance_id(),
			"inside_tree": selected.is_inside_tree(),
			"script_free": selected.get_script() == null
		}
	)


static func _revoked(owner: Dictionary) -> bool:
	return (
		owner.get("state") == 3
		and owner.get("generation") == 2
		and owner.get("reason") == "settlement begins"
		and owner.get("history") == true
		and owner.get("saving") == false
		and owner.get("lost") == false
	)


func _next_runner_observation() -> Dictionary:
	var runner: PhysicalMatchRunner = _app.round_ui.runner
	var lab: PitchBatLab = runner._lab
	return {
		"working": _app.round_ui._working,
		"in_process": not _app.round_ui.process_jobs and not _app.round_ui.process_runner.running,
		"lab_present": is_instance_valid(lab),
		"releases":
		(
			lab._automation.releases.size()
			if is_instance_valid(lab) and lab._automation != null
			else -1
		),
		"plays": lab._play_records.size() if is_instance_valid(lab) else -1,
		"simulation_seconds":
		(
			lab._match_state.elapsed_seconds
			if is_instance_valid(lab) and lab._match_state != null
			else -1.0
		),
		"runner_seconds": runner._elapsed,
		"completed_reports": _ai_reports.size(),
		"pending_reports": _app.season.physical.pending.reports.size()
	}


func _successful_resume() -> bool:
	var before: Dictionary = _owner()
	var counts: Dictionary = _counts()
	if not _check(
		(
			_app.round_ui.process_jobs == false
			and not _app.round_ui.process_runner.running
			and _app._ac02_resume_authorized()
		),
		"ordinary retry retains exact ticket and in-process-only mode"
	):
		return false
	if not _write("warm-resume-start.json", {"owner": before, "counts": counts, "files": _files()}):
		return false
	var returned_bool: bool = _app._commit_result()
	_warm_resume = {
		"returned_bool": returned_bool,
		"error": SeasonSave.last_error,
		"owner": _owner(),
		"counts": _counts(),
		"files": _files(),
		"app_lab_null": _app.lab == null,
		"ticket_empty": _app._ac02_settlement_ticket.is_empty(),
		"ai": _next_runner_observation()
	}
	# No await or gameplay tick occurs between ordinary resume and ordinary cancel.
	_app.round_ui.cancel()
	_warm_resume["cancelled"] = (
		not _app.round_ui._working
		and not _app.round_ui.runner._running
		and _app.round_ui.runner._lab == null
		and not _app.round_ui.process_runner.running
	)
	if not _write("warm-resume-return.json", _warm_resume) or not _copy_durable("resumed"):
		return false
	var owner: Dictionary = _warm_resume.owner
	var ai: Dictionary = _warm_resume.ai
	return _check(
		(
			not returned_bool
			and _warm_resume.error.is_empty()
			and _warm_resume.app_lab_null
			and _warm_resume.ticket_empty
			and _warm_resume.cancelled
			and _revoked(owner)
			and owner.issue_id == _warm_initial.issue_id
			and owner.bound_career == _warm_initial.bound_career
			and owner.current_career != before.current_career
			and owner.current_career != owner.bound_career
			and owner.cleanup_career == owner.current_career
			and _same(owner.raw, before.raw)
			and owner.restored
			and owner.original_restore_pending
			and _warm_resume.counts.snapshot > counts.snapshot
			and _profile_ok()
			and ai.working
			and ai.in_process
			and ai.lab_present
			and ai.releases == 0
			and ai.plays == 0
			and ai.simulation_seconds == 0.0
			and ai.runner_seconds == 0.0
			and ai.completed_reports == 0
			and ai.pending_reports == 0
		),
		"ordinary resume accepts second fresh cleanup career then cancels next job before AI gameplay"
	)


func _warm_tail(live: WeakRef) -> void:
	_warm_queue = _owner()
	if not _write("warm-queue-owner.json", _warm_queue):
		return
	if not _check(
		(
			_warm_queue.issue_id == _warm_initial.issue_id
			and _revoked(_warm_queue)
			and _warm_queue.bound_career == _warm_initial.bound_career
			and _warm_queue.current_career != _warm_initial.current_career
			and _warm_queue.cleanup_career == _warm_queue.current_career
			and _same(_warm_queue.raw, _warm_initial.raw)
			and _app._ac02_settlement_owner_intact()
			and _app._ac02_resume_authorized()
			and _app.round_ui.process_jobs == false
			and not _app.round_ui.process_runner.running
		),
		"natural queue save advances only cleanup career and retains exact revoked ticket"
	):
		return
	_trace_started = TRACE.begin_session(_output)
	if not _check(
		_trace_started and _profile_ok(),
		"existing passive collector starts only after genuine queue save"
	):
		return
	for label: String in PROBES:
		if not _precondition_probe(label):
			return
	if not _failed_resume():
		return
	if not _prepare_adopted_original():
		return
	await _warm_resume_release_observations(live)


func _warm_resume_release_observations(live: WeakRef) -> void:
	if not _successful_resume():
		return
	# No local issuer or ticket reference survives this synchronous helper boundary.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var originals_released: bool = true
	for reference: WeakRef in _original_refs:
		var original: Variant = reference.get_ref()
		if original != null and original.get_instance_id() != _adopted_id:
			originals_released = false
	var adopted: Variant = _adopted_ref.get_ref() if _adopted_ref != null else null
	_warm_cleanup = {
		"lab_released": live.get_ref() == null,
		"property_released": _property_ref.get_ref() == null,
		"issuer_released": _issue_ref.get_ref() == null,
		"unadopted_originals_released": originals_released,
		"adopted_id": _adopted_id,
		"adopted_survived":
		(
			is_instance_valid(adopted)
			and adopted.get_instance_id() == _adopted_id
			and adopted.get_parent() == _adopt_holder
		),
		"ai_reports": _ai_reports.size(),
		"runner_stopped":
		(
			not _app.round_ui._working
			and not _app.round_ui.runner._running
			and _app.round_ui.runner._lab == null
			and not _app.round_ui.process_runner.running
		),
		"pending_reports": _app.season.physical.pending.reports.size(),
		"results": _app.season.results.size(),
		"files": _files()
	}
	if not _write("warm-cleanup.json", _warm_cleanup):
		return
	_warm_complete = _check(
		(
			_warm_cleanup.lab_released
			and _warm_cleanup.property_released
			and _warm_cleanup.issuer_released
			and _warm_cleanup.unadopted_originals_released
			and _warm_cleanup.adopted_survived
			and _warm_cleanup.ai_reports == 0
			and _warm_cleanup.runner_stopped
			and _warm_cleanup.pending_reports == 0
			and _warm_cleanup.results == 0
			and _profile_ok()
		),
		(
			"ordinary resume disposal releases exact lifetime and preserves adopted original "
			+ "without AI gameplay"
		)
	)
