extends Node3D
## Original visible surface coverage, stable grass placement and appearance-only boundaries.

var _failures: int = 0


func _ready() -> void:
	var helper: Node = load("res://src/tests/stadium_recipe_field_test.gd").new()
	var grounds: Array[String] = [""]
	grounds.append_array(StadiumGroundModels.IDS)
	grounds.append_array(StadiumInfieldModels.IDS)
	var graphs: Array[StadiumRecipeBoundary] = [StadiumRecipeBoundary.create("straight"),
		StadiumRecipeBoundary.create("deeper_center"), StadiumOffsetBoundary.new()]
	var samples: int = 0
	for graph: StadiumRecipeBoundary in graphs:
		var baseline: Dictionary = {}
		for ground: String in grounds:
			var root: Node3D = StadiumSurfaceFinish.build(graph, "grass", "short", "ST-063b", ground)
			_check(root != null, "complete independent appearance channels")
			var masks: Array = StadiumInfieldModels.masks(ground) if (
				StadiumInfieldModels.IDS.has(ground)) else StadiumGroundModels.masks(ground)
			helper._measure(root.get_node("Surface"), graph, masks)
			var transforms: Array = root.get_node("GrassTufts").get_meta("authored_transforms")
			_check(transforms.size() > 5000 and transforms.size() < 26000,
				"bounded full-field tuft budget")
			for transform: Transform3D in transforms:
				var point: Vector2 = Vector2(transform.origin.x, transform.origin.z)
				_check(graph.contains(point) and not StadiumGrassFinish._inside(point, masks),
					"visible tufts remain in real grass, outside dirt cuts")
				var cell: Vector2i = Vector2i(floori(point.x / StadiumGrassFinish.SPACING),
					floori(point.y / StadiumGrassFinish.SPACING))
				if ground.is_empty():
					_check(not baseline.has(cell), "one stable tuft per cell")
					baseline[cell] = transform
				else:
					_check(baseline.has(cell) and baseline[cell].is_equal_approx(transform),
						"cutting dirt never regenerates the remaining grass")
			_check(root.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"finish has no collision or gameplay surface")
			if ground == "ST-063j":
				var rake: MeshInstance3D = root.get_node("InfieldTreatment/SurfaceVisual")
				_check(is_equal_approx(rake.material_override.get_shader_parameter(
					"vertex_pigment_scale"), 0.6), "raked dirt retains readable earth-tone palette")
			root.free()
			samples += 1
		for foundation: String in ["rough_dirt", "maintained_dirt"]:
			var dirt: Node3D = StadiumSurfaceFinish.build(graph, foundation, "short", "")
			helper._measure(dirt.get_node("Surface"), graph, [])
			_check(not dirt.has_node("GrassTufts"), "all-dirt foundation is genuinely grass-free")
			dirt.free()
	_check(helper._failures == 0 and samples == 21, "all three shapes and seven dirt choices fit")
	helper.free()
	_heights()
	var texture: ImageTexture = StadiumSurfaceTexture.texture()
	var image: Image = texture.get_meta("source_image")
	_check(image.get_size() == Vector2i(128, 128) and image.has_mipmaps(),
		"original seamless texture has distance filtering")
	_check(StadiumSurfaceTexture.texture() == texture, "immutable texture is shared, not regenerated")
	_check(StadiumSurfaceFinish.build(graphs[0], "slope", "short", "") == null
		and StadiumSurfaceFinish.build(graphs[0], "grass", "absurd", "") == null
		and StadiumSurfaceFinish.build(graphs[0], "grass", "short", "invented") == null,
		"unknown terrain, lengths and patterns never silently activate")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro surface finish checks passed: "
			+ "exact coverage, stable tufts and no physics change.")
	get_tree().quit(0 if _failures == 0 else 1)


func _heights() -> void:
	var polygon: PackedVector2Array = [Vector2(2, 7), Vector2(4, 7), Vector2(4, 9), Vector2(2, 9)]
	var origins: Array[Vector3] = []
	for length: String in StadiumGrassFinish.HEIGHTS:
		var blades: MultiMeshInstance3D = StadiumGrassFinish.create(polygon, [], length)
		var transforms: Array = blades.get_meta("authored_transforms")
		_check(transforms.size() > 50 and transforms.size() < 120, "restrained local tuft density")
		var height: float = StadiumGrassFinish.HEIGHTS[length]
		for index in range(transforms.size()):
			var transform: Transform3D = transforms[index]
			_check(transform.basis.get_scale().y >= height * 0.8 - 0.00001
				and transform.basis.get_scale().y <= height + 0.00001,
				"every blade retains the fixed restrained height envelope")
			if length == "very_short":
				origins.append(transform.origin)
			else:
				_check(index < origins.size() and origins[index] == transform.origin,
					"mowing height changes length, not the whole grass distribution")
			if DisplayServer.get_name() != "headless":
				_check(blades.multimesh.get_instance_transform(index).is_equal_approx(transform),
					"native instancing matches the exact authored blades")
		blades.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
