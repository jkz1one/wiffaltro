class_name AtBatCadenceController
extends RefCounted

enum State {
	IDLE,
	DELIVERY,
	PITCH_LIVE,
	DEAD_BALL_HOLD,
}

enum Event {
	NONE,
	THROW_PITCH,
	CONTINUE_PLAY,
}

const DELIVERY_SECONDS: float = 1.35
const DEAD_BALL_HOLD_SECONDS: float = 0.90
const MIN_DELIVERY_SECONDS: float = 1.12
const MAX_DELIVERY_SECONDS: float = 1.78
const LONG_SET_CHANCE: float = 0.18

var state: State = State.IDLE
var elapsed_seconds: float = 0.0
var active_delivery_seconds: float = DELIVERY_SECONDS
var active_hold_seconds: float = DEAD_BALL_HOLD_SECONDS

func begin_delivery(seed: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	active_delivery_seconds = rng.randf_range(
		MIN_DELIVERY_SECONDS,
		MAX_DELIVERY_SECONDS
	)
	if rng.randf() < LONG_SET_CHANCE:
		active_delivery_seconds += rng.randf_range(0.28, 0.62)
	state = State.DELIVERY
	elapsed_seconds = 0.0

func mark_pitch_live() -> void:
	state = State.PITCH_LIVE
	elapsed_seconds = 0.0

func hold_dead_ball(seed: int = 0) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	active_hold_seconds = rng.randf_range(0.72, 1.08)
	state = State.DEAD_BALL_HOLD
	elapsed_seconds = 0.0

func stop() -> void:
	state = State.IDLE
	elapsed_seconds = 0.0

func advance(delta_seconds: float) -> Event:
	if state != State.DELIVERY and state != State.DEAD_BALL_HOLD:
		return Event.NONE
	elapsed_seconds += maxf(0.0, delta_seconds)
	if state == State.DELIVERY and elapsed_seconds >= active_delivery_seconds:
		state = State.PITCH_LIVE
		return Event.THROW_PITCH
	if (
		state == State.DEAD_BALL_HOLD
		and elapsed_seconds >= active_hold_seconds
	):
		state = State.IDLE
		return Event.CONTINUE_PLAY
	return Event.NONE

func delivery_progress() -> float:
	if state != State.DELIVERY:
		return 0.0
	return clampf(elapsed_seconds / active_delivery_seconds, 0.0, 1.0)

func delivery_cue() -> String:
	var progress: float = delivery_progress()
	if progress < 0.28:
		return "PITCHER SET"
	if progress < 0.82:
		return "WINDUP"
	return "DELIVERY"
