class_name StadiumLowWallProperty
extends StadiumPropertyGeometry
## Full paid base property plus a separately validated low-wall owner.
var low_layout: Dictionary = {}
var low_checked: Dictionary = {}
var low_owners: Dictionary = {}


var _low_context_snapshot: Dictionary = {}
var _low_context_lab: WeakRef
var _low_state: MatchState
var _low_paid: ClubAssetLedger
var _low_generation: int = -1
var _low_host: Node3D
var _low_host_parent: Node
var _low_attached: bool = false
var _low_pose: Transform3D
var _low_host_pose: Transform3D
var _low_inputs: StadiumLowWallIssuedInputs
var _low_issued_live: bool = false
var _low_issued_nodes: Array[Dictionary] = []
var _low_issued_objects: Dictionary = {}


func build_complete(
	property_tier: String,
	layout: Dictionary,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String]
) -> bool:
	var checked: Dictionary = StadiumLowWallLayout.validate(
		layout, stock, pieces, access, property_tier
	)
	if not checked.ok or not super.build(property_tier, StadiumLowWallLayout.base(layout), stock):
		return false
	low_layout = layout.duplicate(true)
	low_checked = checked.duplicate(true)
	low_owners = {"stock": stock, "pieces": pieces, "access": access.duplicate()}
	set_meta("property_signature", StadiumLowWallLayout.geometry(property_tier, layout))
	return true


func bind_props_context(lab: PitchBatLab) -> bool:
	if (
		_low_context_lab != null
		or not is_instance_valid(lab)
		or lab._match_state == null
		or lab._field_id != PitchBatLab.FIELD_ID
		or not StadiumLowWallSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
		or not ClubCareer.same(lab._match_state.stadium.layout, low_layout)
	):
		return false
	_low_state = lab._match_state
	_low_paid = lab._stadium_ledger
	_low_generation = _low_paid.mutation_generation()
	_low_context_snapshot = lab._match_state.stadium.duplicate(true)
	_low_context_lab = weakref(lab)
	if not super.bind_props_context(lab):
		return false
	_low_inputs = StadiumLowWallIssuedInputs.new()
	return _low_inputs.capture(lab, self) and low_context_intact()


func low_context_intact(deep: bool = false) -> bool:
	if _low_context_lab == null:
		return true
	var lab: PitchBatLab = _low_context_lab.get_ref()
	return (
		_props_live
		and (_low_inputs == null or _low_inputs.intact(deep))
		and is_instance_valid(lab)
		and lab._match_state == _low_state
		and lab._stadium_ledger == _low_paid
		and _low_paid != null
		and _low_paid.mutation_generation() == _low_generation
		and lab._field_id == PitchBatLab.FIELD_ID
		and (not deep or lab._match_state.stadium == _low_context_snapshot)
		and (
			not _low_attached
			or (
				is_instance_valid(_low_host)
				and get_parent() == _low_host
				and _low_host.get_parent() == _low_host_parent
				and transform == _low_pose
				and _low_host.global_transform == _low_host_pose
				and lab.has_meta("stadium_property")
				and lab.get_meta("stadium_property") == self
			)
		)
	)


func props_intact() -> bool:
	return low_context_intact() and super.props_intact()


func seal_low_context(host: Node3D) -> bool:
	if _low_attached or host == null or get_parent() != host or not low_context_intact():
		return false
	_low_host = host
	_low_host_parent = host.get_parent()
	_low_pose = transform
	_low_host_pose = host.global_transform
	_low_attached = true
	if not low_context_intact(true) or not super.props_intact():
		return false
	return _capture_issued_property()


func _capture_issued_property() -> bool:
	if _low_issued_live:
		return false
	var boundary: Node = get_node_or_null("BoundaryGraph")
	if not boundary is StadiumLowWallBoundaryRuntime:
		return false
	var critical: Dictionary = {}
	for node: Node in find_children("*", "", true, false):
		if boundary.is_ancestor_of(node) or node == boundary:
			continue
		if not node.tree_exiting.is_connected(_retire_issued_property):
			node.tree_exiting.connect(_retire_issued_property)
		if not node.child_order_changed.is_connected(_retire_issued_property):
			node.child_order_changed.connect(_retire_issued_property)
		if node is CollisionObject3D or node is CollisionShape3D:
			var ancestor: Node = node
			while ancestor != null and ancestor != self:
				critical[ancestor.get_instance_id()] = ancestor
				ancestor = ancestor.get_parent()
	for node: Node in critical.values():
		var row: Dictionary = {"node": node, "parent": node.get_parent()}
		row.make_read_only()
		_low_issued_nodes.append(row)
	_low_issued_nodes.make_read_only()
	_low_issued_objects = objects.duplicate()
	_low_issued_objects.make_read_only()
	tree_exiting.connect(_retire_issued_property)
	child_order_changed.connect(_retire_issued_property)
	_low_issued_live = true
	return true


func _retire_issued_property() -> void:
	_low_issued_live = false
	var boundary: StadiumLowWallBoundaryRuntime = (
		get_node_or_null("BoundaryGraph") as StadiumLowWallBoundaryRuntime
	)
	if boundary != null:
		boundary._retire()


func issued_props_intact(lab: PitchBatLab) -> bool:
	if (
		not _low_issued_live
		or not _low_attached
		or _low_context_lab == null
		or _low_context_lab.get_ref() != lab
		or not _props_live
		or not low_context_intact()
	):
		_retire_issued_property()
		return false
	if objects.size() != _low_issued_objects.size():
		_retire_issued_property()
		return false
	for copy: String in _low_issued_objects:
		var node: Variant = _low_issued_objects[copy]
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
			or objects.get(copy) != node
		):
			_retire_issued_property()
			return false
	for row: Dictionary in _low_issued_nodes:
		if (
			not is_instance_valid(row.node)
			or row.node.is_queued_for_deletion()
			or row.node.get_parent() != row.parent
		):
			_retire_issued_property()
			return false
	var boundary: StadiumLowWallBoundaryRuntime = (
		get_node_or_null("BoundaryGraph") as StadiumLowWallBoundaryRuntime
	)
	return boundary != null and boundary.intact()
