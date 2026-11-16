extends Node
## Fixed real AY02 fixture2 observation from the retained completed-human checkpoint.
## Ordinary PhysicalMatchRunner only. Cancellation preserves the complete saved season.
# gdlint: disable=max-returns

const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
const INPUT: String = "res://src/tests/fixtures/ac02-public-completed-pending.json"
const INPUT_SHA: String = "af9a5c7d8e4d92e31290d5dabce9a006172f4065c8f3e00e529e28d4c7114356"
const FRAME_LIMIT: int = 1200
const WINDOW_MSEC: int = 120000
const TOTAL_MSEC: int = 150000
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _checks: int = 0
var _failures: int = 0
var _frames: int = 0
var _born: int = 0
var _window: int = 0
var _observation_msec: int = 0
var _reason: String = "setup_failed"
var _runner_failure: String = ""
var _reports: int = 0
var _begin: Dictionary = {}
var _end: Dictionary = {}
var _ordinary: bool = false
var _preserved: bool = false
var _cancelled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_born = Time.get_ticks_msec()
	await _run()
	await TestAudioDrain.finish(get_tree())
	_check(Time.get_ticks_msec() - _born < TOTAL_MSEC, "bounded total native birth")
	print("AY02_PUBLIC_ISSUED_PROGRESS_REPORT ", JSON.stringify({
		"schema": "ay02-public-issued-progress-v1", "runtime": _runtime,
		"execution": _execution, "nonce": _nonce, "pid": OS.get_process_id(),
		"input_sha256": INPUT_SHA, "checks": _checks, "failures": _failures,
		"status": "PASS" if _failures == 0 else "FAILED", "stop_reason": _reason,
		"frames": _frames, "frame_limit": FRAME_LIMIT, "window_msec": WINDOW_MSEC,
		"total_msec": TOTAL_MSEC, "wall_msec": Time.get_ticks_msec() - _born,
		"observation_msec": _observation_msec,
		"begin": _begin, "end": _end, "ordinary_callbacks": _ordinary,
		"season_unchanged": _preserved, "cancelled": _cancelled,
		"runner_failure": _runner_failure, "reports": _reports, "completed_games": 0}))
	if _failures == 0:
		print("AY02_PUBLIC_ISSUED_PROGRESS_PASS")
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var expected: String = ""
	for argument: String in args:
		if argument.begins_with("--ay02-issued-runtime="):
			expected = argument.trim_prefix("--ay02-issued-runtime=")
		elif argument.begins_with("--ay02-issued-execution="):
			_execution = argument.trim_prefix("--ay02-issued-execution=")
		elif argument.begins_with("--ay02-issued-nonce="):
			_nonce = argument.trim_prefix("--ay02-issued-nonce=")
	if not _check(args.size() == 4 and args.has("--physical-in-process"), "exact four arguments"):
		return
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if not _check(_runtime.length() == 64 and _runtime == expected
		and _execution.length() == 64 and _nonce.length() == 32, "exact source and run identities"):
		return
	if not _check(FileAccess.get_sha256(INPUT) == INPUT_SHA
		and FileAccess.get_file_as_bytes(INPUT).size() == 385135, "exact retained checkpoint bytes"):
		return
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		FileAccess.get_file_as_string(INPUT)))
	if not _check(season != null and season.npc_venues.version == 3
		and season.physical.pending.human.size() == 17
		and season.physical.pending.reports.size() == 1, "genuine saved v3 pending season restores"):
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var fixture: Dictionary = SeasonVenues.fixture_for_id(season, 2)
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if not _check(fixture == {"id": 2, "round": 0, "away": 2, "home": 3}
		and source != null and source.stadium.manifest.id == "AY-02"
		and source.stadium.version == 19 and source.stadium.binding.fixture == 2,
		"exact pending AY02 AI fixture2 public19 context"):
		return
	if not _check(_clock_valid(), "ordinary unpaused fixed60 clock"):
		return
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.failed.connect(func(reason: String) -> void: _runner_failure = reason)
	runner.finished.connect(func(_report: Dictionary) -> void: _reports += 1)
	var started: bool = runner.start(source, SeasonPhysicalFixtures.seed_for(season, fixture),
		&"field.npc_venue", null, {}, season)
	if not _check(started and runner._lab != null and runner._running,
		"ordinary real PhysicalMatchRunner starts"):
		runner.cancel()
		runner.queue_free()
		return
	var lab: PitchBatLab = runner._lab
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var live: WeakRef = weakref(lab)
	_check(property != null and property.public_bound and property.ordinary_callbacks()
		and not lab.has_meta(R.OPT_IN) and not lab.has_meta(R.RETAINED_OPT_IN),
		"issued public startup keeps exact ordinary callbacks")
	_begin = _snapshot(lab)
	_window = Time.get_ticks_msec()
	_reason = "frame_limit"
	for frame in range(FRAME_LIMIT):
		if Time.get_ticks_msec() - _born >= TOTAL_MSEC \
			or Time.get_ticks_msec() - _window >= WINDOW_MSEC:
			_reason = "wall_bound"
			break
		if not _clock_valid() or not runner._running or not is_instance_valid(runner._lab):
			_reason = "runner_or_clock_stopped"
			break
		await get_tree().physics_frame
		_frames = frame + 1
		if not is_instance_valid(runner._lab):
			_reason = "runner_stopped"
			break
		_end = _snapshot(lab)
	_observation_msec = Time.get_ticks_msec() - _window
	if is_instance_valid(runner._lab):
		_end = _snapshot(lab)
		_ordinary = property != null and property.ordinary_callbacks() \
			and property.phase in [&"ready", &"playing"] \
			and not lab.has_meta("stadium_npc_runtime_interrupted")
	_check(_reason in ["frame_limit", "wall_bound"] and _end.get("releases", 0) >= 3
		and _end.get("plays", 0) >= 1 and _end.get("elapsed", 0.0) > _begin.get("elapsed", 0.0)
		and _reports == 0 and _runner_failure.is_empty() and _frames > 0
		and _observation_msec > 0, "bounded window observes three releases and one actual play")
	_check(_ordinary and _clock_valid(), "ordinary callback graph and fixed60 preserved")
	_check(is_instance_valid(runner._lab) and R.installed_bound(lab, lab._match_state.stadium),
		"cold final public installation validates actual observed runtime")
	runner.cancel()
	await get_tree().process_frame
	_cancelled = not runner._running and runner._lab == null and runner._viewport == null \
		and live.get_ref() == null
	_check(_cancelled, "ordinary cancel removes runtime without a completed report")
	_preserved = ClubCareer.same(before, SeasonSave.snapshot(season))
	_check(_preserved, "saved pending human and first AI evidence remain exact")
	_check(FileAccess.get_sha256(INPUT) == INPUT_SHA,
		"retained checkpoint unchanged after observation")
	runner.queue_free()
	await get_tree().process_frame


func _snapshot(lab: PitchBatLab) -> Dictionary:
	var state: MatchState = lab._match_state
	return {"elapsed": state.elapsed_seconds, "throws": lab._throw_number,
		"releases": lab._automation.releases.size() if lab._automation != null else -1,
		"plays": lab._play_records.size(), "phase": state.phase,
		"pa": state.plate_appearance_number, "balls": state.balls, "strikes": state.strikes,
		"outs": state.outs, "pitch_running": lab._pitch_actor.running}


func _clock_valid() -> bool:
	return not get_tree().paused and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AY02_PUBLIC_ISSUED_PROGRESS " + label)
	return ok
