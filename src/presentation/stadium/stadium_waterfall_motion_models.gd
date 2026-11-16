class_name StadiumWaterfallMotionModels
extends RefCounted
## Explicit opt-in presentation variant. The frozen static factory stays unchanged.
const VERSION: int = 1
const WATER: Array[String] = [
	"Pool",
	"UpperWater",
	"LowerWater",
	"Foam",
	"UpperRillA",
	"UpperRillB",
	"LowerRillA",
	"LowerRillB"
]
const CODE: String = """shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 base_color : source_color;
uniform float phase = 0.0;
varying float water_height;
void vertex() {
 water_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
 float flow = sin(water_height * 18.849556 + phase * 6.283185);
 float cross_ripple = sin(UV.x * 18.849556 - phase * 6.283185);
 ALBEDO = base_color.rgb * (0.96 + 0.035 * flow + 0.015 * cross_ripple);
 ROUGHNESS = 0.85;
}
"""


static func create() -> Node3D:
	var root: Node3D = StadiumWaterfallModels.create()
	root.set_meta("water_motion_version", VERSION)
	for id: String in WATER:
		var material: ShaderMaterial = ShaderMaterial.new()
		var shader: Shader = Shader.new()
		shader.code = CODE
		material.shader = shader
		material.set_shader_parameter("base_color", Color(StadiumWaterfallModels.PARTS[id][2]))
		material.set_shader_parameter("phase", 0.0)
		root.get_node(id).material_override = material
	return root


static func valid(root: Node3D, phase: float) -> bool:
	if (
		root == null
		or root.get_class() != "Node3D"
		or not StadiumWaterfallModels._clean(root)
		or root.get_child_count() != StadiumWaterfallModels.PARTS.size()
		or not is_finite(phase)
		or phase < 0
		or phase >= 1.0
	):
		return false
	for pair: Array in [
		["stadium_item", TYPE_STRING, "ST-046"],
		["working_geometry_only", TYPE_BOOL, true],
		["geometry_version", TYPE_INT, 1],
		["obstacle_units", TYPE_INT, 0],
		["night_qualified", TYPE_BOOL, false],
		["water_motion_version", TYPE_INT, VERSION]
	]:
		if not StadiumWaterfallModels._meta(root, pair[0], pair[1], pair[2]):
			return false
	for id: String in StadiumWaterfallModels.PARTS:
		var part: MeshInstance3D = root.get_node_or_null(id) as MeshInstance3D
		if (
			part == null
			or not StadiumWaterfallModels._clean(part)
			or part.get_child_count() != 0
			or part.transform != Transform3D(Basis.IDENTITY, StadiumWaterfallModels.PARTS[id][0])
			or not part.mesh is BoxMesh
			or part.mesh.size != StadiumWaterfallModels.PARTS[id][1]
			or part.mesh.get_script() != null
			or part.mesh.flip_faces
			or part.mesh.subdivide_width != 0
			or part.mesh.subdivide_height != 0
			or part.mesh.subdivide_depth != 0
			or part.mesh.material != null
			or part.material_overlay != null
			or part.get_surface_override_material(0) != null
			or part.layers != 1
			or part.transparency != 0.0
			or not StadiumWaterfallModels._render_state(part)
		):
			return false
		if id not in WATER:
			if not StadiumWaterfallModels._material(
				part.material_override, Color(StadiumWaterfallModels.PARTS[id][2])
			):
				return false
		else:
			var material: ShaderMaterial = part.material_override as ShaderMaterial
			if (
				material == null
				or material.get_script() != null
				or material.next_pass != null
				or material.render_priority != 0
				or material.shader == null
				or material.shader.get_script() != null
				or material.shader.code != CODE
				or (
					material.get_shader_parameter("base_color")
					!= Color(StadiumWaterfallModels.PARTS[id][2])
				)
				or material.get_shader_parameter("phase") != phase
			):
				return false
	return true
