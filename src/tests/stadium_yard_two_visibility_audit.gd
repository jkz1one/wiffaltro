extends RefCounted
## Independent rendered-triangle evidence for AY02. Runtime obstacle lists never decide a hit.
## A caller-owned cache pins authentic nodes/resources; labels never confer an exemption.
# gdlint: disable=max-returns

const ShellControls = preload("res://src/tests/stadium_yard_two_shell_controls.gd")
const Shell = preload("res://src/tests/stadium_yard_two_shell_geometry.gd")
const Actors = preload("res://src/tests/stadium_grand_iii_actor_proof.gd")
const Mechanics = preload("res://src/tests/stadium_npc_retained_daylight_support.gd")
const CACHE_KEY: String = "ay02_rendered_identity_v1"
const ZONES: Array[String] = ["ZoneLeft", "ZoneRight", "ZoneBottom", "ZoneTop"]
const DEPTH_EPSILON: float = 0.000001


static func audit(lab: PitchBatLab, cache: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"meshes": 0,
		"visible": 0,
		"triangle_hits": 0,
		"blocked": 0,
		"guide_hits": 0,
		"target_front_hits": 0,
		"marking_front_hits": 0,
		"receiver_fade_hits": 0,
		"actor_fade_hits": 0,
		"self_hits": 0,
		"invalid": 0,
		"hits": []
	}
	if not is_instance_valid(lab._camera) or not is_instance_valid(lab._batted_ball):
		result.invalid = 1
		return result
	if not cache.has(CACHE_KEY):
		cache[CACHE_KEY] = _bind(lab)
	var bound: Dictionary = cache[CACHE_KEY]
	if bound.lab != lab or bound.ball != lab._batted_ball or bound.camera != lab._camera:
		result.invalid = 1
		return result
	# Validate pinned self content before broad-phase AABB culling can hide tampering.
	if bound.ball_meshes.size() != 1:
		result.invalid += 1
	for self_row: Dictionary in bound.ball_meshes.values():
		if not is_instance_valid(self_row.mesh) or not _self_intact(lab, self_row.mesh, self_row):
			result.invalid += 1
	var from: Vector3 = lab._camera.global_position
	var to: Vector3 = lab._batted_ball.global_position
	var radius: float = lab._batted_ball.radius_m
	var distance: float = from.distance_to(to)
	if not is_finite(radius) or radius <= 0 or not from.is_finite() or not to.is_finite():
		result.invalid = 1
		return result
	var front: float = maxf(0.0, distance - radius)
	for mesh: MeshInstance3D in lab.find_children("*", "MeshInstance3D", true, false):
		result.meshes += 1
		if (
			mesh.mesh == null
			or not mesh.is_visible_in_tree()
			or (mesh.layers & lab._camera.cull_mask) == 0
		):
			continue
		result.visible += 1
		for hit: Dictionary in _intersections(mesh, from, to, cache):
			var classified: Dictionary = _classify(lab, bound, mesh, hit.distance, front)
			var category: String = classified.classification
			result.triangle_hits += 1
			result[category] += 1
			hit.merge(
				{
					"mesh": mesh.get_instance_id(),
					"path": String(lab.get_path_to(mesh)),
					"classification": category,
					"reason": classified.reason,
					"ball_center_distance": distance,
					"ball_front_distance": front,
					"physical_radius": radius,
					"behind_ball_front": hit.distance + DEPTH_EPSILON >= front,
					"depth_epsilon": DEPTH_EPSILON,
					"source": classified.get("source", "")
				}
			)
			result.hits.append(hit)
	return result


static func _intersections(
	mesh: MeshInstance3D, from: Vector3, to: Vector3, cache: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if from.is_equal_approx(to) or is_zero_approx(mesh.global_basis.determinant()):
		return result
	var inverse: Transform3D = mesh.global_transform.affine_inverse()
	var start: Vector3 = inverse * from
	var end: Vector3 = inverse * to
	var box: AABB = mesh.get_aabb()
	if not box.has_point(start) and not box.has_point(end):
		if box.intersects_segment(start, end) == null:
			return result
	# Read current faces before consulting the cache, including in-place resource mutations.
	# This oracle must not inherit the runtime helper's immutable-mesh assumption.
	var faces: PackedVector3Array = mesh.mesh.get_faces()
	var id: int = mesh.mesh.get_instance_id()
	if not cache.has(id) or cache[id] != faces:
		cache[id] = faces
	faces = cache[id]
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	var scale_factor: float = 1.0 / radius if radius > 0.0 and radius < 1.0 else 1.0
	var normalized_start: Vector3 = (start - center) * scale_factor
	var normalized_end: Vector3 = (end - center) * scale_factor
	for index in range(0, faces.size() - 2, 3):
		var point: Variant = Geometry3D.segment_intersects_triangle(
			normalized_start,
			normalized_end,
			(faces[index] - center) * scale_factor,
			(faces[index + 1] - center) * scale_factor,
			(faces[index + 2] - center) * scale_factor
		)
		if point == null:
			continue
		var world: Vector3 = mesh.global_transform * ((point as Vector3) / scale_factor + center)
		result.append(
			{"face_index": index / 3, "position": world, "distance": from.distance_to(world)}
		)
	return result


static func _classify(
	lab: PitchBatLab, bound: Dictionary, mesh: MeshInstance3D, distance: float, front: float
) -> Dictionary:
	var id: int = mesh.get_instance_id()
	if bound.ball_meshes.has(id) and _self_intact(lab, mesh, bound.ball_meshes[id]):
		return _reason(
			"self_hits",
			(
				"authentic unchanged authored ball shell"
				if mesh is WiffleBallVisual
				else "authentic unchanged legacy ball sphere"
			),
			"BattedBallBody"
		)
	if bound.guides.has(id) and _guide_intact(lab, mesh, bound.guides[id]):
		return _reason(
			"guide_hits",
			"exact source translucent guide and pinned node/mesh/material",
			"StarterFieldLabGeometry"
		)
	if bound.markings.has(id) and _marking_intact(lab, mesh, bound.markings[id]):
		if distance + DEPTH_EPSILON >= front and _physical_sphere_intact(lab._batted_ball):
			return _reason(
				"marking_front_hits",
				"exact opaque baseline scoring guide lies behind physical ball front",
				"StadiumPropertyGeometry.build"
			)
		return _reason("blocked", "exact baseline scoring guide is before physical ball front")
	if bound.target.has(id) and _target_intact(lab, mesh, bound.target[id]):
		# Only this authenticated marker is depth-qualified. No scenery/contact/wall exception.
		if distance + DEPTH_EPSILON >= front and _physical_sphere_intact(lab._batted_ball):
			return _reason(
				"target_front_hits",
				"authentic pitch target triangle behind physical ball front",
				"StarterFieldLabGeometry._build_aim_markers"
			)
		return _reason("blocked", "authentic pitch target lies before physical ball front")
	if bound.receiver.has(id) and _receiver_faded(lab, bound, mesh, bound.receiver[id]):
		return _reason(
			"receiver_fade_hits",
			"bound genuine chair with exact source 0.20 alpha fade",
			"StadiumReceiverVisibility"
		)
	if bound.actors.has(id) and _actor_faded(lab, mesh, bound.actors[id]):
		return _reason(
			"actor_fade_hits",
			"retained genuine actor with actual registered 0.20 fade resource",
			"StadiumNpcRetainedActorCutaway"
		)
	return _reason("blocked", "visible triangle without a verified narrow presentation exception")


static func _reason(kind: String, reason: String, source: String = "") -> Dictionary:
	return {"classification": kind, "reason": reason, "source": source}


static func _bind(lab: PitchBatLab) -> Dictionary:
	var bound: Dictionary = {
		"lab": lab,
		"ball": lab._batted_ball,
		"camera": lab._camera,
		"guides": {},
		"target": {},
		"markings": {},
		"receiver": {},
		"actors": {},
		"ball_meshes": {}
	}
	_bind_guides(lab, bound)
	_bind_markings(lab, bound)
	_bind_self(lab, bound)
	_bind_receiver(lab, bound)
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property", null)
	var study: StadiumNpcRetainedActorCutaway = property.actor_cutaway if property != null else null
	for role: String in Actors.actors(lab):
		var actor: Node3D = Actors.actors(lab)[role]
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh != null:
				var original: Material = mesh.material_override
				if study != null and study.entries.has(mesh.get_instance_id()):
					original = study.entries[mesh.get_instance_id()].original_material
				bound.actors[mesh.get_instance_id()] = {
					"actor": actor,
					"role": role,
					"mesh": mesh,
					"source_mesh": mesh.mesh,
					"parent": mesh.get_parent(),
					"faces": mesh.mesh.get_faces(),
					"original_material": original,
					"original_signature": _material_signature(original)
				}
	return bound


static func _bind_guides(lab: PitchBatLab, bound: Dictionary) -> void:
	var host: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if (
		host == null
		or (
			host.get_script()
			!= preload("res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd")
		)
	):
		return
	# Build detached reference geometry using the unchanged baseline source and actual profiles.
	# Reference nodes are never added to the lab or counted as scene geometry.
	var reference: StarterFieldLabGeometry = StarterFieldLabGeometry.new()
	reference._build_strike_zone(lab.ZONE_MIN_X, lab.ZONE_MAX_X, lab.ZONE_MIN_Y, lab.ZONE_MAX_Y)
	var contact: SwingProfileDefinition = ContentDB.get_swing(lab.CONTACT_SWING_ID)
	var power: SwingProfileDefinition = ContentDB.get_swing(lab.POWER_SWING_ID)
	reference._build_aim_markers(
		Vector2(contact.contact_radius_x_m, contact.contact_radius_y_m) * 2.0,
		Vector2(power.contact_radius_x_m, power.contact_radius_y_m) * 2.0
	)
	for label: String in ZONES:
		var actual: MeshInstance3D = host.get_node_or_null(NodePath(label))
		var source: MeshInstance3D = reference.get_node(NodePath(label))
		var row: Dictionary = _source_binding(actual, source, [0.35])
		if not row.is_empty() and actual.transform == source.transform:
			row["host"] = host
			row["kind"] = "zone"
			bound.guides[actual.get_instance_id()] = row
	if (
		host.batting_aim_marker == lab._batting_aim_marker
		and host.get_node_or_null("BattingAim") == lab._batting_aim_marker
	):
		for label: String in ["ContactCoverage", "PowerCoverage"]:
			var actual: Node3D = lab._batting_aim_marker.get_node_or_null(NodePath(label))
			var source: Node3D = reference.batting_aim_marker.get_node(NodePath(label))
			if actual == null or actual.get_child_count() != source.get_child_count():
				continue
			for index in range(source.get_child_count()):
				var source_mesh: MeshInstance3D = source.get_child(index)
				var actual_mesh: MeshInstance3D = actual.get_child(index) as MeshInstance3D
				var alpha: float = 0.82 if label == "ContactCoverage" else 0.92
				var row: Dictionary = _source_binding(
					actual_mesh, source_mesh, [alpha, alpha * 0.45]
				)
				if not row.is_empty() and actual_mesh.transform == source_mesh.transform:
					row.merge(
						{
							"host": host,
							"kind": "aim",
							"outline": actual,
							"aim": lab._batting_aim_marker,
							"outline_transform": source.transform
						}
					)
					bound.guides[actual_mesh.get_instance_id()] = row
	if (
		host.pitch_target_marker == lab._pitch_target_marker
		and host.get_node_or_null("PitchTarget") == lab._pitch_target_marker
	):
		var row: Dictionary = _source_binding(
			lab._pitch_target_marker, reference.pitch_target_marker
		)
		if not row.is_empty():
			row["host"] = host
			bound.target[lab._pitch_target_marker.get_instance_id()] = row
	reference.free()


static func _source_binding(
	mesh: MeshInstance3D, source: MeshInstance3D, alphas: Array = []
) -> Dictionary:
	if mesh == null or mesh.mesh == null or not mesh.material_override is StandardMaterial3D:
		return {}
	if (
		mesh.mesh.get_class() != source.mesh.get_class()
		or mesh.mesh.get_faces() != source.mesh.get_faces()
	):
		return {}
	var material: StandardMaterial3D = source.material_override.duplicate() as StandardMaterial3D
	var allowed: Array = []
	if alphas.is_empty():
		allowed.append(_material_signature(material))
	for alpha: float in alphas:
		material.albedo_color.a = alpha
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		allowed.append(_material_signature(material))
	return {
		"mesh": mesh,
		"source_mesh": mesh.mesh,
		"surface_count": source.mesh.get_surface_count(),
		"material": mesh.material_override,
		"parent": mesh.get_parent(),
		"transform": source.transform,
		"faces": source.mesh.get_faces(),
		"materials": allowed,
		"mesh_properties": _resource_signature(source.mesh),
		"layers": source.layers,
		"shadow": source.cast_shadow
	}


static func _resource_signature(resource: Resource) -> Array:
	var values: Array = []
	for property: Dictionary in resource.get_property_list():
		var key: String = property.name
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or key.begins_with("resource_"):
			continue
		values.append([key, resource.get(key)])
	return values.duplicate(true)


static func _material_signature(material: Material) -> Array:
	return _resource_signature(material) if material != null else []


static func _resource_intact(mesh: MeshInstance3D, row: Dictionary) -> bool:
	if (
		not is_instance_valid(mesh)
		or not is_instance_valid(mesh.mesh)
		or not is_instance_valid(row.get("mesh"))
	):
		return false
	return (
		mesh == row.mesh
		and mesh.get_parent() == row.parent
		and mesh.mesh == row.source_mesh
		and mesh.material_override == row.material
		and mesh.material_overlay == null
		and mesh.transparency == 0.0
		and mesh.layers == row.layers
		and mesh.mesh.get_surface_count() == row.surface_count
		and mesh.get_surface_override_material_count() <= 1
		and mesh.get_surface_override_material(0) == null
		and mesh.mesh.get_faces() == row.faces
		and _resource_signature(mesh.mesh) == row.mesh_properties
		and _material_signature(mesh.material_override) in row.materials
	)


static func _guide_intact(lab: PitchBatLab, mesh: MeshInstance3D, row: Dictionary) -> bool:
	if (
		row.host != lab.get_node_or_null("StarterFieldGeometry")
		or row.host.global_transform != Transform3D.IDENTITY
		or not _resource_intact(mesh, row)
		or mesh.transform != row.transform
		or mesh.cast_shadow != row.shadow
	):
		return false
	if row.kind == "zone":
		return (
			mesh.get_parent() == row.host and row.host.get_node_or_null(NodePath(mesh.name)) == mesh
		)
	var factor: float = 1.0
	if lab._match_mode and lab._match_state != null:
		factor = lerpf(0.82, 1.18, float(lab._match_state.batter().definition.contact) / 10.0)
	var expected: Transform3D = Transform3D(
		Basis.from_scale(Vector3(factor, factor, 1.0)),
		Vector3(lab._batting_aim.x, lab._batting_aim.y, -0.015)
	)
	return (
		row.aim == lab._batting_aim_marker
		and row.host.batting_aim_marker == row.aim
		and row.aim.get_parent() == row.host
		and row.outline.get_parent() == row.aim
		and row.outline.transform == row.outline_transform
		and row.aim.transform.is_equal_approx(expected)
	)


static func _target_intact(lab: PitchBatLab, mesh: MeshInstance3D, row: Dictionary) -> bool:
	return (
		row.host == lab.get_node_or_null("StarterFieldGeometry")
		and row.host.global_transform == Transform3D.IDENTITY
		and row.host.pitch_target_marker == mesh
		and lab._pitch_target_marker == mesh
		and row.host.get_node_or_null("PitchTarget") == mesh
		and _resource_intact(mesh, row)
		and mesh.cast_shadow == row.shadow
		and mesh.basis == Basis.IDENTITY
		and mesh.position == Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015)
	)


static func _bind_self(lab: PitchBatLab, bound: Dictionary) -> void:
	var authored: WiffleBallVisual = WiffleBallVisual.create(0.78)
	var source: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	source.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.98, 0.96, 0.84)
	material.roughness = 0.78
	source.material_override = material
	for child: Node in lab._batted_ball.get_children():
		if child is WiffleBallVisual:
			var geometry: Dictionary = Shell._supp_shell_geometry(child)
			print("AY02_SUPPLEMENTARY_SHELL_BIND ", JSON.stringify(geometry))
			if Shell._supp_current_shell(lab._batted_ball, child) and geometry.errors.is_empty():
				var row: Dictionary = _source_binding(child, authored)
				if not row.is_empty():
					bound.ball_meshes[child.get_instance_id()] = row
		elif child is MeshInstance3D and child.mesh is SphereMesh:
			var row: Dictionary = _source_binding(child, source)
			if not row.is_empty():
				bound.ball_meshes[child.get_instance_id()] = row
	authored.free()
	source.free()


static func _self_intact(lab: PitchBatLab, mesh: MeshInstance3D, row: Dictionary) -> bool:
	if not is_instance_valid(mesh) or not is_instance_valid(mesh.mesh):
		return false
	return (
		mesh.get_parent() == lab._batted_ball
		and _self_transform_intact(lab, mesh)
		and _resource_intact(mesh, row)
		and mesh.cast_shadow == row.shadow
		and _physical_sphere_intact(lab._batted_ball)
		and mesh.visible
		and (not mesh is WiffleBallVisual or Shell._supp_current_shell(lab._batted_ball, mesh))
	)


static func _self_transform_intact(lab: PitchBatLab, mesh: MeshInstance3D) -> bool:
	if mesh.transform == Transform3D.IDENTITY:
		return true
	var hr: PitchBatLabHomeRun = lab._home_run
	return (
		hr != null
		and hr.active
		and hr._ball_visual != null
		and hr._body != null
		and hr._ball_visual.get_ref() == mesh
		and hr._body.get_ref() == lab._batted_ball
		and hr._ball_visual_scale == Vector3.ONE
		and is_finite(hr._ball_scale_factor)
		and hr._ball_scale_factor >= 1.0
		and hr._ball_scale_factor <= 8.0
		and (
			mesh.transform
			== Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * hr._ball_scale_factor), Vector3.ZERO)
		)
	)


static func _physical_sphere_intact(ball: BattedBallBody) -> bool:
	if (
		not ball.global_basis.get_scale().is_equal_approx(Vector3.ONE)
		or not is_equal_approx(ball.radius_m, 0.0365)
	):
		return false
	var count: int = 0
	for child: Node in ball.get_children():
		if child is CollisionShape3D:
			if (
				not child.shape is SphereShape3D
				or child.disabled
				or child.transform != Transform3D.IDENTITY
				or not is_equal_approx(child.shape.radius, ball.radius_m)
			):
				return false
			count += 1
	return count == 1


static func _bind_receiver(lab: PitchBatLab, bound: Dictionary) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property", null)
	if property == null:
		return
	var receiver: StadiumYardTwoReceiver = property.get_node_or_null("PitchReceiverPresentation")
	if receiver == null or not receiver.bound() or receiver._actor != lab._pitch_actor:
		return
	bound["receiver_node"] = receiver
	bound["property"] = property
	var reference: Node3D = StadiumStarterModels.create("ST-079")
	for source: MeshInstance3D in reference.get_node("Visual").get_children():
		var mesh: MeshInstance3D = receiver.chair.get_node_or_null(reference.get_path_to(source))
		var row: Dictionary = _source_binding(mesh, source, [0.20])
		if not row.is_empty() and mesh.transform == source.transform:
			bound.receiver[mesh.get_instance_id()] = row
	reference.free()


static func _receiver_faded(
	lab: PitchBatLab, bound: Dictionary, mesh: MeshInstance3D, row: Dictionary
) -> bool:
	var receiver: StadiumYardTwoReceiver = bound.receiver_node
	return (
		is_instance_valid(receiver)
		and receiver.bound()
		and lab.get_meta("stadium_property", null) == bound.property
		and receiver._actor == lab._pitch_actor
		and receiver._actor.receiver_router == receiver.route
		and receiver.chair.get_node("Visual") == mesh.get_parent()
		and receiver.chair.get_meta("receiver_render_state", "") == "faded"
		and mesh.transform == row.transform
		and _resource_intact(mesh, row)
		and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


static func _actor_faded(lab: PitchBatLab, mesh: MeshInstance3D, row: Dictionary) -> bool:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property", null)
	var study: StadiumNpcRetainedActorCutaway = property.actor_cutaway if property != null else null
	if (
		study == null
		or Actors.actors(lab).get(row.role) != row.actor
		or mesh != row.mesh
		or mesh.get_parent() != row.parent
		or mesh.mesh != row.source_mesh
		or mesh.mesh.get_faces() != row.faces
		or not Actors.faded(mesh, study)
		or mesh.material_overlay != null
		or mesh.transparency != 0
	):
		return false
	var entry: Dictionary = study.entries.get(mesh.get_instance_id(), {})
	if (
		entry.is_empty()
		or not entry.faded
		or entry.mesh.get_ref() != mesh
		or entry.source_mesh != mesh.mesh
		or _material_signature(entry.original_material) != row.original_signature
	):
		return false
	# Stance/swing setup regenerates source-equivalent avatar materials, and restore_all
	# regenerates fade resources. Verify the current registry identities and immutable source
	# semantics; guide/target/chair identities remain strictly pinned elsewhere.
	if not row.has("fade_signature"):
		var original: StandardMaterial3D = entry.original_material as StandardMaterial3D
		if original == null:
			return false
		var expected: StandardMaterial3D = original.duplicate() as StandardMaterial3D
		expected.albedo_color.a = minf(expected.albedo_color.a, 0.20)
		expected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		row["fade_signature"] = _material_signature(expected)
	return (
		mesh.material_override == entry.fade_material
		and _material_signature(mesh.material_override) == row.fade_signature
	)


static func controls(owner: Node, lab: PitchBatLab) -> void:
	var camera: Camera3D = lab._camera
	var ball: BattedBallBody = lab._batted_ball
	var saved_camera: Transform3D = camera.transform
	var saved_mechanics: Dictionary = Mechanics.mechanics(lab)
	var cache: Dictionary = {}
	audit(lab, cache)
	var bound: Dictionary = cache[CACHE_KEY]
	owner._check(bound.guides.size() == 12, "audit pins all twelve exact baseline guide meshes")
	owner._check(
		bound.target.size() == 1 and bound.ball_meshes.size() == 1,
		"audit pins genuine target and ball resource identities"
	)
	camera.global_position = ball.global_position + Vector3(0, 3, -5)
	var probe: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE * 0.2
	probe.mesh = box
	probe.material_override = StandardMaterial3D.new()
	var holder: Node3D = Node3D.new()
	lab.add_child(holder)
	holder.add_child(probe)
	probe.global_position = camera.global_position.lerp(ball.global_position, 0.5)
	for label: String in ["Target", "PitchTarget", "Zone", "ZoneLeft", "BattingAim"]:
		probe.name = label
		owner._check(
			_count(audit(lab, cache), probe, "blocked") > 0,
			"noncolliding opaque copied-name " + label + " remains a triangle blocker"
		)
	probe.global_position += Vector3(20, 0, 0)
	owner._check(
		_count(audit(lab, cache), probe, "blocked") == 0,
		"moving copied-name probe away clears its triangle evidence"
	)
	holder.free()
	_guide_controls(owner, lab, cache, bound)
	_marking_controls(owner, lab, cache, bound)
	_target_controls(owner, lab, cache, bound)
	ShellControls.run(
		owner, lab, cache, bound, load("res://src/tests/stadium_yard_two_visibility_audit.gd")
	)
	camera.transform = saved_camera
	camera.force_update_transform()
	owner._check(
		Mechanics.mechanics(lab) == saved_mechanics,
		"audit controls preserve exact genuine ball transform, physics and gameplay state"
	)
	owner._check(camera.transform == saved_camera, "audit controls restore exact camera transform")
	print("AY02_RENDERED_GEOMETRY_CONTROLS ", audit(lab, cache))


static func _guide_controls(
	owner: Node, lab: PitchBatLab, cache: Dictionary, bound: Dictionary
) -> void:
	var tested: int = 0
	for row: Dictionary in bound.guides.values():
		var mesh: MeshInstance3D = row.mesh
		if not mesh.is_visible_in_tree() or not _guide_intact(lab, mesh, row):
			continue
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		var away: Vector3 = (center - lab._batted_ball.global_position).normalized()
		if away.is_zero_approx():
			continue
		lab._camera.global_position = center + away * 2.0
		if _count(audit(lab, cache), mesh, "guide_hits") == 0:
			continue
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		var transparency: int = material.transparency
		material.albedo_color.a = 1.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		owner._check(
			_count(audit(lab, cache), mesh, "blocked") > 0,
			"making genuine source guide opaque revokes its exception"
		)
		material.albedo_color = color
		material.transparency = transparency as BaseMaterial3D.Transparency
		owner._check(
			_count(audit(lab, cache), mesh, "guide_hits") > 0,
			"restoring exact guide material restores only its qualified translucency"
		)
		mesh.material_override = material.duplicate()
		owner._check(
			_count(audit(lab, cache), mesh, "blocked") > 0,
			"copied guide material cannot impersonate the pinned original resource"
		)
		mesh.material_override = material
		owner._check(
			_guide_intact(lab, mesh, row), "guide controls restore exact original identity"
		)
		tested += 1
		break
	owner._check(
		tested == 1, "genuine visible source guide has a positive and opaque negative control"
	)


static func _target_controls(
	owner: Node, lab: PitchBatLab, cache: Dictionary, bound: Dictionary
) -> void:
	var target: MeshInstance3D = lab._pitch_target_marker
	if target == null or not bound.target.has(target.get_instance_id()):
		owner._check(false, "finite-radius target controls require pinned authentic geometry")
		return
	var row: Dictionary = bound.target[target.get_instance_id()]
	var saved_visible: bool = target.visible
	var saved_pose: Transform3D = target.transform
	var ball: Vector3 = lab._batted_ball.global_position
	var center: Vector3 = target.global_transform * target.get_aabb().get_center()
	var axis: Vector3 = (center - ball).normalized()
	owner._check(not axis.is_zero_approx(), "target control has a real fixed-ball direction")
	if axis.is_zero_approx():
		return
	# Expose the unchanged source target only for this explicitly labelled control.
	# The genuine ball stays at its existing source-history/control position throughout.
	target.visible = true
	lab._camera.global_position = ball - axis * 3.0
	var positive: Dictionary = audit(lab, cache)
	var positive_rows: Array[Dictionary] = _hit_rows(positive, target)
	var behind: bool = not positive_rows.is_empty()
	for hit: Dictionary in positive_rows:
		behind = (
			behind
			and (
				hit.classification == "target_front_hits"
				and hit.distance + DEPTH_EPSILON >= hit.ball_front_distance
				and is_equal_approx(hit.physical_radius, lab._batted_ball.radius_m)
			)
		)
	owner._check(
		behind,
		"actual target triangles behind physical ball front receive the narrow depth exception"
	)
	print("AY02_TARGET_FRONT_CONTROL side=behind_physical_front hits=", positive_rows)
	var holder: Node3D = Node3D.new()
	lab.add_child(holder)
	var copied: MeshInstance3D = MeshInstance3D.new()
	copied.name = "PitchTarget"
	copied.mesh = target.mesh
	copied.material_override = target.material_override
	holder.add_child(copied)
	copied.global_transform = target.global_transform
	var copied_rows: Array[Dictionary] = _hit_rows(audit(lab, cache), copied)
	var copied_blocked: bool = not copied_rows.is_empty()
	for hit: Dictionary in copied_rows:
		copied_blocked = copied_blocked and hit.classification == "blocked"
	owner._check(
		copied_blocked and _depths(copied_rows) == _depths(positive_rows),
		"identical copied-name sphere at identical depths remains opaque despite shared resources"
	)
	print("AY02_TARGET_FRONT_CONTROL side=copied_sphere hits=", copied_rows)
	holder.free()
	lab._camera.global_position = ball + axis * 3.0
	var negative_rows: Array[Dictionary] = _hit_rows(audit(lab, cache), target)
	var before: bool = false
	for hit: Dictionary in negative_rows:
		before = (
			before
			or (
				hit.classification == "blocked"
				and hit.distance + DEPTH_EPSILON < hit.ball_front_distance
			)
		)
	owner._check(
		before,
		"authentic target becomes a blocker when actual triangles precede physical ball front"
	)
	print("AY02_TARGET_FRONT_CONTROL side=before_physical_front hits=", negative_rows)
	target.visible = saved_visible
	owner._check(
		(
			target.visible == saved_visible
			and target.transform == saved_pose
			and _target_intact(lab, target, row)
		),
		"target controls restore exact visible flag, pose, mesh and material identities"
	)


static func _hit_rows(proof: Dictionary, mesh: MeshInstance3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hit: Dictionary in proof.hits:
		if hit.mesh == mesh.get_instance_id():
			result.append(hit)
	return result


static func _depths(hits: Array[Dictionary]) -> Array:
	var result: Array = []
	for hit: Dictionary in hits:
		result.append([hit.face_index, hit.distance])
	return result


static func _count(proof: Dictionary, mesh: MeshInstance3D, category: String) -> int:
	var count: int = 0
	for hit: Dictionary in proof.hits:
		if hit.mesh == mesh.get_instance_id() and hit.classification == category:
			count += 1
	return count


static func _bind_markings(lab: PitchBatLab, bound: Dictionary) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property", null)
	if property == null:
		return
	var source: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	if not source.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new()):
		source.free()
		return
	for label: String in ["Safe", "Deep"]:
		var actual_root: Node3D = property.get_node_or_null(NodePath(label))
		var source_root: Node3D = source.get_node(NodePath(label))
		if actual_root == null or actual_root.get_child_count() != 1:
			continue
		var actual: MeshInstance3D = actual_root.get_child(0) as MeshInstance3D
		var reference: MeshInstance3D = source_root.get_child(0) as MeshInstance3D
		var row: Dictionary = _source_binding(actual, reference)
		if row.is_empty() or actual_root.transform != source_root.transform:
			continue
		row.merge(
			{
				"property": property,
				"root": actual_root,
				"root_pose": source_root.transform,
				"label": label
			}
		)
		bound.markings[actual.get_instance_id()] = row
	source.free()


static func _marking_intact(lab: PitchBatLab, mesh: MeshInstance3D, row: Dictionary) -> bool:
	return (
		lab.get_meta("stadium_property", null) == row.property
		and row.property.global_transform == Transform3D.IDENTITY
		and row.property.get_node_or_null(NodePath(row.label)) == row.root
		and row.root.get_parent() == row.property
		and row.root.get_child_count() == 1
		and row.root.get_child(0) == mesh
		and row.root.transform == row.root_pose
		and mesh.transform == row.transform
		and mesh.cast_shadow == row.shadow
		and _resource_intact(mesh, row)
	)


static func _marking_controls(
	owner: Node, lab: PitchBatLab, cache: Dictionary, bound: Dictionary
) -> void:
	owner._check(bound.markings.size() == 2, "exact original Safe and Deep marking identities")
	var ball: BattedBallBody = lab._batted_ball
	var saved: Transform3D = ball.transform
	# The point is the exact newly recorded ground-contact failure. It is a named
	# classification control, never inserted into accepted physics-history counts.
	ball.position = Vector3(0.571501613, 0.0273750015, 11.262716293)
	lab._camera.global_position = Vector3(-5.692966, 5.344961, 20.99799)
	for row: Dictionary in bound.markings.values():
		if row.label != "Safe":
			continue
		var mesh: MeshInstance3D = row.mesh
		owner._check(
			_count(audit(lab, cache), mesh, "marking_front_hits") > 0,
			"exact canonical opaque Safe guide behind physical front is depth-classified"
		)
		var copy: MeshInstance3D = mesh.duplicate() as MeshInstance3D
		lab.add_child(copy)
		copy.name = "Safe"
		copy.global_transform = mesh.global_transform
		owner._check(
			_count(audit(lab, cache), copy, "blocked") > 0,
			"identical opaque copied-name Safe mesh cannot borrow canonical guide authority"
		)
		copy.free()
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		var roughness: float = material.roughness
		material.roughness = 0.8
		owner._check(
			_count(audit(lab, cache), mesh, "blocked") > 0,
			"altered opaque canonical-guide material revokes classification"
		)
		material.roughness = roughness
		var box: BoxMesh = mesh.mesh as BoxMesh
		var size: Vector3 = box.size
		box.size.y += 0.002
		owner._check(
			_count(audit(lab, cache), mesh, "blocked") > 0,
			"in-place guide geometry mutation cannot inherit front-plane classification"
		)
		box.size = size
		lab._camera.global_position = Vector3(20, ball.position.y, ball.position.z)
		owner._check(
			_count(audit(lab, cache), mesh, "blocked") > 0,
			"canonical opaque scoring guide before physical front remains blocked"
		)
		owner._check(_marking_intact(lab, mesh, row), "exact original guide state restored")
	ball.transform = saved
