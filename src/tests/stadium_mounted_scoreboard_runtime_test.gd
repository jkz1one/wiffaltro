extends Node3D
## Raw fixture15 runtime only. No public scheduling, report or reward admission is enabled.

const Data = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")
const SHAPES: Array[String] = [
	"straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"
]
var _failures: int = 0
var _installed: int = 0


func _ready() -> void:
	_check(not StadiumScoreboardRuntime.install_mounted_bound(null, null), "null install refuses")
	_check(not StadiumScoreboardRuntime.mounted_installed(null, {}, null), "null integrity refuses")
	for shape: String in SHAPES:
		await _case(shape)
	await _empty_profiles()
	_check(_installed == 5, "all five real paid wall-shape runtimes installed")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard runtime passed: paid raw15, atomic guards and integrity.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(shape: String) -> Dictionary:
	# Explicit synthetic test history adds the historical target gate; it is never a public reward.
	var progress: Array = Data.progress()
	for row: Dictionary in progress:
		row["strikeouts"] = 2
	var funded: ClubAssetLedger = Data.fund()
	if funded == null:
		_check(false, "existing paid mounted test fixture funds")
		return {}
	var ledger: ClubAssetLedger = ClubAssetLedger.from_data(
		funded.to_data(), Data.SEED, Data.credits(), progress)
	if ledger == null:
		_check(false, "test-only historical gate replays the original genuine purchase journal")
		return {}
	for item: String in ["ST-026", "ST-025"]:
		var price: int = StadiumPurchases.TARGET_VERSION if item == "ST-026" \
			else StadiumPurchases.NET_VERSION
		var bought: Dictionary = ledger.commit(Data.buy(ledger, "stadium_buy", item, 1, price))
		_check(bought.ok, "receiver is separately bought through original operation: " + item)
		if not bought.ok:
			return {}
	var layout: Dictionary = Data.mounted(ledger, shape)
	layout.receiver = ""
	layout.target = Data.copy_id(ledger.construction().copies, "ST-026")
	layout.net = Data.copy_id(ledger.construction().copies, "ST-025")
	layout.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}
	]
	_check(Data.apply(ledger, layout), "raw15 fixture drafts and applies through original journal")
	var entry: Dictionary = StadiumMountedScoreboardSnapshot.capture(ledger)
	var frozen: Dictionary = StadiumMountedScoreboardSnapshot.fixture(entry, 47, 0)
	_check(not frozen.is_empty(), "entry14 creates exact raw fixture15")
	return {"ledger": ledger, "fixture": frozen, "entry": entry}


func _lab(fixture: Dictionary, managed: bool = false) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._automation = MatchAutomation.new()
	lab._managed_match = managed
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH and not lab._pitch_actor.running,
		"ordinary automated ready reaches permitted delivery-before-release startup")
	lab._match_state.stadium = fixture.duplicate(true)
	return lab


func _case(shape: String) -> void:
	var data: Dictionary = _fixture(shape)
	if data.is_empty() or data.fixture.is_empty():
		return
	var ledger: ClubAssetLedger = data.ledger
	var fixture: Dictionary = data.fixture
	var original: Dictionary = fixture.duplicate(true)
	var ledger_before: Dictionary = Data.state(ledger)
	var lab: PitchBatLab = _lab(fixture, shape == "left_loft")
	if shape == "straight":
		_guards(lab, data)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var shot: int = lab._camera_director.shot
	_check(StadiumScoreboardRuntime.install_mounted_bound(lab, ledger),
		"bound raw fixture15 installs complete mounted world: " + shape)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	_installed += 1
	_check(lab._camera_director.shot == shot, "installation preserves selected paused camera")
	lab._camera_director.restore_after_pause()
	_check(_valid(lab, data), "exact mounted world authenticates after camera restore")
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	_check(property.find_children("BoundaryGraph", "", true, false).size() == 1
		and property.objects.size() == property.board_objects.size() + 4,
		"one complete boundary, two real obstacles, separately paid target/net and one board")
	_check(not property.has_meta("scoreboard_authoring_only")
		and not lab.has_meta("stadium_candidate_only"), "runtime retains clean raw15 provenance")
	_wiring(lab, data)
	_refused(lab, ledger, "duplicate install")
	if shape == "straight":
		_descendants(lab, data)
		_meshes(lab, data)
		_labels(lab, data)
		_identities(lab, data)
		_latent_colliders(lab, data)
		_camera_cache(lab, data)
		_mounted_proxy_cache(lab, data)
		_installed_origins(lab, data)
	_lifecycle(lab, data)
	_check(ClubCareer.same(original, fixture) and ClubCareer.same(ledger_before, Data.state(ledger)),
		"installation, tampering tests and restart preserve caller snapshot and paid ledger")
	_check(StadiumLayoutSnapshot.valid(fixture) == StadiumMountedScoreboardLayout.RUNTIME_READY
		and not StadiumScoreboardRuntime.installed(lab, fixture),
		"snapshot readiness is explicit; the legacy runtime never impersonates mounted15")
	lab.free()
	await get_tree().process_frame


func _guards(lab: PitchBatLab, data: Dictionary) -> void:
	var fixture: Dictionary = data.fixture
	var ledger: ClubAssetLedger = data.ledger
	lab._match_state.stadium = data.entry.duplicate(true)
	_refused(lab, ledger, "entry14 is not a fixture15")
	for field: String in ["revision", "future", "ownership", "inventory", "pieces", "surface",
		"model", "profile", "site", "version", "night", "missing", "extra"]:
		var bad: Dictionary = fixture.duplicate(true)
		match field:
			"revision": bad.revision -= 1
			"future": bad.revision = ledger.revision() + 1
			"ownership": bad.scoreboard_inventory.copies.erase(
				bad.scoreboard_inventory.copies.keys()[-1])
			"inventory": bad.inventory.copies.erase("starter-v1:ST-079")
			"pieces": bad.wall_piece_inventory.stock.copies.erase(
				bad.wall_piece_inventory.stock.copies.keys()[-1])
			"surface": bad.surface_access = []
			"model": bad.layout.scoreboards[0].model = "electronic-v3"
			"profile": bad.layout.scoreboards[0].mount_profile = ""
			"site": bad.layout.scoreboards[0].site = "BOARD-RIGHT-v2"
			"version": bad.version = 14
			"night": bad.environment.mode = "night"
			"missing": bad.erase("scoreboard_inventory")
			"extra": bad["approved"] = true
		lab._match_state.stadium = bad
		_refused(lab, ledger, "wrong frozen " + field)
	lab._match_state.stadium = fixture.duplicate(true)
	_refused(lab, null, "missing paid ledger")
	_refused(lab, Data.fund(), "wrong paid ledger prefix")
	for marker: StringName in [&"stadium_candidate_only", &"stadium_lab_only",
		&"scoreboard_authoring_fixture", &"novel_authoring_origin", &"novel_lab_only_origin"]:
		for node: Node in [self, lab, lab.get_node("StarterFieldGeometry/Ground")]:
			node.set_meta(marker, false)
			_refused(lab, ledger, "candidate marker exists even with false value")
			_check(node.has_meta(marker) and node.get_meta(marker) == false,
				"refusal never clears provenance from ancestor or descendant")
			node.remove_meta(marker)
	var tracker: BallTrackingVisibility = lab._camera_director.tracking_visibility
	lab._camera_director.tracking_visibility = null
	_refused(lab, ledger, "missing tracking visibility before any host mutation")
	lab._camera_director.tracking_visibility = tracker
	_host_guards(lab, ledger)
	_live_guards(lab, ledger)
	var before: Dictionary = _field_state(lab)
	_check(not StadiumPropertyRuntime.install_bound(lab),
		"public property dispatcher refuses missing retained ownership proof")
	_check(before == _field_state(lab), "public raw15 refusal preserves field and all wiring")


func _host_guards(lab: PitchBatLab, ledger: ClubAssetLedger) -> void:
	for origin: Node3D in [self, lab]:
		origin.visible = false
		_refused(lab, ledger, "host inherits hidden visibility from lab or ancestor")
		_check(not origin.visible, "rejection preserves hidden-origin state")
		origin.visible = true
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	var pose: Transform3D = host.transform
	host.position.x += 1
	_refused(lab, ledger, "translated host")
	host.transform = pose
	host.scale.x = 2
	_refused(lab, ledger, "scaled host")
	host.transform = pose
	host.visible = false
	_refused(lab, ledger, "hidden host")
	host.visible = true
	host.top_level = true
	_refused(lab, ledger, "top-level host")
	host.top_level = false
	host.transform = pose
	host.name = "MissingHost"
	_refused(lab, ledger, "missing named host")
	var wrong_host: Node3D = Node3D.new()
	wrong_host.name = "StarterFieldGeometry"
	lab.add_child(wrong_host)
	_refused(lab, ledger, "correctly named host of the wrong class")
	wrong_host.free()
	host.name = "StarterFieldGeometry"
	var fake: Node3D = Node3D.new()
	fake.name = "HomeProperty"
	host.add_child(fake)
	_refused(lab, ledger, "preexisting property child")
	fake.free()
	var field: StringName = lab._field_id
	lab._field_id = &"wrong.field"
	_refused(lab, ledger, "wrong field identity")
	lab._field_id = field
	var mode: bool = lab._match_mode
	lab._match_mode = false
	_refused(lab, ledger, "mechanics-lab mode")
	lab._match_mode = mode


func _live_guards(lab: PitchBatLab, ledger: ClubAssetLedger) -> void:
	var state: MatchState = lab._match_state
	lab._match_state = null
	_refused(lab, ledger, "missing match")
	lab._match_state = state
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY,
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.GAME_END]:
		state.phase = phase
		_refused(lab, ledger, "non-startup match phase")
	state.phase = MatchState.Phase.PRE_PITCH
	var ball: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = ball
	_refused(lab, ledger, "live batted body in pre-pitch phase")
	lab._batted_ball = null
	ball.free()
	lab._pitch_actor.running = true
	_refused(lab, ledger, "running pitch")
	lab._pitch_actor.running = false
	lab._release_controller.begin()
	_refused(lab, ledger, "active release controller")
	lab._release_controller.cancel()
	var cadence: int = lab._at_bat_cadence.state
	for value: int in [AtBatCadenceController.State.PITCH_LIVE,
		AtBatCadenceController.State.DEAD_BALL_HOLD]:
		lab._at_bat_cadence.state = value as AtBatCadenceController.State
		_refused(lab, ledger, "live cadence")
	lab._at_bat_cadence.state = cadence as AtBatCadenceController.State


func _wiring(lab: PitchBatLab, data: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var receiver: StadiumPairedReceiver = property.get_node("PitchReceiverPresentation")
	_check(receiver.chair == property.objects[data.fixture.layout.target]
		and receiver.net == property.objects[data.fixture.layout.net]
		and lab._pitch_actor.receiver_router == receiver.route
		and lab._ball_play_resolver.segment_observer == property.observe
		and lab._primary_fielder.stadium_boundary_clip == property.boundary.graph.clip
		and ClubCareer.same(lab._primary_fielder.stadium_obstacles, property.route_obstacles())
		and lab._camera_director.tracking_visibility is StadiumMountedCameraVisibility
		and lab._camera_director.tracking_visibility._recipe == property.boundary.graph,
		"actual paid receiver, exact observer, defender clip/routes and camera graph are bound")
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	_rejected(lab, data, "substitute boundary observer")
	lab._ball_play_resolver.segment_observer = observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	_rejected(lab, data, "substitute defender clip")
	lab._primary_fielder.stadium_boundary_clip = clip
	var routes: Array[Dictionary] = lab._primary_fielder.stadium_obstacles.duplicate(true)
	lab._primary_fielder.stadium_obstacles.clear()
	_rejected(lab, data, "missing actual defender obstacle routes")
	lab._primary_fielder.stadium_obstacles = routes.duplicate(true)
	lab._primary_fielder.stadium_obstacles[0].radius += 0.1
	_rejected(lab, data, "stale defender obstacle radius")
	lab._primary_fielder.stadium_obstacles = routes
	lab._pitch_actor.receiver_router = Callable()
	_rejected(lab, data, "missing real receiver route")
	lab._pitch_actor.receiver_router = receiver.route
	var camera: BallTrackingVisibility = lab._camera_director.tracking_visibility
	lab._camera_director.tracking_visibility = BallTrackingVisibility.new()
	_rejected(lab, data, "unconfigured legacy camera class")
	lab._camera_director.tracking_visibility = camera
	var copy: String = data.fixture.layout.scoreboards[0].copy
	var display: StadiumScoreboardTierDisplay = property.board_display(copy)
	display.bind_match(null)
	_rejected(lab, data, "unbound actual nested display")
	property.rebind_displays(lab._match_state)
	display.set_process(false)
	_rejected(lab, data, "disabled live display processing cannot silently freeze its readout")
	display.set_process(true)
	var paused: bool = get_tree().paused
	get_tree().paused = true
	_check(display.is_processing() and _valid(lab, data),
		"paused tree preserves configured mounted display processing and runtime integrity")
	get_tree().paused = paused
	_check(_valid(lab, data), "restored exact live wiring authenticates")


func _descendants(lab: PitchBatLab, data: Dictionary) -> void:
	var board: Node3D = _board(lab, data)
	var cabinet: Node3D = board.get_node("Visual/ElectronicV2Cabinet")
	var nodes: Array[Node3D] = [board, board.get_node("Visual"), cabinet,
		cabinet.get_node("Visual"), board.get_node("Visual/Mast1"),
		cabinet.get_node("Visual/ScoreDisplay")]
	for node: Node3D in nodes:
		var pose: Transform3D = node.transform
		node.position += Vector3(0.03, 0.04, 0.05)
		_rejected(lab, data, "moved descendant " + String(node.name))
		node.transform = pose
		node.scale *= 0.9
		_rejected(lab, data, "scaled descendant " + String(node.name))
		node.transform = pose
		node.visible = false
		_rejected(lab, data, "hidden descendant " + String(node.name))
		node.visible = true
		node.top_level = true
		_rejected(lab, data, "top-level descendant " + String(node.name))
		node.top_level = false
		node.transform = pose
		var parent: Node = node.get_parent()
		var index: int = node.get_index()
		parent.remove_child(node)
		_rejected(lab, data, "removed descendant " + String(node.name))
		parent.add_child(node)
		parent.move_child(node, index)
		_check(_valid(lab, data), "descendant transform/visibility/membership restores exactly")
	var mesh: MeshInstance3D = board.get_node("Visual/Mast1")
	var parent: Node = mesh.get_parent()
	var index: int = mesh.get_index()
	var replacement: MeshInstance3D = mesh.duplicate()
	parent.remove_child(mesh)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	_rejected(lab, data, "identical replacement support node cannot impersonate original ID")
	replacement.free()
	parent.add_child(mesh)
	parent.move_child(mesh, index)
	_check(_valid(lab, data), "original support node restores exact identity")


func _meshes(lab: PitchBatLab, data: Dictionary) -> void:
	var mesh: MeshInstance3D = _board(lab, data).get_node("Visual/Mast1")
	var original: BoxMesh = mesh.mesh
	var dimensions: Vector3 = original.size
	original.size.x += 0.02
	_rejected(lab, data, "mutated existing support mesh dimensions")
	original.size = dimensions
	original.flip_faces = not original.flip_faces
	_rejected(lab, data, "flipped existing mesh faces")
	original.flip_faces = not original.flip_faces
	mesh.mesh = original.duplicate()
	_rejected(lab, data, "identical replacement mesh resource")
	mesh.mesh = SphereMesh.new()
	_rejected(lab, data, "different primitive mesh")
	mesh.mesh = null
	_rejected(lab, data, "missing mesh resource")
	mesh.mesh = original
	var box: AABB = mesh.custom_aabb
	mesh.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE)
	_rejected(lab, data, "forged custom mesh bounds")
	mesh.custom_aabb = box
	var material: StandardMaterial3D = mesh.material_override
	_check(material != null, "support mesh owns a real material")
	if material != null:
		var color: Color = material.albedo_color
		material.albedo_color = Color.MAGENTA
		_rejected(lab, data, "existing material appearance mutated")
		material.albedo_color = color
		mesh.material_override = material.duplicate()
		_rejected(lab, data, "identical replacement material resource")
		mesh.material_override = material
	for row: Array in [["transparency", 0.5], ["layers", 0], ["extra_cull_margin", 10.0]]:
		var old: Variant = mesh.get(row[0])
		mesh.set(row[0], row[1])
		_rejected(lab, data, "mesh rendering field changed: " + row[0])
		mesh.set(row[0], old)
	_render_ranges(lab, data, mesh)
	_check(_valid(lab, data), "original mesh resources and rendering fields restore")


func _labels(lab: PitchBatLab, data: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var copy: String = data.fixture.layout.scoreboards[0].copy
	var display: StadiumScoreboardTierDisplay = property.board_display(copy)
	var label: Label3D = display._labels.home
	var text_before: String = label.text
	label.text = "99"
	_check(_valid(lab, data), "legitimate changing score text is excluded from geometry identity")
	label.text = text_before
	for channel: String in ["_labels", "_detail_labels"]:
		var saved: Dictionary = display.get(channel).duplicate()
		var key: String = saved.keys()[0]
		display.get(channel).erase(key)
		_rejected(lab, data, "missing exact readout-map membership " + channel)
		display.set(channel, saved.duplicate())
		display.get(channel)["unknown"] = saved[key]
		_rejected(lab, data, "extra readout-map membership " + channel)
		display.set(channel, saved.duplicate())
		var keys: Array = saved.keys()
		display.get(channel)[keys[0]] = saved[keys[1]]
		_rejected(lab, data, "aliased readout IDs " + channel)
		display.set(channel, saved)
	for row: Array in [["font_size", label.font_size + 1], ["pixel_size", label.pixel_size * 2],
		["offset", Vector2(1, 2)], ["outline_size", label.outline_size + 1], ["layers", 0],
		["no_depth_test", not label.no_depth_test], ["fixed_size", not label.fixed_size]]:
		var original: Variant = label.get(row[0])
		label.set(row[0], row[1])
		_rejected(lab, data, "label non-text field changed " + row[0])
		label.set(row[0], original)
	_render_ranges(lab, data, label)
	var font: Font = label.font
	label.font = SystemFont.new()
	_rejected(lab, data, "substitute font resource")
	label.font = font
	var pose: Transform3D = label.transform
	label.position.x += 0.01
	_rejected(lab, data, "label moved inside unchanged display")
	label.transform = pose
	var index: int = label.get_index()
	display.remove_child(label)
	_rejected(lab, data, "detached label still listed in display map")
	var replacement: Label3D = label.duplicate()
	display.add_child(replacement)
	display.move_child(replacement, index)
	display._labels.home = replacement
	_rejected(lab, data, "identical-looking replacement label and forged map")
	replacement.free()
	display.add_child(label)
	display.move_child(label, index)
	display._labels.home = label
	_check(_valid(lab, data), "label geometry, resources, maps and identities restore")


func _render_ranges(lab: PitchBatLab, data: Dictionary, node: GeometryInstance3D) -> void:
	for row: Array in [["visibility_range_begin", 50.0], ["visibility_range_end", 0.1],
		["visibility_range_begin_margin", 2.0], ["visibility_range_end_margin", 2.0],
		["visibility_range_fade_mode", GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF]]:
		var original: Variant = node.get(row[0])
		node.set(row[0], row[1])
		_rejected(lab, data, "hidden render-range mutation " + node.get_class() + "/" + row[0])
		node.set(row[0], original)


func _identities(lab: PitchBatLab, data: Dictionary) -> void:
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	var copy: String = data.fixture.layout.scoreboards[0].copy
	for key: String in ["property", "boundary", "mounted_host", "mounted_lab"]:
		for value: Variant in [float(identity[key]), str(identity[key]), true, null]:
			var bad: Dictionary = identity.duplicate(true)
			bad[key] = value
			lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
			_rejected(lab, data, "live integer ID rejects alternate type: " + key)
	for key: String in ["objects", "displays"]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key][copy] = float(bad[key][copy])
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "per-copy integer ID cannot normalize from float")
	for key: String in ["nodes", "boundary_nodes"]:
		var bad: Dictionary = identity.duplicate(true)
		var ids: Array = []
		ids.assign(bad[key])
		ids[0] = float(ids[0])
		bad[key] = ids
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "child-ID integer array cannot normalize from float")
	for target: String in ["tree_id", "tree_parent", "mesh_id", "label_id", "camera_id",
		"camera_script", "prism_id", "prism_script"]:
		var bad: Dictionary = identity.duplicate(true)
		var tree: Dictionary = bad.mounted_assemblies.boards[copy].tree
		match target:
			"tree_id": tree.id = float(tree.id)
			"tree_parent": tree.parent = float(tree.parent)
			"mesh_id":
				var mesh: Dictionary = _find_mesh_record(tree)
				_check(not mesh.is_empty(), "frozen descendant tree includes mesh identity")
				if not mesh.is_empty():
					mesh.id = float(mesh.id)
			"label_id":
				var labels: Dictionary = bad.mounted_assemblies.boards[copy].labels._labels
				labels.home = float(labels.home)
			"camera_id": bad.mounted_camera.id = float(bad.mounted_camera.id)
			"camera_script": bad.mounted_camera.script = float(bad.mounted_camera.script)
			"prism_id": bad.mounted_camera.prisms.id = float(bad.mounted_camera.prisms.id)
			"prism_script": bad.mounted_camera.prisms.script = float(bad.mounted_camera.prisms.script)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "nested frozen integer ID rejects float: " + target)
	for key: String in ["mounted_assemblies", "mounted_camera"]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key] = "invalid"
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "malformed mounted certificate " + key)
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
	_check(_valid(lab, data), "all exact64-bit identity metadata restores")


func _find_mesh_record(tree: Dictionary) -> Dictionary:
	if tree.has("mesh"):
		return tree.mesh
	for child: Dictionary in tree.children:
		var result: Dictionary = _find_mesh_record(child)
		if not result.is_empty():
			return result
	return {}


func _latent_colliders(lab: PitchBatLab, data: Dictionary) -> void:
	var board: Node3D = _board(lab, data)
	for node: Node in [StaticBody3D.new(), Area3D.new(), CollisionShape3D.new(),
		CollisionPolygon3D.new()]:
		if node is CollisionObject3D:
			node.collision_layer = 0
			node.collision_mask = 0
		if node is CollisionShape3D:
			node.shape = BoxShape3D.new()
			node.disabled = true
		if node is CollisionPolygon3D:
			node.disabled = true
		board.get_node("Visual").add_child(node)
		_rejected(lab, data, "latent collider rejects even when disabled or on no collision layer")
		node.free()
	_check(_valid(lab, data), "removing latent colliders restores decorative contract")


func _camera_cache(lab: PitchBatLab, data: Dictionary) -> void:
	var camera: StadiumMountedCameraVisibility = lab._camera_director.tracking_visibility
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	for key: String in ["_obstacles", "_uprights", "_wall_bounds"]:
		var saved: Array[AABB] = []
		saved.assign(camera.get(key))
		_check(not saved.is_empty(), "fixture contains independently meaningful camera cache " + key)
		if saved.is_empty():
			continue
		camera.get(key).clear()
		_rejected(lab, data, "missing camera cache " + key)
		camera.set(key, saved.duplicate())
		camera.get(key).append(saved[0])
		_rejected(lab, data, "duplicate camera cache " + key)
		camera.set(key, saved.duplicate())
		camera.get(key)[0] = saved[0].grow(0.02)
		_rejected(lab, data, "stale transformed cache bounds " + key)
		# Forging the certificate too cannot hide a cache that differs from actual meshes.
		var bad: Dictionary = identity.duplicate(true)
		bad.mounted_camera = StadiumMountedScoreboardIntegrity.camera_capture(camera)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected(lab, data, "self-consistent forged cache still fails fresh mesh derivation")
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
		camera.set(key, saved)
	var wall_z: float = camera.field_wall_z
	camera.field_wall_z += 0.1
	_rejected(lab, data, "stale camera field-wall depth")
	camera.field_wall_z = wall_z
	var replacement: StadiumMountedCameraVisibility = StadiumMountedCameraVisibility.new()
	replacement.configure(lab.get_node("StarterFieldGeometry"))
	lab._camera_director.tracking_visibility = replacement
	_rejected(lab, data, "new identically configured camera cannot impersonate frozen instance")
	lab._camera_director.tracking_visibility = camera
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var obstacle: Node3D = property.objects["starter-v1:ST-001"]
	obstacle.set_meta("scoreboard_mount_profile", Vector3.ZERO)
	_check(_valid(lab, data),
		"nonboard unlike-typed mount metadata cannot break fresh camera derivation")
	obstacle.remove_meta("scoreboard_mount_profile")
	_prism_cache(lab, data)
	_check(_valid(lab, data), "exact camera caches and camera instance restore")


func _mounted_proxy_cache(lab: PitchBatLab, data: Dictionary) -> void:
	var camera: StadiumMountedCameraVisibility = lab._camera_director.tracking_visibility
	var board: Node3D = _board(lab, data)
	var saved: Array[Dictionary] = camera._mounted_meshes.duplicate(true)
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	_check(saved.size() == board.find_children("*", "MeshInstance3D", true, false).size()
		and not saved.is_empty() and is_equal_approx(StadiumMountedCameraVisibility.LOS_MARGIN, 0.080),
		"each actual center mesh has one OBB and the full unchanged rendered-ball margin")
	for proxy: Dictionary in saved:
		var mesh: MeshInstance3D = board.get_node(NodePath(proxy.path))
		_check(proxy.root == board.get_instance_id() and proxy.node == mesh.get_instance_id()
			and proxy.parent == mesh.get_parent().get_instance_id()
			and proxy.mesh == mesh.mesh.get_instance_id() and proxy.bounds == mesh.get_aabb()
			and proxy.pose == mesh.global_transform
			and proxy.inverse.is_equal_approx(mesh.global_transform.affine_inverse()),
			"each OBB binds exact source root/node/parent/mesh/path/bounds/pose/inverse")
		var point: Vector3 = proxy.bounds.get_center()
		var offset: Vector3 = Vector3(0, 0, proxy.bounds.size.z + 1)
		_check(StadiumMountedCameraVisibility.proxy_intersects(proxy,
			proxy.pose * (point - offset), proxy.pose * (point + offset)),
			"actual local-box center ray remains blocked")
	if saved.is_empty():
		return
	for key: String in ["missing", "duplicate", "root", "node", "parent", "mesh", "path",
		"bounds", "pose", "inverse"]:
		match key:
			"missing": camera._mounted_meshes.clear()
			"duplicate": camera._mounted_meshes.append(saved[0].duplicate(true))
			"root", "node", "parent", "mesh":
				camera._mounted_meshes[0][key] = float(saved[0][key])
			"path": camera._mounted_meshes[0].path = "Visual/forged"
			"bounds": camera._mounted_meshes[0].bounds = saved[0].bounds.grow(0.1)
			"pose": camera._mounted_meshes[0].pose = saved[0].pose.translated(Vector3.UP)
			"inverse": camera._mounted_meshes[0].inverse = saved[0].inverse.translated(Vector3.UP)
		_rejected(lab, data, "mounted OBB cache corruption: " + key)
		var forged: Dictionary = identity.duplicate(true)
		forged.mounted_camera = StadiumMountedScoreboardIntegrity.camera_capture(camera)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, forged)
		_rejected(lab, data, "forged OBB certificate fails fresh scene derivation: " + key)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
		camera._mounted_meshes = saved.duplicate(true)
	_check(_valid(lab, data), "exact mounted OBB cache restores")


func _prism_cache(lab: PitchBatLab, data: Dictionary) -> void:
	var camera: StadiumMountedCameraVisibility = lab._camera_director.tracking_visibility
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	var prisms: StadiumWallViewPrisms = camera._wall_prisms
	_check(prisms != null and not prisms.walls.is_empty(), "installed camera has real wall prisms")
	if prisms == null or prisms.walls.is_empty():
		return
	camera._wall_prisms = null
	_rejected(lab, data, "missing narrow-phase camera wall-prism cache")
	camera._wall_prisms = StadiumWallViewPrisms.new(camera._recipe)
	_rejected(lab, data, "identical-geometry replacement prism object")
	camera._wall_prisms = prisms
	var walls: Array[Dictionary] = prisms.walls.duplicate(true)
	for field: String in ["missing", "duplicate", "plane", "height", "polygon"]:
		match field:
			"missing": prisms.walls.clear()
			"duplicate": prisms.walls.append(walls[0].duplicate(true))
			"plane":
				var plane: Plane = prisms.walls[0].planes[0]
				plane.d += 0.1
				prisms.walls[0].planes[0] = plane
			"height": prisms.walls[0].height += 0.1
			"polygon":
				var polygon: PackedVector2Array = prisms.walls[0].polygon.duplicate()
				polygon[0] += Vector2(0.1, 0.2)
				prisms.walls[0].polygon = polygon
		_rejected(lab, data, "mutated narrow-phase camera wall prisms: " + field)
		var forged: Dictionary = identity.duplicate(true)
		forged.mounted_camera = StadiumMountedScoreboardIntegrity.camera_capture(camera)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, forged)
		_rejected(lab, data, "forged prism certificate still fails fresh boundary derivation: " + field)
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
		prisms.walls = walls.duplicate(true)
	_check(_valid(lab, data), "original prism instance and complete wall geometry restore")


func _installed_origins(lab: PitchBatLab, data: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	for node: Node in [self, lab, property, _board(lab, data).get_node("Visual/Mast1")]:
		for marker: StringName in [&"stadium_candidate_only", &"foreign_authoring_origin",
			&"foreign_lab_only_origin"]:
			node.set_meta(marker, true)
			_rejected(lab, data, "candidate provenance is detected anywhere in installed origin")
			_check(node.get_meta(marker) == true, "integrity never erases candidate provenance")
			node.remove_meta(marker)
	for origin: Node3D in [self, lab]:
		origin.visible = false
		_rejected(lab, data, "installed host inherits hidden lab or ancestor visibility")
		origin.visible = true
	_check(_valid(lab, data), "clean origin restores after every candidate marker")


func _lifecycle(lab: PitchBatLab, data: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var copy: String = data.fixture.layout.scoreboards[0].copy
	var display: StadiumScoreboardTierDisplay = property.board_display(copy)
	var previous: MatchState = lab._match_state
	previous.home_team.runs = 7
	display._process(0)
	_check(display.shown.home == 7, "prior match score reaches actual display")
	lab._managed_match = false
	lab._configured_match = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
	lab._configured_match.stadium = data.fixture.duplicate(true)
	lab._start_new_match()
	_check(lab._match_state != previous and display._match == lab._match_state
		and display.shown.home == 0 and _valid(lab, data),
		"actual automatic match restart rebinds existing mounted readout without manual helper")
	lab._match_state.home_team.runs = 4
	lab._match_state.balls = 2
	lab._match_state.phase = MatchState.Phase.PRE_PITCH
	display._process(0)
	for phase: int in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]:
		lab._match_state.phase = phase
		lab._match_state.home_team.runs = 5
		lab._match_state.balls = 3
		display._process(0)
		_check(display.shown.home == 4 and display.details.balls == "2" and _valid(lab, data),
			"real runtime readout holds score/details through every live phase")
	lab._match_state.phase = MatchState.Phase.GAME_END
	display._process(0)
	_check(display.shown.home == 5 and display.details.balls == "3" and _valid(lab, data),
		"safe final phase releases held readout and retains complete runtime integrity")


func _empty_profiles() -> void:
	for item: String in StadiumScoreboardCatalog.IDS:
		var data: Dictionary = _fixture("straight")
		if data.is_empty() or data.fixture.is_empty():
			return
		var ledger: ClubAssetLedger = data.ledger
		var layout: Dictionary = data.fixture.layout.duplicate(true)
		var copies: Dictionary = ledger.scoreboards().copies if item == "ST-090" \
			else ledger.construction().copies
		var copy: String = Data.copy_id(copies, item)
		layout.scoreboards = [{"copy": copy, "item": item,
			"model": StadiumScoreboardModels.MODELS[item],
			"site": "BOARD-LARGE-v2" if item == "ST-040" else "BOARD-RIGHT-v2",
			"mount_profile": ""}]
		_check(Data.apply(ledger, layout), "empty-profile15 layout uses genuine draft/apply: " + item)
		data.fixture = StadiumMountedScoreboardSnapshot.fixture(
			StadiumMountedScoreboardSnapshot.capture(ledger), 47, 0)
		_check(not data.fixture.is_empty(), "all three empty profiles have paid raw15 snapshots")
		if data.fixture.is_empty():
			return
		var lab: PitchBatLab = _lab(data.fixture)
		_check(StadiumScoreboardRuntime.install_mounted_bound(lab, ledger),
			"empty-profile raw15 runtime installs: " + item)
		if lab.has_meta("stadium_property"):
			_check(_valid(lab, data), "unchanged legacy board passes complete mounted integrity: " + item)
			var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
			var visibility: StadiumMountedCameraVisibility = lab._camera_director.tracking_visibility
			_check(property.celebration == null
				and not lab._camera_director.presentation_override.is_valid()
				and not lab._camera_director._live_coverage is StadiumMountedCameraMotion
				and visibility._mounted_meshes.is_empty(),
				"empty profiles retain old motion, empty override and no center OBB cache")
			var display: StadiumScoreboardTierDisplay = property.board_display(copy)
			var old_text: String = display._labels.home.text
			display._labels.home.text = "8"
			_check(_valid(lab, data), "mapped live score text is excluded for each old board model")
			display._labels.home.text = old_text
			if item == "ST-039":
				_static_heading(lab, data, display)
			_check(StadiumLayoutSnapshot.valid(data.fixture)
				== StadiumMountedScoreboardLayout.RUNTIME_READY,
				"empty-profile15 snapshot admission follows the same explicit readiness gate")
		lab.free()
		await get_tree().process_frame


func _static_heading(lab: PitchBatLab, data: Dictionary,
	display: StadiumScoreboardTierDisplay) -> void:
	var heading: Label3D = null
	for child: Node in display.get_children():
		if child is Label3D and not display._labels.values().has(child) \
			and not display._detail_labels.values().has(child):
			heading = child
			break
	_check(heading != null, "manual board contains an actual static heading outside live maps")
	if heading == null:
		return
	var original: String = heading.text
	heading.text = ""
	_rejected(lab, data, "manual static heading blanked while live score labels remain correct")
	heading.text = original
	var index: int = heading.get_index()
	var replacement: Label3D = heading.duplicate()
	display.remove_child(heading)
	display.add_child(replacement)
	display.move_child(replacement, index)
	_rejected(lab, data, "identical replacement manual static heading")
	replacement.free()
	display.add_child(heading)
	display.move_child(heading, index)
	_check(_valid(lab, data), "original manual heading restores exact text and identity")


func _board(lab: PitchBatLab, data: Dictionary) -> Node3D:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	return property.board_objects[data.fixture.layout.scoreboards[0].copy]


func _valid(lab: PitchBatLab, data: Dictionary) -> bool:
	return StadiumScoreboardRuntime.mounted_installed(lab, data.fixture, data.ledger)


func _refused(lab: PitchBatLab, ledger: ClubAssetLedger, reason: String) -> void:
	var before: Dictionary = _field_state(lab)
	var paid: Dictionary = Data.state(ledger) if ledger != null else {}
	_check(not StadiumScoreboardRuntime.install_mounted_bound(lab, ledger), "refuse " + reason)
	_check(before == _field_state(lab), "atomic refusal preserves entire field and wiring: " + reason)
	_check(ledger == null or ClubCareer.same(paid, Data.state(ledger)),
		"atomic refusal preserves paid journal: " + reason)


func _field_state(lab: PitchBatLab) -> Dictionary:
	var nodes: Array[Dictionary] = []
	for child: Node in lab.find_children("*", "", true, false):
		var row: Dictionary = {"id": child.get_instance_id(),
			"parent": child.get_parent().get_instance_id(),
			"name": child.name, "meta": _metadata(child)}
		if child is Node3D:
			row["pose"] = child.transform
			row["visible"] = child.visible
			row["top_level"] = child.top_level
		nodes.append(row)
	return {"nodes": nodes, "meta": _metadata(lab),
		"snapshot": lab._match_state.stadium.duplicate(true) if lab._match_state != null else {},
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera": lab._camera.global_transform if lab._camera.is_inside_tree() else lab._camera.transform,
		"visibility": lab._camera_director.tracking_visibility,
		"motion": lab._camera_director._live_coverage,
		"override": lab._camera_director.presentation_override,
		"cache": StadiumMountedScoreboardIntegrity.camera_capture(
			lab._camera_director.tracking_visibility) \
			if lab._camera_director.tracking_visibility != null else {},
		"shot": lab._camera_director.shot}


func _metadata(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in node.get_meta_list():
		result[key] = node.get_meta(key)
	return result.duplicate(true)


func _rejected(lab: PitchBatLab, data: Dictionary, reason: String) -> void:
	var before: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	_check(not _valid(lab, data), "installed integrity rejects " + reason)
	_check(StadiumMountedScoreboardIntegrity.equal(before,
		lab.get_meta(StadiumScoreboardRuntime.IDENTITY)), "integrity checker does not repair certificate")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
