class_name StadiumGrandIIILightingV1
extends RefCounted
## Source-only premium trial: four aggregates retain all 32 exact authored ST076 head rays.
## Upper inner rays avoid inventing aim; 90 m reach covers the farther premium sites.
## Energy 4.5 and 68-degree cones are starting art parameters, not photometry or night credit.
## Working-owner-acceptance-pending; native nine-canopy/video/waterfall readability unrun.
# gdlint: disable=max-returns

const VERSION: int = 1
const PROFILE: String = "GRAND-III-FOUR-PREMIUM-TOWER-LIGHTING-v1"
const ROOT: String = "GrandIIIActiveLighting"
const PREFIX: String = "npc:GRAND-III:r1:"
const SITES: Array[String] = ["PLIGHT-HL", "PLIGHT-HR", "PLIGHT-OL", "PLIGHT-OR"]
const SHADOW_SITES: Array[String] = ["PLIGHT-HL", "PLIGHT-HR", "PLIGHT-OL", "PLIGHT-OR"]
const ENERGY: float = 4.5
const RANGE: float = 90.0
const ANGLE: float = 68.0
const GLOW_SIZE: Vector2 = Vector2(0.47, 0.36)
const GLOW_FORWARD: float = 0.156
const GLOW_COLOR: Color = Color("ffe4c2")
const GLOW_ENERGY: float = 1.0

const Operations1: GDScript = preload(
	"res://src/presentation/stadium/stadium_grand_iii_lighting_v1_operations_1.gd"
)

static var _issued: Dictionary = {}


static func contract() -> Dictionary:
	var emitters: Array[Dictionary] = []
	for site: String in SITES:
		var selected: int = 5 if site.ends_with("L") else 6
		var rays: Array[Dictionary] = head_rays(site)
		emitters.append(
			{
				"site": site,
				"head": rays[selected].id,
				"origin": rays[selected].origin,
				"direction": rays[selected].direction,
				"represented_heads": 8,
				"color": [1.0, 228.0 / 255.0, 194.0 / 255.0, 1.0],
				"energy": ENERGY,
				"range": RANGE,
				"angle": ANGLE,
				"attenuation": 0.65,
				"angle_attenuation": 0.7,
				"shadows": site in SHADOW_SITES,
				"shadow_bias": 0.1,
				"shadow_normal_bias": 2.0
			}
		)
	return {
		"version": VERSION,
		"profile": PROFILE,
		"visible_heads": 32,
		"dynamic_emitters": 4,
		"shadow_casters": 4,
		"scalar_energy_total": 18.0,
		"grouping": "one-eight-head-aggregate-per-premium-tower-on-upper-inner-authored-ray",
		"atlas": {"size": 2048, "bits": 32, "quadrant_slots": [1, 1, 1, 1]},
		"glow":
		{
			"count": 32,
			"size": [0.47, 0.36],
			"head_forward_offset": GLOW_FORWARD,
			"color": [1.0, 228.0 / 255.0, 194.0 / 255.0, 1.0],
			"emission_energy": GLOW_ENERGY,
			"shading": "unshaded",
			"shadows": false
		},
		"qualification": "grand-iii-nine-canopy-video-waterfall-native-readability-pending",
		"emitters": emitters
	}


static func head_rays(site: String) -> Array[Dictionary]:
	if site not in SITES:
		return []
	# Historical III math is itself the authored eight-head, 0.154 m lens-front reference.
	return StadiumGrandIIIVenueStudy.head_rays(site)


static func apply(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> Dictionary:
	return _apply(lab, property, {})


static func apply_time(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, environment_lease: Dictionary
) -> Dictionary:
	if not StadiumGrandIIIEnvironmentV1.installation_intact(lab, environment_lease):
		return {}
	return _apply(lab, property, environment_lease)


static func _apply(
	lab: PitchBatLab, property: StadiumNpcPublicProperty, time_lease: Dictionary
) -> Dictionary:
	_prune()
	var diagnostic_stage: String = "lights/preflight"
	if (
		is_instance_valid(lab)
		and _issued.has(lab.get_instance_id())
		and not _issued[lab.get_instance_id()].state.restored
	):
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	if (
		not is_instance_valid(lab)
		or not is_instance_valid(property)
		or property.venue_id != "GRAND-III"
		or not property.is_inside_tree()
		or property != StadiumNpcPublicRuntime._property(lab)
		or property.get_node_or_null(ROOT) != null
		or not is_instance_valid(property.construction)
		or property.global_transform != Transform3D.IDENTITY
	):
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	var sun: Node = lab.get_node_or_null("StarterFieldGeometry/Sun")
	var lights: Array[Node] = lab.find_children("*", "Light3D", true, false)
	if not sun is DirectionalLight3D or lights.size() != 1 or lights[0] != sun:
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	diagnostic_stage = "lights/authored-heads"
	var heads: Array[Dictionary] = []
	var towers: Array[Dictionary] = []
	for site: String in SITES:
		var tower: Node3D = property.objects.get(PREFIX + site) as Node3D
		if (
			not is_instance_valid(tower)
			or not property.construction.is_ancestor_of(tower)
			or not tower.has_meta("stadium_item")
			or tower.get_meta("stadium_item") != "ST-076"
		):
			if not time_lease.is_empty():
				StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
			return {}
		var rays: Array[Dictionary] = head_rays(site)
		if not _tower_rays(tower, site, rays):
			if not time_lease.is_empty():
				StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
			return {}
		var visual: Node3D = tower.get_node_or_null("Visual") as Node3D
		if visual == null or not visual.visible:
			if not time_lease.is_empty():
				StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
			return {}
		towers.append(
			{
				"node": tower,
				"site": site,
				"parent": tower.get_parent(),
				"visual": visual,
				"tower_guard": _guard(tower),
				"visual_guard": _guard(visual)
			}
		)
		for index in range(8):
			var head: Node3D = tower.get_node_or_null("Visual/Head%d" % index) as Node3D
			var lens: MeshInstance3D = (
				head.get_node_or_null("Lens") as MeshInstance3D if head != null else null
			)
			if (
				head == null
				or lens == null
				or not head.visible
				or not lens.visible
				or not head.is_visible_in_tree()
				or lens.mesh == null
				or not lens.material_override is StandardMaterial3D
			):
				if not time_lease.is_empty():
					StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
				return {}
			var direction: Vector3 = head.global_basis.z.normalized()
			var origin: Vector3 = head.global_position + direction * 0.154
			if (
				not origin.is_equal_approx(_vector(rays[index].origin))
				or not direction.is_equal_approx(_vector(rays[index].direction))
			):
				if not time_lease.is_empty():
					StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
				return {}
			heads.append(
				{
					"tower": tower,
					"tower_parent": tower.get_parent(),
					"tower_pose": tower.transform,
					"head": head,
					"head_parent": head.get_parent(),
					"head_pose": head.transform,
					"lens": lens,
					"lens_pose": lens.transform,
					"lens_mesh": lens.mesh,
					"lens_material": lens.material_override,
					"lens_albedo": (lens.material_override as StandardMaterial3D).albedo_color,
					"guards":
					[_guard(head), _guard(lens), _guard(lens.mesh), _guard(lens.material_override)]
				}
			)
	diagnostic_stage = "lights/root-attachment"
	var viewport: Viewport = lab.get_viewport()
	var before: Dictionary = {
		"size": viewport.positional_shadow_atlas_size,
		"precision": viewport.positional_shadow_atlas_16_bits,
		"quadrants": []
	}
	for index in range(4):
		before.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
	var root: Node3D = Node3D.new()
	var created: Array[Node] = []
	root.name = ROOT
	property.add_child(root)
	if (
		not time_lease.is_empty()
		and (
			not StadiumGrandIIIEnvironmentV1.installation_intact(lab, time_lease)
			or not is_instance_valid(root)
			or root.get_parent() != property
			or root.get_script() != null
			or root.get_child_count(true) != 0
			or not root.get_meta_list().is_empty()
			or lab.get_viewport() != viewport
			or not _atlas_matches(viewport, before)
		)
	):
		_discard_time_root(root, property, created)
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	var issued: Array[Dictionary] = []
	for emitter: Dictionary in contract().emitters:
		diagnostic_stage = "lights/spot-attachment/" + String(emitter.site)
		var light: SpotLight3D = SpotLight3D.new()
		light.name = emitter.site
		if time_lease.is_empty():
			root.add_child(light)
		light.transform = Transform3D(
			Basis.looking_at(_vector(emitter.direction), Vector3.UP), _vector(emitter.origin)
		)
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
		var intended: Array = _values(light, keys)
		if not time_lease.is_empty():
			created.append(light)
			root.add_child(light)
			if (
				not StadiumGrandIIIEnvironmentV1.installation_intact(lab, time_lease)
				or not is_instance_valid(root)
				or root.get_parent() != property
				or not is_instance_valid(light)
				or light.get_parent() != root
				or light.get_script() != null
				or light.get_child_count(true) != 0
				or not light.get_meta_list().is_empty()
				or _values(light, keys) != intended
				or lab.get_viewport() != viewport
				or not _atlas_matches(viewport, before)
			):
				diagnose_values(light, keys, intended, diagnostic_stage)
				_discard_time_root(root, property, created)
				if not time_lease.is_empty():
					StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
				return {}
		issued.append({"node": light, "pose": light.transform, "keys": keys, "values": intended})
	# Independent glow planes retain the authored lens meshes and materials byte-for-byte.
	for index in range(heads.size()):
		diagnostic_stage = "lights/glow-attachment/%d" % index
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
		var intended_pose: Transform3D = (
			row.head.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, GLOW_FORWARD))
		)
		var intended_guards: Array[Dictionary] = []
		if not time_lease.is_empty():
			glow.transform = intended_pose
			intended_guards = [_guard(glow), _guard(mesh), _guard(material)]
			created.append(glow)
		root.add_child(glow)
		if not time_lease.is_empty():
			if (
				not StadiumGrandIIIEnvironmentV1.installation_intact(lab, time_lease)
				or not is_instance_valid(root)
				or root.get_parent() != property
				or not is_instance_valid(glow)
				or glow.get_parent() != root
				or glow.get_script() != null
				or glow.mesh != mesh
				or glow.material_override != material
				or glow.get_child_count(true) != 0
				or not glow.get_meta_list().is_empty()
				or not is_instance_valid(row.head)
				or not _guards_match(intended_guards)
				or lab.get_viewport() != viewport
				or not _atlas_matches(viewport, before)
			):
				diagnose_guards(intended_guards, diagnostic_stage)
				_discard_time_root(root, property, created)
				if not time_lease.is_empty():
					StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
				return {}
		else:
			glow.transform = (
				row.head.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, GLOW_FORWARD))
			)
		row["glow"] = glow
		row["glow_pose"] = glow.transform
		row["glow_mesh"] = mesh
		row["glow_material"] = material
		row["glow_guards"] = [_guard(glow), _guard(mesh), _guard(material)]
		row["glow_appearance"] = {
			"shading": material.shading_mode,
			"albedo": material.albedo_color,
			"enabled": material.emission_enabled,
			"emission": material.emission,
			"energy": material.emission_energy_multiplier,
			"shadows": glow.cast_shadow
		}
	if (
		not time_lease.is_empty()
		and (
			not StadiumGrandIIIEnvironmentV1.installation_intact(lab, time_lease)
			or lab.get_viewport() != viewport
			or not _atlas_matches(viewport, before)
		)
	):
		_discard_time_root(root, property, created)
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	diagnostic_stage = "lights/atlas-commit"
	viewport.positional_shadow_atlas_size = 2048
	viewport.positional_shadow_atlas_16_bits = false
	for index in range(4):
		viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		)
	var lease: Dictionary = {
		"lab": weakref(lab),
		"property": property,
		"root": root,
		"viewport": viewport,
		"before": before,
		"lights": issued,
		"heads": heads,
		"towers": towers,
		"profile": PROFILE,
		"restored": false
	}
	if not time_lease.is_empty():
		lease["time_profile"] = true
	# Public diagnostics never own the expected operands. A shallow or deep dictionary
	# copy is not an issued lease; nested mutation cannot rewrite the private snapshot.
	_issued[lab.get_instance_id()] = {
		"lease": lease,
		"state": lease.duplicate(true),
		"pending": {},
		"restoring": false,
		"sun": sun,
		"match": lab._match_state
	}
	if not installed(lab, lease):
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, "lights/final-installed")
		restore(lab, lease)
		if not time_lease.is_empty():
			StadiumGrandIIIEnvironmentV1.diagnose_install(lab, diagnostic_stage)
		return {}
	return lease


static func installed(lab: PitchBatLab, issued_lease: Dictionary) -> bool:
	var lease: Dictionary = _state(lab, issued_lease)
	if (
		lease.is_empty()
		or issued_lease != lease
		or (lease.get("time_profile", false) and _issued[lab.get_instance_id()].restoring)
	):
		return false
	# Fixed four lights and 32 retained head/glow pairs. Whole-tree checks stay cold.
	if (
		lease.is_empty()
		or lease.get("restored", true)
		or not is_instance_valid(lab)
		or not lease.get("lab") is WeakRef
		or lease.lab.get_ref() != lab
		or not is_instance_valid(lease.get("property"))
		or not lease.get("property") is StadiumNpcPublicProperty
		or lease.property.venue_id != "GRAND-III"
		or lease.property.global_transform != Transform3D.IDENTITY
		or StadiumNpcPublicRuntime._property(lab) != lease.property
		or not is_instance_valid(lease.get("root"))
		or lease.root.get_parent() != lease.property
		or lease.property.get_node_or_null(ROOT) != lease.root
		or lease.root.get_script() != null
		or lease.root.transform != Transform3D.IDENTITY
		or not lease.root.visible
		or lease.root.top_level
		or lease.root.process_mode != Node.PROCESS_MODE_INHERIT
		or not lease.root.get_meta_list().is_empty()
		or lease.root.get_child_count(true) != 36
		or lease.lights.size() != 4
		or lease.heads.size() != 32
		or lease.towers.size() != 4
		or not is_instance_valid(lease.get("viewport"))
		or lab.get_viewport() != lease.viewport
		or lease.viewport.positional_shadow_atlas_size != 2048
		or lease.viewport.positional_shadow_atlas_16_bits
	):
		return false
	for index in range(4):
		if (
			lease.viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
			!= Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		):
			return false
	for index in range(4):
		var row: Dictionary = lease.lights[index]
		var light: SpotLight3D = row.node as SpotLight3D
		if (
			not is_instance_valid(light)
			or light.get_parent() != lease.root
			or light.get_script() != null
			or light.transform != row.pose
			or lease.root.get_child(index, true) != light
			or light.name != StringName(SITES[index])
			or light.get_child_count(true) != 0
			or not light.get_meta_list().is_empty()
			or not light.visible
			or light.top_level
			or _values(light, row.keys) != row.values
		):
			return false
	for index in range(4):
		var tower: Dictionary = lease.towers[index]
		if (
			not _matches(tower.tower_guard)
			or not _matches(tower.visual_guard)
			or tower.node.get_parent() != tower.parent
			or tower.visual.get_parent() != tower.node
			or lease.property.objects.get(PREFIX + SITES[index]) != tower.node
		):
			return false
	for index in range(32):
		var row: Dictionary = lease.heads[index]
		if (
			not is_instance_valid(row.tower)
			or row.tower.get_parent() != row.tower_parent
			or row.tower.transform != row.tower_pose
			or not row.tower.visible
			or not is_instance_valid(row.head)
			or row.head.get_parent() != row.head_parent
			or row.head.transform != row.head_pose
			or not row.head.visible
			or not is_instance_valid(row.lens)
			or row.lens.get_parent() != row.head
			or row.lens.transform != row.lens_pose
			or not row.lens.visible
			or row.lens.mesh != row.lens_mesh
			or row.lens.material_override != row.lens_material
			or row.lens_material.albedo_color != row.lens_albedo
			or not _guards_match(row.guards)
			or not _glow_installed(row, lease.root, index)
		):
			return false
	return true


static func _glow_installed(row: Dictionary, root: Node3D, index: int) -> bool:
	var glow: MeshInstance3D = row.glow as MeshInstance3D
	var mesh: QuadMesh = row.glow_mesh as QuadMesh
	var material: StandardMaterial3D = row.glow_material as StandardMaterial3D
	if (
		not _guards_match(row.glow_guards)
		or not is_instance_valid(glow)
		or not is_instance_valid(mesh)
		or not is_instance_valid(material)
	):
		return false
	var appearance: Dictionary = row.glow_appearance
	return (
		glow.get_parent() == root
		and root.get_child(index + 4, true) == glow
		and glow.name == StringName("Glow%02d" % index)
		and glow.get_script() == null
		and glow.get_child_count(true) == 0
		and glow.get_meta_list().is_empty()
		and glow.visible
		and not glow.top_level
		and glow.process_mode == Node.PROCESS_MODE_INHERIT
		and glow.transform == row.glow_pose
		and (
			glow.global_transform
			== row.head.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, GLOW_FORWARD))
		)
		and glow.mesh == mesh
		and mesh.get_script() == null
		and mesh.size == GLOW_SIZE
		and mesh.orientation == PlaneMesh.FACE_Z
		and mesh.center_offset == Vector3.ZERO
		and not mesh.flip_faces
		and mesh.subdivide_width == 0
		and mesh.subdivide_depth == 0
		and glow.material_override == material
		and material != row.lens_material
		and glow.material_overlay == null
		and glow.transparency == 0.0
		and material.get_script() == null
		and material.shading_mode == appearance.shading
		and material.albedo_color == appearance.albedo
		and material.emission_enabled == appearance.enabled
		and material.emission == appearance.emission
		and material.emission_energy_multiplier == appearance.energy
		and glow.cast_shadow == appearance.shadows
	)


static func restore(lab: PitchBatLab, issued_lease: Dictionary) -> bool:
	# Identity-bound cleanup uses private state even after public nested tampering.
	var lease: Dictionary = _state(lab, issued_lease)
	if lease.get("time_profile", false):
		return _restore_time(lab, issued_lease, lease)
	if lease.is_empty() or not is_instance_valid(lease.get("viewport")):
		return false
	var owners_match: bool = (
		is_instance_valid(lease.get("property"))
		and lease.property is StadiumNpcPublicProperty
		and lease.property.venue_id == "GRAND-III"
		and lab.get_viewport() == lease.viewport
	)
	if not lease.restored:
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
			lease.viewport.set_positional_shadow_atlas_quadrant_subdiv(
				index, lease.before.quadrants[index]
			)
		lease.restored = true
		issued_lease["restored"] = true
	for index in range(4):
		if (
			lease.viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
			!= lease.before.quadrants[index]
		):
			return false
	return (
		owners_match
		and lease.viewport.positional_shadow_atlas_size == lease.before.size
		and lease.viewport.positional_shadow_atlas_16_bits == lease.before.precision
	)


static func _state(lab: PitchBatLab, lease: Dictionary) -> Dictionary:
	if not is_instance_valid(lab) or not _issued.has(lab.get_instance_id()):
		return {}
	var entry: Dictionary = _issued[lab.get_instance_id()]
	if (
		not is_same(lease, entry.lease)
		or not entry.state.lab is WeakRef
		or entry.state.lab.get_ref() != lab
		or entry.state.profile != PROFILE
	):
		return {}
	return entry.state


static func _prune() -> void:
	# Cold admission housekeeping only. Freed labs cannot retain reusable lease authority.
	for key: int in _issued.keys():
		if not is_instance_valid(_issued[key].state.lab.get_ref()):
			_issued.erase(key)


static func _tower_rays(tower: Node3D, site: String, rays: Array[Dictionary]) -> bool:
	# All potentially absent metadata is guarded before access. Missing annotations
	# fail closed without null.get/Variant conversion errors.
	if (
		tower.get_script() != null
		or tower.top_level
		or not tower.visible
		or tower.process_mode != Node.PROCESS_MODE_INHERIT
		or tower.transform != StadiumGrandIIIVenueStudy.tower_pose(site)
		or not tower.has_meta("npc_head_rays")
		or not tower.has_meta("site")
		or not tower.has_meta("npc_instance")
		or not tower.has_meta("night_qualified")
		or not tower.has_meta("npc_lighting_preset")
		or not tower.has_meta("immutable_geometry_only")
	):
		return false
	if (
		tower.get_meta("site") != site
		or tower.get_meta("npc_instance") != PREFIX + site
		or tower.get_meta("npc_lighting_preset") != StadiumPremiumLightTowerSites.PRESET
		or not tower.get_meta("immutable_geometry_only") is bool
		or not tower.get_meta("immutable_geometry_only")
		or not tower.get_meta("night_qualified") is bool
		or tower.get_meta("night_qualified")
	):
		return false
	var declared: Variant = tower.get_meta("npc_head_rays")
	if not declared is Array or declared.size() != 8:
		return false
	for index in range(8):
		var row: Variant = declared[index]
		if (
			not row is Dictionary
			or row.size() != 3
			or not row.has("id")
			or not row.has("origin")
			or not row.has("direction")
			or not row.id is String
			or not row.origin is Vector3
			or not row.direction is Vector3
		):
			return false
		if (
			row.id != rays[index].id
			or not row.origin.is_finite()
			or not row.direction.is_finite()
			or not row.direction.is_normalized()
			or not row.origin.is_equal_approx(_vector(rays[index].origin))
			or not row.direction.is_equal_approx(_vector(rays[index].direction))
		):
			return false
	return true


static func _guard(object: Object) -> Dictionary:
	var keys: Array[StringName] = _light_keys(object)
	var metadata: Dictionary = {}
	for key: StringName in object.get_meta_list():
		metadata[key] = object.get_meta(key)
	return {
		"object": object,
		"keys": keys,
		"values": _values(object, keys),
		"metadata": metadata.duplicate(true)
	}


static func _matches(guard: Dictionary) -> bool:
	var object: Object = guard.object
	if (
		not is_instance_valid(object)
		or object.get_script() != null
		or object.get_meta_list().size() != guard.metadata.size()
	):
		return false
	for key: StringName in guard.metadata:
		if not object.has_meta(key) or object.get_meta(key) != guard.metadata[key]:
			return false
	return _values(object, guard.keys) == guard.values


static func _guards_match(guards: Array) -> bool:
	for guard: Dictionary in guards:
		if not _matches(guard):
			return false
	return true


static func _light_keys(light: Object) -> Array[StringName]:
	# Capture the native light's bounded stored operands once, including default shadow/fade flags.
	# Scriptless native class membership cannot grow without the ownership guard rejecting it.
	var result: Array[StringName] = []
	for description: Dictionary in light.get_property_list():
		if (int(description.usage) & PROPERTY_USAGE_STORAGE) != 0:
			result.append(StringName(description.name))
	return result


static func _values(light: Object, keys: Array[StringName]) -> Array:
	var result: Array = []
	for key: StringName in keys:
		result.append(light.get(key))
	return result.duplicate(true)


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func update_time(
	lab: PitchBatLab, lease: Dictionary, environment_lease: Dictionary, fraction: float
) -> bool:
	var state: Dictionary = _state(lab, lease)
	if (
		not state.get("time_profile", false)
		or not is_finite(fraction)
		or fraction < 0.0
		or fraction > 1.0
		or not StadiumGrandIIIEnvironmentV1.lamp_write_intact(
			lab, environment_lease, lease, fraction
		)
	):
		return false
	for index in range(4):
		var value: float = PackedFloat32Array([ENERGY * fraction])[0]
		if not _write_time_value(
			lab,
			lease,
			environment_lease,
			fraction,
			state.lights[index].node,
			&"light_energy",
			value,
			index,
			false
		):
			return false
	for index in range(32):
		var color: Color = Color(
			GLOW_COLOR.r * fraction, GLOW_COLOR.g * fraction, GLOW_COLOR.b * fraction, 1.0
		)
		if (
			not _write_time_value(
				lab,
				lease,
				environment_lease,
				fraction,
				state.heads[index].glow_material,
				&"albedo_color",
				color,
				index,
				true
			)
			or not _write_time_value(
				lab,
				lease,
				environment_lease,
				fraction,
				state.heads[index].glow_material,
				&"emission_energy_multiplier",
				PackedFloat32Array([GLOW_ENERGY * fraction])[0],
				index,
				true
			)
		):
			return false
	return StadiumGrandIIIEnvironmentV1.lamp_write_intact(lab, environment_lease, lease, fraction)


static func _write_time_value(
	lab: PitchBatLab,
	lease: Dictionary,
	environment_lease: Dictionary,
	fraction: float,
	object: Object,
	field: StringName,
	value: Variant,
	index: int,
	glow: bool
) -> bool:
	if not StadiumGrandIIIEnvironmentV1.lamp_write_intact(lab, environment_lease, lease, fraction):
		StadiumGrandIIIEnvironmentV1.diagnose_install(
			lab, "lights/pre-write/%s/%d/%s" % [glow, index, field]
		)
		return false
	var state: Dictionary = _state(lab, lease)
	# Only these issued energy/albedo operands may change. Every other stored native value remains
	# pinned.
	for target: Dictionary in [state, lease]:
		if glow:
			var row: Dictionary = target.heads[index]
			var guard: Dictionary = row.glow_guards[2]
			var appearance_field: String = "albedo" if field == &"albedo_color" else "energy"
			# Native unshaded emission energy is not a STORAGE key; its explicit issued value is still exact.
			if (
				guard.object != object
				or field not in [&"albedo_color", &"emission_energy_multiplier"]
				or (field == &"albedo_color" and not guard.keys.has(field))
				or object.get(field) != row.glow_appearance[appearance_field]
			):
				return false
			if guard.keys.has(field):
				guard.values[guard.keys.find(field)] = value
			row.glow_appearance[appearance_field] = value
		else:
			var row: Dictionary = target.lights[index]
			if row.node != object or field != &"light_energy" or not row.keys.has(field):
				return false
			row.values[row.keys.find(field)] = value
	var entry: Dictionary = _issued[lab.get_instance_id()]
	entry.pending = {"object": object, "field": field, "value": value}
	object.set(field, value)
	var valid_write: bool = StadiumGrandIIIEnvironmentV1.lamp_write_intact(
		lab, environment_lease, lease, fraction
	)
	if not valid_write:
		StadiumGrandIIIEnvironmentV1.diagnose_install(
			lab, "lights/post-write/%s/%d/%s" % [glow, index, field]
		)
		if glow:
			diagnose_guards(state.heads[index].glow_guards, "lights/post-write")
		else:
			diagnose_values(
				object, state.lights[index].keys, state.lights[index].values, "lights/post-write"
			)
	entry.pending = {}
	return valid_write


static func owns_dynamic_resource(lab: PitchBatLab, lease: Dictionary, resource: Resource) -> bool:
	var state: Dictionary = _state(lab, lease)
	if not state.get("time_profile", false) or state.restored:
		return false
	for row: Dictionary in state.heads:
		if row.glow_material == resource:
			return true
	return false


static func dynamic_resource_change(
	lab: PitchBatLab, lease: Dictionary, resource: Resource
) -> bool:
	var state: Dictionary = _state(lab, lease)
	if not state.get("time_profile", false) or not installed(lab, lease):
		return false
	var pending: Dictionary = _issued[lab.get_instance_id()].pending
	return (
		not pending.is_empty()
		and pending.object == resource
		and resource.get(pending.field) == pending.value
	)


static func _restore_time(lab: PitchBatLab, lease: Dictionary, state: Dictionary) -> bool:
	var entry: Dictionary = _issued[lab.get_instance_id()]
	if entry.restoring:
		return false
	if state.restored:
		return time_restored(lab, lease)
	if (
		not is_instance_valid(state.property)
		or state.property.get_script() != StadiumNpcPublicProperty
		or lab._match_state != entry.match
		or state.property.bound_state != entry.match
		or not installed(lab, lease)
	):
		return false
	entry.restoring = true
	var restored: bool = _restore_time_owned(lab, lease, state, entry.sun)
	entry.restoring = false
	return restored


static func _restore_time_owned(
	lab: PitchBatLab, lease: Dictionary, state: Dictionary, sun: Node
) -> bool:
	var property: StadiumNpcPublicProperty = state.property
	var root: Node3D = state.root
	var match_state: MatchState = lab._match_state
	var viewport: Viewport = state.viewport
	# Exact issued atlas values remain authoritative across both synchronous tree transitions.
	var expected: Dictionary = {
		"size": 2048,
		"precision": false,
		"quadrants":
		[
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		]
	}
	property.remove_child(root)
	if (
		not _time_cleanup_owner(lab, property, match_state, viewport, sun)
		or not _detached_time_root(root, _time_children(state))
		or not _atlas_matches(viewport, expected)
	):
		return false
	root.free()
	if (
		not _time_cleanup_owner(lab, property, match_state, viewport, sun)
		or not _atlas_matches(viewport, expected)
	):
		return false
	viewport.positional_shadow_atlas_size = state.before.size
	expected.size = state.before.size
	if (
		not _time_cleanup_owner(lab, property, match_state, viewport, sun)
		or not _atlas_matches(viewport, expected)
	):
		return false
	viewport.positional_shadow_atlas_16_bits = state.before.precision
	expected.precision = state.before.precision
	for index in range(4):
		if (
			not _time_cleanup_owner(lab, property, match_state, viewport, sun)
			or not _atlas_matches(viewport, expected)
		):
			return false
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index, state.before.quadrants[index])
		expected.quadrants[index] = state.before.quadrants[index]
	if (
		not _time_cleanup_owner(lab, property, match_state, viewport, sun)
		or not _atlas_matches(viewport, expected)
	):
		return false
	state.restored = true
	lease.restored = true
	return true


static func _time_cleanup_owner(
	lab: Variant, property: Variant, match_state: MatchState, viewport: Variant, sun: Variant
) -> bool:
	if (
		not is_instance_valid(lab)
		or lab.is_queued_for_deletion()
		or lab._match_state != match_state
		or not is_instance_valid(property)
		or property.is_queued_for_deletion()
		or property.get_script() != StadiumNpcPublicProperty
		or StadiumNpcPublicRuntime._property(lab) != property
		or not is_instance_valid(viewport)
		or lab.get_viewport() != viewport
		or property.get_node_or_null(ROOT) != null
		or not is_instance_valid(sun)
	):
		return false
	var lights: Array[Node] = lab.find_children("*", "Light3D", true, false)
	return (
		lights.size() == 1
		and lights[0] == sun
		and lab.get_node_or_null("StarterFieldGeometry/Sun") == sun
	)


static func _atlas_matches(viewport: Viewport, expected: Dictionary) -> bool:
	return Operations1._atlas_matches(viewport, expected)


static func _time_children(state: Dictionary) -> Array:
	return Operations1._time_children(state)


static func _detached_time_root(root: Variant, children: Array) -> bool:
	return Operations1._detached_time_root(root, children)


static func _discard_time_root(root: Variant, property: Variant, children: Array) -> void:
	Operations1._discard_time_root(root, property, children)


static func time_restored(lab: PitchBatLab, lease: Dictionary) -> bool:
	return Operations1._public_time_restored(lab, lease)


static func diagnose_guards(guards: Array, stage: String) -> bool:
	return Operations1._public_diagnose_guards(guards, stage)


static func diagnose_values(object: Object, keys: Array, expected: Array, stage: String) -> bool:
	return Operations1._public_diagnose_values(object, keys, expected, stage)
