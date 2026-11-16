extends Node3D

var _failures: int = 0
var _capture_dir: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	if not _capture_dir.is_empty():
		get_window().size = Vector2i(1280, 720)
	for material: String in StadiumWallRecipes.BACK_IDS:
		await _material(material)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro advanced owned properties passed: exact assemblies and independent surfaces."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _material(material: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var progress: Dictionary = {"seasons": 50, "wins": 200}
	for id: String in [material, "ST-022"]:
		stock = StadiumStock.from_data(
			stock.quote(id, 27 if id == material else 19, progress, id).state
		)
	stock.styles.assign(["ST-063b", "ST-063g"])
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	for height: String in ["low", "tall"]:
		pieces = StadiumWallPieceOwnership.from_data(
			(
				pieces
				. quote(
					StadiumWallPieceCatalog.identity(material, height),
					12,
					height,
					progress,
					stock.copies.size()
				)
				. state
			),
			stock.copies.size()
		)
	var stock_before: Dictionary = stock.to_data()
	var pieces_before: Dictionary = pieces.to_data()
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		for grass: bool in [false, true]:
			var access: Array[String] = []
			if grass:
				access.assign(StadiumSurfaceProgression.INITIAL_LEGACY)
			var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
				StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, grass)
			)
			layout.advanced_back = (
				StadiumAdvancedWallManifest.suggest(shape, material, stock, pieces.stock).manifest
			)
			layout.walls = StadiumWallLayout.propose(layout.walls, stock, "left", "ST-022").walls
			if grass:
				layout.surface.height = "long"
				layout.styles.grass = "ST-063b"
				layout.ground = "ST-063g"
			var property: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
			add_child(property)
			_check(
				property.build_owned("club", layout, stock, pieces, access),
				"complete exact owned property assembles " + shape + material
			)
			_check(
				not property.has_node("TemplateBackWall") and property.has_node("BoundaryGraph"),
				"paid boundary replaces original back rather than overlapping it"
			)
			var boundary: StadiumRecipeBoundaryBody = property.boundary
			_check(
				(
					boundary.get_meta("advanced_manifest")
					== StadiumAdvancedOwnedAssembly.manifest_key(layout.advanced_back, layout.walls)
				),
				"both back and handed sides bind assembly metadata"
			)
			_check(
				(
					boundary.get_node("PanelVisuals").get_child_count()
					== layout.advanced_back.copies.size() + 19
				),
				"no fake or duplicate paid wall visuals"
			)
			_check(
				(
					not boundary.get_node("SIDE-L-01/TemplateWallVisual").visible
					and boundary.get_node("SIDE-R-01/TemplateWallVisual").visible
				),
				"unowned right side retains its template"
			)
			var seen: Array[String] = []
			for model: Node3D in boundary.get_node("PanelVisuals").get_children():
				var copy: String = model.get_meta("owned_copy")
				_check(
					(
						not seen.has(copy)
						and (stock.copies.has(copy) or pieces.stock.copies.has(copy))
					),
					"every model has one exact distinct owned identity"
				)
				seen.append(copy)
			_surface(property, layout, grass)
			_check(
				not property.build_owned("club", layout, stock, pieces, access),
				"repeat build cannot append duplicate geometry"
			)
			await _capture(property, shape, material, grass)
			await get_tree().process_frame
			property.free()
	_check(
		(
			ClubCareer.same(stock.to_data(), stock_before)
			and ClubCareer.same(pieces.to_data(), pieces_before)
		),
		"assembly never edits caller ownership"
	)
	_invalid(stock, pieces)
	_rebuild_failure(stock, pieces, material)


func _surface(property: StadiumAdvancedPropertyGeometry, layout: Dictionary, grass: bool) -> void:
	var finish: Node3D = property.get_node("OwnedSurfaceFinish")
	var graph: StadiumRecipeBoundary = property.boundary.graph
	_check(
		finish.get_meta("boundary_signature") == graph.signature(),
		"surface masks bind actual advanced outline"
	)
	_check(
		(
			finish.get_meta("foundation") == ("grass" if grass else "rough_dirt")
			and finish.get_meta("ground_cut") == layout.ground
			and finish.get_meta("mowing_pattern") == layout.styles.grass
		),
		"dirt cuts and mowing remain independent of wall geometry"
	)
	_check(
		finish.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"visual grass adds no hidden terrain physics"
	)
	var mesh: MeshInstance3D = finish.get_node("Surface")
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		_check(
			graph.contains(Vector2(vertex.x, vertex.z)),
			"surface vertices clip to real concave field"
		)
	for side: int in [-1, 1]:
		var expected: Vector3 = StadiumRecipeFieldStyles.foul_end(property.field, graph, side)
		var line: Node3D = property.get_node("FoulLine" + str(side))
		_check(
			line.position.is_equal_approx(expected / 2 + Vector3(0, 0.02, 0)),
			"foul line endpoints use actual graph"
		)


func _invalid(stock: StadiumStock, pieces: StadiumWallPieceOwnership) -> void:
	var property: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	_check(
		not property.build_owned("club", {}, stock, pieces, []) and property.get_child_count() == 0,
		"invalid layout allocates no partial scene"
	)
	property.free()
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [], false)
	)
	property = StadiumAdvancedPropertyGeometry.new()
	add_child(property)
	_check(
		(
			property.build_owned("backyard", layout, stock, pieces, [])
			and property.boundary is StadiumBoundaryPrototype
		),
		"empty advanced selection retains standard field"
	)
	property.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _capture(property: Node3D, shape: String, material_id: String, grass: bool) -> void:
	if (
		_capture_dir.is_empty()
		or material_id not in ["ST-024", "ST-077"]
		or (material_id == "ST-077" and not grass)
	):
		return
	_check(DisplayServer.get_name() != "headless", "requested captures need native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("142520")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.5
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	light.light_energy = 0.7
	light.shadow_enabled = true
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.position = Vector3(-28, 38, -22)
	camera.look_at(Vector3(0, 0, 11))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 50
	camera.make_current()
	var label: Label = Label.new()
	label.text = (
		"OWNED ASSEMBLY | " + shape + " | " + material_id + (" | grass" if grass else " | dirt")
	)
	label.position = Vector2(32, 24)
	label.add_theme_font_size_override("font_size", 24)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(
		(
			get_viewport().get_texture().get_image().save_png(
				_capture_dir.path_join(
					(
						"advanced-owned-%s-%s-%s.png"
						% [shape, material_id, "grass" if grass else "dirt"]
					)
				)
			)
			== OK
		),
		"actual complete property capture saved"
	)


func _rebuild_failure(
	stock: StadiumStock, pieces: StadiumWallPieceOwnership, material: String
) -> void:
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [], false)
	)
	layout.advanced_back = (
		StadiumAdvancedWallManifest.suggest("left_loft", material, stock, pieces.stock).manifest
	)
	var property: FailSurface = FailSurface.new()
	property.set_meta("caller_note", "preserve")
	add_child(property)
	var quality: int = get_viewport().msaa_3d
	var owners: Variant = get_viewport().get_meta(StadiumWallRenderQuality.META, {}).duplicate(true)
	_check(
		(
			not property.build_owned("club", layout, stock, pieces, [])
			and property.get_child_count() == 0
			and property.boundary == null
			and property.objects.is_empty()
			and property.get_meta("caller_note") == "preserve"
		),
		"injected late failure rolls back only the attempted assembly"
	)
	_check(
		(
			get_viewport().msaa_3d == quality
			and ClubCareer.same(owners, get_viewport().get_meta(StadiumWallRenderQuality.META, {}))
		),
		"failed assembly releases viewport quality ownership"
	)
	property.fail_surface = false
	_check(property.build_owned("club", layout, stock, pieces, []), "same empty object can retry")
	var record: Dictionary = {
		"layout": property.get_meta("advanced_layout"),
		"stock": property.get_meta("advanced_stock"),
		"pieces": property.get_meta("advanced_pieces"),
		"access": property.get_meta("advanced_surface_access")
	}
	record = JSON.parse_string(JSON.stringify(record))
	var restored: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	add_child(restored)
	var access: Array[String] = []
	access.assign(record.access)
	_check(
		(
			restored.build_owned(
				"club",
				record.layout,
				StadiumStock.from_data(record.stock),
				StadiumWallPieceOwnership.from_data(record.pieces),
				access
			)
			and (
				restored.boundary.get_meta("advanced_manifest")
				== property.boundary.get_meta("advanced_manifest")
			)
		),
		"JSON declaration reconstructs the same owned authoring assembly"
	)
	property.free()
	restored.free()
	_check(
		(
			get_viewport().msaa_3d == quality
			and ClubCareer.same(owners, get_viewport().get_meta(StadiumWallRenderQuality.META, {}))
		),
		"last restored assembly releases viewport quality ownership"
	)


class FailSurface:
	extends StadiumAdvancedPropertyGeometry
	var fail_surface: bool = true

	func _surface(graph: StadiumRecipeBoundary, layout: Dictionary, stock: StadiumStock) -> bool:
		return false if fail_surface else super._surface(graph, layout, stock)
