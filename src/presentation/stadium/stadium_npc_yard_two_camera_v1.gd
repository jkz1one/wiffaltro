class_name StadiumNpcYardTwoCameraV1
extends MatchCameraDirector
## AY-02 private adapter: unchanged camera update plus qualified real-actor presentation.

const PROFILE: String = "AY02-ENTRY-AND-SIDE-TARGET-reconstruction-v3"
const ENTRY_Z: float = -6.5
const BATTING_FOCUS: Vector3 = Vector3(0, 1.10, 7.1)

var property_ref: WeakRef
var lab_ref: WeakRef
var actor_cutaway: StadiumNpcRetainedActorCutaway


func bind_candidate(candidate: StadiumNpcYardTwoPropertyV1) -> bool:
	if property_ref != null or candidate == null or candidate.camera != self:
		return false
	property_ref = weakref(candidate)
	return true


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
	var property: StadiumNpcYardTwoPropertyV1
	if lab != null and lab.has_meta("stadium_property"):
		property = lab.get_meta("stadium_property") as StadiumNpcYardTwoPropertyV1
	if (
		lab == null
		or property == null
		or property_ref == null or property_ref.get_ref() != property
		or property.camera != self or not property.callback_intact()
		or property.actor_cutaway != actor_cutaway
		or lab._camera_director != self
		or camera != lab._camera
	):
		_restore_owned()
		return
	actor_cutaway.apply_actors(
		StadiumGrandIIICameraDirector.presentation_actors(lab),
		camera,
		lab._batted_ball,
		ball_live and shot == Shot.BALL_IN_PLAY
	)


func set_shot(next_shot: Shot) -> void:
	super.set_shot(next_shot)
	acquire_precontact_entry()


func set_batter_handedness(is_left_handed: bool) -> void:
	super.set_batter_handedness(is_left_handed)
	acquire_precontact_entry()


func restore_after_pause() -> void:
	super.restore_after_pause()
	acquire_precontact_entry()


func acquire_precontact_entry() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if (
		not _entry_owned()
		or shot != Shot.BATTING
		or _shot_before_inspection >= 0
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor.running
	):
		return false
	# Authored setup/role entry only. Contact, live flight and terminal-body holds never cut.
	snap(lab._camera)
	return true


func _desired_transform(ball_position: Vector3, delta_seconds: float) -> Transform3D:
	if shot != Shot.BATTING or not _entry_owned():
		return super._desired_transform(ball_position, delta_seconds)
	var position: Vector3 = Vector3(_batter_side * 0.18, 2.10, ENTRY_Z)
	var focus: Vector3 = BATTING_FOCUS
	# Retain the exact inherited presentation offsets around the authored fixed entry.
	var amount: float = smoothstep(0.0, 1.0, _presentation_progress)
	match _presentation_motion:
		PresentationMotion.ZOOM_IN:
			position = position.lerp(focus, 0.075 * amount)
		PresentationMotion.ZOOM_OUT:
			position += (position - focus).normalized() * 1.35 * amount
		PresentationMotion.PAN_LEFT:
			position.x -= 1.10 * amount
			focus.x -= 0.64 * amount
		PresentationMotion.PAN_RIGHT:
			position.x += 1.10 * amount
			focus.x += 0.64 * amount
		PresentationMotion.TILT_UP:
			focus.y += 0.78 * amount
		PresentationMotion.TILT_DOWN:
			focus.y -= 0.62 * amount
	return Transform3D(Basis.looking_at((focus - position).normalized(), Vector3.UP), position)


func _entry_owned() -> bool:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcYardTwoPropertyV1
	if lab != null and lab.has_meta("stadium_property"):
		property = lab.get_meta("stadium_property") as StadiumNpcYardTwoPropertyV1
	if (
		lab == null
		or property == null
		or property_ref == null or property_ref.get_ref() != property
		or property.camera != self or not property.callback_intact()
		or not property.is_inside_tree()
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or lab._camera_director != self
		or not is_instance_valid(lab._camera)
		or lab.get_node_or_null("LabCamera") != lab._camera
		or not is_instance_valid(lab._pitch_actor)
		or lab.get_node_or_null("PitchFlightActor") != lab._pitch_actor
		or lab.get_node_or_null("StarterFieldGeometry/AY02InstalledProperty") != property
		or lab._field_definition != property.field
	):
		return false
	var receiver: StadiumNpcYardTwoReceiverV1 = property.get_node_or_null("PitchReceiverPresentation")
	if (
		receiver == null
		or not receiver.owns_actor(lab._pitch_actor)
		or receiver.property != property
		or receiver._actor != lab._pitch_actor
		or lab._pitch_actor.receiver_router != receiver.route
	):
		return false
	var record: Variant = StadiumNpcYardTwoContractV1.canonical()
	return (
		record is Dictionary
		and record.get("camera_profile") is Dictionary
		and record.camera_profile.get("id", "") == PROFILE
	)


func _restore_owned() -> void:
	var property: StadiumNpcYardTwoPropertyV1 = (
		property_ref.get_ref() as StadiumNpcYardTwoPropertyV1 if property_ref != null else null)
	if property == null or property._owned_camera() != self:
		return
	var owned: StadiumNpcRetainedActorCutaway = property._owned_actor_cutaway()
	if is_instance_valid(owned):
		owned.restore_all()
