extends PhysicalMatchRunner
## Test-only terminal capture before cleanup; never edits or settles report evidence.
var evidence_prefix: String = "low"
var retained: bool = false


func _process(delta: float) -> void:
	if (
		_running
		and is_instance_valid(_lab)
		and _lab._match_state.phase == MatchState.Phase.GAME_END
	):
		_retain("natural_game_end")
	super._process(delta)


func _fail(reason: String) -> void:
	_retain("runner_failure: " + reason)
	super._fail(reason)


func _retain(label: String) -> void:
	if retained or not is_instance_valid(_lab):
		return
	retained = true
	var core: Dictionary = PhysicalMatchReport._capture_core(_lab)
	var contacts: Array = PhysicalStadiumContacts.capture(_lab._play_records)
	var snapshot: Dictionary = _lab._match_state.stadium
	var candidate: Dictionary = PhysicalMatchReport.capture(_lab)
	var data: Dictionary = {
		"label": label,
		"elapsed": _elapsed,
		"core": core,
		"contacts": contacts,
		"snapshot": snapshot,
		"ledger": _lab._stadium_ledger.to_data(),
		"public_candidate": candidate,
		"candidate_valid": PhysicalMatchReport.valid(candidate),
		"core_valid": PhysicalMatchReport.valid(core),
		"contacts_valid": PhysicalStadiumContacts.valid(contacts, core.plays, snapshot),
		"installed": StadiumLowWallRuntime.installed_bound(_lab, snapshot)
	}
	var file: FileAccess = FileAccess.open(
		"user://" + evidence_prefix + "-terminal-raw.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()
	print(
		(
			"LOW_TERMINAL_RETAINED "
			+ JSON.stringify(
				{
					"label": label,
					"profile": evidence_prefix,
					"candidate_valid": data.candidate_valid,
					"core_valid": data.core_valid,
					"contacts_valid": data.contacts_valid,
					"installed": data.installed,
					"plays": core.plays.size()
				}
			)
		)
	)
