class_name StadiumGrandIIICameraDirector
extends StadiumGrandICameraDirector
## Grand III opts into the qualified retained all-actor helper without changing camera motion.
## Only the installed lab's current, correctly parented actors may receive presentation fades.


func refresh_actor_cutaway(camera: Camera3D, ball_live: bool) -> void:
	if actor_cutaway == null:
		return
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	var property: StadiumGrandIIIProperty
	if lab != null and lab.has_meta("stadium_property"):
		property = lab.get_meta("stadium_property") as StadiumGrandIIIProperty
	if (
		lab == null
		or property == null
		or property.actor_cutaway != actor_cutaway
		or lab._camera_director != self
		or camera != lab._camera
		or not actor_cutaway is StadiumNpcRetainedActorCutaway
	):
		actor_cutaway.restore_all()
		return
	(actor_cutaway as StadiumNpcRetainedActorCutaway).apply_actors(
		presentation_actors(lab), camera, lab._batted_ball, ball_live and shot == Shot.BALL_IN_PLAY
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
