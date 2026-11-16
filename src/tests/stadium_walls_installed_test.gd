extends Node3D
## Exact paid panels replace only their purchased runs; template sections remain available.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	for row: Array in [["ST-024", 23], ["ST-022", 19], ["ST-023", 19]]:
		var quote: Dictionary = stock.quote(row[0], row[1], {"seasons": 30, "wins": 100}, row[0])
		_check(quote.ok, "authoring receipt")
		stock = StadiumStock.from_data(quote.state)
	var visibility: BallTrackingVisibility = BallTrackingVisibility.new()
	for sample: Array in [["back", "ST-024", "straight", 23, 3],
		["back", "ST-024", "deeper_center", 22, 3], ["left", "ST-022", "straight", 19, 2],
		["right", "ST-023", "straight", 19, 2], ["", "", "straight", 0, 0]]:
		var layout: Dictionary = StadiumWallItems.upgrade(StadiumStarterLayout.empty())
		if not String(sample[0]).is_empty():
			layout.walls = StadiumWallLayout.propose(layout.walls, stock,
				sample[0], sample[1], sample[2]).walls
		var root: Node3D = Node3D.new()
		add_child(root)
		var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		property.name = "HomeProperty"
		root.add_child(property)
		_check(property.build("backyard", layout, stock), "complete candidate property")
		var boundary: Node3D = StadiumBoundaryRuntime.assemble(property)
		_check(boundary != null and property.get_node_or_null("TemplateBackWall") == null,
			"one boundary replaces the old infinite plane")
		if sample[3] == 0:
			_check(boundary is StadiumBoundaryPrototype, "no paid panels preserves original template")
		else:
			_check(boundary is StadiumRecipeBoundaryBody, "paid run uses recipe-aware geometry")
			var visual: Node3D = boundary.get_node("PanelVisuals")
			_check(visual.get_child_count() == sample[3], "only exact purchased copies become visuals")
			for model: Node3D in visual.get_children():
				_check(stock.copies.has(model.get_meta("owned_copy")), "every visible panel has provenance")
				_check(model.get_meta("wall_item") == sample[1], "unselected material is never granted")
				_check(model.get_node_or_null("PanelCollision") == null,
					"shared joined graph has no duplicate per-panel collision")
			var hidden: int = 0
			for row: Dictionary in boundary.graph.segments():
				if not boundary.get_node(row.id + "/TemplateWallVisual").visible:
					hidden += 1
			_check(hidden == (1 if sample[0] == "back" and sample[2] == "straight" else sample[4]),
				"only paid sections hide their free template")
		visibility.configure(root)
		_check(absf(visibility.field_wall_z - (26 if sample[2] == "deeper_center" else 23.4)) < 0.0001,
			"camera depth follows actual center field")
		_check(visibility._uprights.is_empty(), "walls never trigger narrow-upright avoidance")
		if sample[3] == 0:
			_check(visibility._wall_bounds.is_empty() and visibility._recipe == null
				and visibility._obstacles == boundary.visibility_bounds(),
				"returning to the old field clears grouped recipe bounds and preserves old bounds")
		else:
			_check(visibility._wall_bounds == boundary.visibility_bounds()
				and visibility._obstacles.is_empty() and visibility._recipe == boundary.graph,
				"every joined wall bound is retained exactly in one margin group")
			var center: float = (26 if sample[2] == "deeper_center" else 23.4) \
				- BallTrackingVisibility.WALL_CAMERA_CLEARANCE
			_check(absf(visibility.defense_depth(0, 100) - center) < 0.0001,
				"recipe camera begins safely field-side of its center wall")
			if sample[2] == "deeper_center":
				var normal: Vector2 = boundary.graph.inward(boundary.graph.segment("BACK-01"))
				var shoulder: float = lerpf(26, 23.4, 7 / (StadiumWallRecipes.BACK_X - 10)) \
					- BallTrackingVisibility.WALL_CAMERA_CLEARANCE / absf(normal.y)
				_check(absf(visibility.defense_depth(17, 100) - shoulder) < 0.0001
					and absf(visibility.defense_depth(-17, 100) - shoulder) < 0.0001,
					"both shoulders use their local contour instead of maximum stadium depth")
		root.queue_free()
		await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro installed wall checks passed: "
			+ "exact paid panels, template fallback and camera bounds.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
