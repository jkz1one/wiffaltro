class_name StadiumYardTwoActorPresentation
extends Node
## Presentation callbacks keep pause/inspection reversible without a gameplay clock tick.

var lab_ref: WeakRef
var actor_cutaway: StadiumNpcRetainedActorCutaway


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null or not lab._camera_director is StadiumYardTwoCameraDirector:
		actor_cutaway.restore_all()
		return
	var camera: StadiumYardTwoCameraDirector = lab._camera_director as StadiumYardTwoCameraDirector
	if camera.actor_cutaway != actor_cutaway:
		actor_cutaway.restore_all()
		return
	var live: bool = (
		is_instance_valid(lab._batted_ball)
		and lab._ball_play_resolver != null
		and lab._ball_play_resolver.state != null
		and not lab._ball_play_resolver.state.dead
	)
	camera.refresh_actor_cutaway(lab._camera, live)


func _exit_tree() -> void:
	if actor_cutaway != null:
		actor_cutaway.restore_all()
