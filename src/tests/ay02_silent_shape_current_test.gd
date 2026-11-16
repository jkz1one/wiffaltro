extends "res://src/tests/ay02_public_issued_test.gd"
## Real saved-context installations; no fabricated play/result, no production bypass.


func _run() -> void:
	var prepared: SeasonState = FIXTURE.season()
	var season: SeasonState = (
		SeasonSave._decode(
			JSON.parse_string(JSON.stringify(SeasonSave.snapshot(prepared), "", true, true))
		)
		if prepared != null
		else null
	)
	_check(season != null, "actual public v3 saved season cold restores")
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		for field: String in ["margin", "custom_solver_bias", "size"]:
			await _shape_case(season, field)
		var fresh: PitchBatLab = _lab(season)
		_check(
			fresh != null and R._property(fresh).callback_intact(),
			"new independent lifetime remains admitted after old mutations"
		)
		if fresh != null:
			fresh.free()
		_check(
			ClubCareer.same(saved, SeasonSave.snapshot(season)), "no save or progression mutation"
		)
	_check(_installs == 4, "exact four actual public installations")
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"AY02_SILENT_SHAPE_CURRENT checks=%d failures=%d installs=%d"
			% [_checks, _failures, _installs]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _shape_case(season: SeasonState, field: String) -> void:
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var shape: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape
	var original: Variant = shape.get(field)
	var signals: Array[int] = [0]
	var counter: Callable = func() -> void: signals[0] += 1
	shape.changed.connect(counter)
	shape.set(field, original + Vector3(0.01, 0, 0) if field == "size" else float(original) + 0.01)
	var admitted: bool = property.callback_intact()
	print(
		"AY02_SILENT_PROBE ",
		JSON.stringify(
			{
				"field": field,
				"signals": signals[0],
				"admitted_after_mutation": admitted,
				"phase": property.phase
			}
		)
	)
	_check(not admitted, "hot-first actual callback rejects changed shape scalar " + field)
	shape.set(field, original)
	shape.changed.disconnect(counter)
	_sticky(lab, property, score, "restore cannot revive " + field)
	await _dispose(lab, _failures)
