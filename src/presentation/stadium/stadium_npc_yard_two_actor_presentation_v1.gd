class_name StadiumNpcYardTwoActorPresentationV1
extends Node
## Presentation callbacks keep pause/inspection reversible without a gameplay clock tick.

var property_ref: WeakRef
var lab_ref: WeakRef
var actor_cutaway: StadiumNpcRetainedActorCutaway


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null)
	if lab == null or property == null or property.actor_presentation != self \
		or get_parent() != property or not property.callback_intact() \
		or property.actor_cutaway != actor_cutaway \
		or not lab._camera_director is StadiumNpcYardTwoCameraV1:
		_restore_owned()
		return
	var camera: StadiumNpcYardTwoCameraV1 = lab._camera_director as StadiumNpcYardTwoCameraV1
	if camera.actor_cutaway != actor_cutaway:
		_restore_owned()
		return
	# Choose the guarded route before reading unknown state behavior. A callback cannot
	# replace its state/script during that read and thereby opt into the synchronous path.
	if lab.get_script() != PitchBatLab or (lab._ball_play_resolver.state != null \
		and lab._ball_play_resolver.state.get_script() != BallPlayState):
		var guarded_live: bool = (
			is_instance_valid(lab._batted_ball)
			and lab._ball_play_resolver != null
			and lab._ball_play_resolver.state != null
			and not lab._ball_play_resolver.state.dead
		)
		camera.refresh_actor_cutaway(lab._camera, guarded_live)
		return
	var live: bool = (
		is_instance_valid(lab._batted_ball)
		and lab._ball_play_resolver != null
		and lab._ball_play_resolver.state != null
		and not lab._ball_play_resolver.state.dead
	)
	# This entry already admitted this exact property synchronously. Keep all camera joins
	# locally; never expose a helper that accepts a caller's cached success or capability.
	if camera.actor_cutaway == null:
		return
	var cutaway_lab: PitchBatLab = (
		camera.lab_ref.get_ref() as PitchBatLab if camera.lab_ref != null else null)
	var cutaway_property: StadiumNpcYardTwoPropertyV1
	if cutaway_lab != null and cutaway_lab.has_meta("stadium_property"):
		cutaway_property = cutaway_lab.get_meta("stadium_property") as StadiumNpcYardTwoPropertyV1
	if cutaway_lab == null or cutaway_property != property \
		or camera.property_ref == null or camera.property_ref.get_ref() != property \
		or cutaway_property.camera != camera \
		or cutaway_property.actor_cutaway != camera.actor_cutaway \
		or cutaway_lab._camera_director != camera or lab._camera != cutaway_lab._camera:
		camera._restore_owned()
		return
	camera.actor_cutaway.apply_actors(
		StadiumGrandIIICameraDirector.presentation_actors(cutaway_lab),
		lab._camera, cutaway_lab._batted_ball,
		live and camera.shot == MatchCameraDirector.Shot.BALL_IN_PLAY
	)


func _exit_tree() -> void:
	_restore_owned()


func _restore_owned() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null)
	if property == null or property._owned_actor_presentation() != self:
		return
	var owned: StadiumNpcRetainedActorCutaway = property._owned_actor_cutaway()
	if is_instance_valid(owned):
		owned.restore_all()
