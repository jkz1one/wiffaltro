extends "res://src/tests/stadium_grand_ii_assembly_test.gd"
## Exact107-copy installed composition; original component proofs run on real scene objects.

const EXPECTED_III: Dictionary = {
	"ST-065": 23,
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
	"ST-083": 5,
	"ST-082": 5,
	"ST-084": 5,
	"ST-085": 1,
	"ST-088": 1,
	"ST-086": 1,
	"ST-089": 1,
	"ST-040": 1,
	"ST-076": 4,
	"ST-046": 1
}
const COPY_PRICES: Dictionary = {
	"ST-065": 35,
	"ST-022": 25,
	"ST-023": 25,
	"ST-074": 140,
	"ST-021": 90,
	"ST-026": 70,
	"ST-073": 130,
	"ST-029": 100,
	"ST-031": 60,
	"ST-030": 150,
	"ST-053": 110,
	"ST-081": 140,
	"ST-083": 80,
	"ST-082": 180,
	"ST-084": 140,
	"ST-085": 100,
	"ST-088": 100,
	"ST-086": 60,
	"ST-089": 60,
	"ST-040": 220,
	"ST-076": 180,
	"ST-046": 260
}
const PREMIUM_SITES: Dictionary = {
	"PLIGHT-HL": Vector3(-46, 0, -22),
	"PLIGHT-HR": Vector3(46, 0, -22),
	"PLIGHT-OL": Vector3(-46, 0, 50),
	"PLIGHT-OR": Vector3(46, 0, 50)
}
const PREMIUM_TARGETS: Dictionary = {
	"PLIGHT-HL": Vector3(-8, 1.5, 12),
	"PLIGHT-HR": Vector3(8, 1.5, 12),
	"PLIGHT-OL": Vector3(-8, 1.5, 18),
	"PLIGHT-OR": Vector3(8, 1.5, 18)
}
const G3S = preload("res://src/gameplay/stadium/stadium_grand_three_stack_sites.gd")
const PremiumContract = preload("res://src/tests/stadium_premium_light_tower_contract.gd")
const WaterfallContract = preload("res://src/tests/stadium_waterfall_contract.gd")


class GeometryProof:
	extends "res://src/tests/stadium_grand_iii_net_proof.gd"

	func _ready() -> void:
		pass


class PremiumProof:
	extends "res://src/tests/stadium_premium_light_tower_test.gd"

	func _ready() -> void:
		pass


class WaterfallProof:
	extends "res://src/tests/stadium_waterfall_test.gd"

	func _ready() -> void:
		pass


var _complete_paths: Array[Dictionary] = []


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var property: StadiumPropertyGeometry = StadiumGrandIIIVenueStudy.build(self)
	_check(property != null, "independent exact complete Grand III builds")
	if property == null:
		get_tree().quit(1)
		return
	var record: Dictionary = property.get_meta("candidate_venue")
	_record_identity(record)
	print(
		"GRAND_III_QUALIFICATION_SOURCES sha256=",
		record.qualification_sources.sha256,
		" files=",
		record.qualification_sources.files.size(),
		" execution_evidence=",
		record.qualification_sources.execution_evidence
	)
	var models: Dictionary = _actual_models(property, record)
	if models.size() != 107 or _failures > 0:
		get_tree().quit(1)
		return
	var boundary: StadiumClubBoundaryStudy = property.get_node("ClubBoundary")
	_mechanical_identity(property, record, boundary)
	_check(
		boundary.items.size() == 61, "exact shared61 copies preserve the original mechanical graph"
	)
	_check(not property.has_node("TemplateBackWall"), "obsolete infinite template wall is absent")
	for mesh: MeshInstance3D in property.find_children("*", "MeshInstance3D", true, false):
		_check(
			StadiumProperty.contains("mogul", mesh.global_transform * mesh.get_aabb()),
			"complete actual visible geometry fits Mogul property: " + str(mesh.get_path())
		)
	for shape: CollisionShape3D in property.find_children("*", "CollisionShape3D", true, false):
		_check(
			StadiumProperty.contains(
				"mogul", shape.global_transform * shape.shape.get_debug_mesh().get_aabb()
			),
			"complete actual physical geometry fits Mogul property"
		)
	var geometry: GeometryProof = GeometryProof.new()
	var transition: TransitionProof = TransitionProof.new()
	var premium: PremiumProof = PremiumProof.new()
	var waterfall: WaterfallProof = WaterfallProof.new()
	add_child(geometry)
	add_child(transition)
	add_child(premium)
	add_child(waterfall)
	var net: Node3D = models["RECEIVER-CATCH"]
	_actual_net_clearance(net)
	var witness_ready: bool = geometry._init_net_witness() and geometry.audit_installed(net)
	_check(witness_ready, "independent authentic sparse-grid witness initializes")
	if not witness_ready:
		property.queue_free()
		geometry.queue_free()
		transition.queue_free()
		premium.queue_free()
		waterfall.queue_free()
		await get_tree().process_frame
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	transition.panel_verifier = geometry._verified_panel
	if not await _complete_geometry(models, geometry, transition, net):
		_check(false, "failed complete geometry stops dependent qualification")
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	_tower_rays(models, record)
	for site: String in PREMIUM_SITES:
		var tower: Node3D = models[site]
		_check(
			PremiumContract.valid(tower),
			"every installed premium tower matches independent literals"
		)
		premium._geometry(tower)
		premium._reservations(tower)
		premium._collision_rays(tower)
	waterfall._waterfall = models["LANDMARK-A"]
	_check(
		WaterfallContract.valid(waterfall._waterfall),
		"actual installed waterfall matches independent complete geometry/material contract"
	)
	_check(
		waterfall._waterfall.transform == Transform3D(Basis.IDENTITY, Vector3(36.5, 0, 44)),
		"waterfall keeps the exact bounded LANDMARK-A pose"
	)
	waterfall._geometry()
	_board_reservation(models["BOARD-LARGE-v2"])
	_check(
		property.find_children("*", "Light3D", true, false).is_empty(),
		"all four premium towers remain dormant with no fabricated live lights"
	)
	_check(
		(
			geometry._failures == 0
			and transition._failures == 0
			and premium._failures == 0
			and waterfall._failures == 0
		),
		"all independent full installed component assertions propagate"
	)
	_setup_view()
	await _capture("GRAND-III-whole-layout", Vector3(76, 65, -78), Vector3(0, 5, 10), 118)
	await _capture("GRAND-III-nine-canopies", Vector3(43, 37, 33), Vector3(0, 5, -8), 72)
	await _capture("GRAND-III-central-rear-support", Vector3(-13, 18, -40), Vector3(0, 6, -24), 28)
	for hand: int in [-1, 1]:
		await _capture(
			"GRAND-III-%s-roofless-join" % ("right" if hand == 1 else "left"),
			Vector3(hand * 38, 23, 13),
			Vector3(hand * 23, 6, -4),
			29
		)
	await _capture("GRAND-III-board-context", Vector3(16, 17, 11), Vector3(36.5, 6, 31.5), 34)
	await _capture("GRAND-III-board-detail", Vector3(36.5, 10, 15), Vector3(36.5, 7, 31.5), 20)
	await _capture("GRAND-III-waterfall-context", Vector3(19, 12, 29), Vector3(36.5, 2, 44), 28)
	await _capture("GRAND-III-premium-tower-context", Vector3(29, 22, -3), Vector3(46, 9, -22), 28)
	_check(
		_native._failures == 0, "normal and small native captures acknowledge actual image extents"
	)
	property.queue_free()
	geometry.queue_free()
	transition.queue_free()
	premium.queue_free()
	waterfall.queue_free()
	await get_tree().process_frame
	position.x = 1
	_check(StadiumGrandIIIVenueStudy.build(self) == null, "transformed authoring host fails closed")
	position.x = 0
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Grand III assembly passed:107 copies, nine roofs,560 eyes, complete native views."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _mechanical_identity(
	property: StadiumPropertyGeometry, record: Dictionary, boundary: StadiumClubBoundaryStudy
) -> void:
	var original: Dictionary = StadiumGrandIVenueStudy.canonical()
	var source: Dictionary = StadiumGrandIVenueStudy.field_snapshot(
		ContentDB.get_field(PitchBatLab.FIELD_ID)
	)
	_check(property.field != null, "complete property has its actual unchanged field resource")
	if property.field == null:
		return
	_check(
		(
			ClubCareer.same(StadiumGrandIVenueStudy.field_snapshot(property.field), source)
			and ClubCareer.same(record.field, source)
			and ClubCareer.same(record.field, original.field)
		),
		"real field and saved semantics equal frozen Grand I field mound dimensions and scoring bands"
	)
	_check(
		(
			ClubCareer.same(record.boundary, original.boundary)
			and ClubCareer.same(boundary.graph.signature(), record.boundary)
			and ClubCareer.same(
				boundary.graph.signature(), StadiumDugoutBoundary.candidate("straight").signature()
			)
		),
		"actual complete mechanical graph and saved rules stay identical across all three tiers"
	)
	var shared: Dictionary = {}
	for row: Dictionary in original.items:
		if row.item in ["ST-065", "ST-022", "ST-023", "ST-074", "ST-021", "ST-026", "ST-073"]:
			shared[row.site] = row
	var count: int = 0
	for row: Dictionary in record.items:
		if not shared.has(row.site):
			continue
		var old: Dictionary = shared[row.site]
		_check(
			(
				row.item == old.item
				and ClubCareer.same(row.transform, old.transform)
				and row.span == old.span
				and row.model_version == old.model_version
			),
			"each actual shared boundary receiver pole and dugout keeps its exact old site geometry"
		)
		count += 1
	_check(count == 61, "all61 invariant physical infrastructure rows are compared individually")


func _record_identity(record: Dictionary) -> void:
	_check(
		(
			record.id == "GRAND-III-VIDEO-v2"
			and record.version == 2
			and record.property == "mogul"
			and record.items.size() == 107
		),
		"distinct Mogul identity contains exactly107 physical copies"
	)
	_check(
		(
			record.owner == "npc-venue:grandstand-gardens:grand-iii-video-v2"
			and record.batting_home == "higher-seed-separate-from-neutral-venue-owner"
		),
		"neutral venue ownership remains separate from batting-home designation"
	)
	_check(
		(
			record.environment.target_slots == ["19:10"]
			and record.environment.target_weather == ["clear"]
			and record.environment.certificates.is_empty()
			and not record.environment.night_eligible
		),
		"advertised19:10 clear remains unchanged and explicitly unqualified"
	)
	_check(
		record.lighting.dormant and record.lighting.active_lights == 0 and record.live_units == 0,
		"no lights obstacles or gameplay authority are fabricated"
	)
	_check(
		(
			record.archive_layout == "GRAND-III-v1"
			and record.layout_revision.id == "GRAND-III-VIDEO-v2"
			and record.layout_revision.status == "Working-owner-acceptance-pending"
			and record.layout_revision.original_reservation == [30, 0, 29, 13, 12, 5]
			and record.layout_revision.reservation == [29, 0, 30.5, 15, 14, 2]
			and not record.layout_revision.field_changed
			and not record.layout_revision.land_changed
		),
		"explicit Working board reservation revision preserves original archive and unchanged land/field"
	)
	_check(
		(
			record.board.item == "ST-040"
			and record.board.model == "video-v2"
			and record.board.site == "BOARD-LARGE-v2"
			and record.board.factory_version == 1
			and record.board.art_version == 2
		),
		"existing qualified complete video-v2 has separate exact board identity"
	)
	var counts: Dictionary = {}
	var sites: Array[String] = []
	var instances: Array[String] = []
	var value: int = 0
	for row: Dictionary in record.items:
		counts[row.item] = counts.get(row.item, 0) + 1
		_check(
			not sites.has(row.site) and not instances.has(row.instance),
			"every physical copy and layer-qualified site is distinct"
		)
		sites.append(row.site)
		instances.append(row.instance)
		_check(
			(
				row.transform.size() == 12
				and row.instance == "npc-candidate:GRAND-III-VIDEO:v2:" + row.site
				and row.host == record.owner
			),
			"full rigid pose and exact owner identify every purchase"
		)
		_check(COPY_PRICES.has(row.item), "no unlisted physical item enters exact107 composition")
		if COPY_PRICES.has(row.item):
			_check(
				StadiumCatalog.item(row.item).copy_price == COPY_PRICES[row.item],
				"catalog copy value is independently frozen without a purchase or ownership grant"
			)
			value += COPY_PRICES[row.item]
		_support_record(row)
	_check(
		ClubCareer.same(counts, EXPECTED_III), "full archive CY4 counts match independent literals"
	)
	_check(value == 8165, "exact107 physical copies have8165 catalog replacement value only")
	print(
		"GRAND_III_INVENTORY copies=",
		record.items.size(),
		" identities=",
		counts.size(),
		" catalog_copy_value=",
		value,
		" ownership_grant=false"
	)
	for empty: String in ["SCORE-SMALL", "MLIGHT-ML", "MLIGHT-MR"]:
		_check(
			not sites.has(empty) and empty in record.empty_sites,
			"required site stays empty: " + empty
		)
	for site: String in StadiumBaselineSites.SITES + StadiumCurvedLowerSites.SITES:
		for suffix: String in ["", ":CONCOURSE", ":UPPER", ":ROOF"]:
			_check(
				sites.has(site + suffix),
				"every straight and curved site has four distinct purchases"
			)
	for site: String in ["JOIN-R", "JOIN-L"]:
		_check(
			(
				sites.has(site)
				and sites.has(site + ":CONCOURSE")
				and not sites.has(site + ":UPPER")
				and not sites.has(site + ":ROOF")
			),
			"both purchased lower/concourse transition breaks remain deliberately roofless"
		)
	_check(
		record.crowd.total == 560 and record.crowd.status == "Working-art-density",
		"represented560-person art is explicit without income or capacity authority"
	)


func _support_record(row: Dictionary) -> void:
	var site: String = row.site.get_slice(":", 0)
	var prefix: String = "npc-candidate:GRAND-III-VIDEO:v2:"
	var expected: Array[String] = []
	var interface: String = ""
	match row.item:
		"ST-031", "ST-030", "ST-053", "ST-083", "ST-082", "ST-084":
			expected.append(prefix + site)
			if row.item in ["ST-030", "ST-053", "ST-082", "ST-084"]:
				expected.append(prefix + site + ":CONCOURSE")
			if row.item in ["ST-053", "ST-084"]:
				expected.append(prefix + site + ":UPPER")
			var interfaces: Dictionary = {
				"ST-031": G3S.INTERFACE,
				"ST-030": G3S.UPPER_INTERFACE,
				"ST-053": G3S.ROOF_INTERFACE,
				"ST-083": StadiumCurvedStackSites.INTERFACE,
				"ST-082": StadiumCurvedStackSites.UPPER_INTERFACE,
				"ST-084": StadiumCurvedCanopySites.INTERFACE
			}
			interface = interfaces[row.item]
		"ST-086", "ST-089":
			var bowl: String = "BOWL-01" if row.item == "ST-086" else "BOWL-05"
			var base: String = "BASE-R1" if row.item == "ST-086" else "BASE-L1"
			expected.assign(
				[
					prefix + site,
					prefix + bowl,
					prefix + bowl + ":CONCOURSE",
					prefix + base,
					prefix + base + ":CONCOURSE"
				]
			)
			interface = G3S.TRANSITION_INTERFACE
	_check(
		ClubCareer.same(row.supports, expected) and row.interface == interface,
		"serialized dependency graph binds exact same-site purchases and five handed transition hosts"
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
			not models.has(site), "unique manifest rows cannot conceal duplicate actual occupants"
		)
		models[site] = model
		var matching: Dictionary = {}
		for row: Dictionary in record.items:
			if row.instance == model.get_meta("candidate_instance"):
				matching = row
		var pose: Array[float] = []
		for vector: Vector3 in [
			model.global_basis.x, model.global_basis.y, model.global_basis.z, model.global_position
		]:
			pose.append_array([vector.x, vector.y, vector.z])
		_check(
			(
				not matching.is_empty()
				and ClubCareer.same(pose, matching.transform)
				and matching.site == site
				and matching.host == model.get_meta("candidate_host")
				and matching.model_version == model.get_meta("candidate_model_version")
				and property.objects.get(matching.instance) == model
			),
			"actual item exactly matches its manifest pose host version and object index"
		)
		var base: String = site.get_slice(":", 0)
		if item in ["ST-029", "ST-031", "ST-030", "ST-053"]:
			_check(
				model.transform == StadiumBaselineSites.pose(base),
				"exact authored straight bay pose"
			)
		if item in ["ST-081", "ST-083", "ST-082", "ST-084"]:
			_check(
				model.transform == StadiumCurvedLowerSites.pose(base),
				"exact authored curved sector pose"
			)
		if item == "ST-076":
			_check(
				(
					PREMIUM_SITES.has(site)
					and model.global_position == PREMIUM_SITES[site]
					and model.get_meta("reference_target") == PREMIUM_TARGETS[site]
				),
				"only four fixed literal premium positions and targets are installed"
			)
	_check(
		ClubCareer.same(actual, EXPECTED_III) and property.objects.size() == 107,
		"real scene and exact object index contain all107 copies without inherited phantom identities"
	)
	return models


func _complete_geometry(
	models: Dictionary, geometry: GeometryProof, transition: TransitionProof, net: Node3D
) -> bool:
	var audience: Array[Node3D] = []
	var structure: Array[Node3D] = []
	var additions: Array[Node3D] = []
	var bases: Array[Node3D] = []
	for site: String in StadiumBaselineSites.SITES:
		var stack: Array[Node3D] = [
			models[site],
			models[site + ":CONCOURSE"],
			models[site + ":UPPER"],
			models[site + ":ROOF"]
		]
		structure.append_array(stack)
		audience.append_array([stack[0], stack[2]])
		bases.append(stack[0])
		additions.append(stack[3])
		_check(
			G3S.valid_roof(stack[0], stack[1], stack[2], stack[3], site),
			"actual full straight stack passes exact qualified guard-v2 host admission"
		)
		geometry._grand_guard_delta(stack[0])
		for layer: Node3D in [stack[1], stack[2]]:
			geometry._grand_boxes(layer)
		geometry._grand_roof_geometry(stack[3])
	for site: String in StadiumCurvedLowerSites.SITES:
		var stack: Array[Node3D] = [
			models[site],
			models[site + ":CONCOURSE"],
			models[site + ":UPPER"],
			models[site + ":ROOF"]
		]
		structure.append_array(stack)
		audience.append_array([stack[0], stack[2]])
		additions.append(stack[3])
		_ground_and_ends(stack[0])
		_check(
			StadiumCurvedStackSites.valid_lower(stack[0], site), "genuine full curved lower proof"
		)
		_check(
			(
				stack[1].get_meta("lower_instance") == stack[0].get_instance_id()
				and stack[2].get_meta("lower_instance") == stack[0].get_instance_id()
				and stack[2].get_meta("concourse_instance") == stack[1].get_instance_id()
				and stack[3].get_meta("lower_instance") == stack[0].get_instance_id()
				and stack[3].get_meta("concourse_instance") == stack[1].get_instance_id()
				and stack[3].get_meta("upper_instance") == stack[2].get_instance_id()
			),
			"every real curved upper and canopy depends on its own actual lower and concourse"
		)
		_check(
			(
				G3S._matches(stack[1], "ST-083", site)
				and G3S._matches(stack[2], "ST-082", site)
				and G3S._matches(stack[3], "ST-084", site)
			),
			"full canonical curved layer tree, render state and geometry remain unchanged"
		)
	for site: String in ["JOIN-R", "JOIN-L"]:
		var lower: Node3D = models[site]
		var concourse: Node3D = models[site + ":CONCOURSE"]
		structure.append_array([lower, concourse])
		audience.append(lower)
		additions.append(concourse)
		transition._standalone(lower)
		transition._convex_correspondence(lower)
		geometry._concourse_geometry(concourse)
		_transition_bindings(models, site, geometry)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for site: String in StadiumBaselineSites.SITES:
		var stack: Array[Node3D] = [
			models[site],
			models[site + ":CONCOURSE"],
			models[site + ":UPPER"],
			models[site + ":ROOF"]
		]
		geometry._grand_straight_support(stack)
	for site: String in StadiumCurvedLowerSites.SITES:
		var stack: Array[Node3D] = [
			models[site],
			models[site + ":CONCOURSE"],
			models[site + ":UPPER"],
			models[site + ":ROOF"]
		]
		geometry._grand_curved_stack_support(stack)
		geometry._grand_curved_roof_support(stack[2], stack[3])
	for site: String in ["JOIN-R", "JOIN-L"]:
		geometry._concourse_support(models[site + ":CONCOURSE"], _transition_hosts(models, site))
	for root: Node3D in structure:
		geometry._grand_reservation(root)
		geometry._grand_no_penetration(root, structure)
	await _guard_variant(bases)
	if not await geometry._net_visual_controls(net):
		print("GRAND_III_NET_CONTROL_FAILURE ", geometry.diagnostic(net, "ST073_CENTER_NET"))
		return false
	await _addition_integrity(models, audience, structure, additions, geometry, net)
	await geometry._sightline_controls(net)
	_candidate_camera_corridors()
	return _failures == 0 and geometry._failures == 0 and transition._failures == 0


func _transition_hosts(models: Dictionary, site: String) -> Dictionary:
	var right: bool = site == "JOIN-R"
	var bowl: String = "BOWL-01" if right else "BOWL-05"
	var base: String = "BASE-R1" if right else "BASE-L1"
	return {
		"right": right,
		"inputs":
		[
			models[site],
			models[bowl],
			models[bowl + ":CONCOURSE"],
			models[base],
			models[base + ":CONCOURSE"]
		]
	}


func _transition_bindings(models: Dictionary, site: String, geometry: GeometryProof) -> void:
	var piece: Node3D = models[site + ":CONCOURSE"]
	var hosts: Dictionary = _transition_hosts(models, site)
	var keys: Array[String] = [
		"lower_instance",
		"bowl_instance",
		"curved_concourse_instance",
		"baseline_instance",
		"straight_concourse_instance"
	]
	for index in range(keys.size()):
		_check(
			piece.get_meta(keys[index]) == hosts.inputs[index].get_instance_id(),
			"real roofless transition binds each of its five exact purchased hosts"
		)
	_check(
		(
			piece.get_meta("model_version") == 2
			and piece.get_meta("model_variant") == "TRANSITION-ROOF-NEIGHBOR-v2"
			and piece.get_meta("interface") == G3S.TRANSITION_INTERFACE
		),
		"installed transition retains explicit canonical roof-neighbor compatibility revision"
	)

	var reference: Node3D = StadiumGrandThreeStackModels._transition(site)
	_check(reference != null, "independent exact transition compatibility reference constructs")
	if reference != null:
		for branch: String in ["Visual", "Collision"]:
			_check(
				(
					geometry._grand_snapshot(piece.get_node(branch))
					== geometry._grand_snapshot(reference.get_node(branch))
				),
				"complete actual transition visual material collider and execution trees match qualification"
			)
		reference.free()


func _addition_integrity(
	models: Dictionary,
	audience: Array[Node3D],
	structure: Array[Node3D],
	additions: Array[Node3D],
	geometry: GeometryProof,
	net: Node3D
) -> void:
	var host: Node = additions[0].get_parent()
	var frozen: Dictionary = {}
	for piece: Node3D in additions:
		host.remove_child(piece)
	for piece: Node3D in structure:
		if piece not in additions:
			frozen[piece.get_instance_id()] = geometry._grand_snapshot(piece)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_record_complete_paths(models, audience, geometry, net)
	await _opaque_controls(geometry, net)
	for index in range(additions.size()):
		var piece: Node3D = additions[index]
		host.add_child(piece)
		if index < 8:
			continue
		await get_tree().physics_frame
		await get_tree().physics_frame
		for id: int in frozen:
			_check(
				geometry._grand_snapshot(instance_from_id(id)) == frozen[id],
				"installing nine roofs and each separate transition never changes any existing host"
			)
		for row: Dictionary in _complete_paths:
			_check(
				geometry._opaque_path(row.eye, row.target, net).is_empty(),
				"every1680 full opaque path remains clear after each complete installed addition"
			)
		for installed: Node3D in structure:
			if installed.get_parent() == host:
				frozen[installed.get_instance_id()] = geometry._grand_snapshot(installed)
	_record_complete_paths(models, audience, geometry, net)


func _record_complete_paths(
	models: Dictionary, audience: Array[Node3D], geometry: GeometryProof, net: Node3D
) -> void:
	_complete_paths.clear()
	var expected: Dictionary = {
		"ST-029": 200, "ST-030": 64, "ST-081": 180, "ST-082": 80, "ST-085": 18, "ST-088": 18
	}
	var decorative: Array[Node3D] = [models["BOARD-LARGE-v2"], models["LANDMARK-A"]]
	for site: String in PREMIUM_SITES:
		decorative.append(models[site])
	for phase: float in [-PI / 2, 0, PI / 2]:
		var counts: Dictionary = {}
		for root: Node3D in audience:
			geometry._animate_host(root, phase)
			geometry._grand_reservation(root)
			for anchor: Node3D in root.get_node("Visual").get_children():
				if not anchor.get_meta("represented_audience", false):
					continue
				var item: String = root.get_meta("stadium_item")
				counts[item] = counts.get(item, 0) + 1
				var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
				var target: Vector3 = Vector3(0, 1, 8)
				var blockers: Array[RID] = geometry._opaque_path(eye, target, net)
				_check(
					blockers.is_empty(),
					"every actual audience eye sees complete opaque physical path"
				)
				_check(
					_decorative_path_clear(eye, target, decorative),
					"actual opaque board waterfall and premium meshes also clear the full audience ray"
				)
				_complete_paths.append({"eye": eye, "target": target})
		_check(
			ClubCareer.same(counts, expected), "exact560 authentic eyes at each bounded sway phase"
		)
	for root: Node3D in audience:
		geometry._animate_host(root, 0)
	_check(
		_complete_paths.size() == 1680, "rest and both sway extremes retain every actual spectator"
	)
	print("GRAND_III_AUDIENCE eyes=560 phases=3 whole_opaque_paths=", _complete_paths.size())


func _opaque_controls(geometry: GeometryProof, net: Node3D) -> void:
	_check(
		not _complete_paths.is_empty(), "real audience path exists for opaque visibility controls"
	)
	if _complete_paths.is_empty():
		return
	var row: Dictionary = _complete_paths[0]
	var control: Node3D = StadiumBaselineStandModels._root("GRAND-III-OPAQUE-CONTROL")
	add_child(control)
	for index in range(2):
		StadiumSeatingModels._box(
			control,
			"OpaqueControl%d" % index,
			row.eye.lerp(row.target, 0.35 + index * 0.25),
			Vector3.ONE * 0.15,
			Color.RED
		)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hits: Array[RID] = geometry._opaque_path(row.eye, row.target, net)
	_check(hits.size() == 2, "full original ray detects both near and farther opaque blockers")
	for body: StaticBody3D in control.get_node("Collision").get_children():
		_check(body.get_rid() in hits, "whole-path evidence names each exact real control body")
	_check(
		not _decorative_path_clear(row.eye, row.target, [control]),
		"triangle-only decorative visibility independently detects actual opaque mesh"
	)
	control.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		geometry._opaque_path(row.eye, row.target, net).is_empty(),
		"removing controls restores path"
	)


func _decorative_path_clear(from: Vector3, to: Vector3, roots: Array[Node3D]) -> bool:
	for root: Node3D in roots:
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var start: Vector3 = inverse * from
			var end: Vector3 = inverse * to
			if mesh.get_aabb().intersects_segment(start, end) == null:
				continue
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var count: int = indices.size() if not indices.is_empty() else points.size()
				for index in range(0, count - 2, 3):
					var a: int = indices[index] if not indices.is_empty() else index
					var b: int = indices[index + 1] if not indices.is_empty() else index + 1
					var c: int = indices[index + 2] if not indices.is_empty() else index + 2
					if (
						Geometry3D.segment_intersects_triangle(
							start, end, points[a], points[b], points[c]
						)
						!= null
					):
						return false
	return true


func _tower_rays(models: Dictionary, record: Dictionary) -> void:
	_check(
		record.lighting.towers.size() == 4 and record.lighting.preset == "LIGHT-MOGUL-4X076-v1",
		"exactly four separate premium towers retain their named dormant rig"
	)
	var count: int = 0
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = models[tower.site]
		var actual: Array = model.get_meta("candidate_head_rays")
		_check(
			actual.size() == 8 and tower.heads.size() == 8,
			"eight individually identified dormant heads"
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
				"each actual dormant lens ray exactly matches serialized origin direction and identity"
			)
			count += 1
	_check(
		count == 32, "all32 individual premium head rays are proved without any night certificate"
	)


func _board_reservation(board: Node3D) -> void:
	_check(
		(
			board.get_meta("stadium_item") == "ST-040"
			and board.get_meta("candidate_site") == "BOARD-LARGE-v2"
			and board.get_meta("scoreboard_owned_model") == "video-v2"
			and board.get_meta("scoreboard_model_version") == 2
			and board.transform == Transform3D(Basis(Vector3.UP, PI), Vector3(36.5, 0, 31.5))
		),
		"existing qualified ST040 video-v2 occupies its separately named exact revision site"
	)
	var count: int = 0
	for mesh: MeshInstance3D in board.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX
			]
			for vertex: Vector3 in vertices:
				var point: Vector3 = mesh.global_transform * vertex
				_check(
					(
						point.x >= 28.9999
						and point.x <= 44.0001
						and point.z >= 30.4999
						and point.z <= 32.5001
						and point.y >= -0.0001
						and point.y <= 14.0001
					),
					"actual unchanged video-v2 triangles fit the explicitly new reservation"
				)
				count += 1
	_check(count > 0, "large-site proof measures actual board triangles, never labels alone")


func _candidate_camera_corridors() -> void:
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1
		)
		_check(
			get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both batting-side pitch corridors remain clear of all actual purchased models"
		)
	for eye: Vector3 in [
		Vector3(-1.2, 1.6, -1), Vector3(1.2, 1.6, -1), Vector3(0, 4, 11), Vector3(0, 8, 18)
	]:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.3
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = eye
		query.collision_mask = 1
		_check(
			get_world_3d().direct_space_state.intersect_shape(query).is_empty(),
			"real near gameplay-camera probe volumes clear full installed collision"
		)
