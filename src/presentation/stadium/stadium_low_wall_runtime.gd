class_name StadiumLowWallRuntime
extends RefCounted
## Exact-prefix entry32/fixture33 installation. No stock-only fallback.
const BOUND: String = "owned_low_wall_bound_v1"


static func requested(lab: PitchBatLab) -> bool:
	return (
		lab != null
		and lab._match_state != null
		and StadiumLowWallSnapshot.is_family(lab._match_state.stadium)
	)


static func install_bound(lab: PitchBatLab) -> bool:
	if (
		not requested(lab)
		or lab._stadium_ledger == null
		or not StadiumLowWallSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or is_instance_valid(lab._batted_ball)
	):
		return false
	var snapshot: Dictionary = StadiumLowWallSnapshot.normalized(lab._match_state.stadium)
	var owners: Dictionary = StadiumLowWallSnapshot.ownership(snapshot)
	var access: Array[String] = []
	access.assign(snapshot.surface_access)
	var old: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if old == null:
		return false
	var property: StadiumLowWallProperty = StadiumLowWallProperty.new()
	if not property.build_complete(
		snapshot.tier, snapshot.layout, owners.stock, owners.pieces, access
	):
		property.free()
		return false
	var boundary: StadiumLowWallBoundaryRuntime = StadiumLowWallBoundaryRuntime.new()
	boundary.name = "BoundaryGraph"
	if not boundary.build_complete(
		property, snapshot.layout, owners.stock, owners.pieces, access, property.low_checked
	):
		boundary.free()
		property.free()
		return false
	var template: Node = property.get_node_or_null("TemplateBackWall")
	if template == null:
		boundary.free()
		property.free()
		return false
	template.free()
	property.add_child(boundary)
	if not StadiumPropertyRuntime._attach(
		lab, old, property, StadiumLowWallLayout.base(snapshot.layout)
	):
		if not property.is_inside_tree():
			property.free()
		return false
	if not property.seal_low_context(old):
		return false
	lab._ball_play_resolver.segment_observer = boundary.observe
	lab._primary_fielder.stadium_boundary_clip = boundary.graph.clip
	lab.set_meta("boundary_signature", boundary.graph.signature())
	lab.set_meta("stadium_snapshot", snapshot)
	lab.set_meta(BOUND, true)
	lab._camera_director.tracking_visibility.configure(old)
	return installed_bound(lab, snapshot)


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if (
		lab == null
		or not lab.has_meta(BOUND)
		or lab.get_meta(BOUND) != true
		or not lab.has_meta("stadium_property")
		or not lab.has_meta("stadium_snapshot")
		or lab._match_state == null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not StadiumLowWallSnapshot.valid(snapshot)
		or not ClubCareer.same(lab._match_state.stadium, snapshot)
		or not ClubCareer.same(lab.get_meta("stadium_snapshot", {}), snapshot)
		or lab._stadium_ledger == null
		or not StadiumLowWallSnapshot.matches(snapshot, lab._stadium_ledger)
	):
		return false
	var property: StadiumLowWallProperty = (
		lab.get_meta("stadium_property", null) as StadiumLowWallProperty
	)
	if (
		property == null
		or not property.props_intact()
		or not ClubCareer.same(property.low_layout, snapshot.layout)
	):
		return false
	var boundary: StadiumLowWallBoundaryRuntime = (
		property.get_node_or_null("BoundaryGraph") as StadiumLowWallBoundaryRuntime
	)
	return (
		boundary != null
		and boundary.deep_intact()
		and (
			boundary.get_meta("boundary_layout_hash", "")
			== JSON.stringify(snapshot.layout, "", true, true).sha256_text()
		)
		and boundary.graph.signature() == snapshot.boundary
		and lab._ball_play_resolver.segment_observer == boundary.observe
		and lab._primary_fielder.stadium_boundary_clip == boundary.graph.clip
	)
