class_name StadiumNpcAe02PublicCamera
extends StadiumExpandedCameraDirector
## Authored AE02 entry, motions and FOV unchanged; owner is the issued public HomeProperty.

const PROFILE: String = "AE02-r3-owned-entry-side-target"
const ENTRY_Z: float = -6.5
const COVERAGE = preload("res://src/presentation/camera/ball_in_play_camera.gd")
var lab_ref: WeakRef


func bound_property() -> StadiumNpcPublicProperty:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if lab == null or property == null or property.venue_id != "AE-02" \
		or property.suspended or property.lab_ref == null or property.lab_ref.get_ref() != lab \
		or lab._camera_director != self or not is_instance_valid(lab._camera) \
		or lab.get_node_or_null("LabCamera") != lab._camera \
		or not is_instance_valid(lab._pitch_actor) \
		or lab.get_node_or_null("PitchFlightActor") != lab._pitch_actor \
		or lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != property \
		or lab._field_definition != property.field \
		or not property.receiver is StadiumNpcAe02PublicReceiver \
		or property.receiver.get_parent() != property or not property.callback_intact():
		return null
	return property


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
	var property: StadiumNpcPublicProperty = bound_property()
	if property == null:
		return false
	var lab: PitchBatLab = property.lab_ref.get_ref() as PitchBatLab
	if (
		shot != Shot.BATTING
		or _shot_before_inspection >= 0
		or lab.get_tree().paused
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor.running
	):
		return false
	# Acquired before contact. No teleport is introduced during live/held ball states.
	snap(lab._camera)
	return true


func _desired_transform(ball_position: Vector3, delta_seconds: float) -> Transform3D:
	if shot != Shot.BATTING or bound_property() == null:
		return super._desired_transform(ball_position, delta_seconds)
	var position: Vector3 = Vector3(_batter_side * 0.18, 2.10, ENTRY_Z)
	var focus: Vector3 = Vector3(0, 1.10, 7.1)
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


func refresh_actor_cutaway(camera: Camera3D, _ball_live: bool) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if property != null and property.venue_id == "AE-02" and camera == lab._camera \
		and lab._camera_director == self:
		property.refresh_actor_presentation(lab)
