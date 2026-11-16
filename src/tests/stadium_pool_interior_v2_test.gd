extends Node3D
## Private geometry/binding tests. No water awards, path chronology or controller qualification.

const RADIUS: float = 0.0365
const OFFSET: float = 0.00005

var _checks: int = 0
var _failures: int = 0
var _source: String = ""


func _ready() -> void:
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_geometry()
	_models()
	_binding()
	print("POOL_INTERIOR_V2 checks=%d failures=%d source=%s" % [_checks, _failures, _source])
	print("Geometry and exact binding only; runtime water and dry-to-dry completeness unqualified.")
	get_tree().quit(0 if _failures == 0 else 1)


func _geometry() -> void:
	var polygon: PackedVector2Array = StadiumPoolInteriorV2.vertices()
	_check(polygon.size() == 128, "exact original inner-ring count")
	for index: int in range(128):
		var point: Vector3 = StadiumPoolContract.point(1.95, 0, index)
		_check(polygon[index] == Vector2(point.x, point.z), "same original vertex %d" % index)
		var vertex: Vector2 = polygon[index]
		var midpoint: Vector2 = (vertex + polygon[(index + 1) % 128]) / 2
		for boundary: Vector2 in [vertex, midpoint]:
			var outward: Vector2 = boundary.normalized()
			var tangent: Vector3 = _at(boundary + outward * RADIUS, 0.5)
			_check(
				StadiumPoolInteriorV2.sample_local(tangent, RADIUS).tangent_or_uncertain,
				"side tangent, never positive award %d" % index
			)
			_check(
				not StadiumPoolInteriorV2.sample_local(tangent, RADIUS).positive_overlap,
				"side tangent excluded from positive overlap"
			)
			_check(
				(
					StadiumPoolInteriorV2
					. sample_local(_at(boundary + outward * (RADIUS - OFFSET), 0.5), RADIUS)
					. positive_overlap
				),
				"strict side entry %d" % index
			)
			_check(
				(
					StadiumPoolInteriorV2
					. sample_local(_at(boundary + outward * (RADIUS + OFFSET), 0.5), RADIUS)
					. dry
				),
				"strict side separation %d" % index
			)
			for height: float in [0.0, StadiumPoolContract.WATER_HEIGHT]:
				var sign_y: float = -1.0 if height == 0 else 1.0
				var corner: Vector3 = _at(
					boundary + outward * RADIUS * 0.6, height + sign_y * RADIUS * 0.8
				)
				var corner_result: Dictionary = StadiumPoolInteriorV2.sample_local(corner, RADIUS)
				_check(corner_result.tangent_or_uncertain, "rounded prism corner tangency")
				_check(
					absf(corner_result.distance_squared_m2 - RADIUS * RADIUS) < 0.0000001,
					"edge/corner uses Euclidean combined distance"
				)
				var overfilled: Vector3 = _at(
					boundary + outward * RADIUS * 0.9, height + sign_y * RADIUS * 0.9
				)
				_check(
					StadiumPoolInteriorV2.sample_local(overfilled, RADIUS).dry,
					"independent half-plane expansion would overfill this corner"
				)
		var normal: Vector2 = midpoint.normalized()
		var wall_point: Vector3 = _at(midpoint + normal * 0.0002, 0.5)
		_check(Vector2(wall_point.x, wall_point.z).length() < 1.95, "old cylinder mismatch probe")
		_check(
			StadiumPoolInteriorV2.sample_local(wall_point, 0.00005).dry,
			"v2 excludes old cylinder water extending into each wall facet"
		)
		_check(
			(
				StadiumPoolInteriorV2
				. sample_local(_at(midpoint - normal * 0.0002, 0.5), 0.00005)
				. positive_overlap
			),
			"v2 retains water immediately inside each facet"
		)
	var top: Vector3 = Vector3(0, StadiumPoolContract.WATER_HEIGHT + RADIUS, 0)
	_check(StadiumPoolInteriorV2.sample_local(top, RADIUS).tangent_or_uncertain, "top tangency")
	_check(
		StadiumPoolInteriorV2.sample_local(top - Vector3.UP * OFFSET, RADIUS).positive_overlap,
		"strict top entry"
	)
	_check(
		StadiumPoolInteriorV2.sample_local(top + Vector3.UP * OFFSET, RADIUS).dry,
		"strict top separation"
	)
	_check(
		StadiumPoolInteriorV2.sample_local(top, RADIUS * 0.5).dry,
		"actual supplied sphere radius changes the predicate"
	)
	for radius: float in [0.0, -1.0, NAN, INF]:
		_check(not StadiumPoolInteriorV2.sample_local(Vector3.ZERO, radius).valid, "bad radius")
	_check(
		not StadiumPoolInteriorV2.sample_local(Vector3(NAN, 0, 0), RADIUS).valid, "nonfinite center"
	)
	_check(
		StadiumPoolInteriorV2.sample_local(Vector3(0, 0.5, 0), RADIUS).positive_overlap,
		"interior is positively wet"
	)


func _models() -> void:
	var original: Node3D = StadiumPoolModels.create(StadiumPoolContract.LIVE)
	var model: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	for subtree: String in ["Visual", "Collision"]:
		_check(
			_bytes(original.get_node(subtree)) == _bytes(model.get_node(subtree)),
			"original visual/solid subtree unchanged: " + subtree
		)
	_check(
		model.get_node_or_null(StadiumPoolContract.WATER_VOLUME_ID) == null,
		"v1 cylinder carrier absent from v2"
	)
	var carrier: Node3D = model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	_check(
		not carrier is CollisionObject3D and carrier.get_child_count() == 0,
		"v2 descriptor has no physics object or cooked hull"
	)
	_check(carrier.transform == Transform3D.IDENTITY, "descriptor uses model-local floor origin")
	_check(
		carrier.get_meta("descriptor") == StadiumPoolInteriorV2.descriptor(_source),
		"exact source-pinned descriptor"
	)
	var scenery: Node3D = StadiumPoolModels.create(StadiumPoolContract.SCENERY)
	var scenery_v2: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.SCENERY)
	_check(_bytes(scenery) == _bytes(scenery_v2), "scenery remains entirely original")
	scenery_v2.transform = StadiumPoolContract.placement()
	add_child(scenery_v2)
	_check(
		StadiumPoolInteriorV2.capture(scenery_v2, _source) == null,
		"scenery cannot register live water"
	)
	_check(StadiumPoolModelsV2.create("INVALID_ROLE") == null, "invalid role rejected")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	add_child(ball)
	var physical_shape: SphereShape3D = (ball.get_child(0) as CollisionShape3D).shape
	var expected_radius: float = PackedFloat32Array([ball.radius_m])[0]
	_check(physical_shape.radius == expected_radius, "physical radius is exact authored float32")
	_check(physical_shape.radius != ball.radius_m, "nominal double equality is a negative control")
	print(
		"POOL_RADIUS_REPRESENTATION ",
		JSON.stringify(
			{
				"authored_radius_m": ball.radius_m,
				"expected_shape_radius_m": expected_radius,
				"actual_shape_radius_m": physical_shape.radius,
				"authored_float64_le_hex":
				PackedFloat64Array([ball.radius_m]).to_byte_array().hex_encode(),
				"expected_float32_le_hex":
				PackedFloat32Array([ball.radius_m]).to_byte_array().hex_encode(),
				"actual_float32_le_hex":
				PackedFloat32Array([physical_shape.radius]).to_byte_array().hex_encode(),
				"actual_widened_float64_le_hex":
				PackedFloat64Array([physical_shape.radius]).to_byte_array().hex_encode()
			},
			"",
			true,
			true
		)
	)
	_check(
		StadiumPoolInteriorV2.sample_local(Vector3(0, 1.10, 0), physical_shape.radius).dry,
		"physical sphere stays dry where the enlarged visual sphere would overlap"
	)
	_check(
		StadiumPoolInteriorV2.sample_local(Vector3(0, 1.10, 0), 0.075).positive_overlap,
		"negative control demonstrates why visual radius cannot authorize water"
	)
	ball.free()
	for node: Node3D in [original, model, scenery, scenery_v2]:
		node.free()


func _binding() -> void:
	var model: Node3D = _live()
	var context: StadiumPoolInteriorV2 = StadiumPoolInteriorV2.capture(model, _source)
	_check(context != null, "exact live model binds")
	if context == null:
		model.free()
		return
	_check(context.valid(model, _source), "captured context validates")
	_check(context.binding_receipt().source_inputs.size() == 5, "source dependency hashes retained")
	_check(
		context.sample(model.global_position + Vector3.UP * 0.5, RADIUS).positive_overlap,
		"world sample uses exact fixed placement"
	)
	_check(StadiumPoolInteriorV2.capture(model, "0".repeat(64)) == null, "stale source rejected")
	var other: Node3D = _live()
	_check(not context.valid(other, _source), "identical-looking different instance rejected")
	_check(not context.valid(model, _source), "invalidated context cannot revive")
	other.free()
	context = StadiumPoolInteriorV2.capture(model, _source)
	_check(not context.valid(model, "0".repeat(64)), "per-call source token must match capture")
	context = StadiumPoolInteriorV2.capture(model, _source)
	model.position.x += 0.01
	_check(not context.valid(model, _source), "moved model rejected")
	_check(StadiumPoolInteriorV2.capture(model, _source) == null, "moved model cannot bind")
	model.transform = StadiumPoolContract.placement()
	context = StadiumPoolInteriorV2.capture(model, _source)
	model.scale = Vector3(1.001, 1, 1)
	_check(not context.valid(model, _source), "scaled model rejected")
	_check(StadiumPoolInteriorV2.capture(model, _source) == null, "scaled model cannot bind")
	model.transform = StadiumPoolContract.placement()
	context = StadiumPoolInteriorV2.capture(model, _source)
	var carrier: Node3D = model.get_node(StadiumPoolInteriorV2.VOLUME_ID)
	var record: Dictionary = carrier.get_meta("descriptor").duplicate(true)
	var changed: Dictionary = record.duplicate(true)
	changed.height_m += 0.01
	carrier.set_meta("descriptor", changed)
	_check(not context.valid(model, _source), "edited descriptor rejected")
	_check(StadiumPoolInteriorV2.capture(model, _source) == null, "tampered descriptor cannot bind")
	carrier.set_meta("descriptor", record)
	context = StadiumPoolInteriorV2.capture(model, _source)
	carrier.position.y = 0.001
	_check(not context.valid(model, _source), "moved carrier rejected")
	carrier.transform = Transform3D.IDENTITY
	context = StadiumPoolInteriorV2.capture(model, _source)
	var shape: ConcavePolygonShape3D = model.get_node("Collision/POOL_INNER_WALL/Shape").shape
	var faces: PackedVector3Array = shape.get_faces()
	var edited_faces: PackedVector3Array = faces.duplicate()
	edited_faces[0] += Vector3.RIGHT * 0.01
	shape.set_faces(edited_faces)
	_check(not context.valid(model, _source), "in-place solid resource edit rejected")
	shape.set_faces(faces)
	context = StadiumPoolInteriorV2.capture(model, _source)
	var replacement: Node3D = carrier.duplicate() as Node3D
	model.remove_child(carrier)
	carrier.free()
	model.add_child(replacement)
	_check(not context.valid(model, _source), "value-identical replacement carrier rejected")
	context = StadiumPoolInteriorV2.capture(model, _source)
	var holder: Node3D = Node3D.new()
	add_child(holder)
	model.reparent(holder, true)
	_check(not context.valid(model, _source), "same-pose parent replacement rejected")
	holder.free()
	_check(not context.sample(Vector3.ZERO, RADIUS).valid, "freed model stays invalid")


func _live() -> Node3D:
	var model: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	model.transform = StadiumPoolContract.placement()
	add_child(model)
	return model


static func _at(point: Vector2, height: float) -> Vector3:
	return Vector3(point.x, height, point.y)


static func _bytes(node: Node) -> PackedByteArray:
	return var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(node))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
