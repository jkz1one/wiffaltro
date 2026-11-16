extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"
## Exact whole Left Loft composition; inherited methods are geometry tools, not evidence.

const Evidence = preload("res://src/tests/stadium_mogul_two_evidence.gd")
const EXPECTED: Dictionary = {
	"ST-065": 13,
	"ST-065-T": 12,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-031": 4,
	"ST-030": 4,
	"ST-053": 4,
	"ST-081": 5,
	"ST-085": 1,
	"ST-088": 1,
	"ST-039": 1,
	"ST-076": 4
}
var _anonymous_control_items: Array[String] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumMogulTwoStudy.build(self)
	_check(property != null, "independent complete AM-02 assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_exact_contract(property, record)
	var counts: Dictionary = {}
	var sites: Array[String] = []
	var occupied: Array[Node3D] = []
	var structures: Array[Node3D] = []
	for row: Dictionary in record.items:
		_check(not sites.has(row.site), "each complete candidate slot is unique")
		sites.append(row.site)
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null, "each declared copy has a real installed model")
		if model == null:
			continue
		counts[row.item] = counts.get(row.item, 0) + 1
		_check(
			(
				model.get_meta("candidate_instance") == row.instance
				and model.get_meta("candidate_host") == row.host
				and model.get_meta("candidate_site") == row.site
			),
			"actual source model binds exact item, site and owner"
		)
		var components: Array[float] = []
		for vector: Vector3 in [
			model.global_basis.x, model.global_basis.y, model.global_basis.z, model.global_position
		]:
			components.append_array([vector.x, vector.y, vector.z])
		_check(
			ClubCareer.same(row.transform, components), "every full installed rigid pose matches"
		)
		_factory_identity(model, record)
		if row.item in ["ST-029", "ST-030", "ST-081", "ST-085", "ST-088"]:
			occupied.append(model)
		if row.item in ["ST-029", "ST-030", "ST-031", "ST-053", "ST-081", "ST-085", "ST-088"]:
			structures.append(model)
	_check(
		ClubCareer.same(counts, EXPECTED) and property.objects.size() == 91,
		"independent exact 91-copy and17-identity installed inventory"
	)
	for mesh: MeshInstance3D in property.find_children("*", "MeshInstance3D", true, false):
		_check(
			StadiumProperty.contains("mogul", mesh.global_transform * mesh.get_aabb()),
			"every actual mesh fits Mogul land: " + str(mesh.get_path())
		)
	for shape: CollisionShape3D in property.find_children("*", "CollisionShape3D", true, false):
		_check(
			StadiumProperty.contains(
				"mogul", shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
			),
			"complete physical collider fits exact Mogul land"
		)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var net: Node3D = property.objects[StadiumMogulTwoStudy.PREFIX + "RECEIVER-CATCH"]
	_actual_net_clearance(net)
	var witness_ready: bool = _init_net_witness()
	_check(witness_ready, "independent original sparse-strand witness initializes")
	if not witness_ready:
		property.queue_free()
		get_tree().quit(1)
		return
	# The whole boundary adapter adds its own fixed query bit. Do not copy actual
	# collider state into the independent witness or mask missing collider layers.
	for body: StaticBody3D in _net_witness.get_node("Collision").get_children():
		body.collision_layer = 1 | StadiumClubBoundaryStudy.QUERY_MASK
	_check(
		_net_visual_controls(net),
		"whole installed receiver rejects all false transparency controls"
	)
	await _all_spectators(occupied, net)
	for site: String in ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]:
		var stack: Array[Node3D] = [property.objects[StadiumMogulTwoStudy.PREFIX + site]]
		for suffix: String in [".CONCOURSE", ".UPPER", ".ROOF-UPPER"]:
			stack.append(property.objects[StadiumMogulTwoStudy.PREFIX + site + suffix])
		_check(
			StadiumGrandThreeStackSites.valid_roof(stack[0], stack[1], stack[2], stack[3], site),
			"all four actual guard-v2 stacks retain exact legal full host bindings"
		)
		_grand_straight_support(stack)
		_grand_roof_geometry(stack[3])
		for model: Node3D in stack:
			_grand_reservation(model)
			_grand_no_penetration(model, structures)
		for side: int in [-1, 1]:
			_check(
				stack[3].has_node("Collision/FinishedRoofEnd%d" % side),
				"upper roofs keep independently supported finished ends"
			)
		var old_binding: int = stack[3].get_meta("upper_instance")
		stack[3].set_meta("upper_instance", stack[0].get_instance_id())
		_check(
			not StadiumGrandThreeStackSites.valid_roof(
				stack[0], stack[1], stack[2], stack[3], site
			),
			"a forged host binding fails on each complete installed upper roof"
		)
		stack[3].set_meta("upper_instance", old_binding)
	for site: String in ["JOIN-L", "JOIN-R"]:
		var join: Node3D = property.objects[StadiumMogulTwoStudy.PREFIX + site]
		_grand_no_penetration(join, structures)
		_check(
			join.transform == Transform3D.IDENTITY and join.get_meta("represented_seats") == 18,
			"independent lower-only handed transition has exact18 people"
		)
		for row in range(6):
			_check(
				(
					join.has_node("Collision/FinishedBaselineEnd%d" % row)
					and join.has_node("Collision/FinishedBowlEnd%d" % row)
				),
				"both lower-only join interfaces retain their finished ends"
			)
	_dormant_towers(property, record)
	_setup_view()
	await _capture("AM-02-whole-layout", Vector3(76, 65, -78), Vector3(0, 3, 10), 118)
	await _capture("AM-02-four-upper-roofs", Vector3(38, 30, -28), Vector3(0, 7, 2), 70)
	await _capture("AM-02-lower-bowl-joins", Vector3(36, 28, -42), Vector3(0, 2, -10), 69)
	await _capture("AM-02-tall-wall", Vector3(-28, 14, 6), Vector3(-10, 3, 23), 44)
	_check(_native._failures == 0, "actual normal and small native capture handshake")
	property.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumMogulTwoStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro AM-02 assembly passed:91 copies,480 spectators,1440 rays,four upper roofs."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _exact_contract(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	_check(
		(
			property is StadiumMogulTwoProperty
			and record.id == "AM-02"
			and record.version == 1
			and record.owner == "npc-venue:AM-02:left-loft-v1"
			and record.property == "mogul"
		),
		"independent immutable AM-02 candidate identity"
	)
	_check(
		record.live_units == 0 and record.status == "CANDIDATE" and record.mapping == "WORKING",
		"Working authoring never grants obstacle units"
	)
	_check(
		(
			record.environment.certificates.is_empty()
			and not record.environment.night_eligible
			and record.environment.target_slots == ["13:10", "16:10"]
			and record.environment.target_weather == ["clear"]
		),
		"clear daytime candidate only"
	)
	_check(
		(
			record.crowd.total == 480
			and record.crowd.baseline_lower == 200
			and record.crowd.baseline_upper == 64
			and record.crowd.bowl_lower == 180
			and record.crowd.transition_lower == 36
		),
		"real factory audience arithmetic, no capacity grant"
	)
	_check(
		(
			record.structural_layers.roofs == 4
			and record.structural_layers.curved_roofs == 0
			and record.structural_layers.curved_concourses == 0
			and record.structural_layers.curved_uppers == 0
			and record.structural_layers.transition_concourses == 0
		),
		"exact side-deck silhouette with lower-only central bowl and joins"
	)
	_check(
		(
			record.endowment
			== {
				"blueprint_value": 7390,
				"copy_value": 5975,
				"land_value": 6400,
				"total_value": 19765
			}
		),
		"independent current catalog and separate tall-variant valuation"
	)
	var source: FieldDefinition = load("res://src/content/fields/npc_venue_field.tres")
	_check(
		(
			property.field != source
			and property.field.get_script() == source.get_script()
			and ClubCareer.same(
				StadiumMogulTwoStudy.field_snapshot(property.field),
				StadiumMogulTwoStudy.field_snapshot(source)
			)
		),
		"private unchanged NPC sport field"
	)
	_check(
		(
			record.field.safe_hit_z_m == 11.25
			and record.field.deep_air_z_m == 17
			and record.field.back_wall_z_m == 23.4
			and record.field.home_run_height_m == 3.25
			and record.field.fair_half_angle_degrees == 42
		),
		"independent original sport dimensions"
	)
	var boundary: StadiumMogulTwoBoundary = property.get_node("ClubBoundary")
	_check(
		(
			boundary.graph is StadiumMogulTwoGraph
			and boundary.graph.segments().size() == 18
			and boundary.items.size() == 63
			and record.boundary == boundary.graph.signature()
		),
		"exact composite18-edge/63-piece Left Loft concrete-dugout foundation"
	)
	_check(not property.has_node("TemplateBackWall"), "obsolete unbounded back wall absent")
	var blueprints: Array = EXPECTED.keys()
	blueprints.sort()
	_check(
		(
			record.blueprint_entitlements == blueprints
			and blueprints.size() == 17
			and record.wall_piece_ownership == StadiumWallPieceOwnership.signature()
			and "ST-065-T" in blueprints
		),
		"tall entitlement is separate, never standard-copy conversion"
	)
	_check(
		(
			record.empty_sites
			== [
				"LANDMARK-A",
				"SCORE-LARGE-A",
				"BOWL-CONCOURSES",
				"BOWL-UPPERS",
				"BOWL-ROOFS",
				"JOIN-CONCOURSES",
				"ELEVATED-CORRIDORS"
			]
		),
		"explicit forbidden/unoccupied layers"
	)
	for row: Dictionary in record.items:
		_check(
			row.item not in ["ST-040", "ST-046", "ST-082", "ST-083", "ST-084", "ST-086", "ST-089"],
			"manifest cannot silently import finals decoration or upper bowl layers"
		)
		if row.item in ["ST-065", "ST-065-T"]:
			_check(
				(
					row.wall.height == (4.875 if row.item == "ST-065-T" else 3.25)
					and row.wall.width > 0
					and row.wall.width <= 2.000001
				),
				"every exact back-wall width and height is explicit"
			)
		if row.item in ["ST-031", "ST-030", "ST-053"]:
			_check(
				not row.support.is_empty() and row.support.lower in property.objects,
				"each serialized upper structural layer binds a concrete lower instance"
			)
		if row.item == "ST-053":
			_check(
				(
					row.support.upper in property.objects
					and row.support.concourse in property.objects
					and row.support.mount == "BASE-UPPER-ROOF-v1"
				),
				"each of four roofs binds actual owned upper and concourse instances"
			)


func _all_spectators(roots: Array[Node3D], net: Node3D) -> void:
	var anchors: Array[Node3D] = []
	var poses: Array[Vector3] = []
	var owners: Array[Node3D] = []
	for model: Node3D in roots:
		for anchor: Node3D in model.get_node("Visual").get_children():
			if anchor.get_meta("represented_audience", false):
				anchors.append(anchor)
				poses.append(anchor.position)
				owners.append(model)
	_check(anchors.size() == 480, "exact480 actual occupied factory audience anchors")
	var samples: int = 0
	for sway: float in [-0.04, 0, 0.04]:
		for index in range(anchors.size()):
			anchors[index].position = poses[index] + Vector3.UP * sway
		await get_tree().physics_frame
		for index in range(anchors.size()):
			var eye: Vector3 = anchors[index].global_position + Vector3.UP * 0.57
			var clear: bool = _sightline_clear(eye, Vector3(0, 1, 8), net)
			if not clear:
				_spectator_diagnostic(owners[index], anchors[index], eye, Vector3(0, 1, 8), net)
			_check(clear, "every actual audience eye sees pitch at rest and both sway extrema")
			samples += 1
	for index in range(anchors.size()):
		anchors[index].position = poses[index]
	_check(samples == 1440, "all1440 complete-layout audience rays actually sampled")
	await _sightline_controls(net)


func _dormant_towers(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"premium artwork produces zero active lights"
	)
	_check(
		(
			record.lighting.profile == "MOGUL4-PREMIUM"
			and record.lighting.dormant
			and record.lighting.active_lights == 0
			and record.lighting.towers.size() == 4
		),
		"all four exact premium tower sites remain dormant"
	)
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = property.objects[StadiumMogulTwoStudy.PREFIX + tower.site]
		_check(
			model.global_position == StadiumPremiumLightTowerSites.SITES[tower.site],
			"premium tower retains exact existing site"
		)
		var actual: Array = model.get_meta("candidate_head_rays")
		_check(
			actual.size() == 8 and tower.heads.size() == 8,
			"eight independently aimed premium heads"
		)
		for index in range(actual.size()):
			var origin: Vector3 = actual[index].origin
			var direction: Vector3 = actual[index].direction
			_check(
				(
					actual[index].id == tower.heads[index].id
					and ClubCareer.same([origin.x, origin.y, origin.z], tower.heads[index].origin)
					and ClubCareer.same(
						[direction.x, direction.y, direction.z], tower.heads[index].direction
					)
				),
				"all32 dormant head rays match exact serialized source aim"
			)


func _setup_view() -> void:
	# The installed property supplies the only ground; no overlapping diagnostic floor.
	StadiumWallRenderQuality.attach(self)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("263b37")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("b6ccbe")
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	add_child(light)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true


func _spectator_diagnostic(
	stand: Node3D, anchor: Node3D, eye: Vector3, target: Vector3, net: Node3D
) -> void:
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, target, 1)
	var ignored: Array[RID] = []
	var hits: Array[Dictionary] = []
	for index in range(32):
		ray.exclude = ignored
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			break
		var body: StaticBody3D = hit.collider
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		hits.append(
			{
				"body": String(body.get_path()),
				"point": hit.position,
				"point_in_stand": stand.to_local(hit.position),
				"verified_panel": _verified_panel(hit, net),
				"collider_bounds":
				(
					shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
					if shape != null
					else AABB()
				)
			}
		)
		# Diagnostics enumerate even opaque/farther hits; this never changes the failing proof.
		ignored.append(body.get_rid())
	var head: MeshInstance3D = anchor.get_node("Head")
	print(
		"MOGUL_TWO_SPECTATOR_BLOCKED site=",
		stand.get_meta("candidate_site"),
		" anchor=",
		anchor.name,
		" eye=",
		eye,
		" eye_local=",
		stand.to_local(eye),
		" head_center=",
		head.global_position,
		" head_radius=",
		(head.mesh as SphereMesh).radius,
		" target=",
		target,
		" ordered_hits=",
		hits
	)


func _factory_identity(model: Node3D, record: Dictionary) -> void:
	var item: String = model.get_meta("stadium_item", "")
	var site: String = model.get_meta("candidate_site", "")
	var row: Dictionary = {}
	for current: Dictionary in record.items:
		if current.site == site:
			row = current
	_check(not row.is_empty(), "real component has an independently audited manifest row")
	if row.is_empty():
		return
	var reference: Node3D
	match item:
		"ST-065", "ST-065-T":
			for panel: Dictionary in StadiumHeightWallRecipes.rows("left_loft", "ST-065"):
				if panel.socket == site:
					reference = StadiumHeightWallStudy.create("ST-065", panel.width, panel.height)
		"ST-022", "ST-023":
			reference = StadiumWallPanelModels.create(item, row.span)
			reference.get_node("PanelCollision").free()
		"ST-074":
			reference = StadiumConcreteDugoutModels.create()
		"ST-021":
			reference = StadiumFoulPoleModels.create(4.875 if site == "FOUL-POLE-L" else 3.25)
		"ST-026":
			reference = StadiumTargetModels.create()
		"ST-073":
			reference = StadiumReceiverNetModels.create()
		"ST-029":
			reference = StadiumBaselineSightlineModels.lower()
		"ST-031":
			reference = StadiumGrandThreeStackModels._concourse()
		"ST-030":
			reference = StadiumGrandThreeStackModels._upper()
		"ST-053":
			reference = StadiumGrandThreeStackModels._roof()
		"ST-081":
			reference = StadiumCurvedLowerModels.create()
		"ST-085":
			reference = StadiumLowerTransitionModels.create_right()
		"ST-088":
			reference = StadiumLowerTransitionModels.create_left()
		"ST-039":
			reference = StadiumClubModels.create("ST-039")
		"ST-076":
			reference = StadiumPremiumLightTowerModels.create()
			add_child(reference)
			_check(
				StadiumPremiumLightTowerSites.place(reference, site),
				"reference tower exact existing site and aim"
			)
	_check(reference != null, "every actual component comes from its intended existing factory")
	if reference == null:
		return
	var before: Array[Node] = reference.find_children("*", "Node", true, false)
	var after: Array[Node] = model.find_children("*", "Node", true, false)
	_check(
		before.size() == after.size(),
		"actual complete factory hierarchy has no omitted opaque or support member"
	)
	for original: Node in before:
		var path: NodePath = reference.get_path_to(original)
		var actual: Node = model.get_node_or_null(path)
		if (
			original is CollisionShape3D
			or original is Label3D
			or _anonymous_wall_mesh(reference, original)
		):
			var parent: Node = model.get_node_or_null(reference.get_path_to(original.get_parent()))
			actual = (
				parent.get_child(original.get_index())
				if parent != null and original.get_index() < parent.get_child_count()
				else null
			)
		if _anonymous_wall_mesh(reference, original):
			_check(
				_anonymous_wall_matches(original, actual),
				"anonymous wall member retains exact indexed class pose mesh material and opacity"
			)
		_check(
			actual != null and actual.get_class() == original.get_class(),
			"every factory member retains exact component type"
		)
		if actual == null or actual.get_class() != original.get_class():
			continue
		if original is Node3D:
			var actual_node: Node3D = actual as Node3D
			_check(
				actual_node.transform == original.transform,
				"every actual opaque support mesh and collider retains exact factory local pose"
			)
		if original is MeshInstance3D:
			var actual_mesh: MeshInstance3D = actual as MeshInstance3D
			_check(
				(
					actual_mesh.visible == original.visible
					and actual_mesh.transparency == original.transparency
					and actual_mesh.cast_shadow == original.cast_shadow
				),
				"actual component rendering cannot hide a required opaque blocker"
			)
			_check(
				actual_mesh.mesh.get_surface_count() == original.mesh.get_surface_count(),
				"same complete factory mesh surface count"
			)
			for surface in range(original.mesh.get_surface_count()):
				_check(
					(
						actual_mesh.mesh.surface_get_arrays(surface)
						== original.mesh.surface_get_arrays(surface)
					),
					"actual mesh vertices equal qualified component factory"
				)
			var material: StandardMaterial3D = actual_mesh.material_override as StandardMaterial3D
			var expected_material: StandardMaterial3D = (
				original.material_override as StandardMaterial3D
			)
			_check(
				(material == null) == (expected_material == null),
				"factory material presence preserved"
			)
			if material != null and expected_material != null:
				_check(
					(
						material.albedo_color == expected_material.albedo_color
						and material.transparency == expected_material.transparency
						and material.cull_mode == expected_material.cull_mode
					),
					"factory material opacity color and culling preserved"
				)
		if original is CollisionShape3D:
			var actual_shape: CollisionShape3D = actual as CollisionShape3D
			_check(
				(
					actual_shape.shape.get_class() == original.shape.get_class()
					and (
						actual_shape.shape.get_debug_mesh().get_faces()
						== original.shape.get_debug_mesh().get_faces()
					)
				),
				"exact qualified collider shape and vertices"
			)
		if original is Label3D:
			var actual_label: Label3D = actual as Label3D
			_check(
				(
					actual_label.text == original.text
					and actual_label.font_size == original.font_size
					and actual_label.pixel_size == original.pixel_size
					and actual_label.modulate == original.modulate
				),
				"historical board label text and rendering survive independent factory comparison"
			)
	if item in ["ST-065", "ST-065-T", "ST-022", "ST-023"] and item not in _anonymous_control_items:
		_anonymous_control_items.append(item)
		_anonymous_wall_controls(reference, model)
	reference.free()


func _sightlines(root: Node3D, net: Node3D) -> void:
	for child: Node in root.get_node("Visual").get_children():
		if not child is Node3D:
			continue
		var anchor: Node3D = child as Node3D
		if not anchor.has_meta("rest_position"):
			continue
		var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
		_check(
			_sightline_clear(eye, Vector3(0, 1, 8), net),
			"eye-to-pitch ray traverses only verified net panels and rejects all opaque solids"
		)
	# Protected near-field batting corridors on both sides stay clear of all stand geometry.
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1
		)
		_check(
			get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both batting-side pitch corridors clear actual bowl collision"
		)


func _capture(label: String, eye: Vector3, target: Vector3, size_value: float) -> void:
	if StadiumAssetCapture.directory().is_empty() or DisplayServer.get_name() == "headless":
		return
	_camera.position = eye
	_camera.look_at(target)
	_camera.size = size_value
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "native window resize acknowledged")
		_check(
			await Evidence.capture(self, _native, StadiumAssetCapture.directory(), label),
			"actual 1280x720 / 700x393 content readback with eight-frame draw wait"
		)


func _anonymous_wall_mesh(reference: Node3D, member: Node) -> bool:
	return (
		reference.get_meta("wall_item", "") in ["ST-065", "ST-022", "ST-023"]
		and member is MeshInstance3D
		and member.get_parent() == reference.get_node("Visual")
		and (
			String(member.name).begins_with("@MeshInstance3D@") or member.name == &"MeshInstance3D"
		)
	)


func _anonymous_wall_matches(original: Node, actual: Node) -> bool:
	if (
		not original is MeshInstance3D
		or not actual is MeshInstance3D
		or actual.get_class() != original.get_class()
	):
		return false
	var expected: MeshInstance3D = original as MeshInstance3D
	var found: MeshInstance3D = actual as MeshInstance3D
	if (
		found.mesh == null
		or expected.mesh == null
		or found.transform != expected.transform
		or found.visible != expected.visible
		or found.transparency != expected.transparency
		or found.cast_shadow != expected.cast_shadow
		or found.get_child_count() != expected.get_child_count()
		or found.mesh.get_surface_count() != expected.mesh.get_surface_count()
	):
		return false
	for surface in range(expected.mesh.get_surface_count()):
		if found.mesh.surface_get_arrays(surface) != expected.mesh.surface_get_arrays(surface):
			return false
	var material: StandardMaterial3D = found.material_override as StandardMaterial3D
	var expected_material: StandardMaterial3D = expected.material_override as StandardMaterial3D
	if (material == null) != (expected_material == null):
		return false
	return (
		material == null
		or (
			material.albedo_color == expected_material.albedo_color
			and material.transparency == expected_material.transparency
			and material.cull_mode == expected_material.cull_mode
		)
	)


func _anonymous_wall_controls(reference: Node3D, model: Node3D) -> void:
	var visual: Node = model.get_node("Visual")
	var expected_visual: Node = reference.get_node("Visual")
	var children: Array[Node] = visual.get_children()
	_check(children.size() >= 2, "anonymous wall controls require two actual factory members")
	if children.size() < 2:
		return
	var first: MeshInstance3D = children[0] as MeshInstance3D
	var second: MeshInstance3D = children[1] as MeshInstance3D
	var expected: Node = expected_visual.get_child(0)
	_check(
		first != null and second != null and _anonymous_wall_mesh(reference, expected),
		"negative controls operate on authentic unnamed wall meshes"
	)
	if first == null or second == null:
		return
	_check(
		_anonymous_wall_matches(expected, visual.get_child(0)),
		"same anonymous-member predicate accepts the original exact factory slot"
	)
	visual.move_child(second, 0)
	_check(
		not _anonymous_wall_matches(expected, visual.get_child(0)),
		"reordering actual unnamed wall meshes is rejected despite matching parent and class"
	)
	visual.move_child(second, 1)
	_check(
		visual.get_children() == children and _anonymous_wall_matches(expected, first),
		"reorder control restores exact actual child order and mesh semantics"
	)
	var mesh: Mesh = first.mesh
	var substitute: BoxMesh = BoxMesh.new()
	substitute.size = Vector3.ONE * 0.001
	first.mesh = substitute
	_check(
		not _anonymous_wall_matches(expected, visual.get_child(0)),
		"replaced unnamed wall mesh rejects without relying on generated names"
	)
	first.mesh = mesh
	_check(
		first.mesh == mesh and _anonymous_wall_matches(expected, first),
		"replacement control restores exact original mesh resource and vertices"
	)
	var pose: Transform3D = first.transform
	first.position.x += 0.0125
	_check(
		not _anonymous_wall_matches(expected, visual.get_child(0)),
		"changed actual anonymous member pose rejects through the same indexed predicate"
	)
	first.transform = pose
	_check(
		(
			first.transform == pose
			and visual.get_children() == children
			and first.mesh == mesh
			and _anonymous_wall_matches(expected, first)
		),
		"all bounded controls restore exact hierarchy pose and original mesh resource"
	)
