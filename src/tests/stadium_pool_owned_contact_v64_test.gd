extends Node
## Controlled ContactResolver input after one genuine paid pitch release.
## This is not a fully pitched contact, completed game, report or settlement qualification.
# gdlint: disable=max-file-lines,max-returns,function-arguments-number

const CareerFixture = preload("res://src/tests/stadium_pool_owned_career_fixture.gd")
const SEED: int = 42
const MAX_ARTIFACT_BYTES: int = 8 * 1024 * 1024
const FIXTURE: Dictionary = {"id": 3, "round": 1, "away": 4, "home": 0}
const MATCH_SEED: int = 314229
const MAX_RELEASE_FRAMES: int = 1800
const MAX_LAUNCH_FRAMES: int = 180
const EXPECTED_NATIVE_CHECKS: int = 68

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _runtime: String = ""
var _expected_runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _output_admitted: bool = false
var _app: ObservedApp
var _funding: Dictionary = {}
var _placements: Array[Dictionary] = []
var _source: MatchState
var _caller_ledger: ClubAssetLedger
var _caller_ledger_state: PackedByteArray
var _caller_ledger_generation: int = 0
var _season_bytes: PackedByteArray
var _ledger_bytes: PackedByteArray
var _source_bytes: PackedByteArray
var _saved_files: Dictionary = {}
var _runner: PhysicalMatchRunner
var _ledger: ClubAssetLedger
var _lab: PitchBatLab
var _adapter: StadiumPoolControllerActive
var _property: StadiumPoolOwnedProperty
var _token: StadiumPoolOwnedAuthority
var _ball: BattedBallBody
var _state: BallPlayState
var _launch_guard: StadiumPoolWaterGuard
var _reports: int = 0
var _runner_errors: Array[String] = []
var _stage: String = "setup"
var _wait_start: int = -1
var _launch_frame: int = -1
var _terminal_frame: int = -1
var _launches: int = 0
var _actual_release: Dictionary = {}
var _launch_values: Dictionary = {}
var _before: Dictionary = {}
var _terminal: Dictionary = {}
var _post_commit: Dictionary = {}
var _later: Dictionary = {}
var _held_state: PackedByteArray
var _held_generation: int = 0
var _wall_start: int = 0
var _done: bool = false
var _disposed: bool = false
var _terminal_captured: bool = false

class ObservedApp extends SeasonApp:
	var terminal_observer: Callable
	var pending_observer: Callable
	var last_observed_lab: int = 0

	func _commit_result() -> bool:
		var first: bool = not _result_recorded and lab != null \
			and lab._match_state.phase == MatchState.Phase.GAME_END
		if first and last_observed_lab != lab.get_instance_id():
			last_observed_lab = lab.get_instance_id()
			terminal_observer.call(self)
		var result: bool = super._commit_result()
		if first and _result_recorded and not season.physical.pending.is_empty():
			pending_observer.call(self)
		return result


func _purchase_and_place() -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var before: Dictionary = ledger.to_data()
	var balance: int = _app.season.career.balance()
	var revision: int = ledger.revision()
	var bought: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	if not _check(bought.get("ok", false) and not bought.get("replayed", true),
		"ordinary buy_copy pays unlocked full first-Pool price: " + str(bought.get("error", ""))):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_app.season.career.balance() == balance - 700
		and ledger.revision() == revision + 1 and not ClubCareer.same(before, ledger.to_data()),
		"shared wallet decreases exactly700 and journal advances once"):
		return false
	var paid: Dictionary = ledger.to_data()
	var duplicate: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-006", revision)
	if not _check(duplicate.get("ok", false) and duplicate.get("replayed", false)
		and ClubCareer.same(paid, ClubPlayers.assets(_app.season.career).to_data()),
		"same purchase command replays without another charge or copy"):
		return false
	var pool_copy: String = ""
	for id: String in ledger.construction().copies:
		if ledger.construction().copies[id].item == "ST-006":
			if not _check(pool_copy.is_empty(), "one paid Pool copy"):
				return false
			pool_copy = id
	if not _check(not pool_copy.is_empty(), "paid copy comes from actual journal stock"):
		return false
	if not _place_owned_receiver():
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	var base: Dictionary = ledger.view().stadium_active.duplicate(true)
	var layout: Dictionary = StadiumPoolOwnedLayout.upgrade(base, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, pool_copy, Vector2(12, 18), 0)
	if layout.is_empty():
		_write("pool-owned-v28-failure-context.json", {"stage": "pool_upgrade",
			"base": base, "stock": ledger.construction().to_data(),
			"access": ledger.surface_owned(), "tier": ledger.view().land,
			"copy": pool_copy, "position": [12, 18], "yaw": 0,
			"migration_error": StadiumPoolOwnedLayout.migration_error(base,
				ledger.construction(), ledger.surface_owned(), ledger.view().land)})
	if not _check(not layout.is_empty(), "surface-preserving receiver layout upgrade"):
		return false
	var moved: Dictionary = StadiumPoolOwnedLayout.relocated(layout, ledger.construction(),
		ledger.surface_owned(), ledger.view().land, Vector2(-12, 18), 270)
	if not _check(not moved.is_empty() and moved.pool.copy == pool_copy
		and moved.surface == layout.surface, "second distinct legal pose preserves paid copy and finish"):
		return false
	for selected: Dictionary in [moved, layout]:
		ledger = ClubPlayers.assets(_app.season.career)
		var drafted: Dictionary = ClubConstruction.save_draft(_app.season, selected, ledger.revision())
		if not _check(drafted.get("ok", false),
			"ordinary validated draft transaction: " + str(drafted.get("error", ""))):
			return false
		ledger = ClubPlayers.assets(_app.season.career)
		var applied: Dictionary = ClubConstruction.apply_draft(_app.season, selected, ledger.revision())
		if not _check(applied.get("ok", false)
			and StadiumPoolOwnedSnapshot.matches(_app.season.home_property,
				ClubPlayers.assets(_app.season.career)),
			"ordinary atomic apply freezes paid Pool snapshot: " + str(applied.get("error", ""))):
			return false
		_placements.append(selected.pool.duplicate(true))
	var preserved: Dictionary = SeasonSave.snapshot(_app.season)
	var save_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var invalid: Dictionary = layout.duplicate(true)
	invalid.pool.copy = "not-a-paid-copy"
	ledger = ClubPlayers.assets(_app.season.career)
	_check(not ClubConstruction.apply_draft(_app.season, invalid, ledger.revision()).ok,
		"unpaid copy cannot install")
	invalid = layout.duplicate(true)
	invalid.pool.position = [0, 0]
	_check(not ClubConstruction.apply_draft(_app.season, invalid, ledger.revision()).ok,
		"unsafe reserved placement cannot install")
	_check(not ClubConstruction.apply_draft(_app.season, layout, 0).ok,
		"stale unrelated revision cannot apply")
	_check(ClubCareer.same(preserved, SeasonSave.snapshot(_app.season))
		and save_bytes == FileAccess.get_file_as_bytes(SeasonSave.path),
		"rejected ownership, placement and revision transactions preserve live and saved bytes")
	var restored: SeasonState = SeasonSave.restore()
	if not _check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(_app.season)), "purchase and both placements durably replay"):
		return false
	_app.season = restored
	return true

func _owned_receiver_draft(base: Dictionary, copies: Dictionary) -> Dictionary:
	if not base.has("receiver") or not base.receiver is String \
		or not base.has("obstacles") or not base.obstacles is Array \
		or not base.obstacles.is_empty():
		return {}
	var selected: String = base.receiver
	if not selected.is_empty():
		if not copies.has(selected) or copies[selected].item != "ST-079":
			return {}
	else:
		for id: String in copies:
			if copies[id].item == "ST-079":
				if not selected.is_empty():
					return {}
				selected = id
	if selected.is_empty():
		return {}
	var draft: Dictionary = base.duplicate(true)
	draft.receiver = selected
	return draft

func _place_owned_receiver() -> bool:
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(SeasonSave.path)
	var balance: int = _app.season.career.balance()
	var draft: Dictionary = _owned_receiver_draft(ledger.view().stadium_active,
		ledger.construction().copies)
	if not _check(not draft.is_empty()
		and ClubCareer.same(before, SeasonSave.snapshot(_app.season))
		and saved == FileAccess.get_file_as_bytes(SeasonSave.path),
		"select actual owned ST-079 receiver without live or saved mutation"):
		return false
	var drafted: Dictionary = ClubConstruction.save_draft(_app.season, draft, ledger.revision())
	if not _check(drafted.get("ok", false) and _app.season.career.balance() == balance,
		"ordinary receiver draft transaction: " + str(drafted.get("error", ""))):
		return false
	ledger = ClubPlayers.assets(_app.season.career)
	var applied: Dictionary = ClubConstruction.apply_draft(_app.season, draft, ledger.revision())
	ledger = ClubPlayers.assets(_app.season.career)
	if not _check(applied.get("ok", false) and _app.season.career.balance() == balance
		and ClubCareer.same(ledger.view().stadium_active, draft)
		and _app.season.home_property.layout.receiver == draft.receiver
		and StadiumLayoutSnapshot.matches(_app.season.home_property, ledger),
		"ordinary receiver apply freezes owned snapshot: " + str(applied.get("error", ""))):
		return false
	return true

func _fixture(id: int) -> Dictionary:
	var found: Dictionary = {}
	for row: Dictionary in _app.season.schedule:
		if row.id == id:
			if not found.is_empty():
				return {}
			found = row.duplicate(true)
	return found

func _write(name: String, value: Dictionary) -> bool:
	if not _output_admitted:
		return false
	var encoded: String = JSON.stringify(value, "", true, true)
	if not _check(encoded.to_utf8_buffer().size() <= MAX_ARTIFACT_BYTES, "bounded evidence artifact"):
		return false
	var file: FileAccess = FileAccess.open(_output.path_join(name), FileAccess.WRITE)
	if not _check(file != null, "evidence file opened"):
		return false
	file.store_string(encoded)
	file.close()
	return true

func _hex(value: String, size: int) -> bool:
	if value.length() != size:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true

func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		_failed.append(label)
		push_error("POOL_OWNED_V28 " + label)
	return condition

func _profile_genuine_setup() -> bool:
	SeasonSave.path = _output.path_join("owned-career.json")
	PitchBatLabSettings.path = _output.path_join("owned-settings.cfg")
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if not _check(not FileAccess.file_exists(path + suffix), "new isolated save path"):
				return false
	var career = CareerFixture.new()
	_funding = career.fund(SeasonSave.path)
	var saved_funding: Dictionary = _funding.duplicate(true)
	saved_funding.erase("season")
	if not _write("pool-owned-v28-generated-career.json", saved_funding):
		return false
	if not _check(_funding.get("ok", false),
		"predeclared generated career earns ordinary eligibility"):
		return false
	_app = ObservedApp.new()
	add_child(_app)
	await get_tree().process_frame
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.COMPLETE,
		"genuine funded completed career restored by ordinary SeasonApp"):
		return false
	_app.begin_season(SEED, true, true, true, true, false)
	if not _check(_app.season != null and _app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.picks.is_empty() and _app.season.physical != null
		and _app.season.opponents._format == 13 and not _app.season.player_access.is_empty(),
		"normal new Working season opens the earned journal before drafting"):
		return false
	if not _purchase_and_place():
		return false
	for index: int in range(4):
		if not _check(_app.season.offers().size() == 3, "ordinary current draft offer"):
			return false
		var selected: String = _app.season.offers()[0]
		_app.choose_player(selected)
		if not _check(_app.season.picks.size() == index + 1
			and _app.season.picks[index] == selected, "unchanged first-offer draft selection"):
			return false
	return _check(_app.season.pending_fixture() == {"id": 0, "round": 0, "away": 0, "home": 5}
		and _app.season.results.is_empty(), "real opening fixture, no invented history")

func _saved() -> Dictionary:
	var result: Dictionary = {}
	for path: String in [SeasonSave.path, PitchBatLabSettings.path]:
		for suffix: String in ["", ".bak", ".tmp"]:
			var target: String = path + suffix
			result[target] = FileAccess.get_file_as_bytes(target) \
				if FileAccess.file_exists(target) else null
	return result

func _profile_object_data(value: Variant) -> Variant:
	# Read-only script-state capture, same recursive representation used by the V27 fixture.
	if value is RefCounted:
		var result: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = _profile_object_data(value.get(property.name))
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_profile_object_data(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _profile_object_data(value[key])
		return result
	return value

func _unchanged() -> bool:
	return var_to_bytes(SeasonSave.snapshot(_app.season)) == _season_bytes \
		and var_to_bytes(_caller_ledger.to_data()) == _ledger_bytes \
		and StadiumPoolOwnedAuthority._ledger_state(_caller_ledger) == _caller_ledger_state \
		and _caller_ledger.mutation_generation() == _caller_ledger_generation \
		and var_to_bytes(_profile_object_data(_source)) == _source_bytes \
		and var_to_bytes(_saved()) == var_to_bytes(_saved_files) \
		and _app.season.pending_fixture().id == 0 and _app.season.round_index == 0

func _pair_batted_launch(dry: bool) -> BattedBallLaunch:
	var profile: SwingProfileDefinition = load("res://src/content/swings/power_swing.tres")
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	intent.aim_point = Vector2(-0.020532, 1.2394542983688768)
	intent.handedness_left = true
	intent.start_time_seconds = 0.8763333333333333
	if SwingIntent.reachable_aim(intent.aim_point) != intent.aim_point:
		return null
	var pitch: PitchState = PitchState.new()
	pitch.position = Vector3(0, 1.5, 0.25)
	pitch.velocity = Vector3(0, 0, -12)
	pitch.elapsed_time = 1.0166666666666666
	pitch.orientation = (
		Quaternion(0, 0, 0.5, 0.8660254037844386)
		if dry
		else Quaternion(0, 0, -0.8660254037844386, 0.5)
	)
	var contact: ContactResult = ContactResolver.resolve_swept_segment(
		Vector3(0, 1.5, 0.45), 1.0, pitch, intent, profile, 10, 10
	)
	if contact == null or contact.outcome != ContactResult.Outcome.FOUL:
		return null
	var launch: BattedBallLaunch = BattedBallLaunch.from_contact(contact, pitch)
	if (
		not launch.is_foul
		or not launch.position.is_finite()
		or launch.position.x != 0.0
		or launch.position.y != 1.5
		or launch.position.z <= 0.25
		or launch.position.z >= 0.45
		or launch.velocity.x <= 0.0
		or launch.velocity.y <= 0.0
		or launch.velocity.z <= 0.0
		or launch.angular_velocity == Vector3.ZERO
	):
		return null
	return launch


func _ready() -> void:
	set_physics_process(false)
	_wall_start = Time.get_ticks_usec()
	var original_save_path: String = SeasonSave.path
	var original_settings_path: String = PitchBatLabSettings.path
	var original_last_error: String = SeasonSave.last_error
	var original_files: Dictionary = _saved()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-owned-contact-v64-dir="):
			_output = argument.trim_prefix("--pool-owned-contact-v64-dir=")
		if argument.begins_with("--pool-owned-contact-v64-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-owned-contact-v64-runtime=")
		if argument.begins_with("--pool-owned-contact-v64-execution="):
			_execution = argument.trim_prefix("--pool-owned-contact-v64-execution=")
		if argument.begins_with("--pool-owned-contact-v64-nonce="):
			_nonce = argument.trim_prefix("--pool-owned-contact-v64-nonce=")
	await _run_control()
	set_physics_process(false)
	if is_instance_valid(_runner):
		_runner.cancel()
		_runner.queue_free()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
	_ledger = null
	await TestAudioDrain.finish(get_tree())
	SeasonSave.path = original_save_path
	PitchBatLabSettings.path = original_settings_path
	SeasonSave.last_error = original_last_error
	_check(var_to_bytes(original_files) == var_to_bytes(_saved()),
		"original caller save/settings files and path selectors preserved")
	_check(_checks + 1 == EXPECTED_NATIVE_CHECKS, "exact source-derived successful check total")
	var summary: Dictionary = {"version": 1, "status": "PASS" if _failures == 0 else "FAILED",
		"pid": OS.get_process_id(), "runtime": _runtime, "execution": _execution, "nonce": _nonce,
		"checks": _checks, "expected_checks": EXPECTED_NATIVE_CHECKS,
		"failures": _failures, "failed": _failed, "launches": _launches,
		"ordinary_reports": _reports, "runner_errors": _runner_errors,
		"disposed": _disposed, "fixture": FIXTURE, "match_seed": MATCH_SEED,
		"terminal_captured": _terminal_captured, "terminal_frame": _terminal_frame,
		"launch_frame": _launch_frame, "release_wait_start": _wait_start,
		"max_release_frames": MAX_RELEASE_FRAMES, "max_launch_frames": MAX_LAUNCH_FRAMES,
		"wall_seconds": (Time.get_ticks_usec() - _wall_start) / 1000000.0,
		"qualification": "CONTROLLED_CONTACT_INPUT_AFTER_GENUINE_RELEASE_ONLY",
		"actual_pitched_contact_qualified": false, "production_qualified": false,
		"report_settlement_qualified": false, "performance_qualified": false,
		"rendered_qualified": false, "performance_status": "BLOCKED",
		"public_activation": "CLOSED"}
	if _output_admitted:
		var encoded: String = JSON.stringify(summary, "", true, true)
		if encoded.to_utf8_buffer().size() <= 262144:
			var output: FileAccess = FileAccess.open(
				_output.path_join("pool-owned-contact-v64-summary.json"), FileAccess.WRITE)
			if output != null:
				output.store_string(encoded)
				if output.get_error() != OK:
					_check(false, "summary output write failed")
				output.close()
			else:
				_check(false, "summary output could not open")
		else:
			_check(false, "summary exceeds fixed byte cap")
	print("POOL_OWNED_CONTACT_V64 checks=%d failures=%d launches=%d source=%s" % [
		_checks, _failures, _launches, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run_control() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"),
		"explicit external output and no child-engine jobs"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty(), "fresh empty admitted output directory"):
		return
	_output_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "actual source and run identity bound"):
		return
	if not _check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and not get_tree().paused and StadiumPoolHotpathProfile.active == null
		and process_physics_priority == 1000, "ordinary clock; only test node is a later observer"):
		return
	if not await _profile_genuine_setup():
		return
	var fixture: Dictionary = _fixture(3)
	_source = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	_caller_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(fixture == FIXTURE
		and SeasonPhysicalFixtures.seed_for(_app.season, fixture) == MATCH_SEED
		and _source != null and _caller_ledger != null
		and StadiumPoolOwnedSnapshot.valid(_source.stadium)
		and StadiumPoolOwnedSnapshot.matches(_source.stadium, _caller_ledger)
		and _source.stadium.environment.fixture == fixture.id
		and _source.stadium.environment.seed == MATCH_SEED,
		"actual scheduled paid fixture and genuine generated match seed"):
		return
	_season_bytes = var_to_bytes(SeasonSave.snapshot(_app.season))
	_ledger_bytes = var_to_bytes(_caller_ledger.to_data())
	_caller_ledger_state = StadiumPoolOwnedAuthority._ledger_state(_caller_ledger)
	_caller_ledger_generation = _caller_ledger.mutation_generation()
	_source_bytes = var_to_bytes(_profile_object_data(_source))
	_saved_files = _saved()
	_ledger = ClubPlayers.assets(_app.season.career)
	if not _check(_ledger != null and _ledger != _caller_ledger
		and var_to_bytes(_ledger.to_data()) == _ledger_bytes and _unchanged(),
		"fresh actual paid ledger replay preserves caller authority"):
		return
	_held_state = StadiumPoolOwnedAuthority._ledger_state(_ledger)
	_held_generation = _ledger.mutation_generation()
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.private_finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	_runner.failed.connect(func(reason: String) -> void: _runner_errors.append(reason))
	if not _check(_runner.start(_source, MATCH_SEED, PitchBatLab.FIELD_ID, _ledger),
		"one ordinary detached paid start with real ledger"):
		return
	_lab = _runner._lab
	_property = StadiumPoolOwnedExtension.current(_lab)
	_adapter = _lab.pool_controller_active
	if not _check(_property != null and _property.valid_owner_full_ledger(_lab)
		and _adapter != null and _adapter.enabled and _adapter.freeflight_enabled
		and _lab._automation.releases.is_empty() and _lab._play_records.is_empty()
		and _lab.pool_active_receipt == null and _lab.process_physics_priority == 0
		and _lab._primary_fielder.process_physics_priority == 0
		and _property.admitted_pose() == Transform3D(Basis.IDENTITY, Vector3(12, 0, 18))
		and _unchanged(), "full paid owner and fixed pose valid before first tick"):
		return
	_token = _property.entitlement as StadiumPoolOwnedAuthority
	_wait_start = Engine.get_physics_frames()
	_stage = "wait_release"
	set_physics_process(true)
	while not _done:
		await get_tree().physics_frame
	set_physics_process(false)
	await _dispose_and_write()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(_lab) or not _runner._running or _runner._lab != _lab:
		_check(false, "ordinary runner ended before bounded contact observation")
		_done = true
		return
	var frame: int = Engine.get_physics_frames()
	if _stage == "wait_release":
		if _lab._automation.releases.size() == 1:
			_launch_controlled()
		elif frame - _wait_start >= MAX_RELEASE_FRAMES or _lab._automation.releases.size() > 1:
			_check(false, "first genuine release unavailable within fixed admission window")
			_done = true
	elif _stage == "flight":
		if _state.dead:
			_capture_terminal()
		elif frame - _launch_frame >= MAX_LAUNCH_FRAMES:
			_check(false, "controlled launch had no terminal within180 physics callbacks")
			_post_commit = _body_copy()
			_done = true
	elif _stage == "later":
		# One subsequent callback only. Accelerated ordinary idle cadence may dispose
		# the original ball before this callback. That is recorded, never prevented.
		_later = _body_copy()
		_later["original_body_survived"] = is_instance_valid(_ball)
		_later["original_body_is_current"] = is_instance_valid(_ball) and _lab._batted_ball == _ball
		_check(frame == _terminal_frame + 1, "later observation is exactly next physics callback")
		_done = true


func _launch_controlled() -> void:
	if not _check(Engine.get_physics_frames() - _wait_start <= MAX_RELEASE_FRAMES
		and _lab._match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT
		and _lab._pitch_actor.running and _lab._pitch_actor.state != null
		and _lab._at_bat_cadence.state != AtBatCadenceController.State.DELIVERY
		and _lab._batted_ball == null and _lab._active_play_record != null
		and _lab._play_records.is_empty() and _launches == 0,
		"first actual live pitch admitted after consumed delivery and before any terminal"):
		_done = true
		return
	_actual_release = {"physics_frame": Engine.get_physics_frames(),
		"releases": _lab._automation.releases.duplicate(true),
		"pitch_state_at_admission": _profile_object_data(_lab._pitch_actor.state),
		"pitch_parameters": _profile_object_data(_lab._pitch_actor.parameters),
		"active_record": _lab._active_play_record.to_dict(),
		"cadence_state": int(_lab._at_bat_cadence.state),
		"phase": int(_lab._match_state.phase), "throw_number": _lab._throw_number}
	if not _check(_ordinary_listener_exact(),
		"unchanged exact ordinary outcome listener before launch"):
		_done = true
		return
	if not _check(_property.valid_owner_full_ledger(_lab) and _held_unchanged() and _unchanged(),
		"full live paid authority and source/save boundary valid at controlled launch"):
		_done = true
		return
	_before = _match_copy()
	var launch: BattedBallLaunch = _pair_batted_launch(false)
	if not _check(launch != null, "exact legal projected spinning-foul resolver launch"):
		_done = true
		return
	_launch_values = _profile_object_data(launch)
	_launch_frame = Engine.get_physics_frames()
	_launches += 1
	_lab._start_ball_in_play(launch)
	_ball = _lab._batted_ball
	_state = _lab._ball_play_resolver.state
	_launch_guard = _adapter._guard
	if not _check(_ball != null and _state != null and not _state.dead and _state.is_foul_play
		and _lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY
		and not _lab._pitch_actor.running and _lab._pitch_actor.state == null
		and _adapter._ball == _ball and _adapter._state == _state
		and _adapter._guard != null and _adapter._guard.generation == 1
		and _adapter.commits == 0 and _adapter.decline.is_empty()
		and _lab.is_physics_processing() and _lab._primary_fielder.is_physics_processing(),
		"ordinary launch resets real pitch and binds first owned guard without changing physics"):
		_done = true
		return
	_stage = "flight"


func _capture_terminal() -> void:
	_terminal_frame = Engine.get_physics_frames()
	_terminal_captured = true
	_post_commit = _body_copy()
	var records: Array[Dictionary] = []
	for record: PlayRecord in _lab._play_records:
		records.append(record.to_dict())
	_terminal = {"physics_frame": _terminal_frame, "completed_records": records,
		"record_delta": records.size() - int(_before.completed_records),
		"adapter_commits": _adapter.commits, "adapter_last_commit": _adapter.last_commit.duplicate(true),
		"adapter_decline": _adapter.decline, "match": _match_copy(),
		"state": _profile_object_data(_state), "ordinary_listener_exact": _ordinary_listener_exact(),
		"full_owner_valid": _property.valid_owner_full_ledger(_lab),
		"caller_unchanged": _unchanged(), "held_ledger_unchanged": _held_unchanged()}
	_check(_terminal_frame > _launch_frame and _terminal_frame - _launch_frame <= MAX_LAUNCH_FRAMES,
		"actual terminal captured in same later-priority fixture callback within bound")
	_check(records.size() == 1 and _terminal.record_delta == 1 and _adapter.commits == 1
		and _state.dead and _adapter.decline.is_empty(),
		"one completed ordinary record and one adapter commit with dead latch")
	var record: PlayRecord = _lab._play_records[0] if _lab._play_records.size() == 1 else null
	_check(record != null and record.result == &"foul"
		and record.resolution_reason == &"owned_pool_controller_water_foul",
		"ordinary retained record records owned water foul reason and result")
	var commit: Dictionary = _adapter.last_commit
	var witness_valid: bool = (commit.has("position") and commit.position is Vector3
		and commit.position.is_finite() and commit.get("foul", false)
		and commit.get("generation", -1) == 1 and commit.has("entry_fraction")
		and commit.entry_fraction is float and is_finite(commit.entry_fraction)
		and commit.entry_fraction > 0.0 and commit.entry_fraction < 1.0)
	_check(witness_valid, "actual retained world witness and strict in-range chronological fraction")
	var same_witness: bool = (witness_valid and record != null and is_instance_valid(_ball)
		and commit.position == record.resolution_position and _ball.global_position == commit.position)
	_terminal["witness_exact"] = same_witness
	_terminal["fraction_valid"] = witness_valid
	if witness_valid:
		_terminal["normalized_witness"] = StadiumPoolOwnedFreeflight.normalized(
			_property.admitted_pose(), commit.position)
	_check(same_witness and _ball.linear_velocity == Vector3.ZERO
		and _ball.angular_velocity == Vector3.ZERO and _ball.sleeping,
		"ordinary outcome body stops at exact committed witness in same callback")
	_check(not _state.has_grounded and not _state.defender_touched and not _state.bobbled
		and not _state.caught and _state.result_floor == BallPlayState.ResultFloor.NONE
		and _state.stadium_contacts.is_empty() and _state.last_defender_touch == &""
		and record != null and not record.has_first_ground and record.result_floor == 0,
		"actual terminal preserves no earlier ground catch defender or earned floor")
	var after: Dictionary = _terminal.match
	_check(after.bases == _before.bases and after.strikes == _before.strikes + 1
		and after.balls == _before.balls and after.outs == _before.outs
		and after.pa == _before.pa and after.phase == MatchState.Phase.PLAY_DEAD,
		"ordinary foul holds bases and advances only one strike")
	_check(_terminal.full_owner_valid and _terminal.caller_unchanged
		and _terminal.held_ledger_unchanged and _terminal.ordinary_listener_exact
		and _lab.pool_active_receipt == null and _reports == 0,
		"full paid boundary remains valid after ordinary commit with no new listeners")
	_stage = "later"


func _ordinary_listener_exact() -> bool:
	var rows: Array = _lab._ball_play_resolver.get_signal_connection_list(&"play_resolved")
	return rows.size() == 1 and rows[0].flags == 0 \
		and rows[0].callable == _lab._on_ball_play_resolved


func _match_copy() -> Dictionary:
	return {"bases": StadiumPoolActiveReceipt.bases(_lab),
		"balls": _lab._match_state.balls, "strikes": _lab._match_state.strikes,
		"outs": _lab._match_state.outs, "pa": _lab._match_state.plate_appearance_number,
		"phase": int(_lab._match_state.phase), "completed_records": _lab._play_records.size()}


func _body_copy() -> Dictionary:
	var values: Dictionary = {"physics_frame": Engine.get_physics_frames(),
		"body_valid": is_instance_valid(_ball), "commits": _adapter.commits,
		"decline": _adapter.decline, "last_commit": _adapter.last_commit.duplicate(true),
		"current_body_valid": is_instance_valid(_lab._batted_ball),
		"match": _match_copy(), "releases": _lab._automation.releases.duplicate(true)}
	if is_instance_valid(_ball):
		values.merge({"body_id": _ball.get_instance_id(), "position": _ball.global_position,
			"velocity": _ball.linear_velocity, "spin": _ball.angular_velocity,
			"sleeping": _ball.sleeping, "freeze": _ball.freeze,
			"router_valid": _ball.physics_contact_router.is_valid(),
			"original_is_current": _lab._batted_ball == _ball})
	return values


func _held_unchanged() -> bool:
	return StadiumPoolOwnedAuthority._ledger_state(_ledger) == _held_state \
		and _ledger.mutation_generation() == _held_generation


func _dispose_and_write() -> void:
	var guard: StadiumPoolWaterGuard = _launch_guard
	var guard_data: Dictionary = {}
	if guard != null:
		guard_data = {"records": guard.records.duplicate(true),
			"unsupported": guard.unsupported.duplicate(true), "receipts": guard.receipts.duplicate(true),
			"errors": guard.errors.duplicate(true)}
	var end_body: Dictionary = _body_copy()
	var live: WeakRef = weakref(_lab)
	var property_live: WeakRef = weakref(_property)
	var body_live: WeakRef = weakref(_ball) if is_instance_valid(_ball) else null
	_runner.cancel()
	await get_tree().process_frame
	_disposed = (live.get_ref() == null and property_live.get_ref() == null
		and (body_live == null or body_live.get_ref() == null)
		and _runner._lab == null and _runner._viewport == null and not _runner._running
		and _runner.get_child_count() == 0 and not _adapter.enabled and _adapter._lab == null
		and _adapter._ball == null and _adapter._guard == null
		and not _adapter._ordinary_router.is_valid())
	_check(_disposed, "ordinary cancel disposes owned body guard routers and live nodes")
	var retired: bool = _token._owner != null and _token._owner.get_ref() == null
	_check(retired and _held_unchanged() and _unchanged() and _reports == 0
		and _runner_errors.is_empty(), "paid token retired without reports or source/save mutation")
	var detail: Dictionary = {"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce, "actual_release": _actual_release,
		"controlled_input_helper": "stadium_pool_controller_active_test.gd::_pair_batted_launch(false)",
		"controlled_inputs": {"profile": "res://src/content/swings/power_swing.tres",
			"aim_point": [-0.020532, 1.2394542983688768], "handedness_left": true,
			"swing_start_time_seconds": 0.8763333333333333,
			"pitch_position": [0, 1.5, 0.25], "pitch_velocity": [0, 0, -12],
			"pitch_elapsed_time": 1.0166666666666666,
			"pitch_orientation": [0, 0, -0.8660254037844386, 0.5],
			"previous_position": [0, 1.5, 0.45], "previous_elapsed_seconds": 1.0,
			"contact_ratings": [10, 10], "dry": false},
		"controlled_launch": _launch_values, "before": _before, "terminal": _terminal,
		"same_iteration_body": _post_commit, "later_body": _later, "end_body": end_body,
		"guard": guard_data, "launches": _launches, "disposed": _disposed,
		"token_retired": retired, "caller_preserved": _unchanged(),
		"held_ledger_preserved": _held_unchanged(), "ordinary_reports": _reports,
		"completed_record_evidence_not_independent_signal_count": true,
		"precommit_segment_not_independently_observed": true,
		"preservation_hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"season_sha256": _season_bytes.hex_encode().sha256_text(),
		"ledger_sha256": _ledger_bytes.hex_encode().sha256_text(),
		"source_sha256": _source_bytes.hex_encode().sha256_text(),
		"saved_files_sha256": var_to_bytes(_saved_files).hex_encode().sha256_text()}
	_check(guard_data.get("records", []).size() <= 256
		and guard_data.get("unsupported", []).size() <= 256
		and guard_data.get("receipts", []).size() <= 128,
		"bounded complete actual guard evidence without truncation")
	var native: PackedByteArray = var_to_bytes(detail)
	detail["native_snapshot_hex"] = native.hex_encode()
	detail["native_snapshot_hex_sha256"] = native.hex_encode().sha256_text()
	_write("pool-owned-contact-v64-contact.json", _json_values(detail))


# Native snapshot hex preserves exact Variant types; JSON vectors are numeric arrays.
func _json_values(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[String(key)] = _json_values(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry: Variant in value:
			result.append(_json_values(entry))
		return result
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector2:
		return [value.x, value.y]
	if value is Quaternion:
		return [value.x, value.y, value.z, value.w]
	if value is Transform3D:
		return [_json_values(value.basis.x), _json_values(value.basis.y),
			_json_values(value.basis.z), _json_values(value.origin)]
	if value is StringName:
		return String(value)
	return value
