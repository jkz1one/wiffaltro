class_name StadiumWaterfallAnimationProperty
extends StadiumPropertyGeometry
## Dedicated47 owner. The exact retained base is construction input, never substitute paid
## authority.
var animation_layout: Dictionary = {}
var base_layout: Dictionary = {}
var base_checked: Dictionary = {}
var _context_snapshot: Dictionary = {}
var _context_lab: WeakRef
var _context_state: MatchState
var _context_paid: ClubAssetLedger
var _context_generation: int = -1
var _context_paid_state: String = ""
var _context_titles: Dictionary = {}
var _context_host: Node3D
var _context_parent: Node
var _context_attached: bool = false
var _context_pose: Transform3D
var _context_host_pose: Transform3D
var _context_inputs: StadiumWaterfallAnimationIssuedInputs
var _issued_live: bool = false
var _issue_attempted: bool = false
var _issued_ever: bool = false
var _issued_refs: Dictionary = {}
var _absence_manifest: Dictionary = {}
var _issued_nodes: Array[Dictionary] = []
var _issued_objects: Dictionary = {}


func build_complete(
	property_tier: String,
	layout: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership,
	access: Array[String]
) -> bool:
	var checked: Dictionary = StadiumWaterfallAnimationLayout.validate(
		layout, stock, pieces, access, property_tier, boards
	)
	if not checked.ok or not animation_layout.is_empty():
		return false
	base_layout = StadiumWaterfallAnimationLayout.base(layout)
	base_checked = StadiumOwnedLayout.validate(
		base_layout, stock, pieces, access, property_tier, boards
	)
	_waterfall_animation_copies.assign(checked.waterfall_motion_copies)
	if not super.build(
		property_tier, StadiumWaterfallAnimationLayout.presentation_base(layout), stock
	):
		return false
	animation_layout = layout.duplicate(true)
	set_meta("property_signature", StadiumWaterfallAnimationLayout.geometry(property_tier, layout))
	if has_live_waterfall():
		set_meta("waterfall_live_layout", layout.duplicate(true))
	return true


func bind_props_context(lab: PitchBatLab) -> bool:
	if (
		_context_lab != null
		or not is_instance_valid(lab)
		or lab._match_state == null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not StadiumWaterfallAnimationSnapshot.matches(
			lab._match_state.stadium, lab._stadium_ledger
		)
		or not ClubCareer.same(lab._match_state.stadium.layout, animation_layout)
	):
		return false
	_context_state = lab._match_state
	_context_paid = lab._stadium_ledger
	_context_generation = _context_paid.mutation_generation()
	_context_paid_state = StadiumSurfaceNightRuntime._ledger_state(_context_paid)
	_context_titles = _context_paid._championships.duplicate(true)
	_context_snapshot = lab._match_state.stadium.duplicate(true)
	_context_lab = weakref(lab)
	if not super.bind_props_context(lab):
		return false
	_context_inputs = StadiumWaterfallAnimationIssuedInputs.new()
	if not _context_inputs.capture(lab, self):
		return false
	return motion_context_intact()


func motion_context_intact(deep: bool = true) -> bool:
	if _context_lab == null:
		return true
	var lab: PitchBatLab = _context_lab.get_ref() as PitchBatLab
	if (
		not is_instance_valid(lab)
		or not _props_live
		or lab._match_state != _context_state
		or lab._stadium_ledger != _context_paid
		or _context_paid == null
		or _context_paid.mutation_generation() != _context_generation
		or lab._field_id != PitchBatLab.FIELD_ID
	):
		return false
	if _context_inputs != null and not _context_inputs.intact(deep):
		return false
	if (
		(deep or _context_inputs == null)
		and (
			StadiumSurfaceNightRuntime._ledger_state(_context_paid) != _context_paid_state
			or not ClubCareer.same(_context_paid._championships, _context_titles)
			or lab._match_state.stadium != _context_snapshot
			or animation_layout != _context_snapshot.layout
			or base_layout != StadiumWaterfallAnimationLayout.base(animation_layout)
		)
	):
		return false
	return (
		_waterfall_animation_copies == animation_layout.waterfall_motion
		and (
			not _context_attached
			or (
				is_instance_valid(_context_host)
				and get_parent() == _context_host
				and _context_host.get_parent() == _context_parent
				and transform == _context_pose
				and _context_host.global_transform == _context_host_pose
				and StadiumWaterfallAnimationRuntime.claim_matches(lab, self)
			)
		)
	)


func props_intact() -> bool:
	# Exact NEW47 only: issued actions use current authority/lifetime. Historical45
	# retains its original proof. Transitions and supported writes call deep below.
	if _issued_ever:
		return issued_props_intact(
			_context_lab.get_ref() as PitchBatLab if _context_lab != null else null
		)
	return motion_context_intact() and super.props_intact()


func deep_props_intact() -> bool:
	if (
		_issued_ever
		and not issued_props_intact(
			_context_lab.get_ref() as PitchBatLab if _context_lab != null else null
		)
	):
		return false
	if not motion_context_intact(true):
		if _issue_attempted:
			_retire_issued_context()
		return false
	var boundary: Node = get_node_or_null("BoundaryGraph")
	if boundary != null and not _boundary_deep_intact(boundary):
		if _issue_attempted:
			_retire_issued_context()
		return false
	if not super.props_intact():
		if _issue_attempted:
			_retire_issued_context()
		return false
	return true


func _boundary_deep_intact(boundary: Node) -> bool:
	if animation_layout.get("animation_base") == 45:
		return (
			boundary.get_script() == StadiumWaterfallAnimationBoundary
			and (boundary as StadiumWaterfallAnimationBoundary).deep_intact()
		)
	return (
		animation_layout.get("animation_base") == 46
		and boundary.get_script() == StadiumWaterfallAnimationLowBoundary
		and (boundary as StadiumWaterfallAnimationLowBoundary).deep_intact()
	)


func seal_context(host: Node3D) -> bool:
	if _context_attached or host == null or get_parent() != host or not motion_context_intact():
		return false
	_context_host = host
	_context_parent = host.get_parent()
	_context_pose = transform
	_context_host_pose = host.global_transform
	_context_attached = true
	return motion_context_intact()


func seal_issued_context() -> bool:
	if _issue_attempted or _issued_ever:
		return false
	_issue_attempted = true
	if not _context_attached or _context_inputs == null or not deep_props_intact():
		_retire_issued_context()
		return false
	var lab: PitchBatLab = _context_lab.get_ref() as PitchBatLab
	var boundary: Node = get_node_or_null("BoundaryGraph")
	if boundary == null or not _boundary_deep_intact(boundary):
		_retire_issued_context()
		return false
	if (
		animation_layout.animation_base == 45
		and not (boundary as StadiumWaterfallAnimationBoundary).seal_issued_context()
	):
		_retire_issued_context()
		return false
	return _seal_issued_context_remaining_checks(lab, boundary)


func _seal_issued_context_remaining_checks(lab: PitchBatLab, boundary: Node) -> bool:
	var critical: Dictionary = {}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or node.get_child_count(true) != node.get_child_count()
		):
			_retire_issued_context()
			return false
		pending.append_array(node.get_children())
		if boundary.is_ancestor_of(node) or node == boundary:
			continue
		if (
			not node.tree_exiting.is_connected(_retire_issued_context)
			and node.tree_exiting.connect(_retire_issued_context) != OK
		):
			_retire_issued_context()
			return false
		if (
			not node.child_order_changed.is_connected(_retire_issued_context)
			and node.child_order_changed.connect(_retire_issued_context) != OK
		):
			_retire_issued_context()
			return false
		if (
			node is CollisionObject3D
			or node is CollisionShape3D
			or node.get_script() == StadiumWaterfallAnimationRuntime
		):
			var ancestor: Node = node
			while ancestor != null and ancestor != self:
				critical[ancestor.get_instance_id()] = ancestor
				ancestor = ancestor.get_parent()
	for node: Node in critical.values():
		var row: Dictionary = {
			"node": node, "parent": node.get_parent(), "script": node.get_script()
		}
		row.make_read_only()
		_issued_nodes.append(row)
	_issued_nodes.make_read_only()
	_issued_objects = objects.duplicate()
	_issued_objects.make_read_only()
	var refs: Dictionary = {
		"boundary": boundary, "live_waterfall": has_live_waterfall(), "objects": objects
	}
	if refs.live_waterfall:
		if (
			not is_instance_valid(lab._primary_fielder)
			or not is_instance_valid(lab._pitcher_marker)
		):
			_retire_issued_context()
			return false
		refs["fielder"] = lab._primary_fielder
		refs["fielder_parent"] = lab._primary_fielder.get_parent()
		refs["fielder_script"] = lab._primary_fielder.get_script()
		refs["pitcher"] = lab._pitcher_marker
		refs["pitcher_parent"] = lab._pitcher_marker.get_parent()
		refs["pitcher_script"] = lab._pitcher_marker.get_script()
	refs.make_read_only()
	_issued_refs = refs
	_capture_absence()
	# Runtime child, clock, receiver and all model construction already exist.
	# Reconcile before publishing; never recapture an installation after failure.
	if not deep_props_intact() or not _dynamic_live_intact(lab, boundary):
		_retire_issued_context()
		return false
	_issued_ever = true
	_issued_live = true
	return true


func _retire_issued_context() -> void:
	_issue_attempted = true
	_issued_live = false
	_retire_props()
	var boundary: Node = get_node_or_null("BoundaryGraph")
	if (
		boundary != null
		and (
			boundary.get_script()
			in [StadiumWaterfallAnimationBoundary, StadiumWaterfallAnimationLowBoundary]
		)
	):
		boundary._retire()


func issued_props_intact(lab: PitchBatLab) -> bool:
	if (
		not _issued_live
		or not _issued_ever
		or get_script() != StadiumWaterfallAnimationProperty
		or is_queued_for_deletion()
		or not _context_attached
		or _context_lab == null
		or _context_lab.get_ref() != lab
		or not _props_live
		or not motion_context_intact(false)
	):
		_retire_issued_context()
		return false
	if objects.size() != _issued_objects.size():
		_retire_issued_context()
		return false
	for copy: String in _issued_objects:
		var node: Variant = _issued_objects[copy]
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or objects.get(copy) != node
		):
			_retire_issued_context()
			return false
	for row: Dictionary in _issued_nodes:
		if (
			not is_instance_valid(row.node)
			or row.node.is_queued_for_deletion()
			or row.node.get_parent() != row.parent
			or row.node.get_script() != row.script
		):
			_retire_issued_context()
			return false
	var boundary: Node = get_node_or_null("BoundaryGraph")
	if (
		boundary == null
		or boundary != _issued_refs.boundary
		or not boundary.intact()
		or not _dynamic_live_intact(lab, boundary)
	):
		_retire_issued_context()
		return false
	return true


func _dynamic_live_intact(lab: PitchBatLab, boundary: Node) -> bool:
	# Moving actor legality and action callbacks are live semantics, not optional
	# raw-field anti-debugger scans. Keep these on every issued action/contact.
	if not _issued_refs.get("live_waterfall", false):
		return true
	var fielder: Variant = _issued_refs.fielder
	var pitcher: Variant = _issued_refs.pitcher
	if (
		not is_instance_valid(fielder)
		or not is_instance_valid(pitcher)
		or fielder.is_queued_for_deletion()
		or pitcher.is_queued_for_deletion()
		or lab._primary_fielder != fielder
		or lab._pitcher_marker != pitcher
		or fielder.get_parent() != _issued_refs.fielder_parent
		or pitcher.get_parent() != _issued_refs.pitcher_parent
		or fielder.get_script() != _issued_refs.fielder_script
		or pitcher.get_script() != _issued_refs.pitcher_script
	):
		return false
	return (
		fielder.stadium_waterfall_step == waterfall_step
		and fielder.stadium_waterfall_clip == waterfall_clip
		and is_finite(fielder.reach_m)
		and fielder.reach_m <= StadiumWaterfallLiveModels.MAX_DEFENDER_REACH
		and StadiumWaterfallLiveRoutes.legal(fielder.global_position, boundary.graph)
		and StadiumWaterfallLiveRoutes.legal(pitcher.global_position, boundary.graph)
	)


func _capture_absence() -> void:
	var specs: Dictionary = {
		&"live_furnishings": [&"live_furnishing_layout", &"live_furnishings", _furnishing_water],
		&"salvage_car": [&"salvage_car_layout", &"salvage_cars", _junk_car_traps]
	}
	var result: Dictionary = {"objects": objects}
	for feature: StringName in specs:
		var spec: Array = specs[feature]
		var placements: Variant = animation_layout.get(spec[1])
		var base_placements: Variant = base_layout.get(spec[1])
		if (
			not placements is Array
			or not placements.is_empty()
			or not base_placements is Array
			or not base_placements.is_empty()
			or not spec[2].is_empty()
			or not has_meta(spec[0])
		):
			continue
		var metadata: Variant = get_meta(spec[0])
		if (
			not metadata is Dictionary
			or not metadata.get(spec[1]) is Array
			or not metadata[spec[1]].is_empty()
		):
			continue
		var absent: bool = true
		for model: Variant in objects.values():
			if not is_instance_valid(model) or not model is Node3D:
				absent = false
				break
			var item: String = str(model.get_meta("stadium_item", ""))
			if (
				item == "ST-005"
				if feature == &"salvage_car"
				else StadiumLiveFurnishingItems.PRICES.has(item)
			):
				absent = false
				break
		if not absent:
			continue
		var row: Dictionary = {
			"meta_key": spec[0],
			"array_key": spec[1],
			"metadata": metadata,
			"placements": metadata[spec[1]],
			"map": spec[2]
		}
		row.make_read_only()
		result[feature] = row
	result.make_read_only()
	_absence_manifest = result


func issued_feature_absent(feature: StringName) -> bool:
	if (
		get_script() != StadiumWaterfallAnimationProperty
		or feature not in [&"live_furnishings", &"salvage_car"]
		or not _absence_manifest.is_read_only()
		or not _absence_manifest.has(feature)
		or not is_same(objects, _absence_manifest.objects)
	):
		return false
	var row: Dictionary = _absence_manifest[feature]
	var current_map: Dictionary = (
		_furnishing_water if feature == &"live_furnishings" else _junk_car_traps
	)
	if (
		not has_meta(row.meta_key)
		or not is_same(get_meta(row.meta_key), row.metadata)
		or not is_same(row.metadata.get(row.array_key), row.placements)
		or not row.placements.is_empty()
		or not is_same(current_map, row.map)
		or not current_map.is_empty()
	):
		return false
	return issued_props_intact(
		_context_lab.get_ref() as PitchBatLab if _context_lab != null else null
	)
