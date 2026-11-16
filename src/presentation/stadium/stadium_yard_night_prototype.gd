class_name StadiumYardNightPrototype
extends RefCounted
## Readability candidate only. Does not grant lights, alter saves or schedule night fixtures.

const VERSION: int = 1


static func apply(lab: PitchBatLab) -> void:
	apply_scene(lab, lab._world_environment.environment,
		lab.get_node("StarterFieldGeometry/Sun"))


static func apply_scene(owner: Node, environment: Environment, sun: DirectionalLight3D) -> void:
	_shadow_profile(owner)
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("14263d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("92acc9")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	sun.light_color = Color("93accb")
	sun.light_energy = 0.28


static func coverage(point: Vector3, lamps: Array[Node3D]) -> int:
	var count: int = 0
	for lamp: Node3D in lamps:
		var beam: SpotLight3D = lamp.get_node("FieldLight")
		var delta: Vector3 = point - beam.global_position
		if delta.length() > beam.spot_range or delta.length() < 0.001:
			continue
		var alignment: float = (-beam.global_basis.z).dot(delta.normalized())
		if alignment < cos(deg_to_rad(beam.spot_angle)):
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			beam.global_position, point, 1)
		if lamp.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			count += 1
	return count


static func _shadow_profile(lab: Node) -> void:
	if lab.has_meta("yard_shadow_profile"):
		return
	var viewport: Viewport = lab.get_viewport()
	var previous: Dictionary = {"precision": viewport.positional_shadow_atlas_16_bits,
		"size": viewport.positional_shadow_atlas_size, "quadrants": []}
	for index in range(4):
		previous.quadrants.append(viewport.get_positional_shadow_atlas_quadrant_subdiv(index))
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index,
			Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1)
	viewport.positional_shadow_atlas_size = 2048
	viewport.positional_shadow_atlas_16_bits = false
	lab.set_meta("yard_shadow_profile", true)
	lab.tree_exited.connect(_restore_shadows.bind(viewport, previous), CONNECT_ONE_SHOT)


static func _restore_shadows(viewport: Viewport, previous: Dictionary) -> void:
	if not is_instance_valid(viewport):
		return
	viewport.positional_shadow_atlas_size = previous.size
	viewport.positional_shadow_atlas_16_bits = previous.precision
	for index in range(4):
		viewport.set_positional_shadow_atlas_quadrant_subdiv(index, previous.quadrants[index])
