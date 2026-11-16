extends RefCounted
## Independent exact geometry differences and physical predecessor/host controls.

const PREFIX: String = "finals-candidate:LONG-YARD:v2:"
var _test: Node3D


func _init(test: Node3D) -> void:
	_test = test


func _check(ok: bool, message: String) -> void:
	_test.call("_check", ok, message)


func approved_lower() -> Node3D:
	# Build the expected difference independently; do not ask the candidate factory what changed.
	var expected: Node3D = StadiumBaselineStandModels.lower()
	var mesh: MeshInstance3D = expected.get_node("Visual/FrontGuard")
	var body: StaticBody3D = expected.get_node("Collision/FrontGuard")
	var shape: CollisionShape3D = body.get_child(0)
	_check(
		(
			mesh.position == Vector3(-0.35, 3.5, 0.06)
			and (mesh.mesh as BoxMesh).size == Vector3(5.3, 1.0, 0.12)
			and body.position == mesh.position
			and (shape.shape as BoxShape3D).size == mesh.mesh.size
		),
		"frozen v1 guard remains unchanged before the approved explicit difference"
	)
	mesh.position = Vector3(-0.35, 3.45, 0.06)
	(mesh.mesh as BoxMesh).size = Vector3(5.3, 0.9, 0.12)
	body.position = mesh.position
	(shape.shape as BoxShape3D).size = mesh.mesh.size
	return expected


func approved_canopy() -> Node3D:
	# The sole roof geometry exception is the right column; every other node must match v1.
	var expected: Node3D = StadiumBaselineStandModels.lower_canopy()
	var mesh: MeshInstance3D = expected.get_node("Visual/RearColumn1")
	var body: StaticBody3D = expected.get_node("Collision/RearColumn1")
	var shape: CollisionShape3D = body.get_child(0)
	_check(
		(
			mesh.position == Vector3(2.7, 7.2, 6.6)
			and (mesh.mesh as BoxMesh).size == Vector3(0.18, 2.4, 0.18)
			and body.position == mesh.position
			and (shape.shape as BoxShape3D).size == mesh.mesh.size
		),
		"frozen v1 floating post remains available as an honest negative control"
	)
	mesh.position = Vector3(2.7, 7.05, 6.6)
	(mesh.mesh as BoxMesh).size = Vector3(0.18, 2.7, 0.18)
	body.position = mesh.position
	(shape.shape as BoxShape3D).size = mesh.mesh.size
	return expected


func roof_support(lower: Node3D, roof: Node3D) -> void:
	_check(
		StadiumLongYardLowerRoofSites.supported(lower, roof),
		"production predicate covers both complete actual column footprints"
	)
	var original: Node3D = StadiumBaselineStandModels.lower_canopy()
	_check(
		not StadiumLongYardLowerRoofSites.supported(lower, original),
		"unchanged v1 canopy right post remains a failed-support control"
	)
	original.free()
	# Independent coverage is exact for this frozen geometry: left post over row9,
	# right post split at z6.65 between stairs37 and38. Check physical boxes, not y6 metadata.
	for side: int in [-1, 1]:
		var post: AABB = _local_box(roof.get_node("Collision/RearColumn%d" % side))
		var pads: Array[AABB] = []
		if side == -1:
			pads.append(_local_box(lower.get_node("Collision/SolidRow9")))
		else:
			pads.append(_local_box(lower.get_node("Collision/EntryStep37")))
			pads.append(_local_box(lower.get_node("Collision/EntryStep38")))
		var covered: float = 0.0
		for pad: AABB in pads:
			var x: float = maxf(
				0.0, minf(post.end.x, pad.end.x) - maxf(post.position.x, pad.position.x)
			)
			var z: float = maxf(
				0.0, minf(post.end.z, pad.end.z) - maxf(post.position.z, pad.position.z)
			)
			var embed: float = pad.end.y - post.position.y
			_check(
				embed >= -0.00001 and embed <= 0.15001,
				"actual pad top touches or embeds by at most the approved0.15m"
			)
			covered += x * z
		_check(
			absf(covered - post.size.x * post.size.z) < 0.000001,
			"disjoint real deck or stair tops cover the entire0.18m square column foot"
		)
		_check(
			is_equal_approx(post.end.y, 8.4), "support extension preserves the exact upper joint"
		)
	var step: StaticBody3D = lower.get_node("Collision/EntryStep37")
	var shape: CollisionShape3D = step.get_child(0)
	shape.disabled = true
	_check(
		not StadiumLongYardLowerRoofSites.supported(lower, roof),
		"missing physical stair support fails even with unchanged column metadata"
	)
	shape.disabled = false
	_check(
		StadiumLongYardLowerRoofSites.supported(lower, roof), "support negative control restores"
	)


func _local_box(body: StaticBody3D) -> AABB:
	var shape: CollisionShape3D = body.get_child(0)
	_check(shape.shape is BoxShape3D, "support shape is an actual box")
	var size_value: Vector3 = (shape.shape as BoxShape3D).size
	return body.transform * shape.transform * AABB(-size_value / 2, size_value)


func host_controls(property: StadiumPropertyGeometry, roof_site: String) -> void:
	var site: String = roof_site.trim_prefix("ROOF:")
	var lower: Node3D = property.objects[PREFIX + site]
	var roof: Node3D = property.objects[PREFIX + roof_site]
	_check(
		(
			StadiumLongYardLowerRoofSites.valid_lower(lower, site)
			and StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site)
		),
		"independently authenticated actual lower and attached compatible roof"
	)
	_check(
		StadiumLongYardLowerRoofModels.create(lower, site) == null,
		"occupied host cannot manufacture a duplicate canopy"
	)
	for key: String in ["lower_instance", "site", "interface", "candidate_mount"]:
		var original: Variant = roof.get_meta(key)
		for malformed: Variant in [false, [], {}]:
			roof.set_meta(key, malformed)
			_check(
				not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
				"typed roof identity refuses malformed " + key
			)
		roof.set_meta(key, original)
	for forbidden: String in [
		"upper_instance", "concourse_instance", "assembly_state", "roof_state"
	]:
		roof.set_meta(forbidden, "unowned-service")
		_check(
			not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
			"lower-only canopy refuses upper or service attachment " + forbidden
		)
		roof.remove_meta(forbidden)
	var parent_pose: Transform3D = property.transform
	property.position.x += 0.01
	_check(
		(
			not StadiumLongYardLowerRoofSites.valid_lower(lower, site)
			and not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site)
		),
		"transformed common parent cannot silently move an authenticated assembly"
	)
	property.transform = parent_pose
	var other: Node3D = property.objects[PREFIX + ("BASE-R2" if site == "BASE-L2" else "BASE-L2")]
	_check(
		not StadiumLongYardLowerRoofSites.valid_roof(other, roof, site),
		"valid opposite lower copy cannot impersonate the physical host"
	)
	roof.set_meta("lower_instance", other.get_instance_id())
	_check(
		not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
		"authentic other instance identifier cannot reparent the canopy"
	)
	roof.set_meta("lower_instance", lower.get_instance_id())
	var pose: Transform3D = roof.transform
	roof.position.y += 0.01
	_check(
		not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
		"one-centimeter physical mount displacement is rejected"
	)
	roof.transform = pose
	var duplicate: Node3D = Node3D.new()
	duplicate.set_meta("stadium_item", "ST-053")
	duplicate.set_meta("lower_instance", lower.get_instance_id())
	property.add_child(duplicate)
	_check(
		not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
		"second claimed roof blocks the exact host"
	)
	property.remove_child(duplicate)
	duplicate.free()
	for item: String in ["ST-030", "ST-031", "ST-055", "ST-057"]:
		var incompatible: Node3D = Node3D.new()
		incompatible.set_meta("stadium_item", item)
		property.add_child(incompatible)
		_check(
			not StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
			"upper or service occupancy cannot reuse the lower-only interface"
		)
		property.remove_child(incompatible)
		incompatible.free()
	_check(
		StadiumLongYardLowerRoofSites.valid_roof(lower, roof, site),
		"all host controls restore exact hierarchy, identity, pose and physical support"
	)


func v1_predecessor(stands: Array[Node3D]) -> void:
	var samples: int = 0
	var blocked: int = 0
	for actual: Node3D in stands:
		var original: Node3D = StadiumBaselineStandModels.lower()
		original.visible = false
		_test.add_child(original)
		original.transform = actual.global_transform
		for body: StaticBody3D in original.get_node("Collision").get_children():
			body.collision_layer = 128
		await _test.get_tree().physics_frame
		await _test.get_tree().physics_frame
		for index in range(50):
			var person: Node3D = original.get_node("Visual/CrowdAnchor%d" % index)
			var eye: Vector3 = person.global_position + Vector3.UP * 0.57
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				eye, Vector3(0, 1, 8), 128
			)
			var hit: Dictionary = _test.get_world_3d().direct_space_state.intersect_ray(ray)
			samples += 1
			if index < 5:
				blocked += int(not hit.is_empty())
				_check(
					(
						not hit.is_empty()
						and hit.collider == original.get_node("Collision/FrontGuard")
						and absf(original.to_local(hit.position).y - 3.990334) < 0.0001
					),
					"v1 preserves each documented first-row FrontGuard obstruction"
				)
			else:
				_check(
					hit.is_empty(), "remaining45 original spectator rays stay unchanged and clear"
				)
		original.queue_free()
		await _test.get_tree().process_frame
	_check(
		samples == 200 and blocked == 20,
		"all200 v1 spectators sampled; exactly20 own FrontGuard blockers remain documented"
	)
	print(
		"LONG_YARD_V1_PREDECESSOR samples=",
		samples,
		" blocked=",
		blocked,
		" qualified=false; revised assembly measured separately"
	)


func mound_precision(record: Dictionary) -> void:
	# Independent literal follows the documented Vector3 float32 representation.
	# Compare exact stored components, never a widened epsilon or altered runtime value.
	var expected: Vector3 = Vector3(0.0, 0.0, 13.716)
	var components: Array = [expected.x, expected.y, expected.z]
	_check(record.field.mound_origin == components, "unchanged exact stored mound components")
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0, 13.716)
	_check(
		bytes.decode_float(0) == expected.z and bytes.decode_u32(0) == 0x415b74bc,
		"independent IEEE754 literal matches exact canonical Vector3 component"
	)
	var canonical: Dictionary = StadiumLongYardFixture.capture(record)
	_check(not canonical.is_empty(), "unchanged mound retains exact canonical fixture")
	if canonical.is_empty():
		return
	for bits: int in [0x415b74bb, 0x415b74bd]:
		bytes.encode_u32(0, bits)
		var altered: Dictionary = canonical.duplicate(true)
		altered.venue.field.mound_origin[2] = bytes.decode_float(0)
		_check(
			altered.venue.field.mound_origin[2] != expected.z,
			"adjacent float32 control is genuinely different from the expected mound"
		)
		altered.sha256 = JSON.stringify(altered.venue, "", true, true).sha256_text()
		_check(
			not StadiumLongYardFixture.valid(altered),
			"correctly rehashed adjacent float32 mound still rejects without tolerance"
		)
	for axis: int in [0, 1]:
		var altered: Dictionary = canonical.duplicate(true)
		altered.venue.field.mound_origin[axis] = 0.000001
		_check(components[axis] == 0.0, "zero-coordinate negative has an actual zero baseline")
		altered.sha256 = JSON.stringify(altered.venue, "", true, true).sha256_text()
		_check(
			not StadiumLongYardFixture.valid(altered),
			"correctly rehashed nonzero displacement of a zero mound coordinate rejects"
		)
	print(
		"LONG_YARD_MOUND_COMPONENTS ",
		JSON.stringify({"expected": components, "record": record.field.mound_origin}, "", true, true)
	)
