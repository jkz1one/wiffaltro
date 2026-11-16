class_name StadiumGrandIIIProperty
extends StadiumClubPropertyGeometry
## Exact Grand III adapter lifecycle. Existing Club geometry and classes remain frozen.

var lab_ref: WeakRef
var actor_cutaway: StadiumActorCutawayStudy = StadiumNpcRetainedActorCutaway.new()


func configure_candidate(lab: PitchBatLab) -> bool:
	if (
		lab == null
		or not StadiumGrandIIIFixtureStudy.valid(
			StadiumGrandIIIFixtureStudy.capture(get_meta("candidate_venue", {}))
		)
	):
		return false
	if not super.configure_candidate(lab):
		return false
	var board: Node3D = objects.get(
		StadiumGrandIIIVenueStudy.PREFIX + StadiumGrandIIIVenueStudy.BOARD_SITE
	)
	if board == null:
		return false
	display = board.get_node_or_null("Visual/ScoreDisplay") as StadiumScoreboardTierDisplay
	if display == null:
		return false
	display.bind_match(lab._match_state)
	return true


func _process(_delta: float) -> void:
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab != null:
		rebind_display(lab._match_state)


func _exit_tree() -> void:
	actor_cutaway.restore_all()
	var lab: PitchBatLab = lab_ref.get_ref() as PitchBatLab if lab_ref != null else null
	if lab == null:
		return
	if lab._camera_director is StadiumGrandICameraDirector:
		var camera: StadiumGrandICameraDirector = (
			lab._camera_director as StadiumGrandICameraDirector
		)
		if camera.actor_cutaway == actor_cutaway:
			camera.actor_cutaway = null
	if (
		is_instance_valid(receiver)
		and is_instance_valid(lab._pitch_actor)
		and lab._pitch_actor.receiver_router == receiver.route
	):
		lab._pitch_actor.receiver_router = Callable()
	if lab._ball_play_resolver != null and lab._ball_play_resolver.segment_observer == observe:
		lab._ball_play_resolver.segment_observer = Callable()
	if (
		is_instance_valid(boundary)
		and is_instance_valid(lab._primary_fielder)
		and lab._primary_fielder.stadium_boundary_clip == boundary.graph.clip
	):
		lab._primary_fielder.stadium_boundary_clip = Callable()
		lab._primary_fielder.stadium_obstacles = []
	if lab.get_meta("stadium_property", null) == self:
		lab.remove_meta("stadium_property")
