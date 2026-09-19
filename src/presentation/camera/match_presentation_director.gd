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

const SHOT_SECONDS: float = 0.82
const SETTLE_SECONDS: float = 0.38

var mode: Mode = Mode.IDLE
var shot_sequence: Array[int] = []
var shot_index: int = 0
var elapsed_seconds: float = 0.0

func begin_intro(seed: int) -> void:
	shot_sequence = _select_shots(seed, true)
	shot_index = 0
	elapsed_seconds = 0.0
	mode = Mode.INTRO

func begin_outro(seed: int) -> void:
	shot_sequence = _select_shots(seed, false)
	shot_index = 0
	elapsed_seconds = 0.0
	mode = Mode.OUTRO

func reset() -> void:
	mode = Mode.IDLE
	shot_sequence.clear()
	shot_index = 0
	elapsed_seconds = 0.0

func blocks_gameplay() -> bool:
	return mode != Mode.IDLE

func current_shot() -> int:
	if shot_sequence.is_empty():
		return MatchCameraDirector.Shot.ESTABLISHING
	return shot_sequence[clampi(shot_index, 0, shot_sequence.size() - 1)]

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
	elif elapsed_seconds >= SHOT_SECONDS:
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

static func _select_shots(seed: int, include_batting: bool) -> Array[int]:
	var pool: Array[int] = [
		MatchCameraDirector.Shot.ESTABLISHING,
		MatchCameraDirector.Shot.SIDE,
		MatchCameraDirector.Shot.PITCHING,
	]
	if include_batting:
		pool.append(MatchCameraDirector.Shot.BATTING)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	for index in range(pool.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: int = pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = held
	var shot_count: int = rng.randi_range(2, 3)
	var result: Array[int] = []
	for index in range(mini(shot_count, pool.size())):
		result.append(pool[index])
	return result
