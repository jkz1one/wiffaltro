class_name StadiumNpcAc02PublicGuides
extends RefCounted

const AC02_PASSIVE_4 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Captures five genuine current host guides at public installation, then checks concrete owners.
## Only visibility is changed. Resource edits permanently retire this lifetime; no per-frame
## profiles.
# gdlint: disable=max-returns

const NAMES: Array[String] = ["ZoneLeft", "ZoneRight", "ZoneBottom", "ZoneTop"]
var _lab_ref: WeakRef
var _property_ref: WeakRef
var _camera_ref: WeakRef
var _host_ref: WeakRef
var _director_ref: WeakRef
var _guides: Array[Dictionary] = []
var _retired: bool = false
var _suppressed: bool = false
var _issued_lifetime: bool = false


func configure(lab: PitchBatLab, property: StadiumNpcPublicProperty, camera: Camera3D) -> bool:
	var ac02_token: int = AC02_PASSIVE_4.enter("stadium_npc_ac02_public_guides.configure")
	var ac02_result: bool = _ac02_passive_04_configure(lab, property, camera)
	AC02_PASSIVE_4.leave(ac02_token)
	return ac02_result


func _ac02_passive_04_configure(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, camera: Camera3D
) -> bool:
	var previous: StadiumNpcPublicProperty = (
		_property_ref.get_ref() as StadiumNpcPublicProperty if _property_ref != null else null
	)
	if (
		not StadiumNpcAc02IssuedWritersV1.preissue_only(previous, "guides-reconfigure")
		or not StadiumNpcAc02IssuedWritersV1.preissue_only(property, "guides-owner-reconfigure")
	):
		return false
	return _configure_body(lab, property, camera)


func _configure_startup(attempt: RefCounted, property: StadiumNpcPublicProperty) -> bool:
	if attempt != property._ac02_startup_attempt or not attempt.owns(property):
		return false
	return _configure_body(attempt.lab, property, attempt.lab._camera)


func _configure_body(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, camera: Camera3D
) -> bool:
	if (
		_lab_ref != null
		or lab == null
		or property == null
		or camera == null
		or lab.get_script() != PitchBatLab
		or property.get_script() != StadiumNpcPublicProperty
		or property.venue_id != "AC-02"
		or not lab._camera_director is StadiumNpcAc02PublicCamera
		or lab._camera != camera
		or lab.get_node_or_null("LabCamera") != camera
	):
		return false
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or host.get_script() != StarterFieldLabGeometry
		or host.get_parent() != lab
		or property.get_parent() != host
		or host.get_node_or_null("HomeProperty") != property
		or host.transform != Transform3D.IDENTITY
	):
		return false
	var rows: Array[Dictionary] = []
	for name: String in NAMES:
		var mesh: MeshInstance3D = host.get_node_or_null(NodePath(name)) as MeshInstance3D
		var vertical: bool = name in ["ZoneLeft", "ZoneRight"]
		var expected: BoxMesh = BoxMesh.new()
		expected.size = (
			Vector3(0.034, lab.ZONE_MAX_Y - lab.ZONE_MIN_Y, 0.034)
			if vertical
			else (Vector3(lab.ZONE_MAX_X - lab.ZONE_MIN_X, 0.034, 0.034))
		)
		var position: Vector3 = (
			Vector3(
				lab.ZONE_MIN_X if name == "ZoneLeft" else lab.ZONE_MAX_X,
				(lab.ZONE_MIN_Y + lab.ZONE_MAX_Y) * 0.5,
				0
			)
			if vertical
			else (Vector3(0, lab.ZONE_MIN_Y if name == "ZoneBottom" else lab.ZONE_MAX_Y, 0))
		)
		var material: StandardMaterial3D = _material(Color(1, 0.95, 0.68))
		if (
			not _admit(mesh, host, expected, material, true)
			or mesh.transform != Transform3D(Basis.IDENTITY, position)
			or not mesh.visible
		):
			return false
		rows.append(_capture(mesh, true))
	var marker: MeshInstance3D = lab._pitch_target_marker
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	if (
		marker != host.pitch_target_marker
		or host.get_node_or_null("PitchTarget") != marker
		or not _admit(marker, host, sphere, _material(Color(1, 0.22, 0.18)), false)
		or (
			marker.transform
			!= Transform3D(Basis.IDENTITY, Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015))
		)
	):
		return false
	rows.append(_capture(marker, false))
	_lab_ref = weakref(lab)
	_property_ref = weakref(property)
	_camera_ref = weakref(camera)
	_host_ref = weakref(host)
	_director_ref = weakref(lab._camera_director)
	_guides = rows
	for index in range(_guides.size()):
		_guides[index].mesh.changed.connect(_resource_changed.bind(index, false))
		_guides[index].material.changed.connect(_resource_changed.bind(index, true))
	return owners_intact()


static func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.9
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return result


static func _admit(
	mesh: MeshInstance3D,
	host: Node,
	expected_mesh: Mesh,
	expected_material: StandardMaterial3D,
	bar: bool
) -> bool:
	if (
		not is_instance_valid(mesh)
		or mesh.get_parent() != host
		or mesh.get_script() != null
		or mesh.get_child_count() != 0
		or not mesh.material_override is StandardMaterial3D
		or mesh.mesh == null
	):
		return false
	var expected_node: MeshInstance3D = MeshInstance3D.new()
	expected_node.mesh = expected_mesh
	var render: Dictionary = _render(expected_node)
	expected_node.free()
	return (
		var_to_bytes(_profile(mesh.mesh)) == var_to_bytes(_profile(expected_mesh))
		and (
			var_to_bytes(_material_profile(mesh.material_override, bar))
			== var_to_bytes(_material_profile(expected_material, bar))
		)
		and var_to_bytes(_render(mesh)) == var_to_bytes(render)
	)


static func _capture(mesh: MeshInstance3D, bar: bool) -> Dictionary:
	return {
		"node": weakref(mesh),
		"name": mesh.name,
		"mesh": mesh.mesh,
		"material": mesh.material_override,
		"pose": mesh.transform,
		"visible": mesh.visible,
		"bar": bar,
		"mesh_profile": _profile(mesh.mesh),
		"material_profile": _material_profile(mesh.material_override, bar)
	}


func mark_issued() -> void:
	var property: StadiumNpcPublicProperty = (
		_property_ref.get_ref() as StadiumNpcPublicProperty if _property_ref != null else null
	)
	if is_instance_valid(property) and property.has_ac02_issue():
		_issued_lifetime = true


func owners_intact() -> bool:
	var ac02_token: int = AC02_PASSIVE_4.enter("stadium_npc_ac02_public_guides.owners_intact")
	var ac02_result: bool = _ac02_passive_04_owners_intact()
	AC02_PASSIVE_4.leave(ac02_token)
	return ac02_result


func _ac02_passive_04_owners_intact() -> bool:
	mark_issued()
	var lab: PitchBatLab = _lab_ref.get_ref() as PitchBatLab if _lab_ref != null else null
	var host: StarterFieldLabGeometry = (
		_host_ref.get_ref() as StarterFieldLabGeometry if _host_ref != null else null
	)
	var property: StadiumNpcPublicProperty = (
		_property_ref.get_ref() as StadiumNpcPublicProperty if _property_ref != null else null
	)
	if (
		_retired
		or lab == null
		or host == null
		or property == null
		or _guides.size() != 5
		or lab.get_node_or_null("StarterFieldGeometry") != host
		or host.get_parent() != lab
		or host.get_script() != StarterFieldLabGeometry
		or host.transform != Transform3D.IDENTITY
		or host.get_node_or_null("HomeProperty") != property
		or property.get_parent() != host
		or lab._camera != _camera_ref.get_ref()
		or lab._camera_director != _director_ref.get_ref()
	):
		return false
	for row: Dictionary in _guides:
		var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		if (
			not is_instance_valid(mesh)
			or mesh.get_parent() != host
			or host.get_node_or_null(NodePath(row.name)) != mesh
			or mesh.get_script() != null
			or mesh.get_child_count() != 0
			or mesh.mesh != row.mesh
			or mesh.material_override != row.material
			or mesh.material_overlay != null
			or mesh.top_level
			or not mesh.visibility_parent.is_empty()
			or mesh.transparency != 0
			or mesh.layers != 1
		):
			return false
		if row.bar and mesh.transform != row.pose:
			return false
		if (
			not row.bar
			and (
				lab._pitch_target_marker != mesh
				or host.pitch_target_marker != mesh
				or (
					mesh.transform
					!= Transform3D(
						Basis.IDENTITY, Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015)
					)
				)
			)
		):
			return false
	return true


func _resource_changed(index: int, material: bool) -> void:
	if _retired or index < 0 or index >= _guides.size():
		return
	var row: Dictionary = _guides[index]
	var actual: Dictionary = (
		_material_profile(row.material, row.bar) if material else (_profile(row.mesh))
	)
	var expected: Dictionary = row.material_profile if material else row.mesh_profile
	if var_to_bytes(actual) != var_to_bytes(expected):
		var property: StadiumNpcPublicProperty = (
			_property_ref.get_ref() as StadiumNpcPublicProperty if _property_ref != null else null
		)
		# Invalidate the issue before restoration can synchronously invoke another callback.
		if (
			is_instance_valid(property)
			and (
				property.ac02_startup_pending()
				or property.has_ac02_issue()
				or property._ac02_preparing
			)
		):
			property.ac02_revoke("guide-resource-retired")
		_retired = true
		restore_all()


func refresh() -> void:
	var ac02_token: int = AC02_PASSIVE_4.enter("stadium_npc_ac02_public_guides.refresh")
	_ac02_passive_04_refresh()
	AC02_PASSIVE_4.leave(ac02_token)


func _ac02_passive_04_refresh() -> void:
	var lab: PitchBatLab = _lab_ref.get_ref() as PitchBatLab if _lab_ref != null else null
	var director: StadiumNpcAc02PublicCamera = (
		_director_ref.get_ref() as StadiumNpcAc02PublicCamera if _director_ref != null else null
	)
	if not owners_intact() or director == null or not director._step_live(lab._camera, true):
		restore_all()
		return
	if not _suppressed:
		for row: Dictionary in _guides:
			var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
			if row.bar and not mesh.visible:
				return
	# New-lifetime writes recheck the captured issuer after every visibility callback.
	# The historical loop below remains unchanged.
	if _issued_lifetime:
		var property: StadiumNpcPublicProperty = _property_ref.get_ref() as StadiumNpcPublicProperty
		var issuer: StadiumNpcAc02IssuedStateV1 = (
			property._ac02_issue if is_instance_valid(property) else null
		)
		for row: Dictionary in _guides:
			if issuer == null or not issuer.continue_action(lab):
				if is_instance_valid(property):
					property.ac02_revoke("guide-hide-owner-replaced")
				cleanup_local()
				return
			var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
			mesh.visible = false
		_suppressed = true
		return
	for row: Dictionary in _guides:
		var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		mesh.visible = false
	_suppressed = true


func restore_all() -> void:
	if not _suppressed:
		return
	var property: StadiumNpcPublicProperty = (
		_property_ref.get_ref() as StadiumNpcPublicProperty if _property_ref != null else null
	)
	mark_issued()
	var issued: bool = _issued_lifetime
	if issued and (not is_instance_valid(property) or not property.ac02_owns_cleanup()):
		if is_instance_valid(property):
			property.ac02_revoke("guide-restore-owner-replaced")
		cleanup_local()
		return
	var lab: PitchBatLab = _lab_ref.get_ref() as PitchBatLab if _lab_ref != null else null
	var host: Node = _host_ref.get_ref() as Node if _host_ref != null else null
	for row: Dictionary in _guides:
		# A preceding visibility signal may have replaced an owner synchronously.
		if issued and (not is_instance_valid(property) or not property.ac02_owns_cleanup()):
			if is_instance_valid(property):
				property.ac02_revoke("guide-restore-owner-replaced")
			cleanup_local()
			return
		var mesh: MeshInstance3D = row.node.get_ref() as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		# A shared host may now belong to another installation. Never restore its substitutes.
		if (
			issued
			and (
				not is_instance_valid(host)
				or mesh.get_parent() != host
				or host.get_node_or_null(NodePath(row.name)) != mesh
				or mesh.mesh != row.mesh
				or mesh.material_override != row.material
			)
		):
			continue
		mesh.visible = (
			row.visible
			if row.bar or lab == null
			else (true if not lab._match_mode else lab._player_is_pitching())
		)
	_suppressed = false


func cleanup_local() -> void:
	# Only callbacks owned by this exact guide object may be disconnected.
	# Do not restore visibility, material or resources borrowed by a replacement owner.
	_retired = true
	_suppressed = false
	for index in range(_guides.size()):
		var row: Dictionary = _guides[index]
		for material: bool in [false, true]:
			var resource: Resource = row.material if material else row.mesh
			var callback: Callable = _resource_changed.bind(index, material)
			if is_instance_valid(resource) and resource.changed.is_connected(callback):
				resource.changed.disconnect(callback)


static func _profile(resource: Resource) -> Dictionary:
	var result: Dictionary = {}
	for entry: Dictionary in resource.get_property_list():
		if int(entry.usage) & PROPERTY_USAGE_STORAGE:
			result[entry.name] = resource.get(entry.name)
	return result.duplicate(true)


static func _material_profile(material: StandardMaterial3D, bar: bool) -> Dictionary:
	var result: Dictionary = _profile(material)
	if bar:
		# The existing role presenter changes these two scalars, including during role transitions.
		var color: Color = result.albedo_color
		if (
			color.a not in [Color(0, 0, 0, 0.35).a, 1.0]
			or (
				result.transparency
				not in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_DISABLED]
			)
		):
			result["invalid_role_style"] = true
		color.a = 1
		result.albedo_color = color
		result.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return result


static func _render(mesh: MeshInstance3D) -> Dictionary:
	var result: Dictionary = {"surface_override": mesh.get_surface_override_material(0)}
	for key: String in [
		"layers",
		"transparency",
		"cast_shadow",
		"material_overlay",
		"gi_mode",
		"ignore_occlusion_culling",
		"visibility_range_begin",
		"visibility_range_end",
		"visibility_range_begin_margin",
		"visibility_range_end_margin",
		"visibility_range_fade_mode",
		"lod_bias",
		"extra_cull_margin",
		"custom_aabb",
		"sorting_offset",
		"sorting_use_aabb_center",
		"top_level",
		"visibility_parent"
	]:
		result[key] = mesh.get(key)
	return result
