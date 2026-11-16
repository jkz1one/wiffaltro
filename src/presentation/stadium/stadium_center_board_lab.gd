class_name StadiumCenterBoardLab
extends RefCounted
## Explicit unmanaged, pre-pitch, physically idle opt-in; never production admission.


static func install(lab: PitchBatLab, shape: String = "straight") -> bool:
	if lab == null or not lab.get_meta("stadium_center_board_lab_only", false) \
		or lab._managed_match or lab._automation != null or not lab._match_mode \
		or lab._match_state == null or lab._match_state.phase != MatchState.Phase.PRE_PITCH \
		or lab._field_id != PitchBatLab.FIELD_ID or lab.has_meta("stadium_property") \
		or is_instance_valid(lab._batted_ball) \
		or not StadiumPropertyRuntime.authoring_delivery_idle(lab):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() \
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var property: StadiumCenterBoardProperty = StadiumCenterBoardProperty.new()
	if not property.build_candidate(shape, true):
		property.free()
		return false
	if not StadiumPropertyRuntime._attach(lab, host, property, StadiumStarterLayout.empty()):
		property.free()
		return false
	lab.set_meta("stadium_candidate_only", true)
	lab.set_meta("center_board_authoring_source", StadiumCenterBoardProperty.PROVENANCE)
	lab._ball_play_resolver.segment_observer = property.observe
	lab._primary_fielder.stadium_boundary_clip = property.boundary.graph.clip
	lab.set_meta("boundary_signature", property.boundary.graph.signature())
	lab._camera_director._live_coverage = StadiumCenterBoardCameraMotion.new()
	lab._camera_director.tracking_visibility = StadiumCenterBoardVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	property.bind_celebration(lab)
	StadiumWallRenderQuality.attach(property.boundary)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true
