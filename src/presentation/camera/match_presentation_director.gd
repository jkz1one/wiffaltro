class_name MatchPresentationDirector
extends RefCounted

enum Mode {
	IDLE,
	INTRO,
	INTRO_SETTLE,
	OUTRO,
	OUTRO_HOLD,
}

enum Event {
	NONE,
	SHOT_CHANGED,
	RETURN_TO_GAMEPLAY,
	INTRO_COMPLETE,
	OUTRO_COMPLETE,
}

const SHOT_SECONDS: float = 1.70
const LONG_SHOT_SECONDS: float = 2.90
const SETTLE_SECONDS: float = 0.38

var mode: Mode = Mode.IDLE
var shot_sequence: Array[MatchCameraDirector.Shot] = []
var motion_sequence: Array[MatchCameraDirector.PresentationMotion] = []
var shot_index: int = 0
var elapsed_seconds: float = 0.0

func begin_intro(sequence_seed: int) -> void:
	shot_sequence = _select_shots(sequence_seed, true)
	motion_sequence = _select_motions(sequence_seed + 104729, shot_sequence.size())
	shot_index = 0
	elapsed_seconds = 0.0
	mode = Mode.INTRO

func begin_outro(sequence_seed: int) -> void:
	shot_sequence = _select_shots(sequence_seed, false)
	motion_sequence = _select_motions(sequence_seed + 130363, shot_sequence.size())
	shot_index = 0
	elapsed_seconds = 0.0
	mode = Mode.OUTRO

func reset() -> void:
	mode = Mode.IDLE
	shot_sequence.clear()
	motion_sequence.clear()
	shot_index = 0
	elapsed_seconds = 0.0

func blocks_gameplay() -> bool:
	return mode != Mode.IDLE

func current_shot() -> MatchCameraDirector.Shot:
	if shot_sequence.is_empty():
		return MatchCameraDirector.Shot.ESTABLISHING
	return shot_sequence[clampi(shot_index, 0, shot_sequence.size() - 1)]

func current_motion() -> MatchCameraDirector.PresentationMotion:
	if motion_sequence.is_empty():
		return MatchCameraDirector.PresentationMotion.STILL
	return motion_sequence[clampi(shot_index, 0, motion_sequence.size() - 1)]

func shot_progress() -> float:
	if mode == Mode.INTRO_SETTLE or mode == Mode.OUTRO_HOLD:
		return 1.0
	return clampf(elapsed_seconds / shot_duration_seconds(), 0.0, 1.0)

func shot_duration_seconds() -> float:
	return LONG_SHOT_SECONDS if shot_sequence.size() == 1 else SHOT_SECONDS

func advance(delta_seconds: float) -> Event:
	var next_event: Event = Event.NONE
	if mode == Mode.IDLE or mode == Mode.OUTRO_HOLD:
		return next_event

	elapsed_seconds += maxf(0.0, delta_seconds)
	if mode == Mode.INTRO_SETTLE:
		if elapsed_seconds >= SETTLE_SECONDS:
			mode = Mode.IDLE
			elapsed_seconds = 0.0
			next_event = Event.INTRO_COMPLETE
	elif elapsed_seconds >= shot_duration_seconds():
		elapsed_seconds = 0.0
		if shot_index + 1 < shot_sequence.size():
			shot_index += 1
			next_event = Event.SHOT_CHANGED
		elif mode == Mode.INTRO:
			mode = Mode.INTRO_SETTLE
			next_event = Event.RETURN_TO_GAMEPLAY
		else:
			mode = Mode.OUTRO_HOLD
			next_event = Event.OUTRO_COMPLETE
	return next_event

func skip() -> Event:
	if mode == Mode.INTRO or mode == Mode.INTRO_SETTLE:
		mode = Mode.IDLE
		return Event.INTRO_COMPLETE
	if mode == Mode.OUTRO:
		mode = Mode.OUTRO_HOLD
		return Event.OUTRO_COMPLETE
	return Event.NONE

static func _select_shots(
	sequence_seed: int,
	include_batting: bool
) -> Array[MatchCameraDirector.Shot]:
	var pool: Array[MatchCameraDirector.Shot] = [
		MatchCameraDirector.Shot.ESTABLISHING,
		MatchCameraDirector.Shot.SIDE,
		MatchCameraDirector.Shot.PITCHING,
		MatchCameraDirector.Shot.FOUL_SIDE,
		MatchCameraDirector.Shot.OUTFIELD,
	]
	if include_batting:
		pool.append(MatchCameraDirector.Shot.BATTING)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sequence_seed
	for index in range(pool.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: MatchCameraDirector.Shot = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = held
	# One in four packages is a single longer take. The others deliberately
	# alternate between two and three shots.
	var package_variant: int = absi(sequence_seed) % 4
	var shot_count: int = 1 if package_variant == 0 else (2 if package_variant <= 2 else 3)
	var result: Array[MatchCameraDirector.Shot] = []
	for index in range(mini(shot_count, pool.size())):
		result.append(pool[index])
	return result

static func _select_motions(
	sequence_seed: int,
	shot_count: int
) -> Array[MatchCameraDirector.PresentationMotion]:
	var pool: Array[MatchCameraDirector.PresentationMotion] = [
		MatchCameraDirector.PresentationMotion.STILL,
		MatchCameraDirector.PresentationMotion.ZOOM_IN,
		MatchCameraDirector.PresentationMotion.ZOOM_OUT,
		MatchCameraDirector.PresentationMotion.PAN_LEFT,
		MatchCameraDirector.PresentationMotion.PAN_RIGHT,
		MatchCameraDirector.PresentationMotion.TILT_UP,
		MatchCameraDirector.PresentationMotion.TILT_DOWN,
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sequence_seed
	var result: Array[MatchCameraDirector.PresentationMotion] = []
	for index in range(shot_count):
		var motion: MatchCameraDirector.PresentationMotion = pool[
			rng.randi_range(0, pool.size() - 1)
		]
		if index > 0 and motion == result[index - 1]:
			motion = pool[(int(motion) + 1) % pool.size()]
		result.append(motion)
	return result
