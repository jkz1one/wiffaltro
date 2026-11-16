class_name StadiumYardTwoLab
extends RefCounted
## One explicit AY-02 authoring install. No managed match, historical record or night activation.

const STARTER: Resource = preload("res://src/content/fields/starter_field.tres")
const REMOVED: Array[String] = [
	"Ground",
	"BackWall",
	"LiveObjectPole",
	"Plate",
	"MoundMarker",
	"SafeBoundary",
	"DeepAirBoundary",
	"RightFoulLine",
	"LeftFoulLine"
]


static func install(lab: PitchBatLab, fixture: Variant = null) -> bool:
	if not _admissible(lab) or (fixture != null and not StadiumYardTwoFixture.valid(fixture)):
		return false
	var property: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
	if property == null:
		return false
	var host: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	var receiver: StadiumYardTwoReceiver = StadiumYardTwoReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	property.add_child(receiver)
	if (
		not receiver.configure_candidate(property, lab._sounds)
		or not receiver.bind_actor(lab._pitch_actor)
	):
		property.free()
		return false
	var motion: StadiumYardTwoCameraMotion = StadiumYardTwoCameraMotion.new()
	if not motion.bind_candidate(property):
		property.free()
		return false
	# Every fallible check precedes replacement; no shared human-copy receiver installer is used.
	for id: String in REMOVED:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			old.queue_free()
	property.name = "HomeProperty"
	host.add_child(property)
	# Actual candidate presentation uses the existing viewport-lifetime wall quality lease.
	# Headless acquisition is intentionally a no-op; native ownership restores on detach.
	StadiumWallRenderQuality.attach(property.get_node("BoundaryGraph") as Node3D)
	lab.set_meta("stadium_property", property)
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._field_id = property.field.id
	lab._field_definition = property.field
	lab.set_meta("stadium_candidate_only", true)
	lab.set_meta(
		"stadium_yard_two_candidate",
		StadiumYardTwoFixture.capture(property.get_meta("candidate_venue"))
	)
	lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	var previous: MatchCameraDirector = lab._camera_director
	var camera: StadiumYardTwoCameraDirector = StadiumYardTwoCameraDirector.new()
	for key: String in [
		"shot",
		"_field_focus",
		"_batter_side",
		"_presentation_motion",
		"_presentation_progress",
		"_presentation_transition_speed",
		"_pitch_focus",
		"_standard_fov",
		"_tracking_height",
		"_shot_before_inspection"
	]:
		camera.set(key, previous.get(key))
	camera.lab_ref = weakref(lab)
	property.lab_ref = weakref(lab)
	camera.actor_cutaway = property.actor_cutaway
	camera._live_coverage = motion
	var visibility: StadiumYardTwoTrackingVisibility = StadiumYardTwoTrackingVisibility.new()
	visibility.lab_ref = weakref(lab)
	visibility.motion_ref = weakref(motion)
	visibility.configure(host)
	camera.tracking_visibility = visibility
	lab._camera_director = camera
	var foreground: StadiumYardTwoActorPresentation = StadiumYardTwoActorPresentation.new()
	foreground.name = "AY02ActorPresentation"
	foreground.lab_ref = weakref(lab)
	foreground.actor_cutaway = property.actor_cutaway
	property.add_child(foreground)
	camera.acquire_precontact_entry()
	PitchBatLabPresentation.refresh_markers(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true


static func _admissible(lab: PitchBatLab) -> bool:
	if (
		not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or not lab.get_meta("stadium_yard_two_lab_only", false)
		or lab._managed_match
		or lab._automation != null
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or lab.get_meta("stadium_candidate_only", false)
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor.receiver_router.is_valid()
		or lab._match_state == null
		or not lab._match_state.stadium.is_empty()
		or lab._ball_play_resolver.segment_observer.is_valid()
		or lab._primary_fielder.stadium_boundary_clip.is_valid()
		or not lab._primary_fielder.stadium_obstacles.is_empty()
		or lab._camera_director.presentation_override.is_valid()
		or lab._camera_director._live_coverage.get_script() != BallInPlayCamera
		or lab._camera_director._live_coverage.position_filter.is_valid()
		or lab._camera_director._live_coverage.framing_lead_degrees != 0
		or (
			lab._camera_director.get_script()
			!= load("res://src/presentation/camera/match_camera_director.gd")
		)
		or (
			lab._camera_director.tracking_visibility.get_script()
			!= load("res://src/presentation/camera/ball_tracking_visibility.gd")
		)
	):
		return false
	if lab._field_definition == null or lab._field_definition.get_script() != STARTER.get_script():
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if lab._field_definition.get(key) != StadiumNpcYardV1.FIELD[key]:
			return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or not host.is_inside_tree()
		or host.global_transform != Transform3D.IDENTITY
		or not host.has_node("PitchReceiverDebug")
	):
		return false
	for body: CollisionObject3D in host.find_children("*", "CollisionObject3D", true, false):
		if body.get_parent() != host or String(body.name) not in REMOVED:
			return false
	var expected: BallTrackingVisibility = BallTrackingVisibility.new()
	expected.configure(host)
	var actual: BallTrackingVisibility = lab._camera_director.tracking_visibility
	return (
		actual._obstacles == expected._obstacles
		and actual._uprights == expected._uprights
		and actual._wall_bounds == expected._wall_bounds
		and actual._recipe == null
		and actual._wall_prisms == null
		and actual.field_wall_z == expected.field_wall_z
	)
