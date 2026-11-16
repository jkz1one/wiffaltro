extends Node
## Actual AY-01/r1 data admission and detached construction correspondence only.
## No fixture, season, save, physical-worker, settlement or environment certification.

const EXPECTED_SHA256: String = "6295c0e4b2221666530fa343c6a0b39d6a7e61cff11b5850b59e13ec10c811e7"
const SITES: Array[String] = ["SC-L1", "SC-L2", "SC-R1", "SC-R2"]
const FIELD: Dictionary = {
	"id": &"field.starter_backyard", "display_name": "Yard Club Field", "environment_style": 0,
	"fair_half_angle_degrees": 42.0, "safe_hit_z_m": 11.25, "deep_air_z_m": 17.0,
	"back_wall_z_m": 23.4, "home_run_height_m": 3.25, "dead_ball_z_m": 29.0,
	"shallow_anchor_z_m": 8.5, "middle_anchor_z_m": 14.0, "middle_center_anchor_z_m": 17.0,
	"deep_anchor_z_m": 19.5, "side_anchor_x_m": 5.5,
	"shallow_center_available": false, "middle_center_available": false
}

var _failures: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club()
	var ledger_bytes: String = _json(ledger.to_data())
	var field_bytes: String = FileAccess.get_sha256("res://src/content/fields/starter_field.tres")
	var literal: Dictionary = StadiumNpcVenues.definition("AY-01", 1)
	_check(not literal.is_empty(), "exact AY-01/r1 literal is admitted")
	if literal.is_empty():
		get_tree().quit(1)
		return
	_provenance()
	_literal(literal)
	_raw_types(literal)
	_canonical_numbers(literal)
	_attacks(literal)
	_copied_revisions(literal)
	_candidate_refusal(literal)
	_assembly(literal)
	_check(ledger_bytes == _json(ledger.to_data()),
		"literal lookup and both assemblies preserve complete human ledger bytes")
	_check(field_bytes == FileAccess.get_sha256("res://src/content/fields/starter_field.tres"),
		"literal lookup and detached construction never rewrite the shared field")
	_check(not StadiumLayoutSnapshot.valid(literal) and not PhysicalMatchReport.valid(literal),
		"admitted definition is neither a human snapshot nor a production report")
	_check(ClubAssetLedger.from_data(literal, 0, []) == null,
		"NPC catalog copies cannot be imported as human ownership")
	await get_tree().process_frame
	if _failures == 0:
		print("stadium NPC AY-01 definition: PASS "
			+ "(immutable r1 data and independent assembly correspondence)")
	get_tree().quit(0 if _failures == 0 else 1)


func _provenance() -> void:
	# Admission-test evidence only: neither registry lookup nor retained build reads these files.
	for path: String in StadiumNpcYardProvenance.SOURCES:
		_check(FileAccess.get_sha256(path) == StadiumNpcYardProvenance.SOURCES[path],
			"independent qualified authoring provenance " + path)
	for path: String in StadiumNpcYardProvenance.CONSTRUCTION_SOURCES:
		_check(FileAccess.get_sha256(path) == StadiumNpcYardProvenance.CONSTRUCTION_SOURCES[path],
			"retained revision-1 construction provenance " + path)


func _literal(value: Dictionary) -> void:
	var encoded: String = _json(value)
	_check(encoded.to_utf8_buffer().size() == 1737
		and encoded.sha256_text() == EXPECTED_SHA256
		and StadiumNpcYardDefinitionV1.SHA256 == EXPECTED_SHA256,
		"complete canonical bytes retain the independently pinned AY-01/r1 hash")
	_check(StadiumNpcVenues.valid_manifest(value) and StadiumNpcVenues.key(value) == EXPECTED_SHA256,
		"actual published literal passes exact production lookup and identity")
	_check(_json(StadiumNpcVenues.decode(encoded)) == encoded
		and _json(StadiumNpcVenues.normalized(value)) == encoded,
		"real literal canonical decode and normalization preserve every byte")
	_check(_json(StadiumNpcManifest.canonical_shape(StadiumNpcYardDefinitionV1.payload())) == encoded,
		"the fresh raw literal is exactly the admitted canonical payload")
	_check(value.id == "AY-01" and value.revision == 1 and value.version == 1
		and value.assembly == {"id": "AY-01-backyard-v1", "version": 1}
		and value.field == "field.starter_backyard" and value.tier == "backyard"
		and value.shape == "straight" and value.rules_version == 1, "explicit assembly/field/rules")
	var source: Dictionary = StadiumYardVenueStudy.canonical()
	_check(value.models == {
		"spectator-chair": {"version": 1, "sha256": source.model_sources.chair},
		"free-template": {"version": 1, "sha256": source.model_sources.template},
		"template-boundary": {"version": 1, "sha256": source.model_sources.boundary}}
		and value.catalog == {"version": 1, "sha256": StadiumCatalog.signature()}
		and value.valuation.price_sha256 == source.endowment.price_version,
		"literal complete model/catalog identity matches independently qualified source hashes")
	_check(value.instances.size() == 4 and value.blueprints == ["ST-080"]
		and value.live_units == 0 and value.land == {"version": 1, "tier": "backyard", "stages": []},
		"exact four catalog copies, one blueprint, free land and zero live units")
	_check(value.valuation == {"price_version": 1,
		"price_sha256": "5210c3c47688b06faa35a50ec211f65de0a881debc5d7567a4c0e2abe6df204f",
		"blueprints": 150, "copies": 160, "land": 0, "total": 310},
		"310 is pinned content valuation without a wallet or purchase history")
	_check(value.environment_certificates.is_empty() and value.presentation == {
		"profile": "AY-01-default-backyard-v1", "options": {}}
		and value.surface_version == 1 and value.routing_version == 1,
		"fixed default presentation has no inferred daytime or nighttime certificates")
	for index in range(value.instances.size()):
		var row: Dictionary = value.instances[index]
		_check(row.site == SITES[index] and row.instance == "npc:AY-01:r1:" + SITES[index]
			and row.item == "ST-080" and row.host == "field"
			and row.transform == _components(_pose(index)), "literal exact catalog row " + row.site)
	for revision: int in [-1, 0, 3, 1000000]:
		_check(StadiumNpcVenues.definition("AY-01", revision).is_empty(),
			"no latest-revision fallback " + str(revision))
	for id: String in ["ay-01", "AY-01 ", "UNKNOWN", "AE-01-unknown", "AC-01-unknown", "SCHEMA-ONLY"]:
		_check(StadiumNpcVenues.definition(id, 1).is_empty(), "no alias or unpublished fallback " + id)
	_check(encoded.to_utf8_buffer().size() < StadiumNpcManifest.MAX_BYTES,
		"published literal fits the inherited canonical byte bound")
	_check(_json(StadiumNpcVenues.decode(encoded + " ".repeat(
		StadiumNpcManifest.MAX_BYTES - encoded.to_utf8_buffer().size()))) == encoded,
		"exact maximum input bytes may contain a valid published literal")
	_check(StadiumNpcVenues.decode(encoded + " ".repeat(
		StadiumNpcManifest.MAX_BYTES + 1 - encoded.to_utf8_buffer().size())).is_empty(),
		"one-byte-over input cannot bypass the inherited decode cap")


func _canonical_numbers(value: Dictionary) -> void:
	var equivalent: Dictionary = value.duplicate(true)
	equivalent.revision = 1.0
	equivalent.valuation.total = 310.0
	equivalent.instances[0].transform[9] = -24.0 + 0.000000000001
	equivalent.instances[0].transform[0] = -0.0
	var normalized: Dictionary = StadiumNpcVenues.normalized(equivalent)
	_check(not normalized.is_empty() and _json(normalized) == _json(value),
		"real literal comparison occurs after integer and float32 reconstruction")
	if normalized.is_empty():
		return
	_check(normalized.revision is int and normalized.valuation.total is int
		and PackedFloat64Array([normalized.instances[0].transform[0]]).to_byte_array()
		== PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]),
		"real literal canonical integer types and positive-zero bits")
	_check(equivalent.revision is float and equivalent.instances[0].transform[9] != -24.0,
		"representation normalization does not mutate its caller")
	var changed: Dictionary = value.duplicate(true)
	changed.instances[0].transform[9] = float(PackedFloat32Array([-24.0000019073486328125])[0])
	_check(changed.instances[0].transform[9] != -24.0
		and not StadiumNpcManifest.canonical_shape(changed).is_empty()
		and not StadiumNpcVenues.valid_manifest(changed),
		"one adjacent float32 scene coordinate is a different literal")


func _raw_types(value: Dictionary) -> void:
	for key: String in StadiumNpcManifest.KEYS:
		var bad: Dictionary = value.duplicate(true)
		bad[key] = false
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty()
			and not StadiumNpcVenues.valid_manifest(bad), "published raw top-level type " + key)
	for edit in range(17):
		var bad: Dictionary = JSON.parse_string(_json(value))
		match edit:
			0: bad.instances[0].transform[0] = false
			1: bad.instances[0].transform[4] = true
			2: bad.instances[0].transform[9] = NAN
			3: bad.instances[0].transform[9] = INF
			4: bad.instances[0].transform[9] = 1e100
			5: bad.instances[0].transform = {"x": 0}
			6: bad.instances[0] = null
			7: bad.models["spectator-chair"] = null
			8: bad.valuation.land = false
			9: bad.revision = 1.00000000001
			10: bad.instances[0].transform.pop_back()
			11: bad.instances[0].host = "missing"
			12: bad.instances[0].host = bad.instances[1].instance
			13: bad.instances[0]["owned_copy"] = "human"
			14: bad.instances[1].site = bad.instances[0].site
			15: bad.environment_certificates = [null]
			16: bad.presentation.options = {"night": true}
		if edit == 12:
			bad.instances[1].host = bad.instances[0].instance
		_check(StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"real literal malformed nested raw value " + str(edit))
		_check(not StadiumNpcVenues.valid_manifest(bad) and StadiumNpcVenues.key(bad).is_empty(),
			"malformed literal cannot acquire authority " + str(edit))


func _attacks(value: Dictionary) -> void:
	for edit in range(21):
		var bad: Dictionary = value.duplicate(true)
		match edit:
			0: bad.instances[0].transform[9] += 0.125
			1: bad.models["spectator-chair"].version = 2
			2: bad.models["spectator-chair"].sha256 = "1".repeat(64)
			3: bad.graph.sha256 = "1".repeat(64)
			4: bad.graph.version = 2
			5: bad.instances[1].host = bad.instances[0].instance
			6: bad.instances.pop_back()
			7: bad.valuation.price_version = 2
			8: bad.valuation.price_sha256 = "1".repeat(64)
			9: bad.catalog.sha256 = "1".repeat(64)
			10: bad.valuation.copies += 40
			11: bad.field = "field.foreign"
			12: bad.presentation.profile = "foreign-default"
			13: bad.surface_version = 2
			14: bad.routing_version = 2
			15: bad.assembly.version = 2
			16: bad.instances[3].site = "SC-R3"
			17: bad.blueprints = ["ST-079"]
			18: bad.environment_certificates = [{"mode": "night", "profile": "invented",
				"version": 1, "assembly_sha256": EXPECTED_SHA256}]
			19: bad.land.stages = ["unearned"]
			20: bad.live_units = 1
		if edit == 10:
			bad.valuation.total += 40
		if edit == 16:
			bad.instances[3].instance = "npc:AY-01:r1:SC-R3"
		if edit == 17:
			for row: Dictionary in bad.instances:
				row.item = "ST-079"
		_check(not StadiumNpcManifest.canonical_shape(bad).is_empty(),
			"attack is structurally valid and has no malformed-input excuse " + str(edit))
		var rehashed: String = _json(bad).sha256_text()
		_check(rehashed != EXPECTED_SHA256 and StadiumNpcVenues.normalized(bad).is_empty()
			and StadiumNpcVenues.key(bad).is_empty()
			and StadiumNpcVenues.decode(_json(bad)).is_empty(),
			"complete literal authority rejects changed and rehashed payload " + str(edit))


func _copied_revisions(value: Dictionary) -> void:
	var baseline: String = _json(value)
	var returned: Dictionary = StadiumNpcVenues.definition("AY-01", 1)
	returned.instances[0].transform[9] = 99.0
	returned.models["spectator-chair"].version = 99
	returned.land.stages.append("foreign")
	var normalized: Dictionary = StadiumNpcVenues.normalized(value)
	normalized.instances.clear()
	var decoded: Dictionary = StadiumNpcVenues.decode(baseline)
	decoded.valuation.total = 0
	var raw: Dictionary = StadiumNpcYardDefinitionV1.payload()
	raw.instances.clear()
	_check(_json(StadiumNpcVenues.definition("AY-01", 1)) == baseline
		and _json(StadiumNpcManifest.canonical_shape(StadiumNpcYardDefinitionV1.payload())) == baseline,
		"nested mutations through every return path leave the published literal immutable")
	# Local copied revisions exercise retention mechanics; this does not publish revision 2.
	var second: Dictionary = _relabel(value, "AY-01", 2)
	second.instances[0].transform[9] = -23.0
	var records: Dictionary = {"AY-01": {"1": value.duplicate(true), "2": second}}
	_check(not StadiumNpcVenues._definition_from(records, "AY-01", 2).is_empty(),
		"locally copied revision remains structurally independent")
	second.models["spectator-chair"].version = 2
	_check(_json(StadiumNpcVenues._definition_from(records, "AY-01", 1)) == baseline,
		"a later copied definition never remodels retained revision 1")
	records["AY-01"]["1"] = second
	_check(StadiumNpcVenues._definition_from(records, "AY-01", 1).is_empty()
		and StadiumNpcVenues.definition("AY-01", 3).is_empty()
		and not StadiumNpcVenues.valid_manifest(second),
		"copied/relabeled revision keys cannot mint production authority")


func _candidate_refusal(value: Dictionary) -> void:
	var authored: Dictionary = StadiumYardVenueStudy.canonical()
	_check(_json(authored).to_utf8_buffer().size() == 3479 and _json(authored).sha256_text()
		== "92aedc3ac410f63ac27dc286d10eb9a510ced850c934c83fdf32966a0f7be2ee",
		"independent authoring bytes retain qualified provenance, not registry authority")
	var envelope: Dictionary = StadiumYardFixtureStudy.capture(authored)
	_check(not envelope.is_empty() and StadiumYardFixtureStudy.valid(envelope),
		"negative control starts with a real qualified-source authoring fixture")
	_check(not StadiumNpcVenues.valid_manifest(authored)
		and not StadiumNpcVenues.valid_manifest(envelope),
		"actual authored record and envelope remain outside registry authority")
	envelope.kind = "npc-authored-v1"
	envelope.venue.status = "VALIDATED"
	envelope.venue["revision"] = 1
	envelope.sha256 = _json(envelope.venue).sha256_text()
	_check(StadiumNpcVenues.decode(_json(envelope)).is_empty()
		and not StadiumNpcVenues.valid_manifest(envelope.venue),
		"correctly rehashed/relabelled real candidate is not a definition")
	var foreign: Dictionary = _relabel(value, "FOREIGN-01", 1)
	_check(not StadiumNpcManifest.canonical_shape(foreign).is_empty()
		and not StadiumNpcVenues.valid_manifest(foreign),
		"structurally valid foreign identity cannot borrow published assembly authority")


func _assembly(value: Dictionary) -> void:
	var actual: StadiumNpcYardV1 = StadiumNpcYardV1.build()
	var candidate: StadiumPropertyGeometry = StadiumYardVenueStudy.build()
	_check(actual != null and candidate != null, "two independent complete factories construct")
	if actual == null or candidate == null:
		if actual != null:
			actual.free()
		if candidate != null:
			candidate.free()
		return
	_check(not actual.is_inside_tree() and actual.get_parent() == null
		and not actual.has_method("install") and not actual.has_method("bind_ball"),
		"construction remains detached and exposes no production installation/contact adapter")
	_check(actual.tier == "backyard" and actual.objects.size() == 4
		and actual.get_child_count() == candidate.get_child_count(), "complete actual assembly counts")
	var geometry: PackedByteArray = var_to_bytes(_geometry(actual))
	_check(geometry == var_to_bytes(_geometry(candidate)),
		"all actual meshes, materials, transforms, collider shapes and surfaces match qualified source")
	_check(actual.get_node("BoundaryGraph").get_child_count() == 6
		and not actual.has_node("TemplateBackWall") and not actual.has_node("PitchReceiverPresentation"),
		"six real shared-miter slabs with no replaced wall or invented receiver geometry")
	for index in range(4):
		var identity: String = "npc:AY-01:r1:" + SITES[index]
		_check(actual.objects.has(identity), "exact NPC instance object exists " + identity)
		if not actual.objects.has(identity):
			continue
		var model: Node3D = actual.objects[identity]
		_check(model.get_parent() == actual and model.transform == _pose(index)
			and _components(model.transform) == value.instances[index].transform
			and model.get_meta("npc_instance", "") == identity
			and model.get_meta("npc_site", "") == SITES[index], "real instance/site/field host/pose")
		_check(model.get_node("Visual").get_child_count() == 11
			and model.get_node("Visual/CrowdAnchor0").get_child_count() == 4
			and model.get_node("Collision").get_child_count() == 6,
			"each occupied ST-080 has its actual chair, audience meshes and six solids")
		for body: Node in model.get_node("Collision").get_children():
			_check(body.get_meta("npc_instance", "") == identity
				and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL",
				"actual chair bodies have NPC decorative provenance")
	_no_human_ownership(actual)
	_fields_and_routes(actual, candidate, value)
	_prisms(actual)
	_geometry_controls(actual, geometry)
	actual.field.safe_hit_z_m = 1.0
	actual.objects["npc:AY-01:r1:SC-L1"].position.x = 0
	var fresh: StadiumNpcYardV1 = StadiumNpcYardV1.build()
	_check(fresh.field != actual.field and fresh.field.safe_hit_z_m == 11.25
		and var_to_bytes(_geometry(fresh)) == geometry
		and StadiumNpcVenues.key(value) == EXPECTED_SHA256,
		"mutating a built assembly cannot rewrite future construction or literal history")
	fresh.free()
	actual.free()
	candidate.free()


func _fields_and_routes(actual: StadiumNpcYardV1, candidate: StadiumPropertyGeometry,
	value: Dictionary) -> void:
	_check(actual.field != candidate.field
		and actual.field != ContentDB.get_field(&"field.starter_backyard"),
		"retained construction owns its independent field resource")
	for key: String in FIELD:
		_check(actual.field.get(key) == FIELD[key] and actual.field.get(key) == candidate.field.get(key),
			"actual field parameter is pinned and matches qualified source " + key)
	var authored: Dictionary = StadiumYardVenueStudy.canonical()
	_check(ClubCareer.same(StadiumNpcYardV1.SURFACE, authored.surface)
		and StadiumNpcYardV1.SURFACE.version == 1
		and StadiumNpcYardV1.SURFACE.styles.is_empty()
		and StadiumNpcYardV1.SURFACE.bounds == [-26, -10, 52, 42],
		"retained complete default surface recipe matches independently qualified source")
	_check(ClubCareer.same(StadiumNpcYardV1.ROUTING, authored.routing)
		and StadiumNpcYardV1.ROUTING.version == 1
		and StadiumNpcYardV1.ROUTING.defender_radius == 0.54
		and StadiumNpcYardV1.ROUTING.live_obstacles.is_empty(),
		"retained version-1 routing recipe pins zero live obstacles and exact defender envelope")
	_foul_lines(actual)
	_check(actual.route_obstacles().is_empty() and candidate.route_obstacles().is_empty(),
		"actual four-chair assembly yields zero defender route obstacles")
	_check(StadiumNpcYardGraphV1.signature() == value.graph.sha256
		and StadiumNpcYardGraphV1.signature() == StadiumBoundaryGraph.signature(),
		"retained graph semantic identity matches literal and independent qualified graph")
	_check(ClubCareer.same(StadiumNpcYardV1.RECEIVER, authored.receiver)
		and StadiumNpcYardV1.RECEIVER.catalog_item == ""
		and StadiumNpcYardV1.RECEIVER.pitch_surfaces.is_empty()
		and StadiumNpcYardV1.RECEIVER.batted_surfaces.is_empty()
		and StadiumNpcYardV1.RECEIVER.plane_z == -1.05
		and StadiumNpcYardV1.RECEIVER.min_travel == 0.055
		and StadiumNpcYardV1.RECEIVER.max_travel == 0.16
		and StadiumNpcYardV1.RECEIVER.hold == 0.18,
		"free receiver pins silent plane/timing without a purchased collider")
	for index in range(9):
		var start: Vector3 = actual.field.fielder_anchor(index)
		_check(start == candidate.field.fielder_anchor(index)
			and actual.field.is_fielder_anchor_available(index)
			== candidate.field.is_fielder_anchor_available(index), "independent defender anchor")
		for target: Vector3 in [Vector3(-30, 0, 25), Vector3(30, 0, 25),
			Vector3(0, 0, -10), Vector3(0, 0, 35)]:
			_check(StadiumNpcYardGraphV1.clip(start, target) == StadiumBoundaryGraph.clip(start, target),
				"actual retained boundary route clipping matches complete qualified graph")
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var midpoint: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumBoundaryGraph.inward(row)
		for height: float in [0.4, 2.0, 4.0]:
			var start: Vector3 = Vector3(midpoint.x + inward.x, height, midpoint.y + inward.y)
			var finish: Vector3 = Vector3(midpoint.x - inward.x, height, midpoint.y - inward.y)
			_check(var_to_bytes(StadiumNpcYardGraphV1.crossing(start, finish)) == var_to_bytes(
				StadiumBoundaryGraph.crossing(start, finish)), "actual retained crossing " + row.id)


func _foul_lines(actual: StadiumNpcYardV1) -> void:
	for side: int in [-1, 1]:
		var line: Node3D = actual.get_node("FoulLine" + str(side))
		var end: Vector3 = Vector3(side * 23.4 * tan(deg_to_rad(42.0)), 0, 23.4)
		var visual: MeshInstance3D = line.get_child(0)
		_check(line.position == end / 2 + Vector3(0, 0.02, 0)
			and line.basis == Basis.from_euler(Vector3(0, atan2(end.x, end.z), 0))
			and visual.mesh is BoxMesh
			and visual.mesh.size == Vector3(0.055, 0.025, end.length()),
			"actual painted foul ray uses pinned 42-degree field and z23.4 endpoint")
		_check(line.get_child_count() == 1 and not line is CollisionObject3D,
			"painted foul ray creates no physical pole or phantom collision")


func _prisms(actual: StadiumNpcYardV1) -> void:
	var retained: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumNpcYardV1.TemplateView.new())
	var independent: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumYardFieldVisibility.TemplateView.new())
	_check(var_to_bytes(retained.walls) == var_to_bytes(independent.walls),
		"retained camera prism data exactly matches independent qualified presentation")
	var boundary: Node3D = actual.get_node("BoundaryGraph")
	_check(retained.walls.size() == 6 and retained.walls.size() == boundary.get_child_count(),
		"one exact camera prism for each actual physical slab")
	for index in range(retained.walls.size()):
		var body: StaticBody3D = boundary.get_child(index)
		var shape: CollisionShape3D = body.get_child(0)
		var points: PackedVector3Array = shape.shape.points
		var prism: Dictionary = retained.walls[index]
		_check(points.size() == 8, "each shared-miter slab has eight actual collider corners")
		for corner in range(4):
			var at: Vector2 = prism.polygon[corner]
			_check(points[corner] == Vector3(at.x, 0, at.y)
				and points[corner + 4] == Vector3(at.x, prism.height, at.y),
				"retained view prism exactly matches physical float32 slab vertices " + body.name)
		var mesh: MeshInstance3D = body.get_child(1)
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(vertices.size() == 36, "complete six-face physical slab triangle mesh")
		for vertex: Vector3 in vertices:
			_check(points.has(vertex), "rendered slab vertices coincide with actual collider points")
	_check(retained.blocked(Vector3(0, 1, 22), Vector3(0, 1, 25), 0)
		and not retained.blocked(Vector3(0, 5, 0), Vector3(0, 1, 15), 0),
		"retained camera prism observes a real back-wall block and clear field corridor")


func _geometry(node: Node) -> Dictionary:
	# Inspect constructed data, never candidate_venue/npc metadata or a factory-supplied checksum.
	var result: Dictionary = {"class": node.get_class(), "children": []}
	if node is Node3D:
		result["transform"] = node.transform
	if node is MeshInstance3D:
		result["visible"] = node.visible
		result["mesh_class"] = node.mesh.get_class()
		result["surfaces"] = []
		for index in range(node.mesh.get_surface_count()):
			result.surfaces.append(node.mesh.surface_get_arrays(index))
		var material: StandardMaterial3D = node.material_override
		result["material"] = [material.albedo_color, material.roughness, material.cull_mode]
	if node is StaticBody3D:
		result["collision"] = [node.collision_layer, node.collision_mask]
	if node is CollisionShape3D:
		result["disabled"] = node.disabled
		result["shape_class"] = node.shape.get_class()
		if node.shape is BoxShape3D:
			result["shape"] = node.shape.size
		elif node.shape is ConvexPolygonShape3D:
			result["shape"] = node.shape.points
		else:
			_check(false, "unreviewed shape cannot pass physical correspondence")
	for key: String in ["stadium_item", "ball_surface", "surface_role", "surface_id",
		"boundary_segment", "represented_seats", "represented_audience"]:
		if node.has_meta(key):
			result[key] = node.get_meta(key)
	for child: Node in node.get_children():
		result.children.append(_geometry(child))
	return result


func _geometry_controls(actual: StadiumNpcYardV1, baseline: PackedByteArray) -> void:
	var model: Node3D = actual.objects["npc:AY-01:r1:SC-L1"]
	var mesh: BoxMesh = model.get_node("Visual/SpectatorSeat").mesh
	var original: Vector3 = mesh.size
	mesh.size.x += 0.01
	_check(var_to_bytes(_geometry(actual)) != baseline,
		"unchanged metadata cannot conceal a changed actual chair mesh")
	mesh.size = original
	var shape: BoxShape3D = model.get_node("Collision/SpectatorSeat").get_child(0).shape
	original = shape.size
	shape.size.z += 0.01
	_check(var_to_bytes(_geometry(actual)) != baseline,
		"unchanged metadata cannot conceal a changed actual collider")
	shape.size = original
	_check(var_to_bytes(_geometry(actual)) == baseline, "physical negative controls restore exactly")


func _no_human_ownership(node: Node) -> void:
	_check(not node.has_meta("owned_copy") and not node.has_meta("candidate_instance")
		and not node.has_meta("candidate_venue") and not node.has_meta("stadium_snapshot"),
		"detached NPC node never carries human/candidate/production-snapshot ownership")
	if node.has_meta("stadium_item"):
		_check(node.get_meta("stadium_item") == "ST-080",
			"no pole, receiver, lighting or other catalog copy accompanies four chairs")
	for child: Node in node.get_children():
		_no_human_ownership(child)


func _pose(index: int) -> Transform3D:
	var side: float = 1.0 if index < 2 else -1.0
	return Transform3D(Basis(Vector3(0, 0, -side), Vector3.UP, Vector3(side, 0, 0)),
		Vector3(-24 if index < 2 else 24, 0, 10 if index % 2 == 0 else 12))


func _components(value: Transform3D) -> Array:
	var result: Array = []
	for vector: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result


func _relabel(value: Dictionary, id: String, revision: int) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.id = id
	result.revision = revision
	for row: Dictionary in result.instances:
		row.instance = "npc:%s:r%d:%s" % [id, revision, row.site]
	return result


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
