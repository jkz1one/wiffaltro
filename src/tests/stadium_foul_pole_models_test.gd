extends Node3D
## Literal nominal-ray sockets and physical piece identity; no runtime contact-policy activation.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var quote: Dictionary = stock.quote("ST-021", 2, {"seasons": 50, "wins": 200}, "poles")
	_check(quote.ok, "synthetic pole funding is distinct from wall stock")
	stock = StadiumStock.from_data(quote.state)
	var ids: Array[String] = ["purchase:poles:0", "purchase:poles:1"]
	for shape: String in ["straight", "deeper_center", "left_loft", "right_shelf"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape) if shape in [
			"straight", "deeper_center"] else StadiumHeightBoundary.candidate(shape)
		var valid: Dictionary = StadiumFoulPoleSites.validate(ids, stock, graph)
		_check(valid.ok, "two exact pole copies bind to " + shape)
		for row: Dictionary in valid.placements:
			_check(is_equal_approx(absf(row.position.x),
				row.position.z * tan(deg_to_rad(42))), "socket uses nominal ray, not tolerated endpoint")
			if shape == "straight":
				_check(absf(absf(row.position.x) - 21.069454636569) < 0.00001
					and is_equal_approx(row.position.z, 23.4), "original straight nominal pole position")
			if shape == "deeper_center":
				_check(absf(absf(row.position.x) - 21.145460000032) < 0.00001
					and absf(row.position.z - 23.484412507855) < 0.00001,
					"angled shoulder recalculates the pole instead of reusing the straight socket")
			_check(row.split == graph.segment(row.segment).height, "pole cap split uses its actual wall")
			var model: Node3D = StadiumFoulPoleModels.create(row.split)
			_check(model != null and model.get_node("Collision").get_child_count() == 1,
				"one continuous cylinder has no artificial internal cap at the scoring split")
			for part: StaticBody3D in model.get_node("Collision").get_children():
				var cylinder: CylinderShape3D = part.get_child(0).shape
				_check(is_equal_approx(cylinder.radius, StadiumFoulPoleSites.RADIUS)
					and cylinder.margin == 0 and cylinder.height == StadiumFoulPoleSites.HEIGHT,
					"literal full-height cylinder without implicit collision margin")
			_check(StadiumFoulPoleModels.role_at(row.split, row.split) == "FOUL_POLE_LOWER"
				and StadiumFoulPoleModels.role_at(row.split + 0.001, row.split) == "FOUL_POLE_UPPER",
				"exact cap is lower; upper begins strictly above it")
			model.free()
	_check(not StadiumFoulPoleSites.validate([ids[0], ids[0]], stock,
		StadiumRecipeBoundary.create("straight")).ok, "one copy cannot occupy both endpoints")
	_check(not StadiumFoulPoleSites.validate([ids[0], "starter-v1:ST-001"], stock,
		StadiumRecipeBoundary.create("straight")).ok, "unrelated inventory cannot impersonate a pole")
	_check(StadiumFoulPoleModels.create(NAN) == null
		and StadiumFoulPoleModels.role_at(INF, 3.25).is_empty(), "nonfinite candidate inputs fail closed")
	var preview: Node3D = StadiumFoulPoleModels.create(3.25)
	add_child(preview)
	_check(await StadiumAssetCapture.save(self,
		AABB(Vector3(-0.09, 0, -0.09), Vector3(0.18, 8, 0.18)), "ST-021-pole"),
		"native pole preview saved")
	preview.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro foul pole models passed: nominal sockets, copies and cap regions.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
