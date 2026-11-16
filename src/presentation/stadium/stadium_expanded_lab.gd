class_name StadiumExpandedLab
extends RefCounted
## Explicit isolated admission only. All checks precede original-scene replacement.


static func install(lab: PitchBatLab, fixture: Variant = null) -> bool:
	if (
		not StadiumPropertyRuntime.authoring_delivery_idle(lab)
		or not lab.get_meta("stadium_expanded_lab_only", false)
		or lab._managed_match
		or lab._automation != null
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or is_instance_valid(lab._batted_ball)
		or lab._pitch_actor.receiver_router.is_valid()
	):
		return false
	if fixture != null and not StadiumExpandedFixtureStudy.valid(fixture):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() or host.global_transform != Transform3D.IDENTITY:
		return false
	var property: StadiumExpandedProperty = StadiumExpandedVenueStudy.build()
	if property == null:
		return false
	if not property.prepare_receiver(lab):
		property.free()
		return false
	# All fallible staging has succeeded. Only now replace the original scene.
	property.name = "HomeProperty"
	host.add_child(property)
	for id: String in [
		"Ground",
		"BackWall",
		"LiveObjectPole",
		"Plate",
		"MoundMarker",
		"SafeBoundary",
		"DeepAirBoundary",
		"RightFoulLine",
		"LeftFoulLine"
	]:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			old.queue_free()
	lab.set_meta("stadium_property", property)
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	lab._pitch_actor.receiver_router = property.receiver.route
	property.display.bind_match(lab._match_state)
	property.lab_ref = weakref(lab)
	lab.set_meta("stadium_candidate_only", true)
	lab.set_meta(
		"stadium_expanded_candidate",
		StadiumExpandedFixtureStudy.capture(property.get_meta("candidate_venue"))
	)
	var boundary: StadiumExpandedBoundary = property.get_node("BoundaryGraph")
	lab._ball_play_resolver.segment_observer = boundary.graph.observe
	lab._primary_fielder.stadium_boundary_clip = boundary.graph.clip
	lab.set_meta("boundary_signature", boundary.graph.signature())
	var camera: StadiumExpandedCameraDirector = StadiumExpandedCameraDirector.new()
	camera.camera_mask |= StadiumExpandedProperty.CAMERA_LAYER
	var previous: MatchCameraDirector = lab._camera_director
	for key: String in [
		"shot",
		"_field_focus",
		"_batter_side",
		"_presentation_motion",
		"_presentation_progress",
		"_presentation_transition_speed",
		"_pitch_focus",
		"_live_coverage",
		"_standard_fov",
		"_tracking_height",
		"_shot_before_inspection"
	]:
		camera.set(key, previous.get(key))
	lab._camera_director = camera
	camera.tracking_visibility.configure(host)
	PitchBatLabPresentation.refresh_markers(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true


static func install_frozen(lab: PitchBatLab, fixture: Variant) -> bool:
	return StadiumExpandedFixtureStudy.valid(fixture) and install(lab, fixture)
