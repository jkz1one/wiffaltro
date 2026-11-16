extends "res://src/tests/hr_landing_scope_test.gd"
## Read-only per-frame presentation telemetry on the genuine three-flight fixture.

var observations: int = 0
var seen_cues: int = 0
var intermediate_fades: int = 0
var previous_opacity: float = 0.0
var previous_case: int = -1
var max_opacity_step: float = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(lab) or lab.is_queued_for_deletion():
		return
	var cue: HomeRunOcclusionMarker = lab._home_run._occlusion_marker
	if not is_instance_valid(cue) or cue.is_queued_for_deletion():
		return
	if previous_case != case_index:
		previous_opacity = 0.0
		previous_case = case_index
	observations += 1
	seen_cues += int(cue.visible and cue.opacity > 0.0)
	intermediate_fades += int(cue.opacity > 0.0 and cue.opacity < 1.0)
	max_opacity_step = maxf(max_opacity_step, absf(cue.opacity - previous_opacity))
	previous_opacity = cue.opacity
	print(
		"HR_CUE_FRAME ",
		JSON.stringify(
			{
				"case": case_index,
				"delta": delta,
				"alpha": cue.opacity,
				"blocked": cue.blocked,
				"visible": cue.visible,
				"flight_complete": lab._home_run.flight_complete,
				"ball":
				[
					lab._batted_ball.position.x,
					lab._batted_ball.position.y,
					lab._batted_ball.position.z
				]
			}
		)
	)


func _exit_tree() -> void:
	print(
		"HR_CUE_MOTION ",
		JSON.stringify(
			{
				"samples": observations,
				"visible_samples": seen_cues,
				"intermediate_fades": intermediate_fades,
				"max_alpha_step": max_opacity_step
			}
		)
	)
