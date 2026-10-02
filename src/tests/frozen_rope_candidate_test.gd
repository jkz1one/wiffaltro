extends Node
## Retained geometry measurement now exercises the user-selected Working production rule.

var _failures: int = 0
var _checks: int = 0
var _report: Dictionary = {
	"status": "selected Working Frozen Rope geometry measurement", "examples": []
}


func _ready() -> void:
	_geometry()
	_gates()
	_sweep()
	_contacts()
	_check(SeasonAlleyGear.ITEMS.size() == 2, "production Alley family still has only two tiers")
	_check(
		SeasonEarnedGear.catalog().size() == 12, "selected final Gear extends the frozen catalog"
	)
	_report.checks = _checks
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--candidate-report="):
			var file: FileAccess = FileAccess.open(
				argument.trim_prefix("--candidate-report="), FileAccess.WRITE
			)
			_check(file != null, "write exact measurement report")
			if file != null:
				file.store_string(JSON.stringify(_report, "\t") + "\n")
	print("FROZEN_ROPE_CANDIDATE ", JSON.stringify(_report))
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Frozen Rope candidate checks passed: isolated geometry and contact experiment."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _geometry() -> void:
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	_check(field != null, "actual starter field exists")
	if field == null:
		return
	var data: Dictionary = FrozenRopeCandidate.snapshot(field, Vector3.ZERO, [Vector3(1, 0, 14)])
	_check(data.near == 8.5 and data.far == 19.5, "authored band spans actual legal anchors")
	var contact: ContactResult = _contact(0.0)
	var one: Dictionary = _example("single defender right of center", data, contact)
	_check(
		one.selected == -4.0 and one.after > one.before, "one defender produces genuine improvement"
	)
	var expected: float = (cos(deg_to_rad(4.0)) + 14.0 * sin(deg_to_rad(4.0))) / 11.0
	_check(absf(one.after - expected) < 0.000001, "independent perpendicular-distance oracle")
	var symmetric: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3.ZERO, [Vector3(0, 0, 14)]
	)
	var tie: Dictionary = _example("exact center symmetry", symmetric, contact)
	_check(tie.reason == "symmetric_tie" and tie.selected == 0.0, "exact symmetry retains original")
	var closed: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3.ZERO, [Vector3(-1, 0, 14), Vector3(1, 0, 14)]
	)
	var no_gap: Dictionary = _example("already centered between two defenders", closed, contact)
	_check(no_gap.reason == "no_improvement", "closed nearby lanes leave launch alone")
	var actual_defense: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3(0, 1, 0.28), [PitchBatLab.MOUND_ORIGIN, field.fielder_anchor(8)]
	)
	_example("pitcher and deep-left fielder, 3 degree original", actual_defense, _contact(3.0))
	var obstacles: Array[Rect2] = [Rect2(-0.85, 9.5, 0.5, 1.0).grow(0.0365)]
	var blocked: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3.ZERO, [Vector3(1, 0, 14)], obstacles
	)
	var restricted: Dictionary = _example(
		"preferred direction blocked by static footprint", blocked, contact
	)
	_check(
		restricted.selected < 0.0 and restricted.selected > -4.0, "obstacle excludes best outer ray"
	)
	var unsafe: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3.ZERO, [Vector3(1, 0, 14)], [Rect2(-0.2, 5, 0.4, 1)]
	)
	_check(
		_choose(unsafe, contact).reason == "unsafe_original",
		"obstruction before band disables comparison"
	)
	# No live references: changing all original sources cannot change a captured decision.
	var custom: FieldDefinition = field.duplicate()
	var defenders: Array[Vector3] = [Vector3(1, 0, 14)]
	var frozen: Dictionary = FrozenRopeCandidate.snapshot(
		custom, Vector3.ZERO, defenders, obstacles
	)
	var committed: Dictionary = _choose(frozen, contact)
	custom.deep_anchor_z_m = 4
	defenders[0] = Vector3(-100, 0, 1)
	obstacles.clear()
	_check(
		_choose(frozen, contact) == committed, "snapshot copies field, defender and obstacle values"
	)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(committed))
	_check(
		absf(saved.selected - committed.selected) < 0.000001,
		"committed choice survives JSON without resampling"
	)
	_check(saved.velocity.size() == 3, "explicit vector evidence is serializable")
	for scale: float in [0.4, 1.8]:
		var scaled: FieldDefinition = field.duplicate()
		scaled.shallow_anchor_z_m *= scale
		scaled.middle_anchor_z_m *= scale
		scaled.middle_center_anchor_z_m *= scale
		scaled.deep_anchor_z_m *= scale
		scaled.back_wall_z_m *= scale
		var scaled_data: Dictionary = FrozenRopeCandidate.snapshot(
			scaled, Vector3.ZERO, [Vector3(1, 0, 14) * scale]
		)
		var measured: Dictionary = _example(
			"uniform field scale %.1f" % scale, scaled_data, contact
		)
		_check(
			measured.selected == one.selected and absf(measured.after - one.after) < 0.000001,
			"scale-relative clearance retains decision"
		)
	var asymmetric: FieldDefinition = field.duplicate()
	asymmetric.middle_center_available = true
	asymmetric.middle_center_anchor_z_m = 21.0
	var asym: Dictionary = FrozenRopeCandidate.snapshot(
		asymmetric, Vector3.ZERO, [Vector3(1, 0, 14)]
	)
	_check(asym.far == 21.0, "band includes special center anchor rather than only row labels")
	_example("asymmetric extended center depth", asym, contact)


func _gates() -> void:
	var field: FieldDefinition = FieldDefinition.new()
	var data: Dictionary = FrozenRopeCandidate.snapshot(field, Vector3.ZERO, [Vector3(1, 0, 14)])
	for quality: float in [0.0, 0.65, 0.8]:
		_check(
			_choose(data, _contact(0, quality)).selected == 0.0,
			"weak/boundary quality receives no help"
		)
	for quality: float in [0.89999999, 0.9, 0.90000001]:
		var nearly_duplicate: Dictionary = _choose(data, _contact(0, quality))
		_check(
			nearly_duplicate.reason == "improved" and nearly_duplicate.selected < 0.0,
			"same-side near-duplicate quality endpoint is not an opposite-side symmetry tie"
		)
	for tier: int in [1, 2]:
		_check(
			FrozenRopeCandidate.choose(data, _contact(0), &"swing.contact", tier).selected == 0.0,
			"lower tiers get no horizontal assistance"
		)
	_check(
		FrozenRopeCandidate.choose(data, _contact(0), &"swing.power").selected == 0.0,
		"Power receives no gap effect"
	)
	for outcome: int in [ContactResult.Outcome.MISS, ContactResult.Outcome.FOUL]:
		var bad: ContactResult = _contact(0)
		bad.outcome = outcome
		_check(
			_choose(data, bad).selected == 0.0,
			"classification blocks miss/foul even with fabricated quality"
		)
	_check(
		_choose(data, _contact(48)).selected == 48.0, "unassisted foul direction never turns fair"
	)
	var missing: Dictionary = FrozenRopeCandidate.snapshot(field, Vector3.ZERO, [])
	_check(not missing.valid, "missing defenders disable comparison")
	var unknown: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3.ZERO, [Vector3.ZERO], [], false
	)
	_check(not unknown.valid, "unknown obstacle geometry disables comparison")
	field.deep_anchor_z_m = field.back_wall_z_m
	_check(
		not FrozenRopeCandidate.snapshot(field, Vector3.ZERO, [Vector3.ZERO]).valid,
		"invalid authored depth fails closed"
	)
	field.deep_anchor_z_m = NAN
	_check(
		not FrozenRopeCandidate.snapshot(field, Vector3.ZERO, [Vector3.ZERO]).valid,
		"nonfinite authored geometry fails closed"
	)
	var fair: FieldDefinition = FieldDefinition.new()
	var offset: Dictionary = FrozenRopeCandidate.snapshot(
		fair, Vector3(8, 1, 0), [Vector3(1, 0, 14)]
	)
	_check(
		_choose(offset, _contact(40)).reason == "unsafe_original",
		"contact origin obeys physical fair geometry"
	)


func _sweep() -> void:
	var samples: int = 0
	var improved: int = 0
	for half: float in [18.0, 42.0, 55.0]:
		var field: FieldDefinition = FieldDefinition.new()
		field.fair_half_angle_degrees = half
		var right: Dictionary = FrozenRopeCandidate.snapshot(
			field, Vector3(0.12, 1, 0.28), [Vector3(1, 0, 14), Vector3(5.5, 0, 19.5)]
		)
		var left: Dictionary = FrozenRopeCandidate.snapshot(
			field, Vector3(-0.12, 1, 0.28), [Vector3(-1, 0, 14), Vector3(-5.5, 0, 19.5)]
		)
		for index in range(201):
			var spray: float = lerpf(-half, half, index / 200.0)
			for quality: float in [0.80001, 0.81, 0.85, 0.9, 0.95, 1.0]:
				var contact: ContactResult = _contact(spray, quality)
				var result: Dictionary = _choose(right, contact)
				var mirror: Dictionary = FrozenRopeCandidate.choose(
					left, _contact(-spray, quality), &"swing.contact", 3, true
				)
				samples += 1
				_check(
					absf(result.selected + mirror.selected) < 0.00001,
					"handed mirrored geometry mirrors direction"
				)
				_check(
					absf(result.selected - spray) <= result.cap + 0.00001,
					"quality-dependent cap holds"
				)
				_check(absf(result.selected) <= half + 0.00001, "fair angular boundary holds")
				_check(
					(
						FrozenRopeCandidate.sector_name(result.selected, half, false)
						== FrozenRopeCandidate.sector_name(spray, half, false)
					),
					"original sector retained"
				)
				_check(result.candidates.size() <= 17, "bounded deterministic search")
				_check(
					_choose(right, contact) == result,
					"identical snapshot produces identical decision"
				)
				var velocity: Vector3 = Vector3(
					result.velocity[0], result.velocity[1], result.velocity[2]
				)
				_check(
					absf(velocity.length() - contact.exit_velocity.length()) < 0.00001,
					"rotation preserves speed"
				)
				_check(velocity.y == contact.exit_velocity.y, "vertical component preserved")
				if result.reason == "improved":
					improved += 1
					_check(
						result.after > result.before + FrozenRopeCandidate.SCORE_EPS,
						"selected candidate strictly improves clearance"
					)
	_report.sweep = {
		"samples": samples,
		"improved": improved,
		"note": "Artificial geometry/quality grid, not hit frequency or success probability."
	}


func _contacts() -> void:
	var field: FieldDefinition = FieldDefinition.new()
	var data: Dictionary = FrozenRopeCandidate.snapshot(
		field, Vector3(0, 1, 0.28), [Vector3(1, 0, 14)]
	)
	var count: int = 0
	var changed: int = 0
	for left: bool in [false, true]:
		for rating: int in [0, 5, 10]:
			for ny: float in [-0.2, -0.1, 0.0, 0.1, 0.2, 0.3]:
				var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
				var intent: SwingIntent = SwingIntent.new()
				intent.handedness_left = left
				var pitch: PitchState = PitchState.new()
				pitch.velocity = Vector3(0, 0, -24)
				var center: Vector3 = Vector3(0, 1, ContactResolver.CONTACT_PLANE_Z)
				var point: Vector3 = (
					center
					+ Vector3(
						0,
						ny * source.contact_radius_y_m * ContactResolver._contact_factor(rating),
						0
					)
				)
				var contact: ContactResult = ContactResolver._resolve_at_contact(
					pitch, point, center, intent, source, rating, rating
				)
				var before: Vector3 = contact.exit_velocity
				var result: Dictionary = FrozenRopeCandidate.choose(
					data, contact, source.id, 3, left
				)
				count += 1
				if result.reason == "improved":
					changed += 1
				if absf(ny) < 0.15:
					_check(
						result.reason == "improved",
						"every clean one-sided ordinary encounter improves"
					)
				_check(contact.exit_velocity == before, "prototype never mutates ordinary contact")
				if ny == 0:
					_check(
						(
							is_equal_approx(result.cap, 4.0)
							and is_equal_approx(absf(result.selected), 4.0)
						),
						"ordinary perfect seven-degree Contact reaches full horizontal envelope"
					)
	_report.ordinary_contacts = {
		"samples": count,
		"changed": changed,
		"note": "Production resolver, isolated post-contact candidate; no physical games."
	}


func _contact(spray: float, quality: float = 1.0) -> ContactResult:
	var result: ContactResult = ContactResult.new()
	result.outcome = ContactResult.Outcome.CONTACT
	result.quality = quality
	result.spray_degrees = spray
	result.launch_angle_degrees = 7.0
	result.exit_velocity = (
		Vector3(
			sin(deg_to_rad(spray)) * cos(deg_to_rad(7.0)),
			sin(deg_to_rad(7.0)),
			cos(deg_to_rad(spray)) * cos(deg_to_rad(7.0))
		)
		* 25.0
	)
	return result


func _choose(data: Dictionary, contact: ContactResult) -> Dictionary:
	return FrozenRopeCandidate.choose(data, contact, &"swing.contact")


func _example(label: String, data: Dictionary, contact: ContactResult) -> Dictionary:
	var result: Dictionary = _choose(data, contact)
	var row: Dictionary = result.duplicate(true)
	row.erase("candidates")
	row.label = label
	row.band = [data.near, data.far]
	_report.examples.append(row)
	return result


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		if _failures <= 20:
			push_error(message)
