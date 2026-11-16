extends Node3D
## Full-scale Working property assembly. No season activation or gameplay certification claimed.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}]
	var inventory: Dictionary = stock.to_data()
	var source: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var previous: AABB
	for tier: String in StadiumProperty.BOUNDS:
		var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		add_child(property)
		_check(property.build(tier, layout, stock), "shared full-scale assembly " + tier)
		if property.field == null:
			property.queue_free()
			continue
		_check(property.get_meta("property_signature") == StadiumProperty.signature(tier),
			"preview and runtime assembly share one geometry contract")
		var bounds: AABB = StadiumProperty.ground_bounds(tier)
		_check(previous.size == Vector3.ZERO or bounds.encloses(previous), "nested property expansion")
		previous = bounds
		_check(property.field != source and property.field.back_wall_z_m == source.back_wall_z_m
			and property.field.safe_hit_z_m == source.safe_hit_z_m, "land does not expand play")
		_check(property.objects.size() == 3 and ClubCareer.same(inventory, stock.to_data()),
			"assembly consumes no money, grants no objects and preserves owned identities")
		_check(property.get_node("Mound").position.z == PitchBatLab.MOUND_ORIGIN.z,
			"mound uses actual runtime coordinates")
		for index in range(9):
			_check(property.field.fielder_anchor(index) == source.fielder_anchor(index),
				"expansion never relocates defender anchors")
		for copy: String in property.objects:
			var model: Node3D = property.objects[copy]
			_check(model.scale == Vector3.ONE and model.get_meta("owned_copy") == copy,
				"full-scale owned asset in stable property site")
			var site: String = model.get_meta("site")
			_check(model.position == (StadiumStarterLayout.RECEIVER if site == "RECEIVER-PRIMARY"
				else StadiumStarterLayout.SITES[site]), "fixed coordinates across land tiers")
		await get_tree().physics_frame
		await get_tree().physics_frame
		var end: float = StadiumProperty.reference_wall_width(source) / 2 - 0.01
		for x: float in [-end, 0.0, end]:
			var hit: Dictionary = _ray(Vector3(x, 1, 22), Vector3(x, 1, 25))
			_check(not hit.is_empty() and hit.collider.get_meta("ball_surface") == &"back_wall",
				"actual wall reaches both tolerated fair endpoints")
		var cone: Node3D = property.objects["starter-v1:ST-001"]
		var hit: Dictionary = _ray(cone.position + Vector3(0, 0.25, 1),
			cone.position + Vector3(0, 0.25, -1))
		_check(not hit.is_empty() and hit.collider.get_meta("owned_copy") == "starter-v1:ST-001",
			"actual placed cone collision retains ownership identity")
		var receiver: Node3D = property.objects["starter-v1:ST-079"]
		hit = _ray(receiver.position + Vector3(0, 0.65, 1),
			receiver.position + Vector3(0, 0.65, -0.4))
		_check(not hit.is_empty() and hit.collider.get_meta("ball_surface") == &"stadium_receiver",
			"receiver uses distinct surface role in actual property")
		property.queue_free()
		await get_tree().process_frame
		await get_tree().physics_frame
	var invalid: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(invalid)
	_check(not invalid.build("unknown", layout, stock) and invalid.get_child_count() == 0,
		"unknown property rejects without partial construction")
	layout.obstacles[0].copy = "unowned"
	_check(not invalid.build("backyard", layout, stock) and invalid.get_child_count() == 0,
		"unowned geometry never appears")
	_check(not StadiumProperty.contains("backyard", AABB(Vector3(26, 0, 0), Vector3.ONE)),
		"complete object envelope must fit the land")
	if _failures == 0:
		print("Wiffaltro stadium property checks passed: full-scale sites, owned objects and boundaries.")
	get_tree().quit(0 if _failures == 0 else 1)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1))


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
