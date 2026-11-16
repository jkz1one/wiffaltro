extends Node3D
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	check(
		not lab.has_meta("stadium_property") and lab._match_state.stadium.is_empty(),
		"actual ordinary Lab has no installed stadium"
	)
	for index in range(12):
		check(
			StadiumPropertyRuntime.clear_control(
				lab, lab._primary_fielder, Vector3(index - 6, 0.3, 8)
			),
			"ordinary no-property control stays clear without metadata read " + str(index)
		)
	for claim: Variant in ["foreign", [], {}, Node3D.new()]:
		lab.set_meta("stadium_property", claim)
		check(
			not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, Vector3(0, 0.3, 8)),
			"foreign property claim refuses safely"
		)
		lab.remove_meta("stadium_property")
		if claim is Node:
			claim.free()
	check(
		StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, Vector3(0, 0.3, 8)),
		"ordinary control restored without mutating field or defender"
	)
	lab.queue_free()
	await get_tree().process_frame
	print(
		(
			"CLEAR_CONTROL_NO_PROPERTY_RESULT "
			+ JSON.stringify(
				{"checks": checks, "failures": failures, "ordinary_lab": true, "games_completed": 0}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)
