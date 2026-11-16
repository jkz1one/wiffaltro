class_name StadiumFloodlightGeometryRebuildChecks
extends RefCounted
## Bounded helper for the shared owned-item runner. Never starts a scene or engine.
## Cone overlap is geometric support only; native exposure/shadows/readability remain separate.
# gdlint: disable=max-line-length,max-returns

const MODELS = preload("res://src/presentation/stadium/stadium_floodlight_owned_models.gd")
const EPS: float = 0.0002
const FROZEN: Dictionary = {
	"stadium_four_head_tower_models.gd": "4bfe5bb1b81e8f2db5698a0a8456863d790b8a605bb1cfa7c00b2f5840e30119",
	"stadium_four_head_tower_sites.gd": "71664f9063f38a142b0416ab7be21eec15207298bb0f432d335482b15af7441d",
	"stadium_premium_light_tower_models.gd": "ce1356ae6f1fc11c6363b2aa3f1bd03ba950a5da1813e88f780f862cddb6ad6c",
	"stadium_premium_light_tower_sites.gd": "6c0e0e8c821e8f0ade13fe7ba7223521c4572ba8acfb064df720e0ceb8b738cc",
	"stadium_npc_ac02_public_light_sites.gd": "90e850ddaa6cc8bc3a35dc7b837af039e46020ece3b4beb689b5a63eda36d6fc",
	"stadium_grand_i_lighting_v1.gd": "1a4f11af641ceca564e2abd7a9820e60459adc6f05f4667a23890b86068d98e9",
	"stadium_grand_iii_lighting_v1.gd": "688ceae01eff0b0dfa07263f290106f74208d24394b003adc0b5ebdb87dd1fed",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"}
const PROFILE_SITES: Dictionary = {
	"CLUB4-LOW": ["CLIGHT-HL", "CLIGHT-HR", "CLIGHT-OL", "CLIGHT-OR"],
	"MOGUL6-STANDARD": ["MLIGHT-HL", "MLIGHT-HR", "MLIGHT-ML", "MLIGHT-MR", "MLIGHT-OL", "MLIGHT-OR"],
	"MOGUL4-PREMIUM": ["PLIGHT-HL", "PLIGHT-HR", "PLIGHT-OL", "PLIGHT-OR"]}
const ALIAS_PROFILES: Array[String] = ["CLUB4-LOW", "MOGUL4-PREMIUM"]
const HIERARCHY_CASES: Array[String] = ["reparent", "add", "reorder"]
const REJECTION_CASES: Array[String] = ["missing-copy", "empty-copy", "foreign-item", "unknown-site", "unknown-profile", "wrong-site-family", "moved-position", "arbitrary-yaw", "live-role"]


static func expected_checks() -> int:
	var sites: int = 0
	for family: Array in PROFILE_SITES.values():
		sites += family.size()
	# One manifest, source hashes, three profile-level checks, 23 checks/site,
	# Four coverage groups/profile, malformed requests, two alias aggregates and three hierarchy probes.
	return 1 + FROZEN.size() + PROFILE_SITES.size() * 7 + sites * 23 + REJECTION_CASES.size() + ALIAS_PROFILES.size() + HIERARCHY_CASES.size()


static func run(parent: Node3D, check: Callable) -> void:
	_emit(check, MODELS.ITEMS == ["ST-038", "ST-076"] and MODELS.PROFILES == PROFILE_SITES.keys(),
		"only the two requested exact models and three named alternatives exist")
	for file: String in FROZEN:
		var actual: String = FileAccess.get_sha256("res://src/presentation/stadium/" + file)
		_emit(check, actual == FROZEN[file], "reused source remains byte-for-byte frozen",
			{"file": file, "actual": actual, "expected": FROZEN[file]})
	var host: Node3D = Node3D.new()
	host.name = "FloodlightGeometryProbe"
	parent.add_child(host)
	host.position = Vector3(1600, 0, 0)
	for profile: String in PROFILE_SITES:
		_profile(profile, check)
		for site: String in PROFILE_SITES[profile]:
			await _tower(host, profile, site, check)
		_coverage(profile, check)
	_rejections(check)
	host.free()


static func _profile(profile: String, check: Callable) -> void:
	var emitters: Array[Dictionary] = MODELS.emitter_rows(profile)
	_emit(check, MODELS.profile_sites(profile).keys() == PROFILE_SITES[profile]
		and emitters.size() == PROFILE_SITES[profile].size(), "exact source sites each own one aggregate", {"profile": profile})
	var heads: int = 8 if profile == "MOGUL4-PREMIUM" else 4
	var valid: bool = true
	var total: int = 0
	var shadows: int = 0
	for row: Dictionary in emitters:
		var selected: int = (6 if row.site.ends_with("L") else 7) if heads == 8 else (2 if row.site.ends_with("L") else 3)
		valid = valid and row.head == "HEAD-%d" % selected and row.represented_heads == heads \
			and row.energy == (4.5 if heads == 8 else 3.0) and row.range == (90.0 if heads == 8 else 80.0) \
			and row.angle == 68.0 and row.attenuation == 0.65 and row.angle_attenuation == 0.7 \
			and row.shadow_bias == 0.1 and row.shadow_normal_bias == 2.0
		total += row.represented_heads
		shadows += int(row.shadows)
	_emit(check, valid and total == heads * PROFILE_SITES[profile].size() and shadows == 4,
		"fixed aggregate selection retains source optics and all owned visible heads",
		{"profile": profile, "heads": total, "shadows": shadows})
	var mutated: Array[Dictionary] = MODELS.emitter_rows(profile)
	mutated[0].energy = 900.0
	_emit(check, MODELS.emitter_rows(profile)[0].energy == emitters[0].energy,
		"caller edits cannot mutate shared source light definitions", {"profile": profile})


static func _placement(profile: String, site: String) -> Dictionary:
	var fixed: Transform3D = MODELS.pose(profile, site)
	return {"copy": "geometry-owned:" + profile + ":" + site, "item": MODELS.profile_item(profile),
		"profile": profile, "site": site, "position": fixed.origin,
		"yaw": rad_to_deg(atan2(fixed.basis.z.x, fixed.basis.z.z)), "role": "DECORATIVE_AFTER_TERMINAL"}


static func _reference(profile: String, site: String) -> Node3D:
	if profile == "CLUB4-LOW":
		return StadiumNpcAc02PublicLightSites.create(site)
	var model: Node3D
	if profile == "MOGUL6-STANDARD":
		model = StadiumFourHeadTowerModels.create()
		StadiumFourHeadTowerSites.place(model, site)
	else:
		model = StadiumPremiumLightTowerModels.create()
		StadiumPremiumLightTowerSites.place(model, site)
	return model


static func _tower(host: Node3D, profile: String, site: String, check: Callable) -> void:
	var row: Dictionary = _placement(profile, site)
	var original: Node3D = _reference(profile, site)
	var frozen: String = _signature(original)
	var model: Node3D = MODELS.create(row.item, row)
	var context: Dictionary = {"profile": profile, "site": site}
	_emit(check, model != null, "complete exact-copy tower is created", context)
	if model == null:
		original.free()
		return
	host.add_child(model)
	var owner_failure: String = _owner_failure(model, row)
	_emit(check, owner_failure.is_empty(), "every authored member carries exact paid-copy/site metadata",
		{"profile": profile, "site": site, "node": owner_failure})
	_emit(check, _signature(model) == frozen, "owned copy retains the entire source visual/collision geometry", context)
	_emit(check, model.transform.is_equal_approx(MODELS.pose(profile, site))
		and model.get_node("Visual").transform == Transform3D.IDENTITY
		and model.get_node("Collision").transform == Transform3D.IDENTITY,
		"actual assembly uses the exact authored field-frame pose", context)
	_emit(check, _envelope_failure(model, profile).is_empty(), "every actual generated vertex fits tower and property bounds",
		{"profile": profile, "site": site, "failure": _envelope_failure(model, profile)})
	_emit(check, _solids(model), "only visible footing plate and mast have layer1 mask0 scenery solids", context)
	var heads: Array[Dictionary] = MODELS.lens_rows(model)
	_emit(check, heads.size() == (8 if row.item == "ST-076" else 4), "all source lens faces retain the exact named head rays", context)
	_emit(check, model.find_children("*", "Light3D", true, false).is_empty()
		and model.get_meta("obstacle_units", -1) == 0 and not model.get_meta("night_qualified", true),
		"dormant geometry creates no lights obstacle units or night grant", context)
	var rig: Dictionary = MODELS.install_owned_rig(model)
	_emit(check, not rig.is_empty() and rig.emitters.size() == 1 and rig.lenses.size() == heads.size(),
		"one bounded dark rig retains one aggregate and every separate glow lens", context)
	if rig.is_empty():
		model.free()
		original.free()
		return
	_emit(check, _signature(model) == frozen and _signature(original) == frozen,
		"adding the separate rig changes neither source geometry nor source lenses", context)
	var beam: SpotLight3D = rig.emitters[0].beam
	var spec: Dictionary = rig.emitters[0].spec
	var field_pose: Transform3D = model.transform * beam.transform
	_emit(check, not beam.visible and field_pose.origin.is_equal_approx(_vector(spec.origin))
		and (-field_pose.basis.z).is_equal_approx(_vector(spec.direction)),
		"aggregate starts dark on the selected real lens-face origin and direction", context)
	var distinct: bool = true
	for lens: Dictionary in rig.lenses:
		distinct = distinct and lens.lens != lens.source_lens and lens.original != lens.source_material \
			and not lens.lens.visible and not lens.original.emission_enabled \
			and lens.original.emission_energy_multiplier == 0.0 \
			and lens.lens.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_emit(check, distinct, "each dark shadowless glow owns its own material without changing the source lens", context)
	_emit(check, MODELS.geometry_intact(model, rig.geometry), "actual native node/resource manifest is intact", context)
	_mutations(model, rig, check, context)
	if profile == "CLUB4-LOW" and site == PROFILE_SITES[profile][0]:
		_hierarchy_mutations(model, rig, check, context)
	if profile in ALIAS_PROFILES and site == PROFILE_SITES[profile][0]:
		var other_row: Dictionary = row.duplicate(true)
		other_row.copy = String(row.copy) + ":independent"
		var other_model: Node3D = MODELS.create(other_row.item, other_row)
		var alias: Dictionary = alias_check(model, rig.geometry, [other_model], rig.lenses)
		_emit(check, not alias.values().has(false), "source material sharing preserves copy isolation and exact mutation guards",
			{"profile": profile, "site": site, "checks": alias})
		if other_model != null:
			other_model.free()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	for offset: float in [0.0, 0.7]:
		var start: Vector3 = model.global_transform * Vector3(offset, 2, -1)
		var end: Vector3 = model.global_transform * Vector3(offset, 2, 1)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1))
		_emit(check, (not hit.is_empty()) == is_zero_approx(offset), "native ray hits the real mast and misses the empty reservation",
			{"profile": profile, "site": site, "offset": offset})
	var low: Vector3 = model.global_transform * Vector3(0.35, 0.15, -1)
	var high: Vector3 = model.global_transform * Vector3(0.35, 0.15, 1)
	_emit(check, not space.intersect_ray(PhysicsRayQueryParameters3D.create(low, high, 1)).is_empty(),
		"native contact retains the visible footing width", context)
	var fresh: Node3D = _reference(profile, site)
	_emit(check, _signature(original) == frozen and _signature(fresh) == frozen,
		"owned creation and rig lifecycle preserve existing and freshly regenerated source models", context)
	fresh.free()
	model.free()
	original.free()


static func alias_check(model: Node3D, seal: Dictionary, other_models: Array, rig_lenses: Array = []) -> Dictionary:
	var result: Dictionary = {"intact_before": false, "shared_within_model": false,
		"no_cross_copy_alias": false, "rig_materials_distinct": true,
		"replacement_refused": false, "scalar_refused": false,
		"restored": false, "appearance_parity": false}
	var members: Array[MeshInstance3D] = _source_members(model)
	if members.is_empty():
		return result
	result.intact_before = MODELS.geometry_intact(model, seal)
	var appearance: String = _signature(model)
	var originals: Array[StandardMaterial3D] = []
	var shared_member: MeshInstance3D
	for member: MeshInstance3D in members:
		var material: StandardMaterial3D = member.material_override as StandardMaterial3D
		if material == null:
			return result
		if originals.has(material):
			shared_member = member
		else:
			originals.append(material)
	result.shared_within_model = shared_member != null
	result.no_cross_copy_alias = not other_models.is_empty()
	for other: Variant in other_models:
		if not other is Node3D or not is_instance_valid(other) or other == model:
			result.no_cross_copy_alias = false
			continue
		var other_members: Array[MeshInstance3D] = _source_members(other)
		if other_members.is_empty():
			result.no_cross_copy_alias = false
		for member: MeshInstance3D in other_members:
			if originals.has(member.material_override):
				result.no_cross_copy_alias = false
	var rig_materials: Array[StandardMaterial3D] = []
	for lens: Variant in rig_lenses:
		if not lens is Dictionary or not lens.get("original") is StandardMaterial3D:
			result.rig_materials_distinct = false
			continue
		var materials: Array[StandardMaterial3D] = [lens.original]
		if lens.has("working"):
			if not lens.working is StandardMaterial3D:
				result.rig_materials_distinct = false
			else:
				materials.append(lens.working)
		for material: StandardMaterial3D in materials:
			if originals.has(material) or rig_materials.has(material):
				result.rig_materials_distinct = false
			rig_materials.append(material)
	if shared_member == null:
		return result
	var original: StandardMaterial3D = shared_member.material_override
	var state: Dictionary = MODELS._source_material_state(original)
	var foreign: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
	if foreign == null:
		return result
	# Resource.duplicate may omit disabled fields; make the foreign reference
	# exactly value-equal before proving that node identity alone rejects it.
	for index in range(state.keys.size()):
		var key: StringName = state.keys[index]
		if foreign.get(key) != state.values[index]:
			foreign.set(key, state.values[index])
	var same_values: bool = MODELS._source_material_state(foreign) == state
	shared_member.material_override = foreign
	result.replacement_refused = same_values and not MODELS.geometry_intact(model, seal)
	shared_member.material_override = original
	var restored_reference: bool = MODELS.geometry_intact(model, seal)
	var roughness: float = original.roughness
	original.roughness = 0.25 if roughness != 0.25 else 0.75
	result.scalar_refused = not MODELS.geometry_intact(model, seal)
	original.roughness = roughness
	result.restored = restored_reference and MODELS.geometry_intact(model, seal)
	result.appearance_parity = same_values and MODELS._source_material_state(original) == state \
		and _signature(model) == appearance
	return result


static func _source_members(model: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not is_instance_valid(model):
		return result
	var visual: Node3D = model.get_node_or_null("Visual") as Node3D
	if visual == null:
		return result
	for member: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		result.append(member)
	return result


static func _mutations(model: Node3D, rig: Dictionary, check: Callable, context: Dictionary) -> void:
	var head: Node3D = rig.lenses[0].head
	var old_pose: Transform3D = head.transform
	head.position.x += 0.01
	_emit(check, not MODELS.geometry_intact(model, rig.geometry), "head movement invalidates the actual geometry manifest", context)
	head.transform = old_pose
	var mesh: BoxMesh = model.get_node("Visual/Footing").mesh
	var old_size: Vector3 = mesh.size
	mesh.size.x += 0.01
	_emit(check, not MODELS.geometry_intact(model, rig.geometry), "in-place authored mesh edits invalidate geometry", context)
	mesh.size = old_size
	var body: StaticBody3D = model.get_node("Collision/Mast")
	body.collision_mask = 2
	_emit(check, not MODELS.geometry_intact(model, rig.geometry), "collision-policy edits invalidate geometry", context)
	body.collision_mask = 0
	var beam: SpotLight3D = rig.emitters[0].beam
	var old_angle: float = beam.spot_angle
	beam.spot_angle = old_angle - 1.0
	_emit(check, not MODELS.geometry_intact(model, rig.geometry), "aggregate optics edits invalidate geometry", context)
	beam.spot_angle = old_angle
	var old_energy: float = beam.light_energy
	beam.visible = true
	beam.light_energy = 0.0
	var glow: MeshInstance3D = rig.lenses[0].lens
	glow.visible = true
	glow.material_override = rig.lenses[0].original.duplicate(true)
	_emit(check, MODELS.geometry_intact(model, rig.geometry), "only clock-owned beam and glow appearance writes are outside geometry seal", context)
	beam.visible = false
	beam.light_energy = old_energy
	glow.visible = false
	glow.material_override = rig.lenses[0].original
	_emit(check, MODELS.geometry_intact(model, rig.geometry), "restored original native resources and poses match the same seal", context)


static func _hierarchy_mutations(model: Node3D, rig: Dictionary, check: Callable, context: Dictionary) -> void:
	var head: Node3D = rig.lenses[0].head
	var parent: Node = head.get_parent()
	var index: int = head.get_index()
	var pose: Transform3D = head.transform
	for kind: String in HIERARCHY_CASES:
		var baseline: bool = MODELS.geometry_intact(model, rig.geometry)
		var changed: bool = false
		var refused: bool = false
		match kind:
			"reparent":
				head.reparent(rig.root, false)
				changed = head.get_parent() == rig.root and head.transform == pose
				refused = not MODELS.geometry_intact(model, rig.geometry)
				head.reparent(parent, false)
				parent.move_child(head, index)
			"add":
				var leaf: MeshInstance3D = rig.lenses[0].source_lens
				var child: Node3D = Node3D.new()
				child.name = "ForeignHierarchyChild"
				leaf.add_child(child)
				changed = leaf.get_child_count() == 1 and child.get_parent() == leaf
				refused = not MODELS.geometry_intact(model, rig.geometry)
				leaf.remove_child(child)
				child.free()
			"reorder":
				parent.move_child(head, 0)
				changed = head.get_parent() == parent and head.get_index() != index and head.transform == pose
				refused = not MODELS.geometry_intact(model, rig.geometry)
				parent.move_child(head, index)
		var restored: bool = head.get_parent() == parent and head.get_index() == index \
			and head.transform == pose and MODELS.geometry_intact(model, rig.geometry)
		_emit(check, baseline and changed and refused and restored,
			"actual hierarchy mutation is refused and exact restoration retains the same seal",
			{"profile": context.profile, "site": context.site, "mutation": kind,
				"baseline": baseline, "changed": changed, "refused": refused, "restored": restored})


static func _owner_failure(node: Node, row: Dictionary) -> String:
	if node.get_meta("stadium_item", "") != row.item or node.get_meta("owned_copy", "") != row.copy \
		or node.get_meta("paid_copy", "") != row.copy or node.get_meta("site", "") != row.site \
		or node.get_meta("floodlight_profile", "") != row.profile \
		or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL":
		return str(node.name)
	for child: Node in node.get_children():
		var failure: String = _owner_failure(child, row)
		if not failure.is_empty():
			return str(node.name) + "/" + failure
	return ""


static func _solids(model: Node3D) -> bool:
	var collision: Node3D = model.get_node("Collision")
	if collision.get_child_count() != 3 or model.find_children("*", "StaticBody3D", true, false).size() != 3:
		return false
	for id: String in ["Footing", "BasePlate", "Mast"]:
		var body: StaticBody3D = collision.get_node_or_null(id) as StaticBody3D
		var visual: MeshInstance3D = model.get_node_or_null("Visual/" + id) as MeshInstance3D
		if body == null or visual == null or body.get_child_count() != 1 \
			or body.collision_layer != 1 or body.collision_mask != 0 or body.has_meta("ball_surface") \
			or body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL" or body.transform != visual.transform:
			return false
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if shape == null or shape.disabled or shape.transform != Transform3D.IDENTITY:
			return false
		if id == "Mast":
			if not shape.shape is CylinderShape3D or not visual.mesh is CylinderMesh \
				or shape.shape.radius != visual.mesh.top_radius or shape.shape.radius != visual.mesh.bottom_radius \
				or shape.shape.height != visual.mesh.height:
				return false
		elif not shape.shape is BoxShape3D or not visual.mesh is BoxMesh or shape.shape.size != visual.mesh.size:
			return false
	return true


static func _envelope_failure(model: Node3D, profile: String) -> String:
	var bound: AABB = MODELS.envelope(MODELS.profile_item(profile)).grow(EPS)
	var nodes: Array[Node] = model.get_node("Visual").find_children("*", "MeshInstance3D", true, false)
	for mesh: MeshInstance3D in nodes:
		var local: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = local * vertex
				var world: Vector3 = model.transform * point
				var radius: float = bound.size.x / 2.0
				var club: bool = profile == "CLUB4-LOW"
				if not point.is_finite() or not bound.has_point(point) or Vector2(point.x, point.z).length() > radius \
					or absf(world.x) > (40.0 if club else 52.0) \
					or world.z < (-22.0 if club else -30.0) or world.z > (46.0 if club else 58.0):
					return str(mesh.name) + ":" + str(point)
	return ""


static func _signature(model: Node3D) -> String:
	var state: Array = []
	for branch: String in ["Visual", "Collision"]:
		_geometry_state(model.get_node(branch), state)
	return var_to_bytes(state).hex_encode().sha256_text()


static func _geometry_state(node: Node3D, state: Array) -> void:
	# Frozen factories leave collider names generated; compare geometry across fresh copies.
	var node_name: String = node.get_class() if node is CollisionShape3D else str(node.name)
	var row: Array = [node_name, node.get_class(), node.transform, node.visible, node.top_level,
		node.process_mode, node.get_script(), node.get_child_count()]
	if node is MeshInstance3D:
		row.append([node.mesh.get_class(), node.cast_shadow, node.layers, node.transparency,
			StadiumCurvedCanopySites._resource(node.material_override),
			StadiumCurvedCanopySites._resource(node.material_overlay)])
		for surface in range(node.mesh.get_surface_count()):
			row.append([node.mesh.surface_get_arrays(surface),
				StadiumCurvedCanopySites._resource(node.mesh.surface_get_material(surface)),
				StadiumCurvedCanopySites._resource(node.get_surface_override_material(surface))])
	if node is CollisionObject3D:
		row.append([node.collision_layer, node.collision_mask, node.disable_mode,
			node.get_meta("surface_role", ""), node.has_meta("ball_surface")])
	if node is CollisionShape3D:
		row.append([node.disabled, StadiumCurvedCanopySites._resource(node.shape)])
	state.append(row)
	for child: Node3D in node.get_children():
		_geometry_state(child, state)


static func _coverage(profile: String, check: Callable) -> void:
	var sets: Dictionary = {"low-field-box": [], "release-zone-corridor": [], "receiver-terminal": [], "retained-tracking": []}
	for x in range(-24, 25):
		for z in range(-6, 29):
			for y: float in [0.15, 1.05, 1.75]:
				sets["low-field-box"].append(Vector3(x, y, z))
	for release: Vector2 in [Vector2(-0.25, 1.75), Vector2(0.25, 1.75), Vector2(-0.72, 1.25), Vector2(0.72, 1.25)]:
		for x: float in [-0.43, 0.0, 0.43]:
			for y: float in [0.55, 1.05, 1.55]:
				for frame in range(101):
					sets["release-zone-corridor"].append(Vector3(release.x, release.y, 13.716).lerp(Vector3(x, y, 0), frame / 100.0))
	for x: float in [-0.6, 0.0, 0.6]:
		for y: float in [0.0, 0.55, 1.05, 1.55, 1.645]:
			for z: float in [-6.0, -1.725, -1.05, 0.0]:
				sets["receiver-terminal"].append(Vector3(x, y, z))
	for end: Vector3 in [Vector3(0, 0.15, 27.9), Vector3(-8, 0.15, 22.4), Vector3(13, 0.15, 22.9),
		Vector3(7, 0.15, 11.75), Vector3(-17, 0.7, 12), Vector3(17, 0.7, 12), Vector3(0, 7, 26), Vector3(0, 35, 25)]:
		for frame in range(151):
			sets["retained-tracking"].append(Vector3(0, 1, 0).lerp(end, frame / 150.0))
	var emitters: Array[Dictionary] = MODELS.emitter_rows(profile)
	for name_value: String in sets:
		var result: Dictionary = cone_coverage(emitters, sets[name_value])
		_emit(check, result.uncovered == 0, "authored cones cover the bounded geometric sample set",
			{"profile": profile, "set": name_value, "count": result.samples, "uncovered": result.uncovered,
				"first": result.first, "minimum_overlap": result.minimum_overlap})


static func cone_coverage(emitters: Array[Dictionary], samples: Array) -> Dictionary:
	var result: Dictionary = {"samples": samples.size(), "uncovered": 0, "first": [], "minimum_overlap": emitters.size()}
	for point: Vector3 in samples:
		var covered: int = 0
		for emitter: Dictionary in emitters:
			var delta: Vector3 = point - _vector(emitter.origin)
			if delta.length() <= emitter.range and delta.normalized().dot(_vector(emitter.direction)) >= cos(deg_to_rad(emitter.angle)):
				covered += 1
		result.minimum_overlap = mini(result.minimum_overlap, covered)
		if covered == 0:
			result.uncovered += 1
			if result.first.is_empty():
				result.first = [point.x, point.y, point.z]
	return result


static func _rejections(check: Callable) -> void:
	for reason: String in REJECTION_CASES:
		var row: Dictionary = _placement("CLUB4-LOW", "CLIGHT-HL")
		var item: String = "ST-038"
		match reason:
			"missing-copy": row.erase("copy")
			"empty-copy": row.copy = ""
			"foreign-item": item = "ST-076"
			"unknown-site": row.site = "ANYWHERE"
			"unknown-profile": row.profile = "CLUB4-TALL"
			"wrong-site-family": row.site = "MLIGHT-HL"
			"moved-position": row.position += Vector3(0.1, 0, 0)
			"arbitrary-yaw": row.yaw += 0.5
			"live-role": row.role = "LIVE_RICOCHET"
		var model: Node3D = MODELS.create(item, row)
		_emit(check, model == null, "malformed or nonauthored tower request fails closed", {"case": reason})
		if model != null:
			model.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print("FLOODLIGHT_GEOMETRY_FAILURE " + JSON.stringify({"message": message, "operands": operands}, "", true, true))
	check.call(ok, message)


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
