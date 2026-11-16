extends Node
## Pure captured-record checks; NOT installed public callback qualification.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var resources: Array[Shape3D] = [
		BoxShape3D.new(),
		CapsuleShape3D.new(),
		CylinderShape3D.new(),
		SphereShape3D.new(),
		ConvexPolygonShape3D.new(),
		ConcavePolygonShape3D.new(),
		HeightMapShape3D.new(),
		WorldBoundaryShape3D.new()
	]
	for resource: Shape3D in resources:
		var property: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoPropertyV1.new()
		var body: StaticBody3D = StaticBody3D.new()
		var node: CollisionShape3D = CollisionShape3D.new()
		node.shape = resource
		body.add_child(node)
		property.add_child(body)
		property._capture_body(body)
		check(
			property._shapes.size() == 1 and property._shape_records_intact(),
			"fresh captured records " + resource.get_class()
		)
		for field: String in ["margin", "custom_solver_bias"]:
			var old: float = resource.get(field)
			resource.set(field, old + 0.01)
			check(not property._shape_records_intact(), "detect silent scalar " + field)
			resource.set(field, old)
			check(
				property._shape_records_intact(),
				"raw record equivalence restored, not issuance " + field
			)
		node.disabled = true
		check(not property._shape_records_intact(), "disabled remains guarded")
		node.disabled = false
		var old_shape: Shape3D = node.shape
		node.shape = old_shape.duplicate()
		check(not property._shape_records_intact(), "equal shape replacement remains guarded")
		node.shape = null
		check(not property._shape_records_intact(), "null shape refuses")
		node.shape = old_shape
		check(property._shape_records_intact(), "original shape identity restores raw comparison")
		property.free()
	check(resources.size() == 8, "all eight native concrete shape classes exercised")
	print(
		(
			"AY02_SHAPE_SCALAR_UNIT checks=%d failures=%d shapes=%d"
			% [checks, failures, resources.size()]
		)
	)
	get_tree().quit(0 if failures == 0 else 1)
