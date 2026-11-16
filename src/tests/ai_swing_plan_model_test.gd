extends Node
## Paired legacy comparison: identical RNG decisions, only legal lock mode/start changes.

const LEGACY = preload("res://src/tests/ai_swing_plan_legacy_model.gd")
var _checks: int = 0
var _failures: int = 0
var _opposite: int = 0


func _ready() -> void:
	var contact: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	var power: SwingProfileDefinition = ContentDB.get_swing(&"swing.power")
	var pitch: PitchDefinition = ContentDB.get_pitch(&"pitch.overhand_four_seam")
	var batter: PlayerDefinition = SeasonBuild.new(
		1, ["player.quinn_riley"]).definition("player.quinn_riley")
	for hand in range(2):
		for count: Vector2i in [Vector2i(0, 0), Vector2i(0, 2), Vector2i(3, 0)]:
			for seed_value in range(256):
				for lock: StringName in [&"", &"swing.contact", &"swing.power"]:
					var old: RefCounted = LEGACY.new()
					var current: BatterApproachModel = BatterApproachModel.new()
					var state: PitchState = PitchState.new()
					state.position = Vector3(0.1, 1.2, 3.0)
					state.velocity = Vector3(0.1, 0.3, -20.0)
					state.elapsed_time = 0.4
					old.track_pitch(pitch, state, batter, count.x, count.y,
						seed_value, hand, contact, power)
					current.locked_swing = lock
					current.track_pitch(pitch, state, batter, count.x, count.y,
						seed_value, hand, contact, power)
					var expected: Dictionary = old._plan.duplicate(true)
					if lock != &"":
						var use_power: bool = lock == power.id
						_opposite += int(expected.use_power != use_power)
						expected.use_power = use_power
						var profile: SwingProfileDefinition = power if use_power else contact
						expected.start_time = expected.contact_time - profile.sweet_spot_seconds
					_check(current._plan == expected,
						"paired plan preserves all RNG-derived values except legal lock timing")
					if lock == &"":
						_check(current.pitch_seen_counts == old.pitch_seen_counts,
							"unlocked planning preserves original observation timing")
	var boundary: BatterApproachModel = BatterApproachModel.new()
	boundary.locked_swing = &"swing.power"
	boundary.reset_pitch()
	_check(boundary.locked_swing == &"swing.power", "next pitch retains entire-PA lock")
	boundary.begin_plate_appearance(2)
	_check(boundary.locked_swing == &"", "new PA clears prior lock before current policy")
	_check(_opposite > 100, "both opposite-choice timing paths exercised")
	print("AI_PLAN_MODEL checks=", _checks, " opposite=", _opposite, " failures=", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)
