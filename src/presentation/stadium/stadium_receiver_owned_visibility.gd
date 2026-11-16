class_name StadiumReceiverOwnedVisibility
extends RefCounted
## Exact owned catchers only. No camera, collider, receiver, call or scoring writes.

const SKIN: float = 0.015
var _lab: WeakRef
var _property: WeakRef
var _camera: WeakRef
var _director: WeakRef
var _tracking: WeakRef
var _authority: Callable
var _context_pin: Dictionary = {}
var _models: Array[Node3D] = []
var _roots: Array[Dictionary] = []
var _nodes: Array[Dictionary] = []
var _members: Array[Dictionary] = []
var _materials: Array[Dictionary] = []
var _geometry_connections: Array[Dictionary] = []
var _changed_geometry: Dictionary = {}
var _active: bool = false
var _installed: bool = false
var _last_position: Vector3
var _last_radius: float = 0.0
var _protected: bool = true


func install(
	lab: PitchBatLab, property: StadiumPropertyGeometry, models: Array[Node3D], authority: Callable
) -> bool:
	if (
		_installed
		or not is_instance_valid(lab)
		or not is_instance_valid(property)
		or not is_instance_valid(lab._camera)
		or lab._camera_director == null
		or not authority.is_valid()
		or not bool(authority.call())
		or models.is_empty()
	):
		return false
	_installed = true
	_lab = weakref(lab)
	_property = weakref(property)
	_camera = weakref(lab._camera)
	_director = weakref(lab._camera_director)
	_tracking = weakref(lab._camera_director.tracking_visibility)
	_authority = authority
	_context_pin = {
		"lab_script": lab.get_script(),
		"property_script": property.get_script(),
		"property_parent": property.get_parent(),
		"camera_parent": lab._camera.get_parent(),
		"camera_script": lab._camera.get_script(),
		"director_script": lab._camera_director.get_script(),
		"tracking_script": lab._camera_director.tracking_visibility.get_script(),
		"override": lab._camera_director.presentation_override,
		"coverage": lab._camera_director._live_coverage,
		"coverage_script": lab._camera_director._live_coverage.get_script()
	}
	_models.assign(models)
	for model: Node3D in _models:
		if (
			not is_instance_valid(model)
			or model.get_parent() != property
			or property.objects.get(model.get_meta("owned_copy", "")) != model
			or model.get_meta("stadium_item", "") not in ["ST-072", "ST-073"]
		):
			return false
		var visual: Node3D = model.get_node_or_null("Visual") as Node3D
		if visual == null:
			return false
		_roots.append(
			{
				"model": model,
				"visual": visual,
				"copy": model.get_meta("owned_copy"),
				"pose": model.transform,
				"visible": visual.visible,
				"expected_visible": visual.visible,
				"had_state": model.has_meta("receiver_render_state"),
				"state": model.get_meta("receiver_render_state", ""),
				"expected_state": model.get_meta("receiver_render_state", "")
			}
		)
		if not _capture(visual, model):
			return false
	var tracking: BallTrackingVisibility = _tracking.get_ref() as BallTrackingVisibility
	if not tracking.bind_owned_receivers(_models, excludes):
		return false
	_active = true
	# All state is applied synchronously before installation can reach first render.
	for member: Dictionary in _members:
		member.node.material_override = member.material.owned
	_last_position = lab._camera.global_position
	_last_radius = near_enclosure(lab._camera)
	return refresh()


func _capture(node: Node, model: Node3D) -> bool:
	var pin: Dictionary = {
		"node": node,
		"parent": node.get_parent(),
		"children": node.get_children(),
		"name": node.name,
		"script": node.get_script(),
		"copy": node.get_meta("owned_copy", ""),
		"site": node.get_meta("site", ""),
		"item": node.get_meta("stadium_item", "")
	}
	if node is Node3D:
		pin.pose = node.transform
		pin.top_level = node.top_level
		pin.visible = node.visible
	_nodes.append(pin)
	if node is GeometryInstance3D:
		if (
			not (node is MeshInstance3D or node is MultiMeshInstance3D)
			or not node.material_override is StandardMaterial3D
		):
			return false
		var original: StandardMaterial3D = node.material_override
		var material: Dictionary = {}
		for saved: Dictionary in _materials:
			if saved.original == original:
				material = saved
				break
		if material.is_empty():
			var owned: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
			material = {
				"original": original,
				"owned": owned,
				"baseline": _material_state(original),
				"expected": _material_state(owned)
			}
			_materials.append(material)
		var row: Dictionary = {
			"node": node,
			"model": model,
			"material": material,
			"overlay": node.material_overlay,
			"render": _render_state(node),
			"expected_material": material.owned,
			"shadow": node.cast_shadow,
			"expected_shadow": node.cast_shadow,
			"visible": node.visible
		}
		_capture_geometry(row)
		_members.append(row)
	for child: Node in node.get_children():
		if not _capture(child, model):
			return false
	return true


static func _render_state(node: GeometryInstance3D) -> Dictionary:
	var result: Dictionary = {}
	for key: String in [
		"layers",
		"transparency",
		"extra_cull_margin",
		"visibility_range_begin",
		"visibility_range_end",
		"visibility_range_begin_margin",
		"visibility_range_end_margin",
		"visibility_range_fade_mode",
		"ignore_occlusion_culling",
		"gi_mode"
	]:
		result[key] = node.get(key)
	return result


func _capture_geometry(row: Dictionary) -> void:
	var member: GeometryInstance3D = row.node
	if member is MeshInstance3D:
		row.mesh = member.mesh
		row.surfaces = []
		for index in range(member.get_surface_override_material_count()):
			row.surfaces.append(member.get_surface_override_material(index))
		_watch(member.mesh)
	elif member is MultiMeshInstance3D:
		row.multi = member.multimesh
		row.multi_state = _multi_state(member.multimesh)
		row.mesh = member.multimesh.mesh if member.multimesh != null else null
		_watch(member.multimesh)
		_watch(row.mesh)


static func _multi_state(multi: MultiMesh) -> Array:
	if multi == null:
		return []
	return [
		multi.transform_format,
		multi.use_colors,
		multi.use_custom_data,
		multi.instance_count,
		multi.visible_instance_count,
		multi.buffer,
		multi.custom_aabb
	]


func _watch(resource: Resource) -> void:
	if resource == null:
		return
	for connection: Dictionary in _geometry_connections:
		if connection.resource == resource:
			return
	var callback: Callable = _geometry_changed.bind(resource)
	resource.changed.connect(callback)
	_geometry_connections.append({"resource": resource, "callback": callback})


func _geometry_changed(resource: Resource) -> void:
	_changed_geometry[resource] = true


static func _material_state(material: StandardMaterial3D) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in material.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			result[property.name] = material.get(property.name)
	return result


func _context_intact() -> bool:
	if (
		not _active
		or _lab == null
		or _property == null
		or _camera == null
		or _director == null
		or _tracking == null
		or not _authority.is_valid()
	):
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	var property: StadiumPropertyGeometry = _property.get_ref() as StadiumPropertyGeometry
	var tracking: BallTrackingVisibility = _tracking.get_ref() as BallTrackingVisibility
	if (
		lab == null
		or property == null
		or tracking == null
		or not lab.has_meta("stadium_property")
		or lab.get_meta("stadium_property") != property
		or lab._camera != _camera.get_ref()
		or lab._camera_director != _director.get_ref()
		or lab._camera_director.tracking_visibility != tracking
		or lab.get_script() != _context_pin.lab_script
		or property.get_script() != _context_pin.property_script
		or property.get_parent() != _context_pin.property_parent
		or lab._camera.get_parent() != _context_pin.camera_parent
		or lab._camera.get_script() != _context_pin.camera_script
		or lab._camera_director.get_script() != _context_pin.director_script
		or tracking.get_script() != _context_pin.tracking_script
		or lab._camera_director.presentation_override != _context_pin.override
		or lab._camera_director._live_coverage != _context_pin.coverage
		or lab._camera_director._live_coverage.get_script() != _context_pin.coverage_script
		or not tracking.owns_receiver_scope(_models, excludes)
		or not bool(_authority.call())
	):
		return false
	for root: Dictionary in _roots:
		if (
			not is_instance_valid(root.model)
			or root.model.get_parent() != property
			or property.objects.get(root.copy) != root.model
			or root.model.transform != root.pose
			or root.model.get_node_or_null("Visual") != root.visual
		):
			return false
	return true


func intact() -> bool:
	return _context_intact() and _pins_intact()


func _pins_intact(ignore_geometry: Array = []) -> bool:
	for root: Dictionary in _roots:
		if (
			not is_instance_valid(root.visual)
			or root.visual.visible != root.expected_visible
			or root.model.get_meta("receiver_render_state", "") != root.expected_state
		):
			return false
	for pin: Dictionary in _nodes:
		var node: Node = pin.node
		if (
			not is_instance_valid(node)
			or node.get_parent() != pin.parent
			or node.get_children() != pin.children
			or node.name != pin.name
			or node.get_script() != pin.script
			or node.get_meta("owned_copy", "") != pin.copy
			or node.get_meta("site", "") != pin.site
			or node.get_meta("stadium_item", "") != pin.item
		):
			return false
		if node is Node3D and (node.transform != pin.pose or node.top_level != pin.top_level):
			return false
		if node is Node3D and node.name != &"Visual" and node.visible != pin.visible:
			return false
	for material: Dictionary in _materials:
		if _material_state(material.owned) != material.expected:
			return false
	return _pins_intact_remaining_checks(ignore_geometry)


func _pins_intact_remaining_checks(ignore_geometry: Array) -> bool:
	for row: Dictionary in _members:
		var member: GeometryInstance3D = row.node
		if (
			member.material_override != row.expected_material
			or member.material_overlay != row.overlay
			or member.cast_shadow != row.expected_shadow
			or member.visible != row.visible
			or _render_state(member) != row.render
		):
			return false
		if ignore_geometry.has(member):
			continue
		if member is MeshInstance3D:
			if (
				member.mesh != row.mesh
				or member.get_surface_override_material_count() != row.surfaces.size()
			):
				return false
			for index in range(row.surfaces.size()):
				if member.get_surface_override_material(index) != row.surfaces[index]:
					return false
		elif member is MultiMeshInstance3D:
			if (
				member.multimesh != row.multi
				or member.multimesh == null
				or member.multimesh.mesh != row.mesh
				or _multi_state(member.multimesh) != row.multi_state
			):
				return false
		if (
			_changed_geometry.has(row.mesh)
			or (row.has("multi") and _changed_geometry.has(row.multi))
		):
			return false
	return true


func refresh(_force_visible: bool = false) -> bool:
	if not intact():
		_abandon()
		return false
	var lab: PitchBatLab = _lab.get_ref() as PitchBatLab
	var camera: Camera3D = _camera.get_ref() as Camera3D
	var director: MatchCameraDirector = _director.get_ref() as MatchCameraDirector
	var current: Vector3 = camera.global_position
	var radius: float = near_enclosure(camera)
	var ball: Node3D = lab._batted_ball
	var live: bool = is_instance_valid(ball)
	var desired: Vector3 = current
	# Live BallInPlayCamera follows an acceleration-bounded path, not the static
	# inspection target. Its actual completed sweep is checked below instead.
	if director.shot != MatchCameraDirector.Shot.BALL_IN_PLAY or not live:
		desired = (
			director._desired_transform(ball.global_position if live else Vector3.ZERO, 0.0).origin
		)
	var actionable: bool = (
		director.shot == MatchCameraDirector.Shot.BATTING and director._shot_before_inspection < 0
	)
	_protected = (
		actionable
		or _swept_members(_last_position, current, maxf(radius, _last_radius) + SKIN)
		or _swept_members(current, desired, radius + SKIN)
	)
	for root: Dictionary in _roots:
		var faded: bool = (
			not _protected
			and live
			and _view_crosses(root.model, camera.global_position, ball.global_position)
		)
		if not _style(root, _protected, faded):
			_abandon()
			return false
	_last_position = current
	_last_radius = radius
	return intact()


func excludes(model: Node3D) -> bool:
	if not _models.has(model) or not _protected:
		return false
	if not intact():
		_abandon()
		return false
	return true


static func near_enclosure(camera: Camera3D) -> float:
	var size: Vector2 = camera.get_viewport().get_visible_rect().size
	var radius: float = camera.near * 2.0
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		radius = maxf(
			radius, camera.global_position.distance_to(camera.project_position(corner, camera.near))
		)
	return radius


func _swept_members(from: Vector3, to: Vector3, radius: float) -> bool:
	for row: Dictionary in _members:
		for part: Dictionary in _parts(row.node):
			var inverse: Transform3D = part.pose.affine_inverse()
			# Owned models have rigid poses. Local testing keeps empty cup corners empty.
			var axes: Basis = inverse.basis
			var padding: Vector3 = (
				Vector3(
					Vector3(axes.x.x, axes.y.x, axes.z.x).length(),
					Vector3(axes.x.y, axes.y.y, axes.z.y).length(),
					Vector3(axes.x.z, axes.y.z, axes.z.z).length()
				)
				* radius
			)
			var bounds: AABB = AABB(
				part.bounds.position - padding, part.bounds.size + padding * 2.0
			)
			if (
				bounds.has_point(inverse * from)
				or bounds.has_point(inverse * to)
				or bounds.intersects_segment(inverse * from, inverse * to) != null
			):
				return true
	return false


func _view_crosses(model: Node3D, from: Vector3, to: Vector3) -> bool:
	for row: Dictionary in _members:
		if row.model != model:
			continue
		for part: Dictionary in _parts(row.node):
			var inverse: Transform3D = part.pose.affine_inverse()
			if part.bounds.intersects_segment(inverse * from, inverse * to) != null:
				return true
	return false


static func _parts(member: GeometryInstance3D) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if member is MeshInstance3D and member.mesh != null:
		parts.append({"pose": member.global_transform, "bounds": member.get_aabb()})
	elif (
		member is MultiMeshInstance3D and member.multimesh != null and member.multimesh.mesh != null
	):
		var multi: MultiMesh = member.multimesh
		var count: int = (
			multi.instance_count
			if multi.visible_instance_count < 0
			else mini(multi.instance_count, multi.visible_instance_count)
		)
		for index in range(count):
			parts.append(
				{
					"pose": member.global_transform * multi.get_instance_transform(index),
					"bounds": multi.mesh.get_aabb()
				}
			)
	return parts


func _style(root: Dictionary, hidden: bool, faded: bool) -> bool:
	var state: String = "hidden" if hidden else "faded" if faded else "visible"
	if root.expected_state == state:
		return true
	var alpha: float = StadiumReceiverVisibility.FADED_ALPHA if faded else 1.0
	for row: Dictionary in _members:
		if row.model != root.model:
			continue
		var saved: Dictionary = row.material
		var color: Color = saved.baseline.albedo_color
		color.a *= alpha
		var transparency: int = (
			BaseMaterial3D.TRANSPARENCY_ALPHA if faded else int(saved.baseline.transparency)
		)
		saved.expected.albedo_color = color
		saved.owned.albedo_color = color
		if not intact():
			return false
		saved.expected.transparency = transparency
		saved.owned.transparency = transparency
		if not intact():
			return false
		row.expected_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hidden or faded else row.shadow
		)
		row.node.cast_shadow = row.expected_shadow
		if not intact():
			return false
	root.expected_visible = root.visible and not hidden
	root.visual.visible = root.expected_visible
	if not intact():
		return false
	root.expected_state = state
	root.model.set_meta("receiver_render_state", state)
	return intact()


func flex_owned(model: Node3D, surface: String, elapsed: float, point: Vector3) -> bool:
	if not intact() or not _models.has(model):
		_abandon()
		return false
	# The sole permitted geometry author is the owned factory, never a caller-supplied
	# callback or replacement resource. Every other style and structural pin survives.
	var affected: Array = []
	for row: Dictionary in _members:
		if row.model == model and str(row.node.name) == surface:
			affected.append(row.node)
	if affected.is_empty() or not StadiumReceiverOwnedModels.flex(model, surface, elapsed, point):
		return false
	if not _context_intact() or not _pins_intact(affected):
		_abandon()
		return false
	for row: Dictionary in _members:
		if affected.has(row.node):
			_changed_geometry.erase(row.mesh)
			if row.has("multi"):
				_changed_geometry.erase(row.multi)
			_capture_geometry(row)
	_prune_geometry_connections()
	return intact()


func _prune_geometry_connections() -> void:
	var used: Array = []
	for row: Dictionary in _members:
		used.append(row.mesh)
		if row.has("multi"):
			used.append(row.multi)
	for connection: Dictionary in _geometry_connections.duplicate():
		if not used.has(connection.resource):
			if connection.resource.changed.is_connected(connection.callback):
				connection.resource.changed.disconnect(connection.callback)
			_changed_geometry.erase(connection.resource)
			_geometry_connections.erase(connection)


func retire() -> void:
	# Every restore uses the same exact authority. A foreign replacement or a
	# synchronous changed callback stops cleanup before any later stale write.
	if not intact():
		_abandon()
		return
	for row: Dictionary in _members:
		row.expected_material = row.material.original
		row.node.material_override = row.expected_material
		if not intact():
			_abandon()
			return
		row.expected_shadow = row.shadow
		row.node.cast_shadow = row.expected_shadow
		if not intact():
			_abandon()
			return
	for root: Dictionary in _roots:
		root.expected_visible = root.visible
		root.visual.visible = root.expected_visible
		if not intact():
			_abandon()
			return
		root.expected_state = root.state
		if root.had_state:
			root.model.set_meta("receiver_render_state", root.state)
		else:
			root.model.remove_meta("receiver_render_state")
		if not intact():
			_abandon()
			return
	_abandon()


func _abandon() -> void:
	_active = false
	var tracking: BallTrackingVisibility = (
		_tracking.get_ref() as BallTrackingVisibility if _tracking != null else null
	)
	if tracking != null:
		tracking.clear_owned_receivers(excludes)
	for connection: Dictionary in _geometry_connections:
		if connection.resource.changed.is_connected(connection.callback):
			connection.resource.changed.disconnect(connection.callback)
	_geometry_connections.clear()
