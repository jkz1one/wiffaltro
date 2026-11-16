class_name StadiumGrandILightingV1
extends RefCounted
## Reversible Grand-only artistic trial. Six aggregate emitters retain all 24 authored heads.
## No tower factory mutation, night certificate, astronomical claim or per-frame tree scan.
# gdlint: disable=max-returns

const VERSION: int = 2
const PROFILE: String = "GRAND-I-SIX-TOWER-LIGHTING-v2"
const ROOT: String = "GrandIActiveLighting"
const PREFIX: String = "npc:GRAND-I:r1:"
const SITES: Array[String] = [
	"MLIGHT-HL", "MLIGHT-HR", "MLIGHT-ML", "MLIGHT-MR", "MLIGHT-OL", "MLIGHT-OR"]
const SHADOW_SITES: Array[String] = ["MLIGHT-HL", "MLIGHT-HR", "MLIGHT-OL", "MLIGHT-OR"]
const ENERGY: float = 3.0
const RANGE: float = 80.0
const ANGLE: float = 68.0
const GLOW_SIZE: Vector2 = Vector2(0.40, 0.34)
const GLOW_FORWARD: float = 0.141
const GLOW_COLOR: Color = Color("ffe4c2")
const GLOW_ENERGY: float = 1.0


static func contract() -> Dictionary:
	var emitters: Array[Dictionary] = []
	for site: String in SITES:
		var selected: int = 1 if site.ends_with("L") else 2
		var rays: Array[Dictionary] = head_rays(site)
		emitters.append({"site": site, "head": rays[selected].id,
			"origin": rays[selected].origin, "direction": rays[selected].direction,
			"represented_heads": 4, "color": [1.0, 228.0 / 255.0, 194.0 / 255.0, 1.0],
			"energy": ENERGY, "range": RANGE, "angle": ANGLE, "attenuation": 0.65,
			"angle_attenuation": 0.7, "shadows": site in SHADOW_SITES,
			"shadow_bias": 0.1, "shadow_normal_bias": 2.0})
	return {"version": VERSION, "profile": PROFILE, "visible_heads": 24,
		"dynamic_emitters": 6, "shadow_casters": 4, "scalar_energy_total": 18.0,
		"grouping": "one-aggregate-per-tower-on-selected-authored-head-ray",
		"atlas": {"size": 2048, "bits": 32, "quadrant_slots": [1, 1, 1, 1]},
		"glow": {"count": 24, "size": [0.40, 0.34], "head_forward_offset": GLOW_FORWARD,
			"color": [1.0, 228.0 / 255.0, 194.0 / 255.0, 1.0],
			"emission_energy": GLOW_ENERGY, "shading": "unshaded", "shadows": false},
		"qualification": "native-readability-and-shadow-tuning-pending", "emitters": emitters}


static func head_rays(site: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if site not in SITES:
		return result
	var toward: Vector3 = StadiumFourHeadTowerSites.TARGETS[site] \
		- StadiumFourHeadTowerSites.SITES[site]
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)),
		StadiumFourHeadTowerSites.SITES[site])
	var local_target: Vector3 = pose.affine_inverse() * StadiumFourHeadTowerSites.TARGETS[site]
	for index in range(4):
		var center: Vector3 = Vector3(StadiumFourHeadTowerModels.HEAD_X[index],
			StadiumFourHeadTowerModels.HEAD_HEIGHT, 0)
		var direction: Vector3 = (local_target - center).normalized()
		var origin: Vector3 = pose * (center + direction * 0.139)
		direction = (pose.basis * direction).normalized()
		result.append({"id": "HEAD-%d" % (index + 1),
			"origin": [origin.x, origin.y, origin.z],
			"direction": [direction.x, direction.y, direction.z]})
	return result


static func apply(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	grand_ii: bool = false) -> Dictionary:
	var venue: String = "GRAND-II" if grand_ii else "GRAND-I"
	var root_name: String = "GrandIIActiveLighting" if grand_ii else ROOT
	var prefix: String = "npc:GRAND-II:r1:" if grand_ii else PREFIX
	if not is_instance_valid(lab) or not is_instance_valid(property) \
		or property.venue_id != venue or not property.is_inside_tree() \
		or property != StadiumNpcPublicRuntime._property(lab) \
		or property.get_node_or_null(root_name) != null \
			or property.global_transform != Transform3D.IDENTITY:
		return {}
	var sun: Node = lab.get_node_or_null("StarterFieldGeometry/Sun")
	var lights: Array[Node] = lab.find_children("*", "Light3D", true, false)
	if not sun is DirectionalLight3D or lights.size() != 1 or lights[0] != sun:
		return {}
	var heads: Array[Dictionary] = []
	for site: String in SITES:
		var tower: Node3D = property.objects.get(prefix + site) as Node3D
		if not is_instance_valid(tower) or not property.construction.is_ancestor_of(tower) \
			or not tower.has_meta("stadium_item") or tower.get_meta("stadium_item") != "ST-038":
			return {}
		var rays: Array[Dictionary] = head_rays(site)
		for index in range(4):
			var head: Node3D = tower.get_node_or_null("Visual/Head%d" % index) as Node3D
			var lens: MeshInstance3D = head.get_node_or_null("Lens") as MeshInstance3D \
				if head != null else null
			if head == null or lens == null or not head.visible or not lens.visible \
				or not head.is_visible_in_tree() or lens.mesh == null \
				or not lens.material_override is StandardMaterial3D:
				return {}
			var direction: Vector3 = head.global_basis.z.normalized()
			var origin: Vector3 = head.global_position + direction * 0.139
			if not origin.is_equal_approx(_vector(rays[index].origin)) \
				or not direction.is_equal_approx(_vector(rays[index].direction)):
				return {}
			heads.append({"tower": tower, "tower_parent": tower.get_parent(),
				"tower_pose": tower.transform, "head": head, "head_parent": head.get_parent(),
				"head_pose": head.transform, "lens": lens, "lens_pose": lens.transform,
				"lens_mesh": lens.mesh, "lens_material": lens.material_override,
				"lens_albedo": (lens.material_override as StandardMaterial3D).albedo_color})
	var viewport: Viewport = lab.get_viewport()
	var before: Dictionary = {"size": viewport.positional_shadow_atlas_size,
		"precision": viewport.positional_shadow_atlas_16_bits, "quadrants": []}
	for index in range(4):
		before.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	var root: Node3D = Node3D.new()
	root.name = root_name
	property.add_child(root)
	var issued: Array[Dictionary] = []
	for emitter: Dictionary in contract().emitters:
		var light: SpotLight3D = SpotLight3D.new()
		light.name = emitter.site
		root.add_child(light)
		light.transform = Transform3D(Basis.looking_at(_vector(emitter.direction), Vector3.UP),
			_vector(emitter.origin))
		light.light_color = Color("ffe4c2")
		light.light_energy = ENERGY
		light.spot_range = RANGE
		light.spot_angle = ANGLE
		light.spot_attenuation = emitter.attenuation
		light.spot_angle_attenuation = emitter.angle_attenuation
		light.shadow_enabled = emitter.shadows
		light.shadow_bias = emitter.shadow_bias
		light.shadow_normal_bias = emitter.shadow_normal_bias
		var keys: Array[StringName] = _light_keys(light)
		issued.append({"node": light, "pose": light.transform, "keys": keys,
			"values": _values(light, keys)})
	# Independent glow planes retain the authored lens meshes and materials byte-for-byte.
	for index in range(heads.size()):
		var row: Dictionary = heads[index]
		var glow: MeshInstance3D = MeshInstance3D.new()
		glow.name = "Glow%02d" % index
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = GLOW_SIZE
		var material: StandardMaterial3D = row.lens_material.duplicate() as StandardMaterial3D
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = GLOW_COLOR
		material.emission_enabled = true
		material.emission = GLOW_COLOR
		material.emission_energy_multiplier = GLOW_ENERGY
		glow.mesh = mesh
		glow.material_override = material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(glow)
		glow.transform = row.head.global_transform * Transform3D(
			Basis.IDENTITY, Vector3(0, 0, GLOW_FORWARD))
		row["glow"] = glow
		row["glow_pose"] = glow.transform
		row["glow_mesh"] = mesh
		row["glow_material"] = material
		row["glow_appearance"] = {"shading": material.shading_mode,
			"albedo": material.albedo_color, "enabled": material.emission_enabled,
			"emission": material.emission, "energy": material.emission_energy_multiplier,
			"shadows": glow.cast_shadow}
	viewport.positional_shadow_atlas_size = 2048
	viewport.positional_shadow_atlas_16_bits = false
	for index in range(4):
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1)
	var lease: Dictionary = {"lab": weakref(lab), "property": property, "root": root,
		"viewport": viewport, "before": before, "lights": issued, "heads": heads,
		"restored": false}
	if not installed(lab, lease, grand_ii):
		restore(lab, lease, grand_ii)
		return {}
	return lease


static func installed(lab: PitchBatLab, lease: Dictionary,
	grand_ii: bool = false) -> bool:
	var venue: String = "GRAND-II" if grand_ii else "GRAND-I"
	var root_name: String = "GrandIIActiveLighting" if grand_ii else ROOT
	# Fixed six lights and 24 retained head/glow pairs. Whole-tree/source checks stay cold.
	if lease.is_empty() or lease.get("restored", true) or not is_instance_valid(lab) \
		or not lease.get("lab") is WeakRef or lease.lab.get_ref() != lab \
		or not is_instance_valid(lease.get("property")) \
		or not lease.get("property") is StadiumNpcPublicProperty \
		or lease.property.venue_id != venue \
		or StadiumNpcPublicRuntime._property(lab) != lease.property \
		or not is_instance_valid(lease.get("root")) or lease.root.get_parent() != lease.property \
		or lease.property.get_node_or_null(root_name) != lease.root \
		or lease.root.get_script() != null or lease.root.transform != Transform3D.IDENTITY \
		or not lease.root.visible or lease.root.top_level \
		or lease.root.process_mode != Node.PROCESS_MODE_INHERIT \
		or not lease.root.get_meta_list().is_empty() or lease.root.get_child_count(true) != 30 \
		or lease.lights.size() != 6 or lease.heads.size() != 24 \
		or not is_instance_valid(lease.get("viewport")) or lab.get_viewport() != lease.viewport \
		or lease.viewport.positional_shadow_atlas_size != 2048 \
		or lease.viewport.positional_shadow_atlas_16_bits:
		return false
	for index in range(4):
		if lease.viewport.get_positional_shadow_atlas_quadrant_subdiv(index) \
			!= Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1:
			return false
	for index in range(6):
		var row: Dictionary = lease.lights[index]
		var light: SpotLight3D = row.node as SpotLight3D
		if not is_instance_valid(light) or light.get_parent() != lease.root \
			or light.get_script() != null or light.transform != row.pose \
			or lease.root.get_child(index, true) != light or light.name != StringName(SITES[index]) \
			or light.get_child_count(true) != 0 or not light.get_meta_list().is_empty() \
			or not light.visible or light.top_level or _values(light, row.keys) != row.values:
			return false
	for index in range(24):
		var row: Dictionary = lease.heads[index]
		if not is_instance_valid(row.tower) or row.tower.get_parent() != row.tower_parent \
			or row.tower.transform != row.tower_pose or not row.tower.visible \
			or not is_instance_valid(row.head) or row.head.get_parent() != row.head_parent \
			or row.head.transform != row.head_pose or not row.head.visible \
			or not is_instance_valid(row.lens) or row.lens.get_parent() != row.head \
			or row.lens.transform != row.lens_pose or not row.lens.visible \
			or row.lens.mesh != row.lens_mesh or row.lens.material_override != row.lens_material \
			or row.lens_material.albedo_color != row.lens_albedo \
			or not _glow_installed(row, lease.root, index):
			return false
	return true


static func _glow_installed(row: Dictionary, root: Node3D, index: int) -> bool:
	var glow: MeshInstance3D = row.glow as MeshInstance3D
	var mesh: QuadMesh = row.glow_mesh as QuadMesh
	var material: StandardMaterial3D = row.glow_material as StandardMaterial3D
	if not is_instance_valid(glow) or not is_instance_valid(mesh) \
		or not is_instance_valid(material):
		return false
	var appearance: Dictionary = row.glow_appearance
	return glow.get_parent() == root and root.get_child(index + 6, true) == glow \
		and glow.name == StringName("Glow%02d" % index) and glow.get_script() == null \
		and glow.get_child_count(true) == 0 and glow.get_meta_list().is_empty() \
		and glow.visible and not glow.top_level and glow.process_mode == Node.PROCESS_MODE_INHERIT \
		and glow.transform == row.glow_pose and glow.global_transform == row.head.global_transform \
			* Transform3D(Basis.IDENTITY, Vector3(0, 0, GLOW_FORWARD)) \
		and glow.mesh == mesh and mesh.get_script() == null and mesh.size == GLOW_SIZE \
		and mesh.orientation == PlaneMesh.FACE_Z and mesh.center_offset == Vector3.ZERO \
		and not mesh.flip_faces and mesh.subdivide_width == 0 and mesh.subdivide_depth == 0 \
		and glow.material_override == material and material != row.lens_material \
		and glow.material_overlay == null and glow.transparency == 0.0 \
		and material.get_script() == null and material.shading_mode == appearance.shading \
		and material.albedo_color == appearance.albedo \
		and material.emission_enabled == appearance.enabled \
		and material.emission == appearance.emission \
		and material.emission_energy_multiplier == appearance.energy \
		and glow.cast_shadow == appearance.shadows


static func restore(lab: PitchBatLab, lease: Dictionary,
	grand_ii: bool = false) -> bool:
	if not lease.get("property") is StadiumNpcPublicProperty \
		or not is_instance_valid(lease.get("property")) \
		or lease.property.venue_id != ("GRAND-II" if grand_ii else "GRAND-I"):
		return false
	if lease.is_empty() or not is_instance_valid(lab) or not lease.get("lab") is WeakRef \
		or lease.lab.get_ref() != lab or not is_instance_valid(lease.get("viewport")):
		return false
	var owners_match: bool = is_instance_valid(lease.get("property")) \
		and lab.get_viewport() == lease.viewport
	if not lease.get("restored", false):
		if is_instance_valid(lease.get("root")):
			owners_match = owners_match and lease.root.get_parent() == lease.property
			if lease.root.get_parent() != null:
				lease.root.get_parent().remove_child(lease.root)
			lease.root.free()
		else:
			owners_match = false
		lease.viewport.positional_shadow_atlas_size = lease.before.size
		lease.viewport.positional_shadow_atlas_16_bits = lease.before.precision
		for index in range(4):
			lease.viewport.set_positional_shadow_atlas_quadrant_subdiv(index,
				lease.before.quadrants[index])
		lease.restored = true
	for index in range(4):
		if lease.viewport.get_positional_shadow_atlas_quadrant_subdiv(index) \
			!= lease.before.quadrants[index]:
			return false
	return owners_match and lease.viewport.positional_shadow_atlas_size == lease.before.size \
		and lease.viewport.positional_shadow_atlas_16_bits == lease.before.precision


static func _light_keys(light: SpotLight3D) -> Array[StringName]:
	# Capture the native light's bounded stored operands once, including default shadow/fade flags.
	# Scriptless native class membership cannot grow without the ownership guard rejecting it.
	var result: Array[StringName] = []
	for description: Dictionary in light.get_property_list():
		if (int(description.usage) & PROPERTY_USAGE_STORAGE) != 0:
			result.append(StringName(description.name))
	return result


static func _values(light: SpotLight3D, keys: Array[StringName]) -> Array:
	var result: Array = []
	for key: StringName in keys:
		result.append(light.get(key))
	return result.duplicate(true)


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
