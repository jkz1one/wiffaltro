class_name StadiumSurfaceFinish
extends RefCounted
## Isolated appearance layer. No owned entitlement, collision change or starter migration.

const PATTERNS: Dictionary = {"": 0, "ST-063a": 1, "ST-063b": 2, "ST-063c": 3, "ST-063d": 4}


static func build(graph: StadiumRecipeBoundary, foundation: String,
	length: String, pattern: String, ground: String = "") -> Node3D:
	if graph == null or foundation not in ["rough_dirt", "maintained_dirt", "grass"] \
		or not StadiumGrassFinish.HEIGHTS.has(length) or not PATTERNS.has(pattern):
		return null
	if not ground.is_empty() and not StadiumGroundModels.IDS.has(ground) \
		and not StadiumInfieldModels.IDS.has(ground):
		return null
	var root: Node3D = Node3D.new()
	root.name = "SurfaceFinishPrototype"
	root.set_meta("foundation", foundation)
	root.set_meta("grass_length", length)
	root.set_meta("mowing_pattern", pattern)
	root.set_meta("ground_cut", ground)
	var dirt: bool = foundation != "grass"
	var masks: Array = [] if dirt else (StadiumInfieldModels.masks(ground) if (
		StadiumInfieldModels.IDS.has(ground)) else StadiumGroundModels.masks(ground))
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polygon: PackedVector2Array = graph.polygon()
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	for index in range(0, triangles.size(), 3):
		var triangle: PackedVector2Array = [polygon[triangles[index]],
			polygon[triangles[index + 1]], polygon[triangles[index + 2]]]
		for piece: PackedVector2Array in StadiumSurfaceMask.subtract(triangle, masks):
			StadiumRecipeFieldStyles._polygon(surface, piece, Color.WHITE, 0.004)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Surface"
	mesh.mesh = surface.commit()
	mesh.material_override = StadiumSurfaceTexture.material(dirt,
		foundation == "rough_dirt", StadiumGrassFinish.HEIGHTS[length], PATTERNS[pattern])
	root.add_child(mesh)
	if not dirt:
		root.add_child(StadiumGrassFinish.create(graph.polygon(), masks, length))
		if not ground.is_empty():
			var treatment: Node3D = StadiumInfieldModels.create(ground) if (
				StadiumInfieldModels.IDS.has(ground)) else StadiumGroundModels.create(ground)
			for dirt_mesh: MeshInstance3D in treatment.find_children("*", "MeshInstance3D", true, false):
				var material: ShaderMaterial = StadiumSurfaceTexture.material(true, false, 0, 0)
				material.set_shader_parameter("use_vertex_color", true)
				# Pale rake marks need a restrained earth tone for the unchanged white ball.
				material.set_shader_parameter("vertex_pigment_scale", 0.6 if ground == "ST-063j" else 1.0)
				dirt_mesh.material_override = material
			root.add_child(treatment)
	return root
