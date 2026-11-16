class_name StadiumMogulOneCamera
extends StadiumGrandICameraDirector
## AM-01 authored pre-contact entry and retained all-actor helper; live motion stays inherited.
## Only the installed lab's current, correctly parented actors may receive presentation fades.

const PROFILE: String = "AM01-BATTING-BEHIND-RECEIVER-v2"
const ENTRY_Z: float = -6.5
const LEGACY_ENTRY_Z: float = -3.38
const BATTING_FOCUS: Vector3 = Vector3(0, 1.10, 7.1)


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
	var property: StadiumMogulOneProperty
	if lab != null and lab.has_meta("stadium_property"):
		property = lab.get_meta("stadium_property") as StadiumMogulOneProperty
	if (
		lab == null
		or property == null
		or property.ended
		or not property.is_inside_tree()
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or lab._camera_director != self
		or not is_instance_valid(lab._camera)
		or lab.get_node_or_null("LabCamera") != lab._camera
		or not is_instance_valid(lab._pitch_actor)
		or lab.get_node_or_null("PitchFlightActor") != lab._pitch_actor
		or lab.get_node_or_null("StarterFieldGeometry/HomeProperty") != property
		or lab._field_definition != property.field
		or not is_instance_valid(property.receiver)
		or not property.receiver is StadiumMogulOneReceiver
		or not (property.receiver as StadiumMogulOneReceiver).intact()
	):
		return false
	var receiver: StadiumMogulOneReceiver = property.receiver as StadiumMogulOneReceiver
	if (
		receiver.get_parent() != property
		or receiver.property_ref == null
		or receiver.property_ref.get_ref() != property
		or receiver.lab_ref == null
		or receiver.lab_ref.get_ref() != lab
		or receiver.actor_ref == null
		or receiver.actor_ref.get_ref() != lab._pitch_actor
	):
		return false
	var record: Variant = property.get_meta("candidate_venue", {})
	if not record is Dictionary:
		return false
	var profile: Variant = record.get("camera_profile", {})
	return profile is Dictionary and profile.get("id", "") == PROFILE


func refresh_actor_cutaway(camera: Camera3D, ball_live: bool) -> void:
	if actor_cutaway == null:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumMogulOneProperty
	if lab != null and lab.has_meta("stadium_property"):
		property = lab.get_meta("stadium_property") as StadiumMogulOneProperty
	if (
		lab == null
		or property == null
		or property.ended
		or not property.is_inside_tree()
		or property.lab_ref == null
		or property.lab_ref.get_ref() != lab
		or property.actor_cutaway != actor_cutaway
		or lab._camera_director != self
		or camera != lab._camera
		or not actor_cutaway is StadiumNpcRetainedActorCutaway
	):
		actor_cutaway.restore_all()
		return
	(actor_cutaway as StadiumNpcRetainedActorCutaway).apply_actors(
		presentation_actors(lab),
		camera,
		lab._batted_ball,
		ball_live and lab._ball_in_play_is_live() and shot == Shot.BALL_IN_PLAY
	)


static func presentation_actors(lab: PitchBatLab) -> Array[Node3D]:
	var actors: Array[Node3D] = []
	if (
		is_instance_valid(lab._batter_avatar)
		and lab.get_node_or_null("BatterAvatar") == lab._batter_avatar
		and lab._batter_avatar.role == PlayerAvatar.Role.BATTER
	):
		actors.append(lab._batter_avatar)
		if is_instance_valid(lab._bat_actor) and lab.get_node_or_null("BatActor") == lab._bat_actor:
			actors.append(lab._bat_actor)
	if (
		is_instance_valid(lab._pitcher_avatar)
		and lab.get_node_or_null("PitcherDefender/PitcherAvatar") == lab._pitcher_avatar
		and lab.get_node_or_null("PitcherDefender") == lab._pitcher_marker
		and lab._pitcher_avatar.role == PlayerAvatar.Role.PITCHER
	):
		actors.append(lab._pitcher_avatar)
	if (
		is_instance_valid(lab._primary_fielder)
		and is_instance_valid(lab._primary_fielder._avatar)
		and lab.get_node_or_null("PrimaryFielder") == lab._primary_fielder
		and lab._primary_fielder.get_node_or_null("FielderAvatar") == lab._primary_fielder._avatar
		and lab._primary_fielder._avatar.role == PlayerAvatar.Role.FIELDER
	):
		actors.append(lab._primary_fielder._avatar)
	return actors
