extends "res://src/tests/stadium_grand_i_assembly_test.gd"
## Full Grand II installed geometry; frozen component proofs run on the actual scene objects.

const EXPECTED_II: Dictionary = {
	"ST-065": 23,
	"ST-022": 16,
	"ST-023": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-081": 5,
	"ST-083": 3,
	"ST-082": 3,
	"ST-085": 1,
	"ST-088": 1,
	"ST-039": 1,
	"ST-038": 6
}
const CENTRAL_II: Array[String] = ["BOWL-02", "BOWL-03", "BOWL-04"]


class StackProof:
	extends "res://src/tests/stadium_curved_stack_models_test.gd"

	func _ready() -> void:
		pass


class TransitionProof:
	extends "res://src/tests/stadium_lower_transition_models_test.gd"

	var panel_verifier: Callable

	func _ready() -> void:
		pass

	func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
		return panel_verifier.is_valid() and panel_verifier.call(hit, net)


var _panel_proofs: Dictionary = {}


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumGrandIIVenueStudy.build(self)
	_check(property != null, "independent complete Grand II assembly builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_record_identity(record)
	print(
		"GRAND_II_QUALIFICATION_SOURCES sha256=",
		record.qualification_sources.sha256,
		" files=",
		record.qualification_sources.files.size(),
		" execution_evidence=",
		record.qualification_sources.execution_evidence
	)
	var models: Dictionary = _actual_models(property, record)
	_check(models.size() == 85, "all eighty-five actual occupied sites are distinct")
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_check(
		boundary.items.size() == 61, "actual straight Club shared infrastructure retains61 copies"
	)
	_check(not property.has_node("TemplateBackWall"), "obsolete infinite template wall absent")
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
	var stack: StackProof = StackProof.new()
	var transition: TransitionProof = TransitionProof.new()
	add_child(stack)
	add_child(transition)
	transition.panel_verifier = _verified_panel
	var net: Node3D = models["RECEIVER-CATCH"]
	_actual_net_clearance(net)
	_prepare_panel_proofs(net)
	await _installed_geometry(models, stack, transition, net)
	_check(
		stack._failures == 0 and transition._failures == 0,
		"every reused actual stack and handed-transition geometry assertion passed"
	)
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"dormant rig contributes zero live Light3D nodes"
	)
	_tower_rays(models, record)
	_setup_view()
	await _capture("GRAND-II-whole-layout", Vector3(76, 65, -78), Vector3(0, 3, 10), 118)
	await _capture("GRAND-II-five-bowls-three-stacks", Vector3(38, 32, 24), Vector3(0, 4, -13), 65)
	await _capture("GRAND-II-central-rear-support", Vector3(-13, 13, -38), Vector3(0, 4.5, -24), 22)
	for hand: int in [-1, 1]:
		await _capture(
			"GRAND-II-%s-join" % ("right-stair" if hand == 1 else "left-solid"),
			Vector3(hand * 31, 14, 6),
			Vector3(hand * 20, 3.2, -2),
			17
		)
	await _capture("GRAND-II-board-context", Vector3(-7, 13, 8), Vector3(-19, 3, 27), 27)
	await _capture("GRAND-II-board-detail", Vector3(-20, 5, 17), Vector3(-20, 4, 30), 10)
	_check(_native._failures == 0, "normal and small native capture handshake checked")
	property.queue_free()
	stack.queue_free()
	transition.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumGrandIIVenueStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Grand II assembly passed: 85 copies, complete bounds, 464 eyes, native views."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _record_identity(record: Dictionary) -> void:
	_check(
		(
			record.id == "GRAND-II"
			and record.version == 1
			and record.property == "mogul"
			and record.items.size() == 85
		),
		"distinct Mogul identity and exact eighty-five copies"
	)
	_check(
		(
			record.owner == "npc-venue:grandstand-gardens:grand-ii-v1"
			and record.batting_home == "higher-seed-separate-from-neutral-venue-owner"
		),
		"neutral authored owner stays separate from batting-home designation"
	)
	_check(
		(
			record.environment.target_slots == ["19:10"]
			and record.environment.target_weather == ["clear"]
			and record.environment.certificates.is_empty()
			and not record.environment.night_eligible
		),
		"advertised19:10 clear is unchanged and still explicitly unqualified"
	)
	_check(
		record.lighting.dormant and record.lighting.active_lights == 0 and record.live_units == 0,
		"no lighting certificate or live obstacle is fabricated"
	)
	var counts: Dictionary = {}
	var instances: Array[String] = []
	var sites: Array[String] = []
	for row: Dictionary in record.items:
		counts[row.item] = counts.get(row.item, 0) + 1
		_check(
			not instances.has(row.instance) and not sites.has(row.site),
			"each exact copy and layer-qualified occupied site is unique"
		)
		instances.append(row.instance)
		sites.append(row.site)
		_check(
			(
				row.transform.size() == 12
				and row.instance == "npc-candidate:GRAND-II:v1:" + row.site
				and row.host == record.owner
			),
			"full rigid pose and exact Grand II owner are stored"
		)
		if row.item == "ST-081":
			_check(row.site in StadiumCurvedLowerSites.SITES, "all five lower bowl sites only")
		elif row.item in ["ST-083", "ST-082"]:
			var suffix: String = ":CONCOURSE" if row.item == "ST-083" else ":UPPER"
			_check(
				row.site.ends_with(suffix) and row.site.trim_suffix(suffix) in CENTRAL_II,
				"only central three receive separate concourse and upper layer identities"
			)
			var lower: String = "npc-candidate:GRAND-II:v1:" + row.site.trim_suffix(suffix)
			var supports: Array = [lower]
			if row.item == "ST-082":
				supports.append(lower + ":CONCOURSE")
			_check(
				(
					row.supports == supports
					and (
						row.interface
						== (
							StadiumCurvedStackSites.INTERFACE
							if row.item == "ST-083"
							else StadiumCurvedStackSites.UPPER_INTERFACE
						)
					)
				),
				"serialized support graph names exact same-site lower and purchased concourse"
			)
		elif row.item in ["ST-085", "ST-088"]:
			_check(
				row.site == ("JOIN-R" if row.item == "ST-085" else "JOIN-L"),
				"right and left joins retain different purchased item identities"
			)
		elif row.item == "ST-038":
			_check(row.site in TOWER_SITES, "only six unchanged authored Mogul tower sites")
	_check(
		ClubCareer.same(counts, EXPECTED_II),
		"independent inventory excludes roofs transition concourses and extra purchases"
	)
	for empty: String in ["LANDMARK-A", "SCORE-LARGE-A"]:
		_check(not sites.has(empty) and empty in record.empty_sites, "reserved empty site " + empty)
	for outer: String in ["BOWL-01", "BOWL-05"]:
		_check(
			(
				sites.has(outer)
				and not sites.has(outer + ":CONCOURSE")
				and not sites.has(outer + ":UPPER")
			),
			"outer sites remain complete lower-only bowls"
		)
	_check(
		record.crowd.total == 464 and record.crowd.status == "Working-art-density",
		"represented art population is explicit, without capacity or income authority"
	)


func _actual_models(property: StadiumPropertyGeometry, record: Dictionary) -> Dictionary:
	var actual: Dictionary = {}
	var models: Dictionary = {}
	for model: Node3D in property.find_children("*", "Node3D", true, false):
		if not model.has_meta("candidate_instance"):
			continue
		var item: String = model.get_meta("stadium_item", "")
		var site: String = model.get_meta("candidate_site", "")
		actual[item] = actual.get(item, 0) + 1
		_check(
			not models.has(site), "no duplicate real model can hide behind a unique manifest row"
		)
		models[site] = model
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
				and matching.site == site
				and matching.host == model.get_meta("candidate_host")
				and matching.model_version == model.get_meta("candidate_model_version")
				and property.objects.get(matching.instance) == model
			),
			"every real component retains exact pose site owner version and object binding"
		)
		if item == "ST-038":
			_check(
				(
					model.global_position == TOWER_SITES[site]
					and model.get_meta("reference_target") == TOWER_TARGETS[site]
				),
				"all six real towers keep frozen authored position and reference aim"
			)
		if item in ["ST-081", "ST-083", "ST-082"]:
			_check(
				model.transform == StadiumCurvedLowerSites.pose(site.split(":")[0]),
				"actual lower and purchased layers share exact authored semantic orientation"
			)
	_check(
		ClubCareer.same(actual, EXPECTED_II),
		"actual scene copies match independent manifest counts"
	)
	_check(
		property.objects.size() == 85, "object index has no retained Grand I or phantom identities"
	)
	return models


func _installed_geometry(
	models: Dictionary, stack: StackProof, transition: TransitionProof, net: Node3D
) -> void:
	var stands: Array[Node3D] = []
	var audience: Array[Node3D] = []
	for site: String in StadiumBaselineSites.SITES:
		stands.append(models[site])
		audience.append(models[site])
	for site: String in StadiumCurvedLowerSites.SITES:
		var lower: Node3D = models[site]
		audience.append(lower)
		_ground_and_ends(lower)
		_check(
			StadiumCurvedStackSites.valid_lower(lower, site),
			"installed lower retains the full frozen actual mesh and collision host proof"
		)
		if site in CENTRAL_II:
			var concourse: Node3D = models[site + ":CONCOURSE"]
			var upper: Node3D = models[site + ":UPPER"]
			audience.append(upper)
			_check(
				(
					concourse.get_meta("lower_instance") == lower.get_instance_id()
					and upper.get_meta("lower_instance") == lower.get_instance_id()
					and upper.get_meta("concourse_instance") == concourse.get_instance_id()
				),
				"every purchased upper is supported by its own actual concourse and lower"
			)
			stack._addon_points(concourse)
			stack._structure(lower, concourse, upper)
	for site: String in ["JOIN-R", "JOIN-L"]:
		var join: Node3D = models[site]
		audience.append(join)
		_check(
			(
				join.get_meta("represented_seats") == 18
				and join.get_node("Collision").get_child_count() == 20
			),
			"each handed lower join is a complete standalone assembly with18 people"
		)
		transition._standalone(join)
		transition._convex_correspondence(join)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for site: String in CENTRAL_II:
		stack._support_contacts(models[site], models[site + ":CONCOURSE"], models[site + ":UPPER"])
	await _guard_variant(stands)
	for phase: float in [-PI / 2, 0, PI / 2]:
		for root: Node3D in audience:
			if root.get_meta("stadium_item") != "ST-029":
				StadiumCurvedLowerModels.animate_crowd(root, phase)
		for site: String in StadiumCurvedLowerSites.SITES:
			_test_points(models[site])
		for site: String in CENTRAL_II:
			stack._addon_points(models[site + ":UPPER"])
		for site: String in ["JOIN-R", "JOIN-L"]:
			transition._transition_points(models[site])
			transition._separating_planes(
				models[site],
				models["BOWL-01" if site == "JOIN-R" else "BOWL-05"],
				models["BASE-R1" if site == "JOIN-R" else "BASE-L1"]
			)
		_spectator_population(audience, net)
	for root: Node3D in audience:
		if root.get_meta("stadium_item") != "ST-029":
			StadiumCurvedLowerModels.animate_crowd(root, 0)
	await _join_neighbor_proof(models, audience, transition, net)
	await _sightline_controls(net)
	_panel_visual_controls(net, transition)
	stack._camera_corridors()


func _spectator_population(roots: Array[Node3D], net: Node3D) -> void:
	var counts: Dictionary = {}
	for root: Node3D in roots:
		var item: String = root.get_meta("stadium_item")
		for anchor: Node3D in root.get_node("Visual").get_children():
			if not anchor.get_meta("represented_audience", false):
				continue
			counts[item] = counts.get(item, 0) + 1
			var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
			var clear: bool = _sightline_clear(eye, Vector3(0, 1, 8), net)
			if not clear:
				_spectator_diagnostic(root, anchor, eye, Vector3(0, 1, 8), net)
			_check(clear, "every represented actual spectator sees the unchanged pitch corridor")
	_check(
		ClubCareer.same(
			counts, {"ST-029": 200, "ST-081": 180, "ST-082": 48, "ST-085": 18, "ST-088": 18}
		),
		"all464 unchanged eye origins tested, including both bounded sway extremes"
	)


func _join_neighbor_proof(
	models: Dictionary, audience: Array[Node3D], transition: TransitionProof, net: Node3D
) -> void:
	var signatures: Dictionary = {}
	var before: Array[Dictionary] = []
	var host: Node = models["JOIN-R"].get_parent()
	for site: String in ["JOIN-R", "JOIN-L"]:
		host.remove_child(models[site])
	for root: Node3D in audience:
		if root.get_meta("stadium_item") in ["ST-085", "ST-088"]:
			continue
		signatures[root.get_instance_id()] = transition._neighbor_signature(root)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for site: String in StadiumBaselineSites.SITES:
		for anchor: Node3D in models[site].get_node("Visual").get_children():
			if not anchor.get_meta("represented_audience", false):
				continue
			var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
			var hits: Array[RID] = transition._opaque_path(eye, Vector3(0, 1, 8), net)
			_check(hits.is_empty(), "all revised baseline eye paths are clear with joins absent")
			before.append({"eye": eye, "hits": hits})
	_check(before.size() == 200, "record every physical baseline path before adding both joins")
	for site: String in ["JOIN-R", "JOIN-L"]:
		host.add_child(models[site])
	await get_tree().physics_frame
	await get_tree().physics_frame
	for root: Node3D in audience:
		if signatures.has(root.get_instance_id()):
			_check(
				signatures[root.get_instance_id()] == transition._neighbor_signature(root),
				"complete before/after geometry proves joins never stretch lift or cut neighbors"
			)
	for row: Dictionary in before:
		_check(
			transition._opaque_path(row.eye, Vector3(0, 1, 8), net) == row.hits,
			"full original segment for every baseline eye stays clear after both actual joins"
		)
	for site: String in ["JOIN-R", "JOIN-L"]:
		_join_no_overlap(models[site], host.get_node("PropertyGround"))


func _join_no_overlap(root: Node3D, ground: StaticBody3D) -> void:
	# The full scene has an intentional supporting ground. Exclude that exact original
	# body only after proving the join never penetrates its actual top surface.
	var ground_shape: CollisionShape3D = ground.get_child(0)
	var top: float = (
		(ground_shape.global_transform * ground_shape.shape.get_debug_mesh().get_aabb()).end.y
	)
	var excluded: Array[RID] = [ground.get_rid()]
	for body: StaticBody3D in root.get_node("Collision").get_children():
		excluded.append(body.get_rid())
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		var bounds: AABB = shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
		_check(
			bounds.position.y >= top - 0.0001, "each complete join solid sits above actual ground"
		)
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = 1
		query.margin = 0
		query.exclude = excluded
		_check(
			get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"actual join collider overlaps no other installed item or opposite hand"
		)


func _tower_rays(models: Dictionary, record: Dictionary) -> void:
	_check(record.lighting.towers.size() == 6, "exact six dormant tower records")
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = models[tower.site]
		var actual_heads: Array = model.get_meta("candidate_head_rays")
		_check(actual_heads.size() == 4 and tower.heads.size() == 4, "four dormant head identities")
		for index in range(actual_heads.size()):
			var actual: Dictionary = actual_heads[index]
			var frozen: Dictionary = tower.heads[index]
			var origin: Vector3 = actual.origin
			var direction: Vector3 = actual.direction
			_check(
				(
					actual.id == frozen.id
					and ClubCareer.same([origin.x, origin.y, origin.z], frozen.origin)
					and ClubCareer.same([direction.x, direction.y, direction.z], frozen.direction)
				),
				"all24 actual dormant rays retain serialized origin direction and identity"
			)


func _prepare_panel_proofs(net: Node3D) -> void:
	# Build an independent original grid and replay the exact public peak-flex operation
	# used by _actual_net_clearance. Current body labels alone never prove optical holes.
	var reference: Node3D = StadiumReceiverNetModels.create()
	for id: String in StadiumReceiverNetModels.PANELS:
		var expected: MeshInstance3D = reference.get_node("Visual/" + id)
		var impact: Vector3 = expected.transform * Vector3(0, 3.375, 0)
		_check(
			StadiumReceiverNetModels.flex(reference, id, 0.275, impact),
			"independent actual canonical grid reaches the same bounded peak flex"
		)
		var actual: MeshInstance3D = net.get_node("Visual/" + id)
		var collider: StaticBody3D = reference.get_node("Collision/" + id)
		var shape: CollisionShape3D = collider.get_child(0)
		_panel_proofs[id] = {
			"mesh": actual,
			"material": actual.material_override,
			"material_semantics":
			_panel_material_semantics(expected.material_override as StandardMaterial3D),
			"pose": expected.transform,
			"body_pose": collider.transform,
			"shape_pose": shape.transform,
			"shape_size": (shape.shape as BoxShape3D).size,
			"rest": expected.get_meta("rest_vertices"),
			"arrays": expected.mesh.surface_get_arrays(0)
		}
	reference.free()


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	if not super._verified_panel(hit, net):
		return false
	var body: StaticBody3D = hit.collider
	var id: String = body.get_meta("surface_id")
	if not _panel_proofs.has(id):
		return false
	var proof: Dictionary = _panel_proofs[id]
	var mesh: MeshInstance3D = net.get_node("Visual/" + id)
	var shape: CollisionShape3D = body.get_child(0)
	return (
		mesh == proof.mesh
		and mesh.is_visible_in_tree()
		and mesh.transparency == 0
		and mesh.transform == proof.pose
		and body.transform == proof.body_pose
		and shape.transform == proof.shape_pose
		and not shape.disabled
		and (shape.shape as BoxShape3D).size == proof.shape_size
		and shape.shape.margin == 0
		and mesh.mesh is ArrayMesh
		and mesh.mesh.get_surface_count() == 1
		and (mesh.mesh as ArrayMesh).surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES
		and mesh.mesh.surface_get_arrays(0) == proof.arrays
		and mesh.get_meta("rest_vertices") == proof.rest
		and mesh.material_override == proof.material
		and mesh.material_override is StandardMaterial3D
		and (
			_panel_material_semantics(mesh.material_override as StandardMaterial3D)
			== proof.material_semantics
		)
	)


func _panel_material_semantics(material: StandardMaterial3D) -> Dictionary:
	var result: Dictionary = {}
	if material == null:
		return result
	for property: Dictionary in material.get_property_list():
		var key: String = property.name
		if (
			int(property.usage) & PROPERTY_USAGE_STORAGE == 0
			or key.begins_with("resource_")
			or key == "script"
			or key.begins_with("metadata/")
		):
			continue
		var value: Variant = material.get(key)
		result[key] = value.get_instance_id() if value is Resource else value
	return result


func _panel_visual_controls(net: Node3D, transition: TransitionProof) -> void:
	var from: Vector3 = Vector3(0, 3, -6)
	var to: Vector3 = Vector3(0, 3, 0)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	_check(
		not hit.is_empty() and _verified_panel(hit, net),
		"original current peak-flex strand-grid passes its independent full geometry witness"
	)
	if hit.is_empty():
		return
	var mesh: MeshInstance3D = net.get_node("Visual/ST073_CENTER_NET")
	var original: Mesh = mesh.mesh
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [
		Vector3(-2, 0.25, 0),
		Vector3(2, 0.25, 0),
		Vector3(2, 6.5, 0),
		Vector3(-2, 0.25, 0),
		Vector3(2, 6.5, 0),
		Vector3(-2, 6.5, 0)
	]:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(point)
	mesh.mesh = surface.commit()
	_check(
		mesh.get_meta("rest_vertices") == _panel_proofs["ST073_CENTER_NET"].rest,
		"opaque replacement preserves trusted-looking grid metadata and physical panel body"
	)
	_check(
		not _verified_panel(hit, net) and not _sightline_clear(from, to, net),
		"actual opaque full-panel replacement cannot inherit original strand-grid exemption"
	)
	var opaque: Array[RID] = transition._opaque_path(from, to, net)
	_check(
		opaque.size() == 1 and opaque[0] == hit.collider.get_rid(),
		"independent complete-segment transition traversal also rejects replacement panel"
	)
	mesh.mesh = original
	mesh.visible = false
	_check(not _verified_panel(hit, net), "hidden original panel is not represented as visible net")
	mesh.visible = true
	var material: StandardMaterial3D = mesh.material_override
	var color: Color = material.albedo_color
	material.albedo_color = Color.RED
	_check(not _verified_panel(hit, net), "in-place original material mutation invalidates witness")
	material.albedo_color = color
	_check(
		(
			_verified_panel(hit, net)
			and _sightline_clear(from, to, net)
			and transition._opaque_path(from, to, net).is_empty()
		),
		"restoring exact actual mesh and material restores both full-segment optical proofs"
	)
