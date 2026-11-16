class_name StadiumClubLab
extends RefCounted
## Explicit isolated complete-field opt-in. No saved season, managed fixture or production grant.


static func install(lab: PitchBatLab) -> bool:
	return _install(lab, {})


static func install_frozen(lab: PitchBatLab, fixture: Variant) -> bool:
	if not StadiumClubFixtureStudy.valid(fixture):
		return false
	return _install(lab, fixture.venue)


static func _install(lab: PitchBatLab, frozen_record: Dictionary) -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_club_lab_only", false) or lab._managed_match \
		or lab._automation != null or lab._field_id != PitchBatLab.FIELD_ID \
		or lab.has_meta("stadium_property") or is_instance_valid(lab._batted_ball):
		return false
	var host: Node3D = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() \
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var property: StadiumClubPropertyGeometry = StadiumClubPropertyGeometry.new()
	if StadiumClubVenueStudy.build(host, property) == null:
		if is_instance_valid(property):
			property.queue_free()
		return false
	# A self-consistent checksum is not authority to change the frozen canonical assembly.
	if (not frozen_record.is_empty() and not ClubCareer.same(
		frozen_record, property.get_meta("candidate_venue"))) or not property.configure_candidate(lab):
		host.remove_child(property)
		property.queue_free()
		return false
	for id: String in ["Ground", "BackWall", "LiveObjectPole", "Plate", "MoundMarker",
		"SafeBoundary", "DeepAirBoundary", "RightFoulLine", "LeftFoulLine"]:
		var old: Node = host.get_node_or_null(NodePath(id))
		if old != null:
			host.remove_child(old)
			old.queue_free()
	property.name = "HomeProperty"
	lab.set_meta("stadium_property", property)
	lab.set_meta("stadium_candidate_only", true)
	lab._pitch_actor.receiver_router = property.receiver.route
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.boundary.graph.clip
	lab._primary_fielder.stadium_obstacles = property.route_obstacles()
	var camera: StadiumClubCameraDirector = StadiumClubCameraDirector.new()
	var previous: MatchCameraDirector = lab._camera_director
	# Preserve paused/setup shots, presentation motion and role-camera state during isolated opt-in.
	for key: String in ["shot", "_field_focus", "_batter_side", "_presentation_motion",
		"_presentation_progress", "_presentation_transition_speed", "_pitch_focus", "_live_coverage",
		"_standard_fov", "_tracking_height", "_shot_before_inspection"]:
		camera.set(key, previous.get(key))
	camera.camera_mask |= StadiumClubPropertyGeometry.CAMERA_LAYER
	camera.tracking_visibility = StadiumClubFieldVisibility.new()
	lab._camera_director = camera
	camera.tracking_visibility.configure(host)
	PitchBatLabPresentation.sync_players(lab)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true
