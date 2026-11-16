class_name StadiumScoreboardLab
extends RefCounted
## Isolated gameplay and paid frozen studies; no production reward eligibility.


static func install(lab: PitchBatLab, layout: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String = "mogul") -> bool:
	if lab == null or not lab.get_meta("stadium_scoreboard_lab_only", false) or lab._managed_match \
		or lab._automation != null or not lab._match_mode or lab._match_state == null \
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH \
		or lab._field_id != PitchBatLab.FIELD_ID or lab.has_meta("stadium_property") \
		or is_instance_valid(lab._batted_ball):
		return false
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() \
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	if not property.build_scoreboards(tier, layout, stock, pieces, boards, access):
		property.free()
		return false
	if not StadiumPropertyRuntime._attach(lab, host, property, layout):
		property.free()
		return false
	lab.set_meta("stadium_candidate_only", true)
	lab._ball_play_resolver.segment_observer = property.observe
	if property.boundary is StadiumRecipeBoundaryBody:
		lab._primary_fielder.stadium_boundary_clip = property.boundary.graph.clip
		lab.set_meta("boundary_signature", property.boundary.graph.signature())
	else:
		lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
		lab.set_meta("boundary_signature", StadiumBoundaryGraph.signature())
	lab._camera_director.tracking_visibility = StadiumHeightCameraVisibility.new() \
		if property.boundary is StadiumHeightBoundaryBody else BallTrackingVisibility.new()
	lab._camera_director.tracking_visibility.configure(host)
	StadiumWallRenderQuality.attach(property.boundary)
	property.rebind_displays(lab._match_state)
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true


static func install_frozen(lab: PitchBatLab, fixture: Variant, ledger: ClubAssetLedger) -> bool:
	if not StadiumScoreboardSnapshot.valid(fixture) \
		or int(fixture.version) != StadiumScoreboardSnapshot.FIXTURE_VERSION \
		or not StadiumScoreboardSnapshot.matches(fixture, ledger):
		return false
	var frozen: Dictionary = StadiumScoreboardSnapshot.normalized(fixture)
	var owners: Dictionary = StadiumScoreboardSnapshot.ownership(frozen)
	var access: Array[String] = []
	access.assign(frozen.surface_access)
	if not install(lab, frozen.layout, owners.stock, owners.pieces, owners.boards,
		access, frozen.tier):
		return false
	lab.set_meta("scoreboard_authoring_fixture", frozen)
	return true
