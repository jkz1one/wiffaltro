class_name StadiumWaterfallAnimationInstall
extends RefCounted
## Exact paid47 snapshot entry34/fixture35; never substitute a projected snapshot for its receipt.
const BOUND: String = "owned_waterfall_animation_bound_v1"


static func requested(lab: PitchBatLab) -> bool:
	return (
		is_instance_valid(lab)
		and lab._match_state != null
		and StadiumWaterfallAnimationSnapshot.is_family(lab._match_state.stadium)
	)


static func install_bound(lab: PitchBatLab) -> bool:
	if (
		not requested(lab)
		or lab._stadium_ledger == null
		or not StadiumWaterfallAnimationSnapshot.matches(
			lab._match_state.stadium, lab._stadium_ledger
		)
		or lab._field_id != PitchBatLab.FIELD_ID
		or lab.has_meta("stadium_property")
		or is_instance_valid(lab._batted_ball)
	):
		return false
	var snapshot: Dictionary = StadiumWaterfallAnimationSnapshot.normalized(
		lab._match_state.stadium
	)
	var owners: Dictionary = StadiumWaterfallAnimationSnapshot.ownership(snapshot)
	var access: Array[String] = []
	access.assign(snapshot.surface_access)
	var old: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if old == null:
		return false
	var property: StadiumWaterfallAnimationProperty = StadiumWaterfallAnimationProperty.new()
	if not property.build_complete(
		snapshot.tier, snapshot.layout, owners.stock, owners.pieces, owners.boards, access
	):
		property.free()
		return false
	var boundary: StadiumBoundaryOwnedRuntime
	var built: bool
	if snapshot.layout.animation_base == 46:
		boundary = StadiumWaterfallAnimationLowBoundary.new()
		boundary.name = "BoundaryGraph"
		built = (boundary as StadiumWaterfallAnimationLowBoundary).build_complete(
			property,
			property.base_layout,
			owners.stock,
			owners.pieces,
			access,
			property.base_checked
		)
	else:
		boundary = StadiumWaterfallAnimationBoundary.new()
		boundary.name = "BoundaryGraph"
		built = boundary.build_from(property, property.get_meta("boundary_layout"), owners.stock)
	if not built:
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
		lab, old, property, StadiumWaterfallAnimationLayout.presentation_base(snapshot.layout)
	):
		if not property.is_inside_tree():
			property.free()
		return false
	if not property.seal_context(old):
		return false
	lab._ball_play_resolver.segment_observer = boundary.observe
	lab._primary_fielder.stadium_boundary_clip = boundary.graph.clip
	lab.set_meta("boundary_signature", boundary.graph.signature())
	lab.set_meta("stadium_snapshot", snapshot)
	lab.set_meta(BOUND, true)
	if not StadiumWaterfallAnimationRuntime.install(lab, property):
		return false
	if not property.seal_issued_context():
		return false
	lab._camera_director.tracking_visibility.configure(old)
	return installed_bound(lab, snapshot)


static func installed_bound(lab: PitchBatLab, snapshot: Dictionary) -> bool:
	if (
		not is_instance_valid(lab)
		or lab.get_meta(BOUND, false) != true
		or lab._match_state == null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not StadiumWaterfallAnimationSnapshot.valid(snapshot)
		or not ClubCareer.same(lab._match_state.stadium, snapshot)
		or not ClubCareer.same(lab.get_meta("stadium_snapshot", {}), snapshot)
		or lab._stadium_ledger == null
		or not StadiumWaterfallAnimationSnapshot.matches(snapshot, lab._stadium_ledger)
	):
		return false
	var property: StadiumWaterfallAnimationProperty = (
		StadiumWaterfallAnimationRuntime.property_claim(lab) as StadiumWaterfallAnimationProperty
	)
	if (
		property == null
		or not property.deep_props_intact()
		or not ClubCareer.same(property.animation_layout, snapshot.layout)
	):
		return false
	var boundary: StadiumBoundaryOwnedRuntime = (
		property.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	var boundary_valid: bool = (
		boundary != null
		and (
			(
				boundary.get_script() == StadiumWaterfallAnimationLowBoundary
				and (boundary as StadiumWaterfallAnimationLowBoundary).deep_intact()
			)
			if snapshot.layout.animation_base == 46
			else (
				boundary.get_script() == StadiumWaterfallAnimationBoundary
				and (boundary as StadiumWaterfallAnimationBoundary).deep_intact()
			)
		)
	)
	if (
		not boundary_valid
		or boundary.graph.signature() != snapshot.boundary
		or lab._ball_play_resolver.segment_observer != boundary.observe
		or lab._primary_fielder.stadium_boundary_clip != boundary.graph.clip
	):
		return false
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
	return (
		(owner != null and owner.intact())
		if StadiumWaterfallAnimationRuntime.required(lab)
		else owner == null
	)
