class_name StadiumNpcAc02PublicCamera
extends StadiumClubCameraDirector

const AC02_PASSIVE_3 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Narrow all-actor presentation opt-in, preserving shared physical camera motion.

var lab_ref: WeakRef


func update(
	camera: Camera3D, delta_seconds: float, ball_live: bool, ball_position: Vector3
) -> void:
	var ac02_token: int = AC02_PASSIVE_3.enter("stadium_npc_ac02_public_camera.update")
	_ac02_passive_03_update(camera, delta_seconds, ball_live, ball_position)
	AC02_PASSIVE_3.leave(ac02_token)


func _ac02_passive_03_update(
	camera: Camera3D, delta_seconds: float, ball_live: bool, ball_position: Vector3
) -> void:
	var visibility: StadiumNpcAc02PublicVisibility = (
		tracking_visibility as StadiumNpcAc02PublicVisibility
	)
	if visibility != null:
		visibility.coverage_live = _step_live(camera, ball_live)
	super.update(camera, delta_seconds, ball_live, ball_position)
	refresh_actor_cutaway(camera, ball_live)


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	var ac02_token: int = AC02_PASSIVE_3.enter("stadium_npc_ac02_public_camera.snap")
	_ac02_passive_03_snap(camera, ball_position)
	AC02_PASSIVE_3.leave(ac02_token)


func _ac02_passive_03_snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	if tracking_visibility is StadiumNpcAc02PublicVisibility:
		(tracking_visibility as StadiumNpcAc02PublicVisibility).coverage_live = false
	super.snap(camera, ball_position)
	refresh_actor_cutaway(camera, false)


func prepare_ball_in_play(defense: bool, ball: Vector3, launch: Vector3 = Vector3.ZERO) -> void:
	var ac02_token: int = AC02_PASSIVE_3.enter(
		"stadium_npc_ac02_public_camera.prepare_ball_in_play"
	)
	_ac02_passive_03_prepare_ball_in_play(defense, ball, launch)
	AC02_PASSIVE_3.leave(ac02_token)


func _ac02_passive_03_prepare_ball_in_play(
	defense: bool, ball: Vector3, launch: Vector3 = Vector3.ZERO
) -> void:
	super.prepare_ball_in_play(defense, ball, launch)
	var visibility: StadiumNpcAc02PublicVisibility = (
		tracking_visibility as StadiumNpcAc02PublicVisibility
	)
	if visibility == null:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var owned: bool = lab != null and _step_owner(lab._camera) == lab
	visibility.prepare_coverage(
		(
			owned
			and defense
			and lab._match_mode
			and lab._match_state != null
			and lab._player_is_pitching()
			and not lab._player_is_batting()
		),
		ball,
		launch
	)


func _step_owner(camera: Camera3D) -> PitchBatLab:
	var ac02_token: int = AC02_PASSIVE_3.enter("stadium_npc_ac02_public_camera._step_owner")
	var ac02_result: PitchBatLab = _ac02_passive_03_private_step_owner(camera)
	AC02_PASSIVE_3.leave(ac02_token)
	return ac02_result


func _ac02_passive_03_private_step_owner(camera: Camera3D) -> PitchBatLab:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if (
		lab == null
		or property == null
		or property.venue_id != "AC-02"
		or property.suspended
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or not lab.is_inside_tree()
		or lab.get_script() != PitchBatLab
		or lab._camera_director != self
		or lab._camera != camera
		or lab.get_node_or_null("LabCamera") != camera
		or lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != property
		or lab._field_definition != property.field
		or not property.callback_intact()
	):
		return null
	return lab


func _step_live(camera: Camera3D, live: bool) -> bool:
	var ac02_token: int = AC02_PASSIVE_3.enter("stadium_npc_ac02_public_camera._step_live")
	var ac02_result: bool = _ac02_passive_03_private_step_live(camera, live)
	AC02_PASSIVE_3.leave(ac02_token)
	return ac02_result


func _ac02_passive_03_private_step_live(camera: Camera3D, live: bool) -> bool:
	var lab: PitchBatLab = _step_owner(camera)
	return (
		lab != null
		and live
		and shot == Shot.BALL_IN_PLAY
		and lab._match_mode
		and lab._match_state != null
		and lab._match_state.phase == MatchState.Phase.BALL_IN_PLAY
		and lab._player_is_pitching()
		and not lab._player_is_batting()
		and not lab.get_tree().paused
		and not lab._debug_paused
		and is_instance_valid(lab._batted_ball)
		and lab._batted_ball.get_parent() == lab
		and lab._ball_play_resolver != null
		and lab._ball_play_resolver.state != null
		and not lab._ball_play_resolver.state.dead
	)


func refresh_actor_cutaway(camera: Camera3D, _ball_live: bool) -> void:
	var ac02_token: int = AC02_PASSIVE_3.enter(
		"stadium_npc_ac02_public_camera.refresh_actor_cutaway"
	)
	_ac02_passive_03_refresh_actor_cutaway(camera, _ball_live)
	AC02_PASSIVE_3.leave(ac02_token)


func _ac02_passive_03_refresh_actor_cutaway(camera: Camera3D, _ball_live: bool) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if (
		property == null
		or property.venue_id != "AC-02"
		or camera != lab._camera
		or lab._camera_director != self
	):
		return
	property.refresh_actor_presentation(lab)


func _snap_startup(attempt: RefCounted, camera: Camera3D) -> bool:
	if (
		not attempt.setup_owners(attempt.property)
		or attempt.lab._camera_director != self
		or attempt.lab._camera != camera
	):
		return false
	(tracking_visibility as StadiumNpcAc02PublicVisibility).coverage_live = false
	super.snap(camera)
	return attempt.property._ac02_startup_actor(attempt)
