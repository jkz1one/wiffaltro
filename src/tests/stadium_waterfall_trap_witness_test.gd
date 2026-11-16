extends Node
const Witness = preload("res://src/presentation/stadium/stadium_waterfall_trap_witness.gd")
const Geometry = preload("res://src/presentation/stadium/stadium_waterfall_live_models.gd")
const R: float = 0.0365
const REST: Vector3 = Vector3(0, 0.2365, -1.08)
var checks: int = 0
var failures: int = 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("WATERFALL_WITNESS_FAILURE " + label)


func _sample(
	previous: Vector3,
	position: Vector3,
	frame: int,
	velocity: Vector3 = Vector3.ZERO,
	contact: String = "none"
) -> Dictionary:
	return {
		"copy": "OWNED-WATERFALL-1",
		"serial": 1,
		"frame": frame,
		"time": frame * 0.05,
		"previous": previous,
		"position": position,
		"velocity": velocity,
		"radius": R,
		"active": true,
		"contact": contact
	}


func _proof() -> Dictionary:
	var witness: StadiumWaterfallTrapWitness = Witness.new()
	var proof: Dictionary = {}
	witness.observe(_sample(Vector3(0, 0.8, -1.08), Vector3(0, 0.5, -1.08), 1, Vector3.DOWN))
	witness.observe(_sample(Vector3(0, 0.5, -1.08), REST, 2, Vector3.DOWN, "impact"))
	for frame in range(3, 11):
		proof = witness.observe(_sample(REST, REST, frame, Vector3.ZERO, "support"))
	return proof


func _ready() -> void:
	var proof: Dictionary = _proof()
	_check(
		not proof.is_empty() and Witness.replay(proof),
		"entry plus continuously quiet real basin pocket yields replayable proof"
	)
	_check(
		proof.get("observed_at", 0.0) - proof.get("quiet_since", 0.0) >= Witness.DWELL,
		"actual quiet duration, not total play timeout"
	)
	for field: String in [
		"copy", "serial", "volume", "quiet_since", "observed_at", "frame", "radius"
	]:
		var bad: Dictionary = proof.duplicate(true)
		bad[field] = "tampered" if bad[field] is String else 999
		_check(not Witness.replay(bad), "replay rejects changed " + field)
	var forged: Dictionary = proof.duplicate(true)
	for row: Dictionary in forged.samples:
		row.previous = REST
		row.position = REST
	_check(not Witness.replay(forged), "terminal location alone cannot fake entry")
	var initial: StadiumWaterfallTrapWitness = Witness.new()
	for frame in range(1, 15):
		_check(initial.observe(_sample(REST, REST, frame)).is_empty(), "initial overlap never arms")
	for mutation: String in [
		"copy", "serial", "radius", "frame", "time", "previous", "active", "gap"
	]:
		var witness: StadiumWaterfallTrapWitness = Witness.new()
		witness.observe(_sample(Vector3(0, 0.8, -1.08), Vector3(0, 0.5, -1.08), 1))
		var bad: Dictionary = _sample(Vector3(0, 0.5, -1.08), REST, 2)
		match mutation:
			"copy":
				bad.copy = "ANOTHER-PAID-COPY"
			"serial":
				bad.serial = 2
			"radius":
				bad.radius = R * 2
			"frame":
				bad.frame = 1
			"time":
				bad.time = 0.0
			"previous":
				bad.previous = Vector3.ZERO
			"active":
				bad.active = false
			"gap":
				bad.time = 1.0
		witness.observe(bad)
		var result: Dictionary = {}
		for frame in range(3, 15):
			result = witness.observe(_sample(REST, REST, frame))
		_check(result.is_empty(), "reset invalidates stale " + mutation)
	for mode: String in ["floating", "moving", "rim", "impact", "drift", "oscillation"]:
		var witness: StadiumWaterfallTrapWitness = Witness.new()
		witness.observe(_sample(Vector3(0, 0.8, -1.08), Vector3(0, 0.5, -1.08), 1))
		var previous: Vector3 = Vector3(0, 0.5, -1.08)
		var any_proof: bool = false
		for frame in range(2, 30):
			var point: Vector3 = REST
			var velocity: Vector3 = Vector3.ZERO
			var contact: String = "none"
			match mode:
				"floating":
					point.y += 0.10
				"moving":
					velocity.x = 0.5
				"rim":
					point.z = -1.45
				"impact":
					contact = "impact"
				"drift":
					point.x += (frame - 2) * 0.002
				"oscillation":
					point.x += 0.001 if frame % 2 == 0 else -0.001
			any_proof = (
				not witness.observe(_sample(previous, point, frame, velocity, contact)).is_empty()
				or any_proof
			)
			previous = point
		_check(not any_proof, "rejects " + mode + " without faking a trapped result")
	for mode: String in ["verified_floor", "unverified_impact", "too_deep"]:
		var witness: StadiumWaterfallTrapWitness = Witness.new()
		witness.observe(_sample(Vector3(0, 0.8, -1.08), Vector3(0, 0.5, -1.08), 1))
		var impact: Vector3 = REST - Vector3.UP * (0.0092 if mode != "too_deep" else 0.03)
		_check(
			(
				witness
				. observe(
					_sample(
						Vector3(0, 0.5, -1.08),
						impact,
						2,
						Vector3.DOWN,
						"floor_impact" if mode != "unverified_impact" else "impact"
					)
				)
				. is_empty()
			),
			"penetration never itself proves trapping " + mode
		)
		witness.observe(_sample(impact, REST, 3, Vector3.UP * 0.2, "floor_impact"))
		var result: Dictionary = {}
		for frame in range(4, 12):
			result = witness.observe(_sample(REST, REST, frame, Vector3.ZERO, "support"))
		_check(
			(
				(not result.is_empty() and Witness.replay(result))
				if mode == "verified_floor"
				else result.is_empty()
			),
			"only bounded verified floor recovery preserves entry " + mode
		)
	_check(
		Witness.support_contact("BasinFloor", REST - Vector3.UP * R, Vector3.UP, Vector3.ZERO, R),
		"real grounded quiet floor contact can sustain observation"
	)
	_check(
		not Witness.support_contact("Pool", REST - Vector3.UP * R, Vector3.UP, Vector3.ZERO, R),
		"visual water cannot claim physical support"
	)
	_check(
		not Witness.support_contact(
			"BasinFloor", REST - Vector3.UP * R, Vector3.RIGHT, Vector3.ZERO, R
		),
		"side contact is not floor support"
	)
	_check(
		not Witness.support_contact(
			"BasinFloor", REST - Vector3.UP * R, Vector3.UP, Vector3.DOWN, R
		),
		"impact is not rest"
	)
	var malformed: Dictionary = _sample(REST, REST, 1)
	malformed.velocity = Vector3(NAN, 0, 0)
	_check(Witness.new().observe(malformed).is_empty(), "nonfinite fails closed")
	_check(not Witness.replay({}), "empty forged proof rejected")
	# Isolated rule controls, not a claim that the contact authority is wired.
	for foul: bool in [false, true]:
		for floor_value in range(5):
			var resolver: BallPlayResolver = BallPlayResolver.new()
			resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
			resolver.state.raise_result_floor(floor_value)
			var outcomes: Array[BallPlayOutcome] = []
			resolver.play_resolved.connect(
				func(value: BallPlayOutcome) -> void: outcomes.append(value)
			)
			if Witness.replay(proof):
				StadiumDugoutBoundary.dead_area(
					resolver,
					REST,
					&"waterfall_basin_minimum_single" if not foul else &"waterfall_basin_foul"
				)
			var expected: int = (
				BallPlayOutcome.Result.FOUL
				if foul
				else [
					BallPlayOutcome.Result.SINGLE,
					BallPlayOutcome.Result.SINGLE,
					BallPlayOutcome.Result.DOUBLE,
					BallPlayOutcome.Result.TRIPLE,
					BallPlayOutcome.Result.HOME_RUN
				][floor_value]
			)
			_check(
				outcomes.size() == 1 and outcomes[0].result == expected and resolver.state.dead,
				"existing foul-first monotone award helper: foul=%s floor=%d" % [foul, floor_value]
			)
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"WATERFALL_WITNESS_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_observations": true,
					"production_award_authority": false,
					"native_trap_trajectory": false
				}
			)
		)
	)
	get_tree().quit(0 if failures == 0 else 1)
