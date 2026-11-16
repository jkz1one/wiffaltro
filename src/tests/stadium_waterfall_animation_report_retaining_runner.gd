extends PhysicalMatchRunner
## Test-only observer: writes the real public capture and raw core before cleanup.
## Does not fabricate a wrapper, alter gameplay, or replace the runner's result.

var output_dir: String = ""
var identity: Dictionary = {}
var retained: bool = false
var retention_errors: Array[String] = []
var terminal: Dictionary = {}


func _process(delta: float) -> void:
	if (
		_running
		and is_instance_valid(_lab)
		and _lab._match_state.phase == MatchState.Phase.GAME_END
	):
		retain("natural_game_end")
	super._process(delta)


func _fail(reason: String) -> void:
	retain("runner_failure: " + reason)
	super._fail(reason)


func cancel() -> void:
	if _running:
		retain("cancel_before_game_end")
	super.cancel()


func retain(label: String) -> void:
	if retained or not is_instance_valid(_lab) or _lab._match_state == null:
		return
	retained = true
	# Keep capture's actual return value, including {} on validation failure.
	var started_us: int = Time.get_ticks_usec()
	var candidate: Dictionary = PhysicalMatchReport.capture(_lab)
	var candidate_us: int = Time.get_ticks_usec() - started_us
	started_us = Time.get_ticks_usec()
	var core: Dictionary = PhysicalMatchReport._capture_core(_lab)
	var core_us: int = Time.get_ticks_usec() - started_us
	started_us = Time.get_ticks_usec()
	var contacts: Array = PhysicalStadiumContacts.capture(_lab._play_records)
	var contacts_us: int = Time.get_ticks_usec() - started_us
	var snapshot: Dictionary = _lab._match_state.stadium.duplicate(true)
	started_us = Time.get_ticks_usec()
	var ledger: Dictionary = _lab._stadium_ledger.to_data() if _lab._stadium_ledger != null else {}
	var ledger_us: int = Time.get_ticks_usec() - started_us
	# Persist raw evidence before running any additional observer diagnostics.
	_write("candidate-raw.json", candidate)
	_write("core-raw.json", core)
	terminal = {
		"schema": 1,
		"identity": identity.duplicate(true),
		"label": label,
		"phase": _lab._match_state.phase,
		"natural_game_end": _lab._match_state.phase == MatchState.Phase.GAME_END,
		"runner_elapsed_seconds": _elapsed,
		"snapshot": snapshot,
		"ledger": ledger,
		"export_timing_us":
		{
			"public_candidate_capture": candidate_us,
			"core_capture": core_us,
			"contacts_capture": contacts_us,
			"ledger_export": ledger_us
		},
		"contacts": contacts,
		"candidate_sha256": FileAccess.get_sha256(output_dir.path_join("candidate-raw.json")),
		"core_sha256": FileAccess.get_sha256(output_dir.path_join("core-raw.json"))
	}
	_write("terminal-raw.json", terminal)
	var diagnostics: Dictionary = {
		"label": label,
		"candidate_valid": PhysicalMatchReport.valid(candidate),
		"core_valid": PhysicalMatchReport.valid(core),
		"contacts_valid": PhysicalStadiumContacts.valid(contacts, core.get("plays", []), snapshot),
		"installed": StadiumWaterfallAnimationInstall.installed_bound(_lab, snapshot),
		"retention_errors": retention_errors.duplicate()
	}
	_write("terminal-diagnostics.json", diagnostics)
	print(
		(
			"WATERFALL47_REPORT_RETAINED "
			+ JSON.stringify(
				{"identity": identity, "output_dir": output_dir, "diagnostics": diagnostics}
			)
		)
	)


func _write(name: String, value: Variant) -> void:
	var path: String = output_dir.path_join(name)
	if FileAccess.file_exists(path):
		retention_errors.append("Refusing to overwrite " + path)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		retention_errors.append("Cannot write " + path + ": " + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(value, "", true, true))
	file.flush()
	if file.get_error() != OK:
		retention_errors.append("Write failed for " + path + ": " + str(file.get_error()))
	file.close()
