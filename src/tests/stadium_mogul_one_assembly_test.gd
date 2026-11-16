extends "res://src/tests/stadium_curved_lower_models_test.gd"

const Evidence = preload("res://src/tests/stadium_mogul_one_evidence.gd")
## Whole AM-01 geometry proof reuses only pure frozen component qualification helpers.

const EXPECTED: Dictionary = {
	"ST-065": 22,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-039": 1,
	"ST-029": 2,
	"ST-081": 3,
	"ST-038": 6
}

const TOWER_SITES: Dictionary = {
	"MLIGHT-HL": Vector3(-46, 0, -22),
	"MLIGHT-HR": Vector3(46, 0, -22),
	"MLIGHT-ML": Vector3(-47, 0, 14),
	"MLIGHT-MR": Vector3(47, 0, 14),
	"MLIGHT-OL": Vector3(-46, 0, 50),
	"MLIGHT-OR": Vector3(46, 0, 50)
}
const TOWER_TARGETS: Dictionary = {
	"MLIGHT-HL": Vector3(-10, 1.5, 10),
	"MLIGHT-HR": Vector3(10, 1.5, 10),
	"MLIGHT-ML": Vector3(-6, 1.5, 15),
	"MLIGHT-MR": Vector3(6, 1.5, 15),
	"MLIGHT-OL": Vector3(-10, 1.5, 18),
	"MLIGHT-OR": Vector3(10, 1.5, 18)
}

var _anonymous_control_items: Array[String] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumMogulOneStudy.build(self)
	_check(property != null, "independent complete AM-01 assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_exact_contract(property, record)
	_check(
		(
			record.id == "AM-01"
			and record.version == 1
			and record.property == "mogul"
			and record.items.size() == 72
		),
		"distinct Mogul identity and exact seventy-two copies"
	)
	_check(
		record.environment.certificates.is_empty() and not record.environment.night_eligible,
		"fixed lighting never implies night qualification"
	)
	var counts: Dictionary = {}
	var instances: Array[String] = []
	var sites: Array[String] = []
	for row: Dictionary in record.items:
		counts[row.item] = counts.get(row.item, 0) + 1
		_check(
			not instances.has(row.instance) and not sites.has(row.site),
			"each exact copy and occupied site is unique"
		)
		instances.append(row.instance)
		sites.append(row.site)
		_check(row.transform.size() == 12, "full rigid pose is stored")
		if row.item == "ST-081":
			_check(row.site in ["BOWL-02", "BOWL-03", "BOWL-04"], "only central lower bowl sectors")
		if row.item == "ST-038":
			_check(row.site.begins_with("MLIGHT-"), "only authored Mogul light sites")
	_check(
		ClubCareer.same(counts, EXPECTED),
		"independent inventory counts include no roofs or upper bowls"
	)
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(boundary.items.size() == 60, "actual deeper-center Club boundary infrastructure reused")
	_check(not property.has_node("TemplateBackWall"), "obsolete infinite wall absent")
	var roots: Array[Node3D] = []
	var straight_stands: Array[Node3D] = []
	var net: Node3D = null
	var board: Node3D = null
	var actual: Dictionary = {}
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if not model.has_meta("candidate_instance"):
			continue
		var item: String = model.get_meta("stadium_item", "")
		_factory_identity(model, record)
		actual[item] = actual.get(item, 0) + 1
		var matching: Dictionary = {}
		for row: Dictionary in record.items:
			if row.instance == model.get_meta("candidate_instance"):
				matching = row
		var components: Array[float] = []
		for vector: Vector3 in [
			model.global_basis.x, model.global_basis.y, model.global_basis.z, model.global_position
		]:
			components.append_array([vector.x, vector.y, vector.z])
		_check(
			(
				not matching.is_empty()
				and ClubCareer.same(components, matching.transform)
				and matching.site == model.get_meta("candidate_site")
				and matching.host == model.get_meta("candidate_host")
			),
			"every real component has the full declared pose, site, and owner"
		)
		if item == "ST-038":
			var site: String = model.get_meta("candidate_site")
			_check(
				(
					model.global_position == TOWER_SITES[site]
					and (model.get_meta("reference_target") == TOWER_TARGETS[site])
				),
				"six real towers retain frozen authored positions and reference aims"
			)
		if item == "ST-029":
			straight_stands.append(model)
		if item == "ST-081":
			roots.append(model)
			_check(
				model.transform == StadiumCurvedLowerSites.pose(model.get_meta("candidate_site")),
				"actual bowl orientation matches semantic site"
			)
		if item == "ST-073":
			net = model
		if item == "ST-039":
			board = model
	_check(
		ClubCareer.same(actual, EXPECTED), "actual scene copies match independent manifest counts"
	)
	_check(
		roots.size() == 3 and net != null and board != null, "required physical assemblies exist"
	)
	for mesh: MeshInstance3D in property.find_children("*", "MeshInstance3D", true, false):
		_check(
			StadiumProperty.contains("mogul", mesh.global_transform * mesh.get_aabb()),
			"every actual catalog mesh fits Mogul land: " + str(mesh.get_path())
		)
	for shape: CollisionShape3D in property.find_children("*", "CollisionShape3D", true, false):
		_check(
			StadiumProperty.contains(
				"mogul", shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
			),
			"complete physical collision bounds fit owned Mogul land"
		)
	if net != null and roots.size() == 3:
		_actual_net_clearance(net)
		for root: Node3D in roots:
			for phase: float in [-PI / 2, 0, PI / 2]:
				StadiumCurvedLowerModels.animate_crowd(root, phase)
				_test_points(root)
			_ground_and_ends(root)
			StadiumCurvedLowerModels.animate_crowd(root, 0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for root: Node3D in roots:
			for phase: float in [-PI / 2, 0, PI / 2]:
				StadiumCurvedLowerModels.animate_crowd(root, phase)
				_sightlines(root, net)
			StadiumCurvedLowerModels.animate_crowd(root, 0)
		await _guard_variant(straight_stands)
		var eye_count: int = 0
		for stand: Node3D in straight_stands:
			for child: Node in stand.get_node("Visual").get_children():
				if not child is Node3D:
					continue
				var anchor: Node3D = child as Node3D
				if not anchor.get_meta("represented_audience", false):
					continue
				eye_count += 1
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var clear: bool = _sightline_clear(eye, Vector3(0, 1, 8), net)
				if not clear:
					_spectator_diagnostic(stand, anchor, eye, Vector3(0, 1, 8), net)
				_check(clear, "every represented straight-stand spectator sees pitch corridor")
		_check(eye_count == 100, "all one hundred straight lower spectators tested")
		await _sightline_controls(net)
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"dormant lighting contributes zero live Light3D nodes"
	)
	for empty: String in [
		"BASE-L2", "BASE-R2", "BOWL-01", "BOWL-05", "JOIN-L", "JOIN-R", "LANDMARK-A"
	]:
		_check(not sites.has(empty) and empty in record.empty_sites, "reserved empty site " + empty)
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = property.objects["npc-candidate:AM-01:deeper-center-v1:" + tower.site]
		var actual_heads: Array = model.get_meta("candidate_head_rays")
		_check(actual_heads.size() == 4 and tower.heads.size() == 4, "four dormant head identities")
		for index in range(actual_heads.size()):
			var actual_head: Dictionary = actual_heads[index]
			var frozen: Dictionary = tower.heads[index]
			var origin: Vector3 = actual_head.origin
			var direction: Vector3 = actual_head.direction
			_check(
				(
					actual_head.id == frozen.id
					and ClubCareer.same([origin.x, origin.y, origin.z], frozen.origin)
					and ClubCareer.same([direction.x, direction.y, direction.z], frozen.direction)
				),
				"actual dormant per-head ray matches serialized origin, direction, and identity"
			)
	# Captures are evidence of the complete installed layout, not isolated model collages.
	_setup_view()
	await _capture("AM-01-whole-layout", Vector3(76, 65, -78), Vector3(0, 3, 10), 118)
	await _capture("AM-01-bowl-context", Vector3(36, 28, -42), Vector3(0, 2, -10), 69)
	if board != null:
		await _capture("AM-01-board-context", Vector3(-7, 13, 8), Vector3(-19, 3, 27), 27)
		await _capture("AM-01-board-detail", Vector3(-20, 5, 17), Vector3(-20, 4, 30), 10)
	_check(_native._failures == 0, "normal and small native capture handshake checked")
	property.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumMogulOneStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro AM-01 assembly passed: 72 copies, complete bounds, spectator rays, native views."
		)
	get_tree().quit(0 if _failures == 0 else 1)


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
		"MOGUL_ONE_SPECTATOR_BLOCKED site=",
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


func _guard_variant(stands: Array[Node3D]) -> void:
	var original_failures: int = 0
	var original_samples: int = 0
	for current: Node3D in stands:
		_check(
			(
				current.get_meta("model_variant", "") == "BASE-LOWER-SIGHTLINE-v2"
				and current.get_meta("model_version", 0) == 2
			),
			"new lower-only Working model identity is explicit"
		)
		var old: Node3D = StadiumBaselineStandModels.lower()
		old.visible = false
		add_child(old)
		old.transform = current.global_transform
		for body: StaticBody3D in old.get_node("Collision").get_children():
			body.collision_layer = 128
		_guard_difference(old, current)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for child: Node in old.get_node("Visual").get_children():
			if not child is Node3D:
				continue
			var anchor: Node3D = child as Node3D
			if not anchor.get_meta("represented_audience", false):
				continue
			original_samples += 1
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				anchor.global_position + Vector3.UP * 0.57, Vector3(0, 1, 8), 128
			)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
			var first_row: bool = int(String(anchor.name).trim_prefix("CrowdAnchor")) < 5
			if first_row:
				original_failures += int(not hit.is_empty())
				_check(
					(
						not hit.is_empty()
						and hit.collider == old.get_node("Collision/FrontGuard")
						and is_equal_approx(old.to_local(hit.position).y, 3.990334)
					),
					"frozen v1 reproduces its measured first-row physical guard obstruction"
				)
			else:
				_check(hit.is_empty(), "remaining frozen v1 spectator rays are unchanged and clear")
		old.queue_free()
		await get_tree().process_frame
	_check(
		original_samples == 100 and original_failures == 10,
		"independent frozen v1 control preserves all100 people and exactly10 measured blockers"
	)


func _guard_difference(old: Node3D, current: Node3D) -> void:
	var before: Array[Node] = old.find_children("*", "Node", true, false)
	var after: Array[Node] = current.find_children("*", "Node", true, false)
	_check(before.size() == after.size(), "variant adds or removes no model members")
	for original: Node in before:
		var path: NodePath = old.get_path_to(original)
		var revised: Node = (
			current.get_node(old.get_path_to(original.get_parent())).get_child(original.get_index())
			if original is CollisionShape3D
			else current.get_node_or_null(path)
		)
		_check(
			revised != null and revised.get_class() == original.get_class(),
			"variant preserves every member type and identity"
		)
		if revised == null:
			continue
		var guard: bool = String(path) in ["Visual/FrontGuard", "Collision/FrontGuard"]
		if original is Node3D:
			var revised_node: Node3D = revised as Node3D
			if guard:
				_check(
					(
						revised_node.position == Vector3(-0.35, 3.45, 0.06)
						and original.position == Vector3(-0.35, 3.5, 0.06)
						and revised_node.basis == original.basis
					),
					"only guard center lowers0.05m without rotation or scale"
				)
			else:
				_check(
					revised_node.transform == original.transform,
					"all decks seats people and other component transforms remain exact"
				)
		if original is MeshInstance3D:
			var revised_mesh: MeshInstance3D = revised as MeshInstance3D
			if guard:
				_check(
					(
						(original.mesh as BoxMesh).size == Vector3(5.3, 1, 0.12)
						and (revised_mesh.mesh as BoxMesh).size == Vector3(5.3, 0.9, 0.12)
					),
					"only actual visible guard height changes0.10m"
				)
			else:
				for surface in range(original.mesh.get_surface_count()):
					_check(
						(
							original.mesh.surface_get_arrays(surface)
							== revised_mesh.mesh.surface_get_arrays(surface)
						),
						"every non-guard actual mesh vertex remains identical"
					)
		if original is CollisionShape3D:
			var revised_shape: CollisionShape3D = revised as CollisionShape3D
			if String(path).begins_with("Collision/FrontGuard/"):
				_check(
					(
						(original.shape as BoxShape3D).size == Vector3(5.3, 1, 0.12)
						and (revised_shape.shape as BoxShape3D).size == Vector3(5.3, 0.9, 0.12)
					),
					"physical guard matches the exact0.10m visible height reduction"
				)
			else:
				_check(
					(
						original.shape.get_debug_mesh().surface_get_arrays(0)
						== revised_shape.shape.get_debug_mesh().surface_get_arrays(0)
					),
					"all non-guard physical vertices remain exact"
				)
	var visual: MeshInstance3D = current.get_node("Visual/FrontGuard")
	var body: StaticBody3D = current.get_node("Collision/FrontGuard")
	var shape: CollisionShape3D = body.get_child(0)
	var visible_bounds: AABB = visual.transform * visual.get_aabb()
	var physical_bounds: AABB = (
		body.transform * shape.transform * shape.shape.get_debug_mesh().get_aabb()
	)
	_check(
		(
			visible_bounds.is_equal_approx(physical_bounds)
			and is_equal_approx(visible_bounds.position.y, 3.0)
			and is_equal_approx(visible_bounds.end.y, 3.90)
		),
		"visible and physical guard bounds match from unchanged deck3.0 to lowered top3.90"
	)


func _exact_contract(property: StadiumPropertyGeometry, record: Dictionary) -> void:
	_check(property is StadiumMogulOneProperty, "actual AM-01 property factory identity")
	_check(record.owner == "npc-venue:AM-01:deeper-center-v1", "exact independent AM-01 owner")
	_check(
		record.live_units == 0 and record.status == "CANDIDATE" and record.mapping == "WORKING",
		"Working authoring grants no live units"
	)
	_check(
		(
			record.environment.target_slots == ["13:10", "16:10"]
			and record.environment.target_weather == ["clear"]
		),
		"only intended ordinary clear slots"
	)
	_check(
		(
			record.endowment
			== {
				"blueprint_value": 4500,
				"copy_value": 3670,
				"land_value": 6400,
				"total_value": 14570
			}
		),
		"independent complete current-catalog endowment"
	)
	_check(
		(
			record.surface
			== {
				"geometry": "flat",
				"grass": "default",
				"ground": "default",
				"markings": "default",
				"bounds": [-52, -30, 104, 88]
			}
		),
		"all-default flat Mogul surface has exact owned bounds"
	)
	_check(
		(
			record.crowd.total == 208
			and record.crowd.baseline_lower == 100
			and record.crowd.bowl_lower == 108
		),
		"exact represented art population grants no capacity"
	)
	_check(
		record.structural_layers.roofs == 0 and record.structural_layers.transition_concourses == 0,
		"no unpurchased overhead or transition layers"
	)
	var source: FieldDefinition = load("res://src/content/fields/npc_venue_field.tres")
	_check(
		(
			property.field != source
			and property.field.get_script() == source.get_script()
			and ClubCareer.same(
				StadiumMogulOneStudy.field_snapshot(property.field),
				StadiumMogulOneStudy.field_snapshot(source)
			)
		),
		"private duplicated unchanged NPC field semantics"
	)
	_check(
		(
			record.field.id == "field.npc_venue"
			and record.field.safe_hit_z_m == 11.25
			and record.field.deep_air_z_m == 17.0
			and record.field.back_wall_z_m == 23.4
			and record.field.home_run_height_m == 3.25
			and record.field.fair_half_angle_degrees == 42.0
		),
		"source-independent unchanged sport dimensions"
	)
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(
		(
			(
				boundary.get_script()
				== preload("res://src/presentation/stadium/stadium_club_boundary_study.gd")
			)
			and boundary.graph.segments().size() == 16
		),
		"unmodified qualified Club boundary factory owns sixteen deeper-center edges"
	)
	_check(
		(
			(
				boundary.graph.signature()
				== StadiumDugoutBoundary.candidate("deeper_center").signature()
			)
			and record.boundary == boundary.graph.signature()
		),
		"actual deeper-center graph matches exact held serialized graph"
	)
	_check(
		(
			boundary.graph.segment("BACK-02").a == Vector2(10, 26)
			and boundary.graph.segment("BACK-02").b == Vector2(-10, 26)
		),
		"center cap stays at independent authored26m depth"
	)
	var blueprints: Array = EXPECTED.keys()
	blueprints.sort()
	_check(
		(
			record.blueprint_entitlements == blueprints
			and record.catalog == StadiumCatalog.signature()
		),
		"eleven exact distinct blueprint entitlements retain current catalog signature"
	)
	var versions: Dictionary = {
		"ST-065": 2,
		"ST-022": 2,
		"ST-023": 2,
		"ST-074": 1,
		"ST-021": 1,
		"ST-026": 1,
		"ST-073": 2,
		"ST-029": 2,
		"ST-081": 1,
		"ST-039": 1,
		"ST-038": 1
	}
	var heads: int = 0
	for row: Dictionary in record.items:
		_check(
			(
				row.instance == "npc-candidate:AM-01:deeper-center-v1:" + row.site
				and row.host == "npc-venue:AM-01:deeper-center-v1"
			),
			"exact copy prefix and host cannot inherit another profile"
		)
		_check(
			versions.has(row.item) and row.model_version == versions.get(row.item),
			"independently frozen factory version"
		)
		_check(
			row.model_variant == ("BASE-LOWER-SIGHTLINE-v2" if row.item == "ST-029" else ""),
			"only exact guard-v2 lower stand variant"
		)
		if row.item == "ST-029":
			_check(row.site in ["BASE-L1", "BASE-R1"], "only two first baseline hosts are occupied")
		if row.item == "ST-081":
			_check(
				row.site in ["BOWL-02", "BOWL-03", "BOWL-04"],
				"only three central lower bowl sectors"
			)
		if row.item == "ST-039":
			var board: Node3D = property.objects[row.instance]
			_check(
				(
					row.site == "SCORE-SMALL"
					and board.transform == Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
				),
				"historical manual board remains grounded at exact180degree SCORE-SMALL pose"
			)
	for tower: Dictionary in record.lighting.towers:
		heads += tower.heads.size()
		_check(
			tower.profile == "MOGUL6-STANDARD",
			"all dormant towers retain exact existing standard profile"
		)
	_check(
		heads == 24 and record.lighting.dormant and record.lighting.active_lights == 0,
		"exact24 dormant rays, zero live lights and no night certificate"
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
		"ST-065", "ST-022", "ST-023":
			reference = StadiumWallPanelModels.create(item, row.span)
			reference.get_node("PanelCollision").free()
		"ST-074":
			reference = StadiumConcreteDugoutModels.create()
		"ST-021":
			reference = StadiumFoulPoleModels.create(3.25)
		"ST-026":
			reference = StadiumTargetModels.create()
		"ST-073":
			reference = StadiumReceiverNetModels.create()
		"ST-029":
			reference = StadiumBaselineSightlineModels.lower()
		"ST-081":
			reference = StadiumCurvedLowerModels.create()
		"ST-039":
			reference = StadiumClubModels.create("ST-039")
		"ST-038":
			reference = StadiumFourHeadTowerModels.create()
			add_child(reference)
			_check(
				StadiumFourHeadTowerSites.place(reference, site),
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
	if item in ["ST-065", "ST-022", "ST-023"] and item not in _anonymous_control_items:
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
