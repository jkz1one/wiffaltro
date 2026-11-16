extends Node3D
## Diagnostic: genuine native scoring and untouched physics in finite authoring ground.

var lab: PitchBatLab
var contacts: Array = []
var scores: Array = []
var case_index: int = 0
var failures: int = 0
var ground_capture: bool = false


func _ready() -> void:
	SeasonSave.path = "user://landing-scope-season.json"
	PitchBatLabSettings.path = "user://landing-scope-settings.cfg"
	for velocity: Vector3 in [Vector3(0, 18, 30), Vector3(0, 12, 24), Vector3(0, 22, 13)]:
		await _case(velocity)
		case_index += 1
	await TestAudioDrain.finish(get_tree())
	print("HR_LANDING_SCOPE_RESULT cases=", case_index, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _case(velocity: Vector3) -> void:
	contacts = []
	ground_capture = false
	scores = []
	lab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_meta("stadium_center_board_lab_only", true)
	assert(StadiumCenterBoardLab.install(lab, "straight"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._ball_play_resolver.play_resolved.connect(_score)
	lab._active_play_record = PlayRecord.new()
	assert(lab._match_state.begin_pitch())
	lab._at_bat_cadence.mark_pitch_live()
	var launch := BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = velocity
	launch.orientation = Quaternion.IDENTITY
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	ball.surface_contact.connect(_contact)
	var below: Array = []
	var end: Dictionary = {}
	for frame: int in range(720):
		await get_tree().physics_frame
		if not is_instance_valid(ball) or ball.is_queued_for_deletion():
			break
		if below.is_empty() and ball.position.y < 0:
			below = [ball.position.x, ball.position.y, ball.position.z]
		if end.is_empty() and lab._home_run.flight_complete:
			_capture.call_deferred("flight_end")
			end = {
				"reason": lab._home_run.flight_end_reason,
				"position": [ball.position.x, ball.position.y, ball.position.z],
				"ground_seen": lab._home_run._ground_seen,
				"seconds": lab._home_run.flight_elapsed
			}
	var valid: bool = scores.size() == 1 and scores[0].result == BallPlayOutcome.Result.HOME_RUN
	valid = valid and not end.is_empty()
	valid = valid and scores[0].reason == &"cleared_hr_boundary"
	valid = valid and (contacts.is_empty() if case_index == 0 else ground_capture)
	if case_index == 2:
		valid = (
			valid and end.get("reason") == "landed" and end.get("ground_seen") and below.is_empty()
		)
	else:
		valid = valid and end.get("reason") == "timeout" and not below.is_empty()
		valid = valid and end.get("ground_seen") == (case_index == 1)
	if not valid:
		failures += 1
	print(
		"HR_LANDING_SCOPE ",
		JSON.stringify(
			{
				"velocity": [velocity.x, velocity.y, velocity.z],
				"scores": scores,
				"contacts": contacts,
				"first_below": below,
				"flight_end": end
			}
		)
	)
	lab.queue_free()
	await get_tree().process_frame


func _contact(surface: StringName, point: Vector3) -> void:
	if surface == &"ground" and not ground_capture:
		ground_capture = true
		_capture.call_deferred("first_ground")
	contacts.append({"surface": surface, "position": [point.x, point.y, point.z]})


func _score(outcome: BallPlayOutcome) -> void:
	_capture.call_deferred("score")
	scores.append(
		{
			"result": outcome.result,
			"reason": outcome.reason,
			"position":
			[
				outcome.resolution_position.x,
				outcome.resolution_position.y,
				outcome.resolution_position.z
			]
		}
	)


func _capture(event: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var index: int = case_index
	await RenderingServer.frame_post_draw
	var path: String = "user://landing-%d-%s.png" % [index, event]
	var error: Error = get_viewport().get_texture().get_image().save_png(path)
	print(
		"HR_LANDING_IMAGE ",
		JSON.stringify(
			{
				"case": index,
				"event": event,
				"error": error,
				"path": ProjectSettings.globalize_path(path)
			}
		)
	)
