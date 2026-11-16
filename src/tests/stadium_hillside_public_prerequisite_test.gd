extends Node
## Bounded construction/HUD prerequisite evidence only. No public game, sweep or progression claim.
# gdlint: disable=max-returns,max-file-lines

const DEFINITION = preload("res://src/gameplay/stadium/stadium_hillside_definition_v1.gd")
const CONSTRUCTION = preload(
	"res://src/presentation/stadium/stadium_hillside_public_construction.gd"
)
const EXPECTED_CHECKS: int = 65
const EXPECTED_GROUPS: Dictionary = {
	"definition": 16,
	"construction": 15,
	"geometry": 10,
	"fail_closed": 4,
	"hillside_hud": 10,
	"pool_board": 6,
	"admission": 3,
	"inventory": 1
}
const SITES: Array[String] = [
	"DUGOUT-L",
	"DUGOUT-R",
	"FOUL-POLE-L",
	"FOUL-POLE-R",
	"RECEIVER-CATCH",
	"RECEIVER-PRIMARY",
	"SIDE-SEAT-L",
	"SIDE-SEAT-R"
]
const ITEMS: Array[String] = [
	"ST-032", "ST-032", "ST-021", "ST-021", "ST-025", "ST-026", "ST-027", "ST-027"
]
const COUNTS: Dictionary = {"ST-021": 2, "ST-025": 1, "ST-026": 1, "ST-027": 2, "ST-032": 2}
const PREFIX: String = "npc:HILLSIDE:r1:"
var _checks: int = 0
var _failures: int = 0
var _groups: Dictionary = {}
var _group: String = ""
var _definition_sha256: String = ""


func _ready() -> void:
	_definition()
	var property: StadiumNpcPublicProperty = _construction()
	if property != null:
		_geometry(property.construction as StadiumHillsidePublicConstruction)
		_fail_closed(property)
		_hillside_hud(property)
		_admission(property)
		property.free()
	_pool_board()
	_group = "inventory"
	_check(_checks == EXPECTED_CHECKS - 1, "fixed prerequisite assertion inventory")
	if _groups != EXPECTED_GROUPS:
		_failures += 1
		push_error("HILLSIDE_PUBLIC_PREREQUISITE: fixed group inventory differs")
	var proof: Dictionary = {
		"schema": "HILLSIDE-PUBLIC-PREREQUISITE-v1",
		"checks": _checks,
		"failures": _failures,
		"groups": _groups,
		"definition_sha256": _definition_sha256,
		"copies": 8,
		"paid_boundary_copies": 0,
		"completed_games": 0,
		"public_admitted": false,
		"physical_contacts_claimed": false,
		"geometry_status": "Working"
	}
	var proof_line: String = (
		"HILLSIDE_PUBLIC_PREREQUISITE_PROOF " + JSON.stringify(proof, "", true, true)
	)
	if proof_line.to_utf8_buffer().size() > 4096:
		push_error("HILLSIDE_PUBLIC_PREREQUISITE: proof exceeds fixed byte bound")
		get_tree().quit(1)
		return
	print(proof_line)
	print("HILLSIDE_PUBLIC_PREREQUISITE checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _definition() -> void:
	_group = "definition"
	var raw: Dictionary = DEFINITION.payload()
	var native: Dictionary = DEFINITION.canonical()
	var decoded: Variant = JSON.parse_string(JSON.stringify(raw, "", true, true))
	var parsed: Dictionary = StadiumNpcManifest.canonical_shape(decoded)
	_check(
		(
			typeof(raw.get("version")) == TYPE_INT
			and decoded is Dictionary
			and typeof(decoded.get("version")) == TYPE_FLOAT
		),
		"raw/JSON numeric types remain distinct"
	)
	_check(
		(
			not native.is_empty()
			and not parsed.is_empty()
			and JSON.stringify(native, "", true, true) == JSON.stringify(parsed, "", true, true)
		),
		"cold native and JSON roundtrip canonical bytes exactly equal"
	)
	_definition_sha256 = JSON.stringify(native, "", true, true).sha256_text()
	_check(
		(
			_definition_sha256.length() == 64
			and _definition_sha256 == JSON.stringify(native, "", true, true).sha256_text()
			and _definition_sha256 == JSON.stringify(parsed, "", true, true).sha256_text()
			and DEFINITION.signature() == StadiumNpcManifest.payload_key(raw)
		),
		"definition hash derives from actual engine canonical bytes"
	)
	_check(
		(
			raw.id == "HILLSIDE"
			and raw.revision == 1
			and raw.tier == "expanded"
			and raw.field == "field.npc_venue"
			and raw.shape == "deeper_center"
		),
		"exact DD revision and retained field shape"
	)
	var counts: Dictionary = {}
	var sites: Array[String] = []
	var identity_ok: bool = true
	for row: Dictionary in raw.instances:
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		sites.append(row.site)
		identity_ok = identity_ok and row.instance == PREFIX + row.site and row.host == "field"
	_check(
		counts == COUNTS and sites == SITES and identity_ok and raw.instances.size() == 8,
		"exact five-type eight-copy named-site recipe"
	)
	var layout: Dictionary = DEFINITION.source_layout()
	_check(
		(
			raw.live_units == 0
			and raw.environment_certificates.is_empty()
			and layout.catalog_copies == 8
			and layout.live_obstacles.is_empty()
			and layout.optional_sites == "all-other-sites-empty"
			and layout.score_display == "HUD-only"
			and layout.time == "13:10"
			and layout.weather == "clear"
			and not layout.night_lighting
			and not layout.production_ready
			and layout.progression_held
		),
		"exact daylight HUD-only layout with optional objects and public admission held"
	)
	_check(
		not DEFINITION.source_paths().is_empty() and DEFINITION.sources_valid(),
		"retained source identity pins validate"
	)
	_check(
		DEFINITION.matches(raw) and DEFINITION.matches(decoded),
		"both raw native and parsed JSON accepted by exact definition comparator"
	)
	var changed: Dictionary = raw.duplicate(true)
	changed.instances.remove_at(0)
	_check(not DEFINITION.matches(changed), "missing copy rejects exact definition")
	changed = raw.duplicate(true)
	changed.instances[0].transform[9] += 0.125
	_check(not DEFINITION.matches(changed), "finite pose mutation rejects exact definition")
	changed = raw.duplicate(true)
	var model_key: String = changed.models.keys()[0]
	changed.models[model_key].sha256 = "0".repeat(64)
	_check(not DEFINITION.matches(changed), "source identity hash mutation rejects")
	changed = raw.duplicate(true)
	var extra: Dictionary = changed.instances[-1].duplicate(true)
	extra.site = "ZZ-UNREQUESTED"
	extra.instance = PREFIX + extra.site
	changed.instances.append(extra)
	_check(not DEFINITION.matches(changed), "well-formed extra object rejects exact definition")
	var wrong_types_reject: bool = true
	for wrong: Variant in [true, "1", null, 1.5, [], {}]:
		changed = raw.duplicate(true)
		changed.revision = wrong
		wrong_types_reject = (
			wrong_types_reject
			and StadiumNpcManifest.canonical_shape(changed).is_empty()
			and not DEFINITION.matches(changed)
		)
	_check(wrong_types_reject, "strict raw revision types reject before canonicalization")
	changed = raw.duplicate(true)
	changed.id = &"HILLSIDE"
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty() and not DEFINITION.matches(changed),
		"StringName cannot impersonate raw String identity"
	)
	changed = raw.duplicate(true)
	changed.instances[0].transform[0] = true
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty() and not DEFINITION.matches(changed),
		"boolean transform component is not a numeric pose"
	)
	changed = raw.duplicate(true)
	changed.graph.id += "-FORGED"
	_check(not DEFINITION.matches(changed), "different graph identity rejects exact definition")


func _construction() -> StadiumNpcPublicProperty:
	_group = "construction"
	var construction: StadiumHillsidePublicConstruction = CONSTRUCTION.build()
	_check(
		is_instance_valid(construction) and construction.get_script() == CONSTRUCTION,
		"actual new construction factory returns its exact script"
	)
	if construction == null:
		return null
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	property.venue_id = "HILLSIDE"
	property.tier = "expanded"
	property.construction = construction
	property.field = construction.field
	property.boundary = construction.boundary
	property.objects = construction.objects
	property.add_child(construction)
	_check(
		CONSTRUCTION.valid(property) and construction.cold_valid(),
		"actual detached eight-copy construction passes cold source/geometry audit"
	)
	var actual_keys: Array = property.objects.keys()
	actual_keys.sort()
	var expected_keys: Array[String] = []
	for site: String in SITES:
		expected_keys.append(PREFIX + site)
	_check(
		property.objects.size() == 8 and actual_keys == expected_keys,
		"exact eight named map entries leave all optional sites empty"
	)
	var counts: Dictionary = {}
	var identities: bool = true
	var poses: bool = true
	var assets: bool = true
	for index in range(SITES.size()):
		var model: Node3D = property.objects[PREFIX + SITES[index]]
		var item: String = str(model.get_meta("stadium_item", ""))
		counts[item] = int(counts.get(item, 0)) + 1
		identities = (
			identities
			and item == ITEMS[index]
			and model.get_parent() == construction
			and model.get_meta("npc_instance", "") == PREFIX + SITES[index]
			and model.get_meta("npc_site", "") == SITES[index]
			and model.get_meta("npc_host", "") == "field"
		)
		poses = poses and model.transform == _expected_pose(SITES[index])
		assets = assets and _asset_nonempty(model)
	_check(counts == COUNTS, "actual assets are precisely ST0261 ST0251 ST0322 ST0272 ST0212")
	_check(identities, "actual descendant identities agree with exact neutral map")
	_check(poses, "actual poses match independent retained placement contracts")
	_check(assets, "every one of eight actual assets has nonempty mesh and collision support")
	_check(
		_only_expected_catalog_assets(construction),
		"no hidden scoreboard lights live obstacles or paid boundary catalog copies"
	)
	_check(
		(
			is_instance_valid(construction.terrain)
			and is_instance_valid(construction.boundary)
			and construction.terrain.get_child_count() > 0
			and construction.boundary.bodies.size() == 10
		),
		"nonempty retained terrain and bespoke perimeter support exist"
	)
	var poles: bool = true
	for row: Dictionary in StadiumFoulPoleSites.rows(StadiumRecipeBoundary.create("deeper_center")):
		var model: Node3D = property.objects[PREFIX + row.site]
		var expected: Vector3 = row.position
		expected.y = StadiumHillsideTerrain.support_height(Vector2(expected.x, expected.z), "hill")
		poles = (
			poles
			and model.position == expected
			and model.basis == Basis.IDENTITY
			and model.scale == Vector3.ONE
		)
	_check(
		poles, "foul poles retain exact CH XZ with sampled terrain Y and vertical unit-scale bases"
	)
	var flat: bool = true
	for site: String in [
		"DUGOUT-L", "DUGOUT-R", "RECEIVER-CATCH", "RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R"
	]:
		var model: Node3D = property.objects[PREFIX + site]
		flat = (
			flat
			and model.position.y == 0
			and (
				StadiumHillsideTerrain.support_height(Vector2(model.position.x, model.position.z))
				== 0
			)
		)
	_check(flat, "six side amenities remain flat at retained support")
	var changed: Node3D = property.objects[PREFIX + "SIDE-SEAT-L"]
	var original: Transform3D = changed.transform
	changed.position.x += 0.125
	_check(not construction.cold_valid(), "actual finite pose mutation rejects cold construction")
	changed.transform = original
	property.objects.erase(PREFIX + "SIDE-SEAT-L")
	var missing_rejected: bool = not construction.cold_valid()
	property.objects[PREFIX + "SIDE-SEAT-L"] = true
	var scalar_rejected: bool = not construction.cold_valid()
	var stale_model: Node3D = Node3D.new()
	property.objects[PREFIX + "SIDE-SEAT-L"] = stale_model
	stale_model.free()
	var stale_model_rejected: bool = not construction.cold_valid()
	property.objects[PREFIX + "SIDE-SEAT-L"] = changed
	_check(
		missing_rejected and scalar_rejected and stale_model_rejected,
		"missing scalar or freed mapped copy rejects cold construction without dereference"
	)
	var extra: Node3D = Node3D.new()
	extra.name = "UnrequestedObject"
	construction.add_child(extra)
	var extra_rejected: bool = not construction.cold_valid()
	extra.free()
	var stale_construction: StadiumHillsidePublicConstruction = CONSTRUCTION.build()
	var stale_body_rejected: bool = false
	if is_instance_valid(stale_construction) and not stale_construction.boundary.bodies.is_empty():
		var stale_body: StaticBody3D = stale_construction.boundary.bodies[0]
		stale_body.free()
		stale_body_rejected = not stale_construction.cold_valid()
	if is_instance_valid(stale_construction):
		stale_construction.free()
	_check(
		extra_rejected and stale_body_rejected,
		"extra object and freed actual boundary member reject cold construction without dereference"
	)
	changed.set_meta("npc_instance", "paid-copy:forged")
	var tamper_rejected: bool = not construction.cold_valid()
	changed.set_meta("npc_instance", PREFIX + "SIDE-SEAT-L")
	var pole: Node3D = property.objects[PREFIX + "FOUL-POLE-L"]
	var pole_shape: CollisionShape3D = (
		pole.get_node_or_null("Collision/Pole/Shape") as CollisionShape3D
	)
	var rename_rejected: bool = false
	var disabled_rejected: bool = false
	if is_instance_valid(pole_shape):
		var original_name: StringName = pole_shape.name
		var original_disabled: bool = pole_shape.disabled
		pole_shape.name = "UnexpectedPoleShape"
		rename_rejected = not construction.cold_valid()
		pole_shape.name = original_name
		pole_shape.disabled = not original_disabled
		disabled_rejected = not construction.cold_valid()
		pole_shape.disabled = original_disabled
	_check(
		tamper_rejected and rename_rejected and disabled_rejected and construction.cold_valid(),
		"identity child-name and hidden disabled mutations reject and exact restoration succeeds"
	)
	return property


func _geometry(construction: StadiumHillsidePublicConstruction) -> void:
	_group = "geometry"
	var shape_node: CollisionShape3D = construction.terrain.get_node(
		"TerrainCollision/ClosedTerrainShape"
	)
	var shape: ConcavePolygonShape3D = shape_node.shape as ConcavePolygonShape3D
	var terrain_data: Dictionary = StadiumHillsideTerrainModels.geometry("hill")
	_check(
		(
			shape != null
			and shape.margin == 0.0
			and not shape.backface_collision
			and shape.get_faces() == terrain_data.faces
		),
		"exact retained closed terrain collider and zero margin"
	)
	_check(
		_closed_faces(shape.get_faces()),
		"actual retained terrain faces form a closed oriented mesh"
	)
	var terrain_visual: MeshInstance3D = construction.terrain.get_node("TerrainVisual")
	_check(
		_raw_mesh_faces(terrain_visual.mesh) == shape.get_faces(),
		"actual visible terrain triangles equal collision triangles exactly"
	)
	var report: Dictionary = construction.geometry_report()
	_check(
		(
			report.status == "WORKING_SOURCE_ONLY_PUBLIC_UNADMITTED"
			and not report.production_ready
			and not report.timber_runtime_admitted
			and report.progression_held
			and report.live_obstacles == 0
			and report.score_display == "HUD-only"
			and report.bounds == [-32, -16, 32, 38]
			and StadiumHillsideTerrain.START_Z == 16.0
			and StadiumHillsideTerrain.END_Z == 26.0
			and StadiumHillsideTerrain.RISE == 2.0
			and StadiumHillsideTerrain.SAMPLE_STEP == 0.25
			and StadiumHillsideTerrain.MAX_LINEAR_ERROR == 0.0009375
		),
		"retained numeric geometry stays Working with no widened error allowance"
	)
	var source: StadiumHillsidePublicBoundarySource = construction.boundary
	var graph: StadiumHillsidePublicBoundary = source.graph
	var retained: StadiumDugoutBoundary = StadiumDugoutBoundary.candidate("deeper_center")
	_check(
		graph.polygon() == retained.polygon() and graph.segments().size() == 16,
		"perimeter retains exact CH XZ and CI replacement polygon"
	)
	var rows_match: bool = true
	for row: Dictionary in graph.segments():
		var old: Dictionary = retained.segment(row.id)
		rows_match = (
			rows_match
			and row.a == old.a
			and row.b == old.b
			and row.role == old.role
			and row.height == (1.3 if row.role == "DUGOUT_OPENING_DEAD" else float(old.height))
		)
	_check(
		rows_match, "only retained timber entry relative height replaces original CI roof opening"
	)
	var slabs_only: bool = source.bodies.size() == 10 and source.get_child_count() == 10
	for body: StaticBody3D in source.bodies:
		slabs_only = (
			slabs_only
			and not String(body.name).begins_with("DUGOUT")
			and not body.has_meta("stadium_item")
			and not body.has_meta("owned_copy")
		)
	_check(slabs_only, "all six CI pieces are physically replaced without paid slab copies")
	_check(
		_boundary_geometry_exact(source),
		"nonempty closed slice/panel geometry uses exact support plus retained vertical height"
	)
	_check(
		_dugout_openings_clear(source),
		"no bespoke slab overlaps either complete two-metre CI aperture"
	)
	_check(
		(
			source.slice_count > 0
			and source.slice_count <= 256
			and report.perimeter.paid_boundary_copies == 0
			and report.perimeter.native_support_error_status == "unmeasured"
			and report.perimeter.max_legal_center_z == 26.0
			and (
				report.perimeter.max_defender_center_z
				== 26.0 - StadiumRecipeBoundary.DEFENDER_RADIUS
			)
		),
		"bounded source-only perimeter preserves measured/unmeasured distinction"
	)


func _fail_closed(property: StadiumNpcPublicProperty) -> void:
	_group = "fail_closed"
	var graph: StadiumHillsidePublicBoundary = property.construction.boundary.graph
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(property.field)
	var previous: Vector3 = Vector3(0, 6, 25)
	var current: Vector3 = Vector3(0, 6, 27)
	var event: Dictionary = graph.crossing(previous, current)
	_check(
		not event.is_empty() and event.get("role") == "BACK_CLEAR",
		"descriptive crossing fixture reaches real retained back boundary"
	)
	_check(
		(
			not graph.apply(resolver, event)
			and not resolver.state.dead
			and resolver.state.result_floor == BallPlayState.ResultFloor.NONE
			and resolver.state.stadium_contacts.is_empty()
		),
		"apply cannot turn descriptive construction event into gameplay authority"
	)
	_check(
		(
			graph.observe(resolver, previous, current).is_empty()
			and not resolver.state.dead
			and resolver.state.result_floor == BallPlayState.ResultFloor.NONE
			and resolver.state.stadium_contacts.is_empty()
		),
		"observe remains fail closed without mutating real resolver state"
	)
	var source: Node3D = property.construction.boundary
	_check(
		(
			not source.has_method("bind_ball")
			and not source.has_method("observe")
			and not source.has_method("apply")
			and not source.has_signal("contact_applied")
		),
		"construction boundary source issues no hidden gameplay or swept-contact adapter"
	)


func _hillside_hud(property: StadiumNpcPublicProperty) -> void:
	_group = "hillside_hud"
	var construction: StadiumHillsidePublicConstruction = property.construction
	_check(
		property.score_display_intact() and property.score_display_intact(true),
		"exact actual eight-copy Hillside accepts HUD-only display absence"
	)
	var display: StadiumScoreboardDisplay = StadiumScoreboardDisplay.new()
	property.display = display
	_check(not property.score_display_intact(), "injected Hillside display rejects")
	property.display = null
	display.free()
	var identity: String = PREFIX + "SIDE-SEAT-L"
	var model: Node3D = property.objects[identity]
	property.objects.erase(identity)
	_check(not property.score_display_intact(), "missing expected Hillside site rejects")
	property.objects[identity] = model
	property.objects[PREFIX + "EXTRA"] = model
	_check(not property.score_display_intact(), "extra Hillside site rejects")
	property.objects.erase(PREFIX + "EXTRA")
	property.objects = property.objects.duplicate()
	property.objects[identity] = construction.objects[PREFIX + "SIDE-SEAT-R"]
	_check(not property.score_display_intact(), "different objects map rejects")
	property.objects = construction.objects
	var impostor: Node3D = Node3D.new()
	property.construction = impostor
	_check(not property.score_display_intact(), "impostor construction script rejects")
	property.construction = construction
	impostor.free()
	construction.remove_child(model)
	_check(not property.score_display_intact(), "detached expected object rejects")
	construction.add_child(model)
	property.venue_id = "HILLSIDE-IMPOSTOR"
	_check(not property.score_display_intact(), "HUD exception requires exact venue identity")
	property.venue_id = "HILLSIDE"
	property.objects[identity] = true
	var scalar_rejected: bool = not property.score_display_intact()
	var freed: Node3D = Node3D.new()
	property.objects[identity] = freed
	freed.free()
	_check(
		scalar_rejected and not property.score_display_intact(),
		"malformed scalar and stale freed object reject without dereference"
	)
	property.objects[identity] = model
	_check(property.score_display_intact(), "all HUD prerequisite references restore exactly")


func _pool_board() -> void:
	_group = "pool_board"
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	property.venue_id = "POOL-PARTY"
	var construction: Node3D = Node3D.new()
	property.construction = construction
	property.add_child(construction)
	var board: Node3D = StadiumClubModels.create("ST-039")
	construction.add_child(board)
	var identity: String = (
		StadiumNpcPublicRuntime.identity_prefix("POOL-PARTY")
		+ StadiumNpcPublicRuntime.board_site("POOL-PARTY")
	)
	property.objects[identity] = board
	var display: StadiumScoreboardDisplay = board.get_node("Visual/ScoreDisplay")
	property.display = display
	_check(
		property.score_display_intact(), "existing Pool actual ST039 board/display identity accepts"
	)
	property.objects.erase(identity)
	_check(not property.score_display_intact(), "existing Pool missing board rejects")
	property.objects[identity] = board
	var other_board: Node3D = StadiumClubModels.create("ST-039")
	construction.add_child(other_board)
	property.display = other_board.get_node("Visual/ScoreDisplay")
	var swapped_display_rejected: bool = not property.score_display_intact()
	property.display = display
	property.objects[identity] = other_board
	_check(
		swapped_display_rejected and not property.score_display_intact(),
		"existing Pool swapped actual board or display rejects"
	)
	property.objects[identity] = board
	property.bound_state = MatchState.new()
	display.bind_match(MatchState.new())
	_check(
		property.score_display_intact() and not property.score_display_intact(true),
		"existing Pool bound-state mismatch rejects in match-checking mode"
	)
	display.bind_match(property.bound_state)
	_check(property.score_display_intact(true), "existing Pool exact match binding accepts")
	property.display = null
	_check(
		not property.score_display_intact(),
		"existing Pool cannot borrow Hillside no-board exception"
	)
	property.free()


func _admission(property: StadiumNpcPublicProperty) -> void:
	_group = "admission"
	_check(
		StadiumNpcPublicRuntime.board_site("HILLSIDE").is_empty(),
		"Hillside resolves no scoreboard site"
	)
	_check(
		not StadiumNpcPublicRuntime.supports_definition("HILLSIDE", 1),
		"Hillside public definition remains unregistered"
	)
	_check(
		property.score_display_intact() and not StadiumNpcPublicRuntime._references(property),
		"positive HUD prerequisite cannot silently authorize public runtime references"
	)


func _expected_pose(site: String) -> Transform3D:
	match site:
		"DUGOUT-L", "DUGOUT-R":
			return StadiumTimberDugoutContract.placement(site == "DUGOUT-L")
		"RECEIVER-PRIMARY":
			return Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION)
		"RECEIVER-CATCH":
			return Transform3D(Basis.IDENTITY, StadiumNetModels.POSITION)
		"SIDE-SEAT-L":
			return Transform3D(
				Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(-24, 0, 12.5)
			)
		"SIDE-SEAT-R":
			return Transform3D(
				Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT), Vector3(24, 0, 12.5)
			)
		"FOUL-POLE-L", "FOUL-POLE-R":
			for row: Dictionary in StadiumFoulPoleSites.rows(
				StadiumRecipeBoundary.create("deeper_center")
			):
				if row.site == site:
					var point: Vector3 = row.position
					point.y = StadiumHillsideTerrain.support_height(
						Vector2(point.x, point.z), "hill"
					)
					return Transform3D(Basis.IDENTITY, point)
	return Transform3D.IDENTITY


func _asset_nonempty(model: Node3D) -> bool:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	var shapes: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
	if meshes.is_empty() or shapes.is_empty():
		return false
	for node: Node in meshes:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh == null or mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
			return false
	for node: Node in shapes:
		var shape: CollisionShape3D = node as CollisionShape3D
		if shape == null or shape.shape == null or shape.disabled:
			return false
	return true


func _only_expected_catalog_assets(construction: Node3D) -> bool:
	var actual: Dictionary = {}
	for node: Node in construction.find_children("*", "", true, false):
		if (
			node is Light3D
			or node is StadiumScoreboardDisplay
			or node is StadiumScoreboardTierDisplay
		):
			return false
		if node.has_meta("stadium_item"):
			var item: Variant = node.get_meta("stadium_item")
			if not item is String or not COUNTS.has(item):
				return false
			if node.get_parent() == construction:
				actual[item] = int(actual.get(item, 0)) + 1
	return actual == COUNTS


func _boundary_geometry_exact(source: StadiumHillsidePublicBoundarySource) -> bool:
	var slices: int = 0
	for body: StaticBody3D in source.bodies:
		var row: Dictionary = source.graph.segment(String(body.name))
		var visual: MeshInstance3D = body.get_node_or_null("TerrainConformedPanels")
		if row.is_empty() or visual == null or visual.mesh == null:
			return false
		var faces: PackedVector3Array = _raw_mesh_faces(visual.mesh)
		if not _closed_faces(faces):
			return false
		var expected_vertices: Dictionary = {}
		for node: Node in body.get_children():
			if not node is CollisionShape3D:
				continue
			var shape: ConvexPolygonShape3D = node.shape as ConvexPolygonShape3D
			if (
				shape == null
				or shape.margin != 0.0
				or node.disabled
				or shape.points.size() < 6
				or shape.points.size() % 2 != 0
			):
				return false
			var half: int = shape.points.size() >> 1
			for index in range(half):
				var lower: Vector3 = shape.points[index]
				var upper: Vector3 = shape.points[index + half]
				var support: float = StadiumHillsideTerrain.support_height(
					Vector2(lower.x, lower.z)
				)
				if (
					lower != Vector3(lower.x, support, lower.z)
					or upper != Vector3(lower.x, support + float(row.height), lower.z)
				):
					return false
			for point: Vector3 in shape.points:
				expected_vertices[_point_key(point)] = true
			slices += 1
		var visible_vertices: Dictionary = {}
		for point: Vector3 in faces:
			visible_vertices[_point_key(point)] = true
		if expected_vertices != visible_vertices:
			return false
	return slices > 0 and slices == source.slice_count


func _dugout_openings_clear(source: StadiumHillsidePublicBoundarySource) -> bool:
	for left: bool in [true, false]:
		var aperture: PackedVector2Array = []
		for sd: Vector2 in [
			Vector2(12, -0.01), Vector2(14, -0.01), Vector2(14, 0.5), Vector2(12, 0.5)
		]:
			var point: Vector3 = StadiumDugoutRecipe.rail_point(sd.x, sd.y, left)
			aperture.append(Vector2(point.x, point.z))
		for body: StaticBody3D in source.bodies:
			for node: Node in body.get_children():
				if not node is CollisionShape3D:
					continue
				var shape: ConvexPolygonShape3D = node.shape as ConvexPolygonShape3D
				var polygon: PackedVector2Array = []
				for index in range(shape.points.size() >> 1):
					var point: Vector3 = shape.points[index]
					polygon.append(Vector2(point.x, point.z))
				if not Geometry2D.intersect_polygons(polygon, aperture).is_empty():
					return false
	return true


func _closed_faces(faces: PackedVector3Array) -> bool:
	if faces.is_empty() or faces.size() % 3 != 0:
		return false
	var edges: Dictionary = {}
	for offset in range(0, faces.size(), 3):
		for index in range(3):
			var a: String = _point_key(faces[offset + index])
			var b: String = _point_key(faces[offset + (index + 1) % 3])
			if a == b:
				return false
			var key: String = a + ":" + b if a < b else b + ":" + a
			var edge: Vector2i = edges.get(key, Vector2i.ZERO)
			edge.x += 1
			edge.y += 1 if a < b else -1
			edges[key] = edge
	for edge: Vector2i in edges.values():
		if edge.x < 2 or edge.x % 2 != 0 or edge.y != 0:
			return false
	return true


func _point_key(point: Vector3) -> String:
	return JSON.stringify([point.x, point.y, point.z], "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	_groups[_group] = int(_groups.get(_group, 0)) + 1
	if not ok:
		_failures += 1
		push_error("HILLSIDE_PUBLIC_PREREQUISITE: " + label)


func _raw_mesh_faces(mesh: Mesh) -> PackedVector3Array:
	# Mesh.get_faces uses TriangleMesh's snapped BVH copy, not the exact render vertices.
	var result: PackedVector3Array = []
	if not is_instance_valid(mesh) or not mesh is ArrayMesh:
		return result
	var surface_mesh: ArrayMesh = mesh as ArrayMesh
	for surface in range(surface_mesh.get_surface_count()):
		if surface_mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return []
		var arrays: Array = surface_mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty():
			result.append_array(vertices)
		else:
			for index: int in indices:
				if index < 0 or index >= vertices.size():
					return []
				result.append(vertices[index])
	return result
