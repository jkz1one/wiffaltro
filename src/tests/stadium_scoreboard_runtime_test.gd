extends Node3D
## Exact frozen runtime integrity, independent of final match/reward proof.

const Fixtures = preload("res://src/tests/stadium_scoreboard_game_test.gd")
var _failures: int = 0
var _fixtures: Node
var _installed: int = 0


func _ready() -> void:
	_fixtures = Fixtures.new()
	for index in range(22):
		_fixtures._credits.append(100000)
		_fixtures._progress.append({"seasons": 1, "wins": 4, "strikeouts": 2})
	_check(not StadiumScoreboardRuntime.install_bound(null), "null startup rejects")
	_check(not StadiumScoreboardRuntime.installed(null, {}), "null integrity check rejects")
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		var fixture: Dictionary = _fixture_for(shape)
		await _case(fixture, shape)
	await _template()
	_material_physics_contract()
	_check(
		_fixtures._failures == 0 and _installed == 6, "all paid fixture/runtime shapes exercised"
	)
	_fixtures.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro scoreboard runtime passed: frozen startup and exact installed-world integrity."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture_for(shape: String) -> Dictionary:
	# Reuse only the fixture helpers; this off-tree node never runs its full-game _ready.
	var failures: int = _fixtures._failures
	_fixtures._prepare(shape)
	if _fixtures._failures != failures or not StadiumScoreboardSnapshot.valid(_fixtures._fixture):
		return {}
	var ledger: ClubAssetLedger = _fixtures._ledger
	var prices: Dictionary = {
		"ST-022": StadiumWallItems.PRICE_VERSION,
		"ST-025": StadiumPurchases.NET_VERSION,
		"ST-026": StadiumPurchases.TARGET_VERSION
	}
	for item: String in prices:
		var bought: Dictionary = ledger.commit(
			_fixtures._buy(ledger, "stadium_buy", item, 19 if item == "ST-022" else 1, prices[item])
		)
		_check(bought.ok, "paid side and paired receiver stock: " + item)
		if not bought.ok:
			return {}
	var layout: Dictionary = _fixtures._fixture.layout.duplicate(true)
	var walls: Dictionary = StadiumWallLayout.propose(
		layout.walls, ledger.construction(), "left", "ST-022"
	)
	_check(walls.ok, "paid side proposal succeeds before its fields are read")
	if not walls.ok:
		return {}
	layout.walls = walls.walls
	layout.receiver = ""
	layout.target = _fixtures._copy(ledger.construction().copies, "ST-026")
	layout.net = _fixtures._copy(ledger.construction().copies, "ST-025")
	layout.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}
	]
	var drafted: Dictionary = ledger.commit(
		{"id": "runtime-draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": layout}
	)
	_check(drafted.ok, "complete runtime layout drafted")
	if not drafted.ok:
		return {}
	var applied: Dictionary = ledger.commit(
		{
			"id": "runtime-apply",
			"rev": ledger.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("mogul", layout)
		}
	)
	_check(applied.ok, "complete runtime layout applied")
	if not applied.ok:
		return {}
	return StadiumScoreboardSnapshot.fixture(StadiumScoreboardSnapshot.capture(ledger), 47, 0)


func _lab(fixture: Dictionary, managed: bool = false) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._automation = MatchAutomation.new()
	lab._managed_match = managed
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(
		(
			lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
			and not lab._pitch_actor.running
		),
		"ordinary automated _ready begins delivery before any physical pitch"
	)
	lab._match_state.stadium = fixture.duplicate(true)
	return lab


func _case(fixture: Dictionary, shape: String) -> void:
	var valid: bool = StadiumScoreboardSnapshot.valid(fixture)
	_check(valid, "valid runtime positive control: " + shape)
	if not valid:
		return
	var lab: PitchBatLab = _lab(fixture, shape == "left_loft")
	if shape == "straight":
		_guards(lab, fixture)
	lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
	lab._camera_director.cycle_paused_view()
	var shot: int = lab._camera_director.shot
	var original: Dictionary = fixture.duplicate(true)
	_check(StadiumScoreboardRuntime.install_bound(lab), "complete frozen field installs: " + shape)
	if not lab.has_meta("stadium_property"):
		lab.free()
		return
	_installed += 1
	_check(lab._camera_director.shot == shot, "installation preserves selected/paused camera")
	lab._camera_director.restore_after_pause()
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "exact installed world authenticates")
	_check(
		(
			property.get_meta("scoreboard_authoring_only", false)
			and not lab.has_meta("stadium_candidate_only")
		),
		"builder's authoring metadata is never erased"
	)
	_check(
		(
			property.find_children("BoundaryGraph", "", true, false).size() == 1
			and property.objects.size() == property.board_objects.size() + 4
		),
		"one complete boundary, two live objects, target, net and exact board models"
	)
	_check(
		lab._pitch_actor.receiver_router.get_object() is StadiumPairedReceiver,
		"real paired receiver route is reused"
	)
	_refused(lab, "duplicate runtime installation")
	_metadata_tamper(lab, fixture)
	_malformed_metadata(lab, fixture)
	_boundary_tamper(lab, fixture)
	_physics_tamper(lab, fixture)
	_board_tamper(lab, fixture)
	_wiring_tamper(lab, fixture)
	_lifecycle(lab, fixture)
	_check(
		ClubCareer.same(original, fixture), "installer and integrity checks never edit caller data"
	)
	_check(
		(
			StadiumScoreboardLayout.RUNTIME_READY
			and not StadiumAdvancedWallLayout.RUNTIME_READY
			and StadiumLayoutSnapshot.valid(fixture)
			and PhysicalMatchReport.capture(lab).is_empty()
		),
		"installed field alone is not a completed-game report or reward authority"
	)
	lab.free()
	await get_tree().process_frame


func _guards(lab: PitchBatLab, fixture: Dictionary) -> void:
	for missing: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		lab._match_state.stadium = fixture.duplicate(true)
		lab._match_state.stadium.erase(missing)
		_refused(lab, "missing frozen " + missing)
	var entry: Dictionary = fixture.duplicate(true)
	entry.version = StadiumScoreboardSnapshot.VERSION
	entry.erase("environment")
	lab._match_state.stadium = entry
	_refused(lab, "entry-only snapshot")
	for field: String in ["version", "model", "environment", "layout"]:
		var bad: Dictionary = fixture.duplicate(true)
		match field:
			"version":
				bad.version = 11
			"model":
				bad.layout.scoreboards[0].model = "manual-v1"
			"environment":
				bad.environment.mode = "night"
			"layout":
				bad.layout.version = 13
		lab._match_state.stadium = bad
		_refused(lab, "malformed frozen " + field)
	lab._match_state.stadium = fixture.duplicate(true)
	for marker: StringName in StadiumScoreboardRuntime.AUTHORING:
		lab.set_meta(marker, true)
		_refused(lab, "authoring marker " + String(marker))
		_check(lab.get_meta(marker) == true, "refusal never clears authoring evidence")
		lab.remove_meta(marker)
	var host: Node3D = lab.get_node("StarterFieldGeometry")
	host.position.x = 1
	_refused(lab, "translated host")
	host.position.x = 0
	host.scale.x = 2
	_refused(lab, "scaled host")
	host.scale.x = 1
	host.name = "MissingHost"
	_check(not StadiumScoreboardRuntime.install_bound(lab), "missing host refuses")
	host.name = "StarterFieldGeometry"
	var field: StringName = lab._field_id
	lab._field_id = &"unknown.field"
	_refused(lab, "wrong field")
	lab._field_id = field
	var state: MatchState = lab._match_state
	lab._match_state = null
	_refused(lab, "missing match")
	lab._match_state = state
	for phase: int in [
		MatchState.Phase.PITCH_IN_FLIGHT,
		MatchState.Phase.BALL_IN_PLAY,
		MatchState.Phase.PLAY_DEAD,
		MatchState.Phase.GAME_END
	]:
		state.phase = phase
		_refused(lab, "non-startup phase")
	state.phase = MatchState.Phase.PRE_PITCH
	var ball: BattedBallBody = BattedBallBody.new()
	lab._batted_ball = ball
	_refused(lab, "physical batted ball despite pre-pitch phase")
	lab._batted_ball = null
	ball.free()
	lab._release_controller.begin()
	_refused(lab, "active release gesture")
	lab._release_controller.cancel()
	for cadence: int in [
		AtBatCadenceController.State.PITCH_LIVE, AtBatCadenceController.State.DEAD_BALL_HOLD
	]:
		lab._at_bat_cadence.state = cadence as AtBatCadenceController.State
		_refused(lab, "non-startup cadence")
	lab._at_bat_cadence.stop()
	lab._match_mode = false
	_refused(lab, "mechanics-only startup")
	lab._throw_pitch()
	_check(lab._pitch_actor.running, "real mechanics pitch is physically airborne")
	lab._match_mode = true
	_refused(lab, "airborne actor with suspended pre-pitch state")
	lab._pitch_actor.reset_pitch()
	lab._automation.begin(lab)


func _metadata_tamper(lab: PitchBatLab, fixture: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	for key: StringName in [
		&"property_signature",
		&"scoreboard_layout",
		&"advanced_layout",
		&"advanced_stock",
		&"advanced_pieces",
		&"scoreboard_inventory",
		&"advanced_surface_access",
		&"scoreboard_models",
		&"scoreboard_authoring_only"
	]:
		var original: Variant = property.get_meta(key)
		property.remove_meta(key)
		_rejected_world(lab, fixture, "missing property metadata " + String(key))
		property.set_meta(key, "forged")
		_rejected_world(lab, fixture, "forged property metadata " + String(key))
		property.set_meta(key, original)
	for key: StringName in [
		&"stadium_snapshot", &"boundary_signature", StadiumScoreboardRuntime.IDENTITY
	]:
		var original: Variant = lab.get_meta(key)
		lab.remove_meta(key)
		_rejected_world(lab, fixture, "missing lab metadata " + String(key))
		lab.set_meta(key, original)
	for key: StringName in [&"advanced_stock", &"advanced_pieces", &"scoreboard_inventory"]:
		var original: Dictionary = property.get_meta(key).duplicate(true)
		var forged: Dictionary = original.duplicate(true)
		var copies: Dictionary = forged.stock.copies if key == &"advanced_pieces" else forged.copies
		copies["invented-unused-copy"] = copies.values()[0].duplicate(true)
		property.set_meta(key, forged)
		_rejected_world(lab, fixture, "unused frozen inventory surplus " + String(key))
		property.set_meta(key, original)
	var held: Dictionary = lab.get_meta("stadium_snapshot")
	lab._match_state.stadium.environment.seed += 1
	_check(
		held.environment.seed == fixture.environment.seed, "bound record is detached from request"
	)
	_rejected_world(lab, fixture, "different current match fixture")
	lab._match_state.stadium = fixture.duplicate(true)
	property.position.x += 1
	_rejected_world(lab, fixture, "moved complete property")
	property.position.x -= 1
	var tier: String = property.tier
	property.tier = "backyard"
	_rejected_world(lab, fixture, "different property tier")
	property.tier = tier
	var candidate: Dictionary = fixture.duplicate(true)
	candidate.environment.fixture += 1
	_rejected_world(lab, candidate, "different valid requested fixture")
	lab.set_meta("stadium_candidate_only", true)
	_rejected_world(lab, fixture, "candidate-marked runtime property")
	_check(
		lab.get_meta("stadium_candidate_only"), "integrity check cannot launder candidate evidence"
	)
	lab.remove_meta("stadium_candidate_only")
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "metadata restores exact integrity")


func _malformed_metadata(lab: PitchBatLab, fixture: Dictionary) -> void:
	_check(
		StadiumScoreboardRuntime._same(
			{"kind": &"owned", "paid": 160}, {"paid": 160.0, "kind": "owned"}
		),
		"JSON-like metadata normalizes names and numeric forms"
	)
	_check(
		(
			not StadiumScoreboardRuntime._same("forged", {})
			and not StadiumScoreboardRuntime._same([], false)
		),
		"unlike metadata rejects without diagnostics"
	)
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: Node3D = property.boundary
	var model: Node3D = property.board_objects.values()[0]
	for node: Node in [lab, property, boundary, model]:
		var key: StringName = (
			&"boundary_signature"
			if node == lab
			else (
				&"advanced_stock"
				if node == property
				else (
					&"scoreboard_model_version"
					if node == model
					else (
						&"wall_manifest"
						if fixture.layout.advanced_back.shape.is_empty()
						else &"advanced_manifest"
					)
				)
			)
		)
		var original: Variant = node.get_meta(key)
		for forged: Variant in [false, 3, "forged", [], {}]:
			node.set_meta(key, forged)
			_rejected_world(lab, fixture, "malformed metadata value " + String(key))
		node.set_meta(key, original)
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	for key: String in [
		"key",
		"property",
		"boundary",
		"nodes",
		"boundary_nodes",
		"objects",
		"poses",
		"items",
		"sites",
		"displays"
	]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key] = "wrong-type" if key != "key" else {}
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected_world(lab, fixture, "malformed identity member " + key)
	for key: String in ["property", "boundary"]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key] = float(identity[key])
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected_world(lab, fixture, "runtime instance IDs require exact integers")
	for key: String in ["nodes", "boundary_nodes"]:
		var bad: Dictionary = identity.duplicate(true)
		var ids: Array = []
		ids.assign(identity[key])
		ids[0] = "wrong-type"
		bad[key] = ids
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected_world(lab, fixture, "runtime identity arrays require exact integers")
	var copy: String = fixture.layout.scoreboards[0].copy
	for key: String in ["objects", "poses", "items", "sites", "displays"]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key][copy] = {}
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected_world(lab, fixture, "malformed per-copy identity " + key)
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
	var objects: Dictionary = property.objects.duplicate()
	property.objects.erase(copy)
	property.objects[17] = objects[copy]
	_rejected_world(lab, fixture, "malformed runtime object-map key")
	property.objects = objects
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture), "malformed metadata restoration is exact"
	)


func _boundary_tamper(lab: PitchBatLab, fixture: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumRecipeBoundaryBody = property.boundary
	var key: StringName = (
		&"wall_manifest" if fixture.layout.advanced_back.shape.is_empty() else &"advanced_manifest"
	)
	var original: String = boundary.get_meta(key)
	boundary.set_meta(key, "forged")
	_rejected_world(lab, fixture, "wrong actual ordinary/advanced paid manifest")
	boundary.set_meta(key, original)
	if key == &"advanced_manifest":
		var no_sides: Dictionary = StadiumWallLayout.empty()
		boundary.set_meta(
			key, StadiumAdvancedOwnedAssembly.manifest_key(fixture.layout.advanced_back, no_sides)
		)
		_rejected_world(lab, fixture, "matching advanced back with wrong paid sides")
		boundary.set_meta(key, original)
	else:
		var stock: Dictionary = property.get_meta("wall_stock")
		property.set_meta("wall_stock", {})
		_rejected_world(lab, fixture, "ordinary wall inventory differs")
		property.set_meta("wall_stock", stock)
	var graph: StadiumRecipeBoundary = boundary.graph
	boundary.graph = StadiumRecipeBoundary.create(
		"deeper_center" if fixture.layout.walls.back.get("shape", "") == "straight" else "straight"
	)
	_rejected_world(lab, fixture, "different actual boundary graph")
	boundary.graph = graph
	boundary.position.x = 1
	_rejected_world(lab, fixture, "moved boundary")
	boundary.position.x = 0
	var segment: Node = boundary.get_children()[0]
	boundary.remove_child(segment)
	_rejected_world(lab, fixture, "missing physical boundary segment")
	boundary.add_child(segment)
	var extra: Node3D = Node3D.new()
	boundary.add_child(extra)
	_rejected_world(lab, fixture, "second boundary component")
	extra.free()
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "boundary restoration authenticates")


func _physics_tamper(lab: PitchBatLab, fixture: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var body: StaticBody3D = property.boundary.find_children("*", "StaticBody3D", true, false)[0]
	_body_physics_tamper(lab, fixture, body)
	var prism: CollisionShape3D = body.find_children("*", "CollisionShape3D", true, false)[0]
	_shape_physics_tamper(lab, fixture, prism)
	var kinds: Dictionary = {"ConvexPolygonShape3D": true}
	for copy: String in property.objects:
		if property.board_objects.has(copy):
			continue
		var model: Node3D = property.objects[copy]
		var container: Node3D = model.get_node("Collision")
		var pose: Transform3D = container.transform
		container.position.x += 0.25
		_rejected_world(lab, fixture, "moved furniture collision container")
		container.transform = pose
		var part: StaticBody3D = container.find_children("*", "StaticBody3D", true, false)[0]
		_body_physics_tamper(lab, fixture, part)
		for collider: CollisionShape3D in container.find_children(
			"*", "CollisionShape3D", true, false
		):
			var kind: String = collider.shape.get_class()
			if not kinds.has(kind):
				kinds[kind] = true
				_shape_physics_tamper(lab, fixture, collider)
	_check(kinds.size() == 4, "actual placed Convex, Box, Cylinder and Capsule physics covered")
	var receiver: StadiumPairedReceiver = property.get_node("PitchReceiverPresentation")
	for copy: String in [fixture.layout.target, fixture.layout.net]:
		var model: Node3D = property.objects[copy]
		receiver.present_contact(
			{
				"copy": copy,
				"elapsed": 0.0,
				"position": model.global_position,
				"surface": "ST026_PANEL" if copy == fixture.layout.target else "ST025_NET"
			},
			"pitch"
		)
	receiver._flex(0.09)
	receiver._flex_net(0.12)
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture),
		"actual receiver contact, panel flex and net pocketing preserve frozen collision"
	)
	receiver._flex(0.18)
	receiver._flex_net(0.24)
	var identity: Dictionary = lab.get_meta(StadiumScoreboardRuntime.IDENTITY).duplicate(true)
	for key: String in ["physics", "object_physics"]:
		var bad: Dictionary = identity.duplicate(true)
		bad[key] = "malformed"
		lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
		_rejected_world(lab, fixture, "malformed static physics certificate")
	var bad: Dictionary = identity.duplicate(true)
	bad.physics.bodies[0].id = float(bad.physics.bodies[0].id)
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
	_rejected_world(lab, fixture, "static-body ID never loses integer identity")
	bad = identity.duplicate(true)
	bad.physics.bodies[0].shapes[0].resource = "wrong-type"
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, bad)
	_rejected_world(lab, fixture, "shape resource ID rejects unlike metadata")
	lab.set_meta(StadiumScoreboardRuntime.IDENTITY, identity)
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "exact static physics restoration")


func _body_physics_tamper(lab: PitchBatLab, fixture: Dictionary, body: StaticBody3D) -> void:
	var pose: Transform3D = body.transform
	body.position.x += 0.25
	_rejected_world(lab, fixture, "moved existing static collision body")
	body.transform = pose
	var changes: Dictionary = {
		"collision_layer": 0,
		"collision_mask": body.collision_mask ^ 1,
		"collision_priority": body.collision_priority + 0.5,
		"disable_mode": CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE,
		"constant_linear_velocity": Vector3.RIGHT,
		"constant_angular_velocity": Vector3.UP,
		"physics_material_override": PhysicsMaterial.new()
	}
	for key: String in changes:
		var original: Variant = body.get(key)
		body.set(key, changes[key])
		_rejected_world(lab, fixture, "altered static physical behavior " + key)
		body.set(key, original)
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "static body restores exactly")


func _shape_physics_tamper(lab: PitchBatLab, fixture: Dictionary, node: CollisionShape3D) -> void:
	var pose: Transform3D = node.transform
	node.position.y += 0.25
	_rejected_world(lab, fixture, "moved collision shape inside unchanged body")
	node.transform = pose
	node.disabled = true
	_rejected_world(lab, fixture, "disabled existing collision shape")
	node.disabled = false
	var resource: Shape3D = node.shape
	for field: String in ["margin", "custom_solver_bias"]:
		var original: float = resource.get(field)
		resource.set(field, original + 0.1)
		_rejected_world(lab, fixture, "altered shape " + field)
		resource.set(field, original)
	_shape_dimensions_tamper(lab, fixture, resource)
	node.shape = resource.duplicate()
	_rejected_world(lab, fixture, "identical replacement shape resource")
	node.shape = SphereShape3D.new()
	_rejected_world(lab, fixture, "unsupported replacement shape geometry")
	node.shape = null
	_rejected_world(lab, fixture, "missing collision shape resource")
	node.shape = resource
	var parent: Node = node.get_parent()
	parent.remove_child(node)
	_rejected_world(lab, fixture, "missing CollisionShape3D node")
	var replacement: CollisionShape3D = CollisionShape3D.new()
	replacement.shape = resource
	replacement.transform = pose
	parent.add_child(replacement)
	_rejected_world(lab, fixture, "identical replacement CollisionShape3D node")
	replacement.free()
	parent.add_child(node)
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture), "exact shape/node/resource restoration"
	)


func _shape_dimensions_tamper(lab: PitchBatLab, fixture: Dictionary, shape: Shape3D) -> void:
	if shape is ConvexPolygonShape3D:
		var original: PackedVector3Array = shape.points.duplicate()
		var changed: PackedVector3Array = original.duplicate()
		changed[0].x += 0.25
		shape.points = changed
		_rejected_world(lab, fixture, "altered convex prism point")
		shape.points = original
	elif shape is BoxShape3D:
		var original: Vector3 = shape.size
		shape.size += Vector3(0.25, 0, 0)
		_rejected_world(lab, fixture, "altered box dimensions")
		shape.size = original
	else:
		for key: String in ["radius", "height"]:
			var original: float = shape.get(key)
			shape.set(key, original * 0.9)
			_rejected_world(lab, fixture, "altered round-shape " + key)
			shape.set(key, original)


func _material_physics_contract() -> void:
	var group: Node3D = Node3D.new()
	var body: StaticBody3D = StaticBody3D.new()
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	body.physics_material_override = PhysicsMaterial.new()
	body.add_child(collider)
	group.add_child(body)
	add_child(group)
	var frozen: Dictionary = StadiumScoreboardRuntime._boundary_physics(group)
	_check(
		not frozen.is_empty() and StadiumScoreboardRuntime._physics_matches(group, frozen),
		"complete explicit Box/material physical control"
	)
	var material: PhysicsMaterial = body.physics_material_override
	for row: Array in [["friction", 0.3], ["bounce", 0.4], ["rough", true], ["absorbent", true]]:
		var original: Variant = material.get(row[0])
		material.set(row[0], row[1])
		_check(
			not StadiumScoreboardRuntime._physics_matches(group, frozen),
			"changed existing physics material value " + row[0]
		)
		material.set(row[0], original)
	body.physics_material_override = material.duplicate()
	_check(
		not StadiumScoreboardRuntime._physics_matches(group, frozen),
		"identical replacement physics material resource"
	)
	body.physics_material_override = material
	_check(
		StadiumScoreboardRuntime._physics_matches(group, frozen),
		"physics material restores exactly"
	)
	group.free()


func _board_tamper(lab: PitchBatLab, fixture: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	for row: Dictionary in fixture.layout.scoreboards:
		var model: Node3D = property.board_objects[row.copy]
		for key: StringName in [
			&"owned_copy",
			&"stadium_item",
			&"scoreboard_owned_model",
			&"site",
			&"surface_role",
			&"scoreboard_candidate",
			&"scoreboard_model_version"
		]:
			var original: Variant = model.get_meta(key)
			model.remove_meta(key)
			_rejected_world(lab, fixture, "missing board " + String(key))
			model.set_meta(key, "forged")
			_rejected_world(lab, fixture, "wrong board " + String(key))
			model.set_meta(key, original)
		var pose: Transform3D = model.transform
		model.position.x += 1
		_rejected_world(lab, fixture, "board moved from exact socket")
		model.transform = pose
		model.scale *= 0.5
		_rejected_world(lab, fixture, "board envelope changed")
		model.transform = pose
		property.board_objects.erase(row.copy)
		_rejected_world(lab, fixture, "missing board map entry")
		property.board_objects[row.copy] = model
		property.objects.erase(row.copy)
		_rejected_world(lab, fixture, "missing complete-property map entry")
		property.objects[row.copy] = model
		property.remove_child(model)
		_rejected_world(lab, fixture, "detached board still in maps")
		var replacement: Node3D = StadiumScoreboardModels.create(row.item, row.model)
		replacement.transform = model.transform
		for key: StringName in model.get_meta_list():
			replacement.set_meta(key, model.get_meta(key))
		property.add_child(replacement)
		property.objects[row.copy] = replacement
		property.board_objects[row.copy] = replacement
		replacement.get_node("Visual/ScoreDisplay").bind_match(lab._match_state)
		_rejected_world(
			lab, fixture, "exact-looking replacement cannot impersonate installed board"
		)
		replacement.free()
		property.add_child(model)
		property.objects[row.copy] = model
		property.board_objects[row.copy] = model
		var collision: StaticBody3D = StaticBody3D.new()
		model.add_child(collision)
		_rejected_world(lab, fixture, "decorative board acquired a collision target")
		collision.free()
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		var tier: String = display.tier
		display.tier = "unknown"
		_rejected_world(lab, fixture, "wrong live readout tier")
		display.tier = tier
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture), "all original boards restore integrity"
	)


func _wiring_tamper(lab: PitchBatLab, fixture: Dictionary) -> void:
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = StadiumBoundaryObserver.observe
	_rejected_world(lab, fixture, "valid but wrong height/boundary observer")
	lab._ball_play_resolver.segment_observer = observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = StadiumBoundaryGraph.clip
	_rejected_world(lab, fixture, "valid but wrong defender clip")
	lab._primary_fielder.stadium_boundary_clip = clip
	var receiver: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	_rejected_world(lab, fixture, "missing receiver router")
	lab._pitch_actor.receiver_router = receiver
	var camera: BallTrackingVisibility = lab._camera_director.tracking_visibility
	lab._camera_director.tracking_visibility = BallTrackingVisibility.new()
	_rejected_world(lab, fixture, "unconfigured tracking camera")
	lab._camera_director.tracking_visibility = camera
	var model: Node3D = property.board_objects.values()[0]
	model.get_node("Visual/ScoreDisplay").bind_match(null)
	_rejected_world(lab, fixture, "unbound physical readout")
	property.rebind_displays(lab._match_state)
	_check(StadiumScoreboardRuntime.installed(lab, fixture), "original runtime wiring restores")


func _lifecycle(lab: PitchBatLab, fixture: Dictionary) -> void:
	lab._managed_match = false
	lab._configured_match = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD"
	)
	lab._configured_match.stadium = fixture.duplicate(true)
	lab._start_new_match()
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture), "ordinary restart automatically rebinds"
	)
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	lab._match_state.home_team.runs = 4
	for model: Node3D in property.board_objects.values():
		model.get_node("Visual/ScoreDisplay")._process(0)
	lab._match_state.phase = MatchState.Phase.BALL_IN_PLAY
	lab._match_state.home_team.runs = 5
	for model: Node3D in property.board_objects.values():
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		display._process(0)
		_check(display.shown.home == 4, "runtime board holds complete live-play readout")
	lab._match_state.phase = MatchState.Phase.GAME_END
	for model: Node3D in property.board_objects.values():
		var display: StadiumScoreboardTierDisplay = model.get_node("Visual/ScoreDisplay")
		display._process(0)
		_check(display.shown.home == 5, "runtime board reaches safe final match data")
	_check(
		StadiumScoreboardRuntime.installed(lab, fixture),
		"integrity is phase independent after install"
	)


func _template() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(19, [], [])
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)
		)
	)
	var drafted: Dictionary = ledger.commit(
		{"id": "template-draft", "rev": 0, "op": "stadium_draft", "layout": layout}
	)
	_check(drafted.ok, "empty three-inventory template drafts")
	if not drafted.ok:
		return
	var applied: Dictionary = ledger.commit(
		{
			"id": "template-apply",
			"rev": 1,
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("backyard", layout)
		}
	)
	_check(applied.ok, "empty three-inventory template applies")
	if not applied.ok:
		return
	var fixture: Dictionary = StadiumScoreboardSnapshot.fixture(
		StadiumScoreboardSnapshot.capture(ledger), 47, 0
	)
	_check(StadiumScoreboardSnapshot.valid(fixture), "valid empty template fixture")
	if fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(fixture, true)
	_check(
		(
			StadiumScoreboardRuntime.install_bound(lab)
			and StadiumScoreboardRuntime.installed(lab, fixture)
		),
		"empty template frozen runtime installs"
	)
	if lab.has_meta("stadium_property"):
		_installed += 1
		var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
		_check(
			property.boundary is StadiumBoundaryPrototype and property.board_objects.is_empty(),
			"no paid wall or board is invented for the ordinary template"
		)
	lab.free()
	await get_tree().process_frame


func _refused(lab: PitchBatLab, reason: String) -> void:
	var before: Dictionary = _field_state(lab)
	_check(not StadiumScoreboardRuntime.install_bound(lab), "reject " + reason)
	_check(before == _field_state(lab), "refusal preserves complete field and wiring: " + reason)


func _field_state(lab: PitchBatLab) -> Dictionary:
	var nodes: Array[int] = []
	for child: Node in lab.get_node("StarterFieldGeometry").find_children("*", "", true, false):
		nodes.append(child.get_instance_id())
	return {
		"nodes": nodes,
		"metadata": lab.get_meta_list(),
		"property": lab.get_meta("stadium_property") if lab.has_meta("stadium_property") else null,
		"observer": lab._ball_play_resolver.segment_observer,
		"receiver": lab._pitch_actor.receiver_router,
		"clip": lab._primary_fielder.stadium_boundary_clip,
		"obstacles": lab._primary_fielder.stadium_obstacles.duplicate(true),
		"camera": lab._camera.global_transform,
		"visibility": lab._camera_director.tracking_visibility,
		"shot": lab._camera_director.shot
	}


func _rejected_world(lab: PitchBatLab, fixture: Dictionary, reason: String) -> void:
	_check(not StadiumScoreboardRuntime.installed(lab, fixture), "integrity rejects " + reason)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
