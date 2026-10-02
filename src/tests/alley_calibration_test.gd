extends Node
## Measurement-only experiment. Candidate values never enter playable profiles or stock.

const STRENGTHS: Array[float] = [0.25, 0.50, 0.75]
const GRID_STEPS: int = 16
var _failures: int = 0
var _report: Dictionary = {
	"status": "unapproved calibration experiment",
	"candidate": {"target": 10.0, "entry": [12.0, 14.0], "quality": [0.65, 0.70]},
	"rows": [],
	"grid": {},
	"swept_encounters": 0
}


func _ready() -> void:
	var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	_check(source.attack_angle_degrees == 7.0, "recalibrate if authored Contact angle changes")
	_fine_sweep(source)
	_grid(source)
	_boundaries()
	_swept(source)
	_check(source.gear_line_drive_strength == 0.0, "authored profile stays neutral")
	_check(SeasonEarnedGear.ITEMS.size() == 10, "historical ten-item catalog remains frozen")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--calibration-report="):
			var file: FileAccess = FileAccess.open(
				argument.trim_prefix("--calibration-report="), FileAccess.WRITE
			)
			_check(file != null, "write measurement artifact")
			if file != null:
				file.store_string(JSON.stringify(_report, "\t") + "\n")
	print("ALLEY_CALIBRATION ", JSON.stringify(_report))
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro Alley calibration checks passed: resolver sweep and isolated candidate.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fine_sweep(source: SwingProfileDefinition) -> void:
	# Best possible quality for each launch: centered horizontally and perfect timing.
	# A 0.00001 vertical-error step resolves the tiny production overlap independently
	# of the coarser 3D grid. This is an envelope, not a player contact distribution.
	for strength: float in STRENGTHS:
		var row: Dictionary = {
			"strength": strength,
			"current_max_degrees": 0.0,
			"candidate_max_degrees": 0.0,
			"current_at": {},
			"candidate_at": {}
		}
		for index in range(100001):
			var ny: float = float(index) / 100000.0
			var result: ContactResult = _contact(source, Vector3(0, ny, 0))
			if not _fair(result):
				continue
			var angle: float = result.launch_angle_degrees
			var current: float = (
				angle - ContactResolver.line_drive_angle(angle, result.quality, strength)
			)
			var candidate: float = angle - _candidate_angle(angle, result.quality, strength)
			for kind: String in ["current", "candidate"]:
				var delta: float = current if kind == "current" else candidate
				if delta > row[kind + "_max_degrees"]:
					row[kind + "_max_degrees"] = delta
					row[kind + "_at"] = {"quality": result.quality, "launch": angle, "ny": ny}
		_report.rows.append(row)
		_check(
			row.current_max_degrees > 0.0 and row.current_max_degrees < 0.001,
			"production overlap exists but cannot yield meaningful flattening"
		)
		_check(
			row.candidate_max_degrees > strength * 6.0,
			"candidate has reachable clean elevated Contact benefit"
		)


func _grid(source: SwingProfileDefinition) -> void:
	var samples: int = 0
	var fair: int = 0
	var affected: int = 0
	var production: SwingProfileDefinition = source.duplicate() as SwingProfileDefinition
	production.gear_line_drive_strength = 0.25
	# Grid equally samples normalized errors, not probability or expected hit rate.
	for rating: int in [0, 5, 10]:
		for left: bool in [false, true]:
			for ix in range(GRID_STEPS + 1):
				for iy in range(GRID_STEPS + 1):
					for iz in range(GRID_STEPS + 1):
						var error: Vector3 = Vector3(ix, iy, iz) * (2.0 / GRID_STEPS) - Vector3.ONE
						var base: ContactResult = _contact(source, error, rating, left)
						var actual: ContactResult = _contact(production, error, rating, left)
						samples += 1
						_check(
							base.quality == actual.quality and base.outcome == actual.outcome,
							"equipped production preserves quality and classification"
						)
						if not _fair(base):
							_check(
								base.exit_velocity == actual.exit_velocity, "miss/foul untouched"
							)
							continue
						fair += 1
						var angle: float = _candidate_angle(
							base.launch_angle_degrees, base.quality, 0.75
						)
						if angle < base.launch_angle_degrees:
							affected += 1
							_check(
								base.quality > 0.65 and base.launch_angle_degrees > 12.0,
								"no weak contact or grounder rescue"
							)
						var vector: Vector3 = _candidate_velocity(base, angle)
						_check(
							is_equal_approx(vector.length(), base.exit_velocity.length()),
							"candidate rotation preserves energy magnitude"
						)
						_check(
							is_equal_approx(
								rad_to_deg(atan2(vector.x, vector.z)), base.spray_degrees
							),
							"candidate retains horizontal direction for both stances"
						)
	_report.grid = {
		"samples": samples,
		"fair": fair,
		"candidate_affected": affected,
		"note": "Uniform error grid; not gameplay frequency, hit rate or balance evidence."
	}
	_check(affected > 0 and affected < fair, "bounded reachable subset of fair contacts")


func _boundaries() -> void:
	for strength: float in STRENGTHS:
		for angle: float in [-22.0, 7.0, 10.0, 12.0, 40.0, 55.0]:
			_check(_candidate_angle(angle, 1.0, strength) == angle, "outside region unchanged")
		for angle: float in [12.0, 14.0, 38.0, 40.0]:
			_check(
				(
					absf(
						(
							_candidate_angle(angle - 0.00001, 0.8, strength)
							- _candidate_angle(angle + 0.00001, 0.8, strength)
						)
					)
					< 0.001
				),
				"candidate has continuous angular shoulders"
			)
		for quality: float in [0.65, 0.70]:
			_check(
				(
					absf(
						(
							_candidate_angle(16.0, quality - 0.00001, strength)
							- _candidate_angle(16.0, quality + 0.00001, strength)
						)
					)
					< 0.001
				),
				"candidate has continuous quality shoulders"
			)
		_check(_candidate_angle(16.0, 0.649, strength) == 16.0, "quality floor retained")
		_check(
			is_equal_approx(_candidate_angle(15.0, 0.75, strength), 15.0 - 5.0 * strength),
			"fully qualifying authored contact has distinct tier strengths"
		)


func _swept(source: SwingProfileDefinition) -> void:
	# The normal public contact entry, at 240 Hz, across legal timing/aim encounters.
	# Candidate is post-contact only and does not change contact selection or aim.
	for speed: float in [12.0, 24.0, 36.0]:
		for rating: int in [0, 5, 10]:
			for left: bool in [false, true]:
				for ny: float in [0.0, 0.25, 0.30, 0.347, 0.50, 0.80]:
					var intent: SwingIntent = SwingIntent.new()
					intent.profile_id = source.id
					intent.handedness_left = left
					intent.aim_point = Vector2(0, 1.05)
					var delta: float = 1.0 / 240.0
					var factor: float = ContactResolver._contact_factor(rating)
					var center: Vector3 = Vector3(
						0,
						1.05 + ny * source.contact_radius_y_m * factor,
						ContactResolver.CONTACT_PLANE_Z
					)
					var pitch: PitchState = PitchState.new()
					pitch.elapsed_time = source.sweet_spot_seconds + delta * 0.5
					pitch.position = center - Vector3(0, 0, speed * delta * 0.5)
					pitch.velocity = Vector3(0, 0, -speed)
					var result: ContactResult = ContactResolver.resolve_swept_segment(
						center + Vector3(0, 0, speed * delta * 0.5),
						pitch.elapsed_time - delta,
						pitch,
						intent,
						source,
						rating,
						rating
					)
					_check(
						result != null, "normal swept contact reaches controlled legal encounter"
					)
					if result == null:
						continue
					_report.swept_encounters += 1
					var angle: float = _candidate_angle(
						result.launch_angle_degrees, result.quality, 0.5
					)
					_check(
						(angle < result.launch_angle_degrees) == (ny in [0.25, 0.30, 0.347]),
						"real swept encounters preserve bounded candidate eligibility"
					)
					var launch: BattedBallLaunch = BattedBallLaunch.from_contact(result, pitch)
					_check(
						(
							launch.velocity == result.exit_velocity
							and launch.contact_quality == result.quality
						),
						"normal launch carries actual measured contact unchanged"
					)


func _contact(
	source: SwingProfileDefinition, error: Vector3, rating: int = 5, left: bool = false
) -> ContactResult:
	var pitch: PitchState = PitchState.new()
	pitch.velocity = Vector3(0, 0, -24)
	var intent: SwingIntent = SwingIntent.new()
	intent.handedness_left = left
	var center: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z)
	var factor: float = ContactResolver._contact_factor(rating)
	var displacement: Vector3 = (
		error
		* Vector3(source.contact_radius_x_m, source.contact_radius_y_m, source.contact_depth_m)
		* factor
	)
	return ContactResolver._resolve_at_contact(
		pitch, center + displacement, center, intent, source, rating, rating
	)


func _candidate_angle(angle: float, quality: float, strength: float) -> float:
	# UNAPPROVED test-only alternative. No production references this function.
	if quality <= 0.65 or angle <= 12.0 or angle >= 40.0:
		return angle
	var weight: float = smoothstep(0.65, 0.70, quality)
	weight *= smoothstep(12.0, 14.0, angle) * (1.0 - smoothstep(38.0, 40.0, angle))
	var expected: float = lerpf(angle, 10.0, strength * weight)
	_check(
		is_equal_approx(SeasonAlleyGear.angle(angle, quality, strength), expected),
		"selected production calibration matches measured candidate"
	)
	return expected


func _candidate_velocity(result: ContactResult, angle: float) -> Vector3:
	var launch: float = deg_to_rad(angle)
	var spray: float = deg_to_rad(result.spray_degrees)
	var speed: float = result.exit_velocity.length()
	return Vector3(sin(spray) * cos(launch), sin(launch), cos(spray) * cos(launch)) * speed


func _fair(result: ContactResult) -> bool:
	return result.outcome in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT]


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		if _failures <= 20:
			push_error(message)
