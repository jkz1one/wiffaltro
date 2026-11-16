class_name StadiumAdvancedLab
extends RefCounted
## Explicit isolated gameplay adapter. Declarations grant no saved-fixture eligibility.


static func install(lab: PitchBatLab, layout: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, access: Array[String], tier: String = "club") -> bool:
	if not StadiumPropertyRuntime.authoring_delivery_idle(lab) \
		or not lab.get_meta("stadium_advanced_lab_only", false) or lab._managed_match \
		or lab._automation != null or lab._match_state == null \
		or lab._field_id != PitchBatLab.FIELD_ID or lab.has_meta("stadium_property") \
		or is_instance_valid(lab._batted_ball):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if host == null or not host.is_inside_tree() \
		or not host.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	var property: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	if not property.build_owned(tier, layout, stock, pieces, access):
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
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	return true


static func install_frozen(lab: PitchBatLab, fixture: Variant, ledger: ClubAssetLedger) -> bool:
	if not StadiumAdvancedSnapshot.valid(fixture) \
		or int(fixture.version) != StadiumAdvancedSnapshot.FIXTURE_VERSION \
		or not StadiumAdvancedSnapshot.matches(fixture, ledger):
		return false
	var frozen: Dictionary = StadiumAdvancedSnapshot.normalized(fixture)
	var stock: StadiumStock = StadiumStock.from_data(frozen.inventory)
	var pieces: StadiumWallPieceOwnership = StadiumAdvancedSnapshot.piece_ownership(frozen, stock)
	var access: Array[String] = []
	access.assign(frozen.surface_access)
	if not install(lab, frozen.layout, stock, pieces, access, frozen.tier):
		return false
	lab.set_meta("advanced_authoring_fixture", frozen)
	return true
