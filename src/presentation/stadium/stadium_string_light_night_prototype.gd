class_name StadiumStringLightNightPrototype
extends Node3D
## Dormant DG1 lighting study. Never called by production or used for admission.
## Complete physical installation is necessary, not sufficient, for Night qualification.

const VERSION: int = 1
const CANDIDATE: String = "CANDIDATE_UNMEASURED"
const LEASE_GROUP: StringName = &"dg1_string_night_study_lease"
const SPAN_ENERGY: float = 0.40
const SPAN_RANGE: float = 65.0
const SPAN_ANGLE: float = 78.0

var profile: String = ""
var active: bool = false
var sources: Array[SpotLight3D] = []
var _installation: Node3D
var _spans: Array[Node3D] = []
var _poles: Array[Node3D] = []
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _source_environment: Environment
var _source_sun: Dictionary = {}
var _source_viewport: Dictionary = {}
var _materials: Array[Dictionary] = []
var _pole_lights: Array[Dictionary] = []
var _viewport: Viewport


static func install(
	installation: Node3D,
	world_environment: WorldEnvironment,
	sun: DirectionalLight3D,
	spans: Array[Node3D],
	poles: Array[Node3D] = []
) -> StadiumStringLightNightPrototype:
	var checked: Dictionary = inspect_installation(installation, spans, poles)
	if (
		not checked.ok
		or not is_instance_valid(world_environment)
		or world_environment.environment == null
		or not is_instance_valid(sun)
		or not world_environment.is_inside_tree()
		or not sun.is_inside_tree()
	):
		return null
	for child: Node in installation.get_children():
		if child is StadiumStringLightNightPrototype:
			return null  # Never overlap environment/viewport leases.
	var rig: StadiumStringLightNightPrototype = StadiumStringLightNightPrototype.new()
	rig.name = "DG1StringLightNightStudy"
	rig.profile = checked.profile
	rig._installation = installation
	rig._world_environment = world_environment
	rig._sun = sun
	rig._spans = spans.duplicate()
	rig._poles = poles.duplicate()
	rig.set_meta("qualification_status", CANDIDATE)
	rig.set_meta("night_qualified", false)
	rig.set_meta("grants_inventory", false)
	installation.add_child(rig)
	rig.add_to_group(LEASE_GROUP)
	for span: Node3D in spans:
		var source: SpotLight3D = SpotLight3D.new()
		source.name = "BroadSpan_" + str(span.get_meta("site"))
		source.set_meta("installed_source", span.get_path())
		source.set_meta("owned_copy", span.get_meta("owned_copy"))
		source.set_meta("site", span.get_meta("site"))
		source.set_meta("source_kind", "one_broad_source_per_span")
		source.light_color = Color("ffe4c2")
		source.light_energy = SPAN_ENERGY
		source.light_size = 0.45
		source.spot_range = SPAN_RANGE
		source.spot_angle = SPAN_ANGLE
		source.spot_attenuation = 0.65
		source.spot_angle_attenuation = 0.7
		source.shadow_enabled = true
		source.shadow_bias = 0.05
		source.shadow_normal_bias = 0.2
		source.visible = false
		rig.add_child(source)
		# Exact installed span midpoint, not an unrelated invisible floodlight tower.
		source.global_position = span.to_global(StadiumStringLightModels.cable_point(0.5))
		source.look_at(installation.to_global(Vector3(0, 3, 12)))
		rig.sources.append(source)
	for pole: Node3D in poles:
		rig.sources.append(pole.get_node("FieldLight"))
	if not rig.set_night(true):
		rig.free()
		return null
	return rig


static func inspect_installation(
	installation: Node3D, spans: Array[Node3D], poles: Array[Node3D]
) -> Dictionary:
	var refused: Dictionary = {"ok": false, "profile": "", "night_qualified": false}
	if (
		not is_instance_valid(installation)
		or not installation.is_inside_tree()
		or not installation.global_basis.get_scale().is_equal_approx(Vector3.ONE)
		or not is_equal_approx(installation.global_basis.determinant(), 1.0)
	):
		return refused
	var copies: Array[String] = []
	var string_rows: Array = []
	var pole_rows: Array = []
	var listed: Array[Node3D] = []
	listed.append_array(spans)
	listed.append_array(poles)
	for model: Node3D in listed:
		if (
			not is_instance_valid(model)
			or model.get_parent() != installation
			or not model.is_inside_tree()
		):
			return refused
		var copy: String = str(model.get_meta("owned_copy", ""))
		var site: String = str(model.get_meta("site", ""))
		if (
			copy.is_empty()
			or copy != str(model.get_meta("paid_copy", ""))
			or copies.has(copy)
			or not model.has_node("Visual")
			or not model.has_node("Collision")
		):
			return refused
		copies.append(copy)
		if spans.has(model):
			if (
				model.get_meta("stadium_item", "") != "ST-036"
				or not StadiumStringLightModels.SITES.has(site)
				or not model.transform.is_equal_approx(StadiumStringLightModels.pose(site))
				or not _whole_span(model)
				or not model.find_children("*", "Light3D", true, false).is_empty()
				or model.get_node("Collision").get_child_count() != 6
			):
				return refused
			string_rows.append({"site": site})
		else:
			if (
				model.get_meta("stadium_item", "") != "ST-037"
				or not site in ["YLIGHT-RL", "YLIGHT-RR"]
				or not model.has_node("FieldLight")
				or not model.get_node("FieldLight") is SpotLight3D
				or not model.has_node("Visual/LampLens")
				or not model.get_node("Visual/LampLens").material_override is StandardMaterial3D
				or model.get_node("Visual").get_child_count() != 6
				or model.get_node("Collision").get_child_count() != 5
			):
				return refused
			var expected: Node3D = StadiumYardLightModels.create()
			StadiumYardLightModels.place(expected, site)
			var exact: bool = (
				model.transform.is_equal_approx(expected.transform)
				and model.get_node("FieldLight").transform.is_equal_approx(
					expected.get_node("FieldLight").transform
				)
			)
			expected.free()
			if not exact:
				return refused
			pole_rows.append({"site": site})
	for child: Node in installation.get_children():
		if child.get_meta("stadium_item", "") in ["ST-036", "ST-037"] and not listed.has(child):
			return refused  # Supplying a subset cannot hide a conflicting extra assembly.
	var complete: String = StadiumStringLightItems.complete_profile(string_rows, pole_rows)
	return {"ok": not complete.is_empty(), "profile": complete, "night_qualified": false}


static func _whole_span(model: Node3D) -> bool:
	if (
		model.get_meta("model_version", -1) != StadiumStringLightModels.VERSION
		or model.get_meta("included_supports", 0) != 2
		or model.get_child_count() != 2
		or model.get_node("Visual").get_child_count() != 104
		or model.get_node("Visual").transform != Transform3D.IDENTITY
		or model.get_node("Collision").transform != Transform3D.IDENTITY
	):
		return false
	for pair: Array in [
		["Cable*", 56], ["Bulb*", 14], ["Dropper*", 14], ["Socket*", 14], ["Post*", 6]
	]:
		if (
			model.get_node("Visual").find_children(pair[0], "MeshInstance3D", false, false).size()
			!= pair[1]
		):
			return false
	for bulb: MeshInstance3D in model.get_node("Visual").find_children(
		"Bulb*", "MeshInstance3D", false, false
	):
		if not bulb.material_override is StandardMaterial3D:
			return false
	return true


func set_night(enabled: bool) -> bool:
	if not enabled:
		restore()
		return true
	if (
		not inspect_installation(_installation, _spans, _poles).ok
		or not is_instance_valid(_world_environment)
		or not is_instance_valid(_sun)
	):
		restore()
		return false
	for other: Node in get_tree().get_nodes_in_group(LEASE_GROUP):
		if (
			other != self
			and other.active
			and (
				other._viewport == get_viewport()
				or other._world_environment == _world_environment
				or other._sun == _sun
			)
		):
			restore()
			return false
	if active:
		return true
	_source_environment = _world_environment.environment
	if _source_environment == null:
		return false
	_source_sun = {"color": _sun.light_color, "energy": _sun.light_energy}
	_viewport = get_viewport()
	_source_viewport = {
		"size": _viewport.positional_shadow_atlas_size,
		"precision": _viewport.positional_shadow_atlas_16_bits,
		"quadrants": []
	}
	for index in range(4):
		_source_viewport.quadrants.append(
			_viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
		)
		_viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4
		)
	_viewport.positional_shadow_atlas_size = 2048
	_viewport.positional_shadow_atlas_16_bits = false
	var study: Environment = _source_environment.duplicate(true)
	study.background_mode = Environment.BG_COLOR
	study.background_color = Color("14263d")
	study.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	study.ambient_light_color = Color("92acc9")
	study.ambient_light_energy = 0.52
	study.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	study.glow_enabled = false
	_world_environment.environment = study
	_sun.light_color = Color("93accb")
	_sun.light_energy = 0.28
	for span: Node3D in _spans:
		for bulb: MeshInstance3D in span.get_node("Visual").find_children(
			"Bulb*", "MeshInstance3D", true, false
		):
			_emissive_copy(bulb)
	for pole: Node3D in _poles:
		var light: SpotLight3D = pole.get_node("FieldLight")
		_pole_lights.append({"node": light, "visible": light.visible})
		_emissive_copy(pole.get_node("Visual/LampLens"))
	for source: SpotLight3D in sources:
		source.visible = true
	active = true
	return true


func _emissive_copy(mesh: MeshInstance3D) -> void:
	_materials.append({"node": mesh, "material": mesh.material_override})
	var copy: StandardMaterial3D = mesh.material_override.duplicate(true)
	copy.emission_enabled = true
	copy.emission_energy_multiplier = 0.8
	mesh.material_override = copy


func restore() -> void:
	if not active:
		return
	active = false
	for source: SpotLight3D in sources:
		if is_instance_valid(source):
			source.visible = false
	for saved: Dictionary in _pole_lights:
		if is_instance_valid(saved.node):
			saved.node.visible = saved.visible
	for saved: Dictionary in _materials:
		if is_instance_valid(saved.node):
			saved.node.material_override = saved.material
	_pole_lights.clear()
	_materials.clear()
	if is_instance_valid(_world_environment):
		_world_environment.environment = _source_environment
	if is_instance_valid(_sun):
		_sun.light_color = _source_sun.color
		_sun.light_energy = _source_sun.energy
	if is_instance_valid(_viewport):
		_viewport.positional_shadow_atlas_size = _source_viewport.size
		_viewport.positional_shadow_atlas_16_bits = _source_viewport.precision
		for index in range(4):
			_viewport.set_positional_shadow_atlas_quadrant_subdiv(
				index, _source_viewport.quadrants[index]
			)


func coverage(point: Vector3) -> int:
	# Finite open-beam geometric evidence only, not lux, contrast or Night qualification.
	if not active or not is_inside_tree() or not point.is_finite():
		return 0
	var count: int = 0
	for source: SpotLight3D in sources:
		if (
			not is_instance_valid(source)
			or not source.is_visible_in_tree()
			or source.light_energy <= 0
		):
			continue
		var delta: Vector3 = point - source.global_position
		if (
			delta.length() > source.spot_range
			or delta.length() < 0.001
			or (-source.global_basis.z).dot(delta.normalized()) < cos(deg_to_rad(source.spot_angle))
		):
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			source.global_position, point, 1
		)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			count += 1
	return count


func _exit_tree() -> void:
	restore()
