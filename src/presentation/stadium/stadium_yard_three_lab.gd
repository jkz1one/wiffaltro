class_name StadiumYardThreeLab
extends RefCounted
## One explicit AY-03 authoring install. No managed match, historical record or night activation.

const STARTER: Resource = preload("res://src/content/fields/starter_field.tres")
const REMOVED: Array[String] = ["Ground", "BackWall", "LiveObjectPole", "Plate", "MoundMarker",
	"SafeBoundary", "DeepAirBoundary", "RightFoulLine", "LeftFoulLine"]


static func install(lab: PitchBatLab, fixture: Variant = null) -> bool:
	if not _admissible(lab) or (fixture != null and not StadiumYardThreeFixture.valid(fixture)):
		return false
	var property: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
	if property == null:
		return false
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	# Every rejection precedes scene replacement. The unchanged private field has Yard values.
	StadiumPropertyRuntime._attach(lab, host, property, StadiumStarterLayout.empty())
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab.set_meta("stadium_candidate_only", true)
	lab.set_meta("stadium_yard_three_candidate", StadiumYardThreeFixture.capture(
		property.get_meta("candidate_venue")))
	lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	lab._camera_director.tracking_visibility = StadiumYardFieldVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	PitchBatLabPresentation.refresh_markers(lab)
	return true


static func _admissible(lab: PitchBatLab) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_yard_three_lab_only", false) or lab._managed_match \
		or lab._automation != null or lab._field_id != PitchBatLab.FIELD_ID \
		or lab.has_meta("stadium_property") or lab.get_meta("stadium_candidate_only", false) \
		or is_instance_valid(lab._batted_ball) or lab._pitch_actor.receiver_router.is_valid() \
		or lab._match_state == null or not lab._match_state.stadium.is_empty() \
		or lab._ball_play_resolver.segment_observer.is_valid() \
		or lab._primary_fielder.stadium_boundary_clip.is_valid() \
		or not lab._primary_fielder.stadium_obstacles.is_empty() \
		or lab._camera_director.get_script() != load(
			"res://src/presentation/camera/match_camera_director.gd") \
		or lab._camera_director.tracking_visibility.get_script() != load(
			"res://src/presentation/camera/ball_tracking_visibility.gd"):
		return false
	if lab._field_definition == null or lab._field_definition.get_script() != STARTER.get_script():
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if lab._field_definition.get(key) != StadiumNpcYardV1.FIELD[key]:
			return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() or host.global_transform != Transform3D.IDENTITY \
		or not host.has_node("PitchReceiverDebug"):
		return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	var expected: BallTrackingVisibility = BallTrackingVisibility.new()
	expected.configure(host)
	var actual: BallTrackingVisibility = lab._camera_director.tracking_visibility
	return actual._obstacles == expected._obstacles and actual._uprights == expected._uprights \
		and actual._wall_bounds == expected._wall_bounds and actual._recipe == null \
		and actual._wall_prisms == null and actual.field_wall_z == expected.field_wall_z
