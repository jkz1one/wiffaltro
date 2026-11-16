extends "res://src/tests/stadium_curved_lower_models_test.gd"
## Whole Grand I geometry proof reuses only pure frozen component qualification helpers.

const EXPECTED: Dictionary = {
	"ST-065": 23,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-039": 1,
	"ST-029": 4,
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


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumGrandIVenueStudy.build(self)
	_check(property != null, "independent complete Grand I assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_check(
		(
			record.id == "GRAND-I"
			and record.version == 1
			and record.property == "mogul"
			and record.items.size() == 75
		),
		"distinct Mogul identity and exact seventy-five copies"
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
			_check(row.site in StadiumCurvedLowerSites.GRAND_I, "only central lower bowl sectors")
		if row.item == "ST-038":
			_check(row.site.begins_with("MLIGHT-"), "only authored Mogul light sites")
	_check(
		ClubCareer.same(counts, EXPECTED),
		"independent inventory counts include no roofs or upper bowls"
	)
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(boundary.items.size() == 61, "actual straight Club boundary infrastructure reused")
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
			_sightlines(root, net)
		await _guard_variant(straight_stands)
		var eye_count: int = 0
		for stand: Node3D in straight_stands:
			for anchor: Node3D in stand.get_node("Visual").get_children():
				if not anchor.get_meta("represented_audience", false):
					continue
				eye_count += 1
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var clear: bool = _sightline_clear(eye, Vector3(0, 1, 8), net)
				if not clear:
					_spectator_diagnostic(stand, anchor, eye, Vector3(0, 1, 8), net)
				_check(clear, "every represented straight-stand spectator sees pitch corridor")
		_check(eye_count == 200, "all two hundred straight lower spectators tested")
		await _sightline_controls(net)
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"dormant lighting contributes zero live Light3D nodes"
	)
	for empty: String in ["BOWL-01", "BOWL-05", "JOIN-L", "JOIN-R", "LANDMARK-A"]:
		_check(not sites.has(empty) and empty in record.empty_sites, "reserved empty site " + empty)
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = property.objects["npc-candidate:GRAND-I:v1:" + tower.site]
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
	await _capture("GRAND-I-whole-layout", Vector3(76, 65, -78), Vector3(0, 3, 10), 118)
	await _capture("GRAND-I-bowl-context", Vector3(36, 28, -42), Vector3(0, 2, -10), 69)
	if board != null:
		await _capture("GRAND-I-board-context", Vector3(-7, 13, 8), Vector3(-19, 3, 27), 27)
		await _capture("GRAND-I-board-detail", Vector3(-20, 5, 17), Vector3(-20, 4, 30), 10)
	_check(_native._failures == 0, "normal and small native capture handshake checked")
	property.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumGrandIVenueStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Grand I assembly passed: 75 copies, complete bounds, spectator rays, native views."
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
		"GRAND_I_SPECTATOR_BLOCKED site=",
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
		for anchor: Node3D in old.get_node("Visual").get_children():
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
		original_samples == 200 and original_failures == 20,
		"independent frozen v1 control preserves all200 people and exactly20 measured blockers"
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
