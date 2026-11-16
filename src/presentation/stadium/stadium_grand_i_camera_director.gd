class_name StadiumGrandICameraDirector
extends StadiumClubCameraDirector
## Isolated presentation wiring; ordinary production and frozen Club cameras remain unchanged.

var lab_ref: WeakRef
var actor_cutaway: StadiumActorCutawayStudy


func update(
	camera: Camera3D, delta_seconds: float, ball_live: bool, ball_position: Vector3
) -> void:
	super.update(camera, delta_seconds, ball_live, ball_position)
	refresh_actor_cutaway(camera, ball_live)


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	super.snap(camera, ball_position)
	refresh_actor_cutaway(camera, false)


func refresh_actor_cutaway(camera: Camera3D, ball_live: bool) -> void:
	if actor_cutaway == null:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null:
		actor_cutaway.restore_all()
		return
	actor_cutaway.apply(
		lab._batter_avatar,
		lab._bat_actor,
		camera,
		lab._batted_ball,
		ball_live and shot == Shot.BALL_IN_PLAY
	)
