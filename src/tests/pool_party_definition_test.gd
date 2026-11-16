extends Node
## Authored native tests. Source-only parsing is not execution or a finished Pool Party final.

const DEFINITION = preload("res://src/gameplay/stadium/stadium_pool_party_definition_v1.gd")
const CONSTRUCTION = preload(
	"res://src/presentation/stadium/stadium_pool_party_public_construction.gd")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_definition()
	_graph()
	_construction()
	print("POOL_PARTY_DEFINITION checks=%d failures=%d completed_games=0" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _definition() -> void:
	var raw: Dictionary = DEFINITION.payload()
	var native: Dictionary = DEFINITION.canonical()
	var decoded: Variant = JSON.parse_string(JSON.stringify(raw, "", true, true))
	_check(typeof(raw.version) == TYPE_INT and decoded is Dictionary
		and typeof(decoded.version) == TYPE_FLOAT, "native int / parsed JSON float types retained")
	var parsed: Dictionary = StadiumNpcManifest.canonical_shape(decoded)
	_check(not native.is_empty() and not parsed.is_empty()
		and JSON.stringify(native, "", true, true) == JSON.stringify(parsed, "", true, true),
		"native and parsed canonical manifests compare exactly")
	_check(JSON.stringify(native, "", true, true).sha256_text() == DEFINITION.SHA256
		and JSON.stringify(parsed, "", true, true).sha256_text() == DEFINITION.SHA256,
		"both native and parsed canonical keys match authored literal")
	if native.is_empty():
		return
	_check(native.id == "POOL-PARTY" and native.revision == 1 and native.tier == "expanded"
		and native.field == "field.npc_venue" and native.shape == "straight"
		and native.assembly.id == "POOL-PARTY-public-straight-v1", "exact neutral public recipe")
	_check(native.instances.size() == 65 and native.models.size() == 30
		and native.live_units == 4 and native.environment_certificates.is_empty()
		and native.presentation.profile == "POOL-PARTY-1310-CLEAR-v1", "exact65 / four live units")
	var counts: Dictionary = {}
	for row: Dictionary in native.instances:
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		_check(row.instance == CONSTRUCTION.INSTANCE_PREFIX + row.site
			and row.host == "field", "neutral instance identity")
	_check(counts == CONSTRUCTION.COUNTS, "exact ten-type recipe without theme extras")
	var layout: Dictionary = DEFINITION.source_layout()
	_check(layout.pool.position == [12, 0, 18] and layout.pool.yaw == 0
		and layout.pool.scale == [1, 1, 1] and layout.pool.ladder_world_direction == "+X"
		and layout.ground.bounds == [-32, -16, 64, 54]
		and layout.optional_sites == "all-other-sites-empty"
		and layout.time == "13:10" and layout.weather == "clear" and not layout.night_lighting,
		"fixed flat Expanded layout, pool handedness and clear daylight")
	for wrong: Variant in [true, "1", null, 1.5, [], {}]:
		var changed: Dictionary = raw.duplicate(true)
		changed.revision = wrong
		_check(StadiumNpcManifest.canonical_shape(changed).is_empty(), "wrong raw revision type")
	var changed: Dictionary = raw.duplicate(true)
	changed.id = &"POOL-PARTY"
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(), "StringName id is not String")
	changed = raw.duplicate(true)
	changed.instances[0].transform[0] = true
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(), "bool transform is not number")
	changed = raw.duplicate(true)
	changed.instances[0].instance = "paid-copy:forged"
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(), "paid identity cannot replace NPC")
	changed = raw.duplicate(true)
	changed.instances[0].transform[9] += 0.125
	_check(JSON.stringify(StadiumNpcManifest.canonical_shape(changed), "", true, true).sha256_text()
		!= DEFINITION.SHA256, "finite pose tamper changes exact manifest key")


func _graph() -> void:
	var graph: StadiumTimberDugoutBoundary = StadiumTimberDugoutBoundary.candidate("straight")
	_check(graph != null and graph.get_script() == StadiumTimberDugoutBoundary,
		"factory returns exact timber graph subclass")
	if graph == null:
		return
	_check(graph.identity() == "PERIM-POOL-PARTY-TIMBER-STRAIGHT-v1"
		and graph.signature() == "a2e51d2a9b8f1238dfec870afc0cf7940237e8fb1f1e74f6363dbe3145aa71cb"
		and graph.signature() == DEFINITION.payload().graph.sha256,
		"source-emulated and actual native graph signature match exactly")
	for side: String in ["L", "R"]:
		_check(graph.segment("DUGOUT-" + side + "-OPEN").height == 1.3
			and graph.segment("DUGOUT-" + side + "-FACE-IN").height == 1.2,
			"roofless timber opening and barrier caps retain distinct exact heights")


func _construction() -> void:
	var construction: StadiumPoolPartyPublicConstruction = CONSTRUCTION.build()
	_check(construction != null, "detached existing-asset construction succeeds")
	if construction == null:
		return
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	property.venue_id = "POOL-PARTY"
	property.tier = "expanded"
	property.construction = construction
	property.field = construction.field
	property.objects = construction.objects
	property.add_child(construction)
	_check(CONSTRUCTION.valid(property), "cold actual65 scene matches exact manifest")
	var source: StadiumPoolPartyPublicBoundarySource = construction.get_node("ClubBoundary")
	for body: StaticBody3D in source.bodies:
		_check(body.get_meta("surface_role") != "DECORATIVE_AFTER_TERMINAL"
			and StadiumTimberDugoutBoundary._tagged(body),
			"every sweep member is a valid preterminal physical surface")
	for model: Node3D in source.items:
		if model.get_meta("stadium_item") != "ST-032":
			continue
		for body: StaticBody3D in model.get_node("Collision").get_children():
			if body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL":
				_check(not source.bodies.has(body)
					and (body.collision_layer & source.QUERY_MASK) == 0,
					"outside timber furniture excluded from live sphere query")
	var pool: Node3D = property.objects[CONSTRUCTION.INSTANCE_PREFIX + "OL-R"]
	_check(pool.transform == StadiumPoolContract.placement()
		and not pool.has_meta("npc_instance") and not pool.has_meta("owned_copy")
		and pool.get_meta("placement_role") == StadiumPoolContract.LIVE,
		"pool remains unchanged shared live factory, with identity outside its tree")
	pool.set_meta("owned_copy", "forged-backyard16-copy")
	_check(not CONSTRUCTION.valid(property), "owned-copy pool impersonation rejects")
	pool.remove_meta("owned_copy")
	_check(CONSTRUCTION.valid(property), "removing tamper restores exact cold scene")
	var changed: Node3D = property.objects[CONSTRUCTION.INSTANCE_PREFIX + "SIDE-SEAT-L"]
	var original: Transform3D = changed.transform
	changed.position.x += 0.125
	_check(not CONSTRUCTION.valid(property), "finite side-seat pose tamper rejects")
	changed.transform = original
	_check(CONSTRUCTION.valid(property), "exact side-seat restoration accepted")
	var obstacles: Array[Dictionary] = construction.route_obstacles()
	_check(obstacles.size() == 3 and obstacles[2].center == Vector3(12, 0, 18)
		and obstacles[2].radius == StadiumPoolContract.VISUAL_RADIUS + StadiumDefenderRoutes.BODY_RADIUS,
		"receiver avoidance plus existing complete pool envelope and actor clearance")
	property.free()


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("POOL_PARTY_DEFINITION: " + label)
