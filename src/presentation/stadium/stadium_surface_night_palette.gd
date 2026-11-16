class_name StadiumSurfaceNightPalette
extends RefCounted
## Candidate-only night palette. No existing saved layout calls this automatically.

const VERSION: int = 1
const PLATE_SAND_FACTOR: float = 0.6


static func apply(property: Node3D, night: bool = true) -> bool:
	if property == null:
		return false
	var ground: Node3D = property.get_node_or_null("OwnedSurfaceFinish/GroundTreatment")
	if ground == null or ground.get_meta("ground_style", "") != "ST-063i":
		return false
	var mesh: MeshInstance3D = ground.get_node_or_null("SurfaceVisual")
	var material: ShaderMaterial = mesh.material_override as ShaderMaterial if mesh != null else null
	if material == null:
		return false
	if not material.has_meta("surface_day_pigment"):
		var original: float = material.get_shader_parameter("vertex_pigment_scale")
		if not is_finite(original) or original <= 0:
			return false
		material.set_meta("surface_day_pigment", original)
	var baseline: float = material.get_meta("surface_day_pigment")
	material.set_shader_parameter("vertex_pigment_scale", baseline * (
		PLATE_SAND_FACTOR if night else 1.0))
	return true
