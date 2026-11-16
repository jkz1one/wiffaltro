extends Node3D
## Geometry-only raw15 exercise. Synthetic funding is explicit; journal operations own every copy.

const Data = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")
const SHAPES: Array[String] = [
	"straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"
]
var _failures: int = 0
var _assemblies: int = 0


func _ready() -> void:
	var ledger: ClubAssetLedger = Data.fund()
	_check(ledger != null, "test-only paid fixture creates all ownership through ledger operations")
	if ledger != null:
		var original: Dictionary = Data.state(ledger)
		for shape: String in SHAPES:
			for tier: String in StadiumLand.TIERS:
				_matrix_case(ledger, shape, tier)
		_old14(ledger)
		_invalid(ledger)
		_check(ClubCareer.same(original, Data.state(ledger)),
			"all assemblies preserve the complete caller ledger and inventories")
	_check(_assemblies == 20, "all five wall shapes and four property tiers built")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard properties passed: 20 assemblies, old14 parity and binding.")
	get_tree().quit(0 if _failures == 0 else 1)


func _matrix_case(ledger: ClubAssetLedger, shape: String, tier: String) -> void:
	var layout: Dictionary = Data.mounted(ledger, shape)
	layout.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}
	]
	var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	add_child(property)
	var built: bool = property.build_scoreboards(tier, layout, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned())
	_check(built, "mounted complete assembly: " + shape + "/" + tier)
	if not built:
		property.free()
		return
	_assemblies += 1
	var row: Dictionary = layout.scoreboards[0]
	var board: Node3D = property.board_objects[row.copy]
	var spec: Dictionary = StadiumScoreboardAssembly.profile(row)
	_check(property.objects[row.copy] == board and property.board_objects.size() == 1,
		"one paid center copy occurs once in both exact object maps")
	_check(board.transform == StadiumScoreboardAssembly.pose(row)
		and board.get_meta("owned_copy") == row.copy
		and board.get_meta("site") == StadiumScoreboardMountCatalog.CENTER_SITE
		and board.get_meta("scoreboard_mount_profile") == StadiumScoreboardMountCatalog.CENTER_PROFILE
		and board.get_meta("stadium_item") == "ST-090"
		and board.get_meta("scoreboard_owned_model") == "electronic-v2"
		and board.get_meta("surface_role") == &"DECORATIVE_AFTER_TERMINAL",
		"exact socket, copy, model, mount and decorative-role metadata")
	_check(property.get_meta("property_signature") == StadiumOwnedLayout.geometry(tier, layout)
		and property.get_meta("scoreboard_mount_catalog") == StadiumScoreboardMountCatalog.signature(1)
		and not property.has_meta("scoreboard_authoring_only"),
		"raw15 assembly retains distinct mount identity without candidate-origin markers")
	_check(property.get_meta("scoreboard_layout") == layout
		and property.get_meta("advanced_layout") == StadiumScoreboardAssembly.base(layout)
		and property.get_meta("scoreboard_inventory") == ledger.scoreboards().to_data(),
		"complete inherited layout and inventory metadata remain exact")
	_check(board.find_children("*", "CollisionObject3D", true, false).is_empty()
		and board.find_children("*", "CollisionShape3D", true, false).is_empty()
		and board.find_children("*", "CollisionPolygon3D", true, false).is_empty(),
		"entire mounted assembly is decorative, including latent collider nodes")
	var cabinet: Node3D = board.get_node(NodePath(spec.model_root_path))
	_check(cabinet.position == Vector3(0, 2.4, 0), "existing cabinet is lifted exactly2.4m")
	for path: String in spec.remove_model_nodes:
		_check(not cabinet.has_node(NodePath(path)), "old post and foot are absent: " + path)
	for part: Dictionary in spec.support:
		_check(board.has_node(NodePath("Visual/" + part.name)), "full support member: " + part.name)
	_bounds(board, row, tier)
	var baseline: StadiumAdvancedPropertyGeometry = StadiumAdvancedPropertyGeometry.new()
	add_child(baseline)
	_check(baseline.build_owned(tier, StadiumScoreboardAssembly.base(layout),
		ledger.construction(), ledger.wall_pieces(), ledger.surface_owned()),
		"exact inherited field builds independently")
	_check(property.route_obstacles().size() == 3
		and ClubCareer.same(property.route_obstacles(), baseline.route_obstacles()),
		"mounted cabinet and support never enter live defender routes")
	_check(property.boundary.graph.signature() == baseline.boundary.graph.signature(),
		"mounted assembly preserves the actual paid boundary graph")
	baseline.free()
	_bindings(property, row)
	_check(property.board_display("not-owned") == null, "display lookup rejects unknown copy")
	_check(not property.build_scoreboards(tier, layout, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned()),
		"repeat build cannot append a second property or board")
	property.free()


func _bounds(board: Node3D, row: Dictionary, tier: String) -> void:
	var reserved: AABB = StadiumScoreboardAssembly.bounds(row)
	_check(reserved == StadiumScoreboardMountCatalog.bounds(row, 1)
		and StadiumProperty.contains(tier, reserved), "full mount envelope uses frozen catalog1")
	var count: int = 0
	for mesh: MeshInstance3D in board.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = board.get_parent().global_transform.affine_inverse() \
			* mesh.global_transform * mesh.get_aabb()
		_check(reserved.grow(0.0001).encloses(box), "actual transformed mesh is inside full envelope")
		count += 1
	_check(count > 12, "cabinet and all12 support meshes are real geometry")


func _bindings(property: StadiumScoreboardPropertyGeometry, row: Dictionary) -> void:
	var display: StadiumScoreboardTierDisplay = property.board_display(row.copy)
	_check(display != null and display == StadiumScoreboardAssembly.display(
		property.board_objects[row.copy], row), "one profile accessor resolves the nested readout")
	if display == null:
		return
	var state: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
	state.inning = 4
	state.home_team.runs = 5
	state.away_team.runs = 3
	state.balls = 2
	state.strikes = 1
	state.outs = 2
	property.rebind_displays(state)
	_check(display._match == state and display.shown.home == 5 and display.details.balls == "2",
		"center readout receives actual match score and details")
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]:
		state.phase = phase
		state.home_team.runs = 6
		state.balls = 3
		display._process(0)
		_check(display.shown.home == 5 and display.details.balls == "2",
			"every live score/detail field holds during flight and ball-in-play")
	state.phase = MatchState.Phase.PRE_PITCH
	display._process(0)
	_check(display.shown.home == 6 and display.details.balls == "3", "safe phase releases held data")
	property.rebind_displays(null)
	_check(display._match == null and display.shown.is_empty() and display.details.is_empty()
		and display._labels.home.text == "—", "unbind clears previous score and details")
	var next: MatchState = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "NEW", "CLUB")
	next.phase = MatchState.Phase.BALL_IN_PLAY
	property.rebind_displays(next)
	_check(display._match == next and display.shown.home == 0,
		"rebind even during live play cannot leak previous match score")


func _old14(ledger: ClubAssetLedger) -> void:
	var layout: Dictionary = Data.layout14(ledger)
	for item: String in StadiumScoreboardCatalog.IDS:
		var copies: Dictionary = ledger.scoreboards().copies if item == "ST-090" \
			else ledger.construction().copies
		var row: Dictionary = {"copy": Data.copy_id(copies, item),
			"item": item, "model": StadiumScoreboardModels.MODELS[item],
			"site": "BOARD-LARGE-v2" if item == "ST-040" else "BOARD-RIGHT-v2"}
		layout.scoreboards = [row]
		var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
		add_child(property)
		_check(property.build_scoreboards("mogul", layout, ledger.construction(),
			ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned()),
			"shared complete builder still accepts exact14: " + item)
		if property.board_objects.has(row.copy):
			var direct: Node3D = StadiumScoreboardModels.create(row.item, row.model)
			var extended: Dictionary = row.duplicate(true)
			extended["mount_profile"] = ""
			var empty_profile: Node3D = StadiumScoreboardAssembly.create(extended)
			var board: Node3D = property.board_objects[row.copy]
			direct.transform = board.transform
			empty_profile.transform = board.transform
			_check(_structure(board) == _structure(direct)
				and _structure(board) == _structure(empty_profile),
				"old14 and empty-profile15 preserve original model tree, meshes and label geometry")
			_check(property.board_display(row.copy) == board.get_node("Visual/ScoreDisplay")
				and property.get_meta("scoreboard_authoring_only")
				and not property.has_meta("scoreboard_mount_catalog")
				and StadiumScoreboardAssembly.bounds(row) == StadiumScoreboardModels.bounds(row)
				and StadiumScoreboardAssembly.pose(row) == StadiumScoreboardSites.pose(row.site),
				"legacy accessor, metadata, socket pose and envelope remain unchanged")
			direct.free()
			empty_profile.free()
		property.free()
		_legacy_camera_cache(ledger, layout)


func _legacy_camera_cache(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var mounted: Dictionary = StadiumMountedScoreboardLayout.upgrade(layout,
		ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), "mogul",
		ledger.scoreboards())
	_check(not mounted.is_empty(), "exact14 upgrades to explicit empty-profile15 for cache parity")
	if mounted.is_empty():
		return
	var host: Node3D = Node3D.new()
	add_child(host)
	var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
	property.name = "HomeProperty"
	host.add_child(property)
	var built: bool = property.build_scoreboards("mogul", mounted, ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned())
	_check(built, "independent exact15 empty-profile property builds for cache parity")
	if built:
		var legacy: BallTrackingVisibility = StadiumHeightCameraVisibility.new() \
			if property.boundary is StadiumHeightBoundaryBody else BallTrackingVisibility.new()
		var next: StadiumMountedCameraVisibility = StadiumMountedCameraVisibility.new()
		legacy.configure(host)
		next.configure(host)
		_check(not legacy._obstacles.is_empty() and next._obstacles == legacy._obstacles
			and next._uprights == legacy._uprights and next._mounted_meshes.is_empty()
			and next._wall_bounds == legacy._wall_bounds
			and next._recipe == legacy._recipe and next.field_wall_z == legacy.field_wall_z,
			"manual/electronic/video empty profiles preserve every legacy obstacle/upright cache")
	host.free()


func _structure(node: Node3D) -> Dictionary:
	var data: Dictionary = {"class": node.get_class(), "pose": node.transform, "children": []}
	if node is MeshInstance3D:
		data["mesh_class"] = node.mesh.get_class()
		data["aabb"] = node.mesh.get_aabb()
	elif node is Label3D:
		data["label"] = [node.text, node.font_size, node.pixel_size]
	for child: Node3D in node.get_children():
		data.children.append(_structure(child))
	return data


func _invalid(ledger: ClubAssetLedger) -> void:
	var layout: Dictionary = Data.mounted(ledger)
	for version: Variant in [13, 16, true, "15"]:
		var bad: Dictionary = layout.duplicate(true)
		bad.version = version
		var property: StadiumScoreboardPropertyGeometry = StadiumScoreboardPropertyGeometry.new()
		_check(not property.build_scoreboards("mogul", bad, ledger.construction(),
			ledger.wall_pieces(), ledger.scoreboards(), ledger.surface_owned())
			and property.get_child_count() == 0 and property.objects.is_empty()
			and property.board_objects.is_empty(), "unsupported schema leaves no partial assembly")
		property.free()
	var bad: Dictionary = layout.scoreboards[0].duplicate(true)
	bad.mount_profile = "unregistered"
	_check(StadiumScoreboardAssembly.profile(bad).is_empty()
		and StadiumScoreboardAssembly.bounds(bad) == AABB()
		and StadiumScoreboardAssembly.create(bad) == null, "unknown mount cannot fabricate geometry")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
