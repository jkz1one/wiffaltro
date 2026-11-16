class_name StadiumPennantMotion
extends Node3D
## ST044-only presentation. Quiet until explicitly bound; invalid ownership fails quiet.

const PERIOD: float = 7.0
const MAX_ANGLE: float = 0.0115  # 1.72m cloth radius gives less than 0.020m displacement.

var _cloth: Node3D
var _visual: Node3D
var _collision: Node3D
var _parts: Array[Dictionary] = []
var _earned: Dictionary = {}
var _phase: float = 0.0
var _angle: float = 0.0
var _mode: int = 0
var _invalid: bool = false
var _parent: WeakRef
var _world: Transform3D
var _pose: Transform3D
var _match: MatchState
var _lab: WeakRef
var _property_parent: WeakRef
var _property_world: Transform3D


func configure_motion() -> bool:
	if _cloth != null or not has_node("Visual") or not has_node("Collision"):
		return false
	set_process(false)
	_visual = get_node("Visual")
	_collision = get_node("Collision")
	_earned = get_meta("earned", {}).duplicate(true)
	_cloth = Node3D.new()
	_cloth.name = "PennantCloth"
	for child: Node3D in _visual.get_children():
		if child.name == "PennantHangingRail" or str(child.name).begins_with("PennantBracket"):
			continue
		_visual.remove_child(child)
		_cloth.add_child(child)
	_visual.add_child(_cloth)
	for holder: Node3D in [_visual, _cloth]:
		for child: Node3D in holder.get_children():
			if child == _cloth:
				continue
			var part: Dictionary = {"node": child, "parent": holder, "pose": child.transform}
			if child is MeshInstance3D:
				part.mesh = child.mesh
				part.material = child.material_override
				part.bounds = child.custom_aabb
				child.mesh.changed.connect(_invalidate)
				child.material_override.changed.connect(_invalidate)
			elif child is Label3D:
				part.label = [
					child.text,
					child.modulate,
					child.font_size,
					child.pixel_size,
					child.outline_size
				]
			_parts.append(part)
	return _intact()


func bind_preview() -> bool:
	if _mode == 2 or not _capture():
		return false
	_mode = 1
	set_process(true)
	return true


func bind_match(state: MatchState, lab: PitchBatLab) -> bool:
	if (
		_mode == 2
		and (
			_match != state
			or _lab == null
			or _lab.get_ref() != lab
			or transform != _pose
			or global_transform != _world
		)
	):
		_invalidate()
		return false
	if (
		state == null
		or not is_instance_valid(lab)
		or lab._match_state != state
		or not get_parent() is StadiumPropertyGeometry
		or not _capture()
	):
		_invalidate()
		return false
	var property: StadiumPropertyGeometry = get_parent()
	if (
		lab.get_meta("stadium_property", null) != property
		or property.objects.get(get_meta("owned_copy", "")) != self
	):
		_invalidate()
		return false
	_match = state
	_lab = weakref(lab)
	_property_parent = weakref(property.get_parent())
	_property_world = property.global_transform
	_mode = 2
	set_process(true)
	return true


func _capture() -> bool:
	if not is_inside_tree() or get_parent() == null or not _intact():
		return false
	_parent = weakref(get_parent())
	_pose = transform
	_world = global_transform
	return true


func _intact() -> bool:
	if (
		_invalid
		or get_child_count() != 2
		or not is_instance_valid(_visual)
		or get_node_or_null("Visual") != _visual
		or not is_instance_valid(_collision)
		or get_node_or_null("Collision") != _collision
		or _collision.get_child_count() != 0
		or _visual.transform != Transform3D.IDENTITY
		or not is_instance_valid(_cloth)
		or _cloth.get_parent() != _visual
		or _cloth.transform != Transform3D(Basis(Vector3.RIGHT, _angle), Vector3.ZERO)
		or _parts.size() != _visual.get_child_count() + _cloth.get_child_count() - 1
		or get_meta("earned", {}) != _earned
	):
		return false
	for part: Dictionary in _parts:
		if (
			not is_instance_valid(part.node)
			or part.node.get_parent() != part.parent
			or part.node.transform != part.pose
			or part.node.get_script() != null
		):
			return false
		if (
			part.has("mesh")
			and (
				part.node.mesh != part.mesh
				or part.node.material_override != part.material
				or part.node.custom_aabb != part.bounds
			)
		):
			return false
		if (
			part.has("label")
			and (
				[
					part.node.text,
					part.node.modulate,
					part.node.font_size,
					part.node.pixel_size,
					part.node.outline_size
				]
				!= part.label
			)
		):
			return false
	return true


func _process(delta: float) -> void:
	if _mode == 0 or not is_finite(delta) or delta < 0.0:
		return
	if (
		not _intact()
		or _parent == null
		or get_parent() != _parent.get_ref()
		or transform != _pose
		or global_transform != _world
	):
		_invalidate()
		return
	if _mode == 2:
		var lab: PitchBatLab = _lab.get_ref() if _lab != null else null
		var property: StadiumPropertyGeometry = get_parent() as StadiumPropertyGeometry
		if (
			not is_instance_valid(lab)
			or property == null
			or lab._match_state != _match
			or lab.get_meta("stadium_property", null) != property
			or property.objects.get(get_meta("owned_copy", "")) != self
			or property.get_parent() != _property_parent.get_ref()
			or property.global_transform != _property_world
		):
			_invalidate()
			return
		if (
			lab._pitch_actor == null
			or lab._pitch_actor.running
			or (lab._release_controller != null and lab._release_controller.active)
			or _match.phase in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]
		):
			return
	_phase = fposmod(_phase + minf(delta, 0.1) * TAU / PERIOD, TAU)
	_angle = sin(_phase) * MAX_ANGLE
	_cloth.transform = Transform3D(Basis(Vector3.RIGHT, _angle), Vector3.ZERO)


func _invalidate() -> void:
	_invalid = true
	set_process(false)


func _exit_tree() -> void:
	_invalidate()
