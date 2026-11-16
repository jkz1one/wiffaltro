extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One shared exact-copy/support/earned reward regression and two combined readable originals.

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _awards: Dictionary = {}
var _copies: Dictionary = {}
var _layout: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"STRAIGHT_REBUILD_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"shared straight fixture requires rendering and an explicit output folder"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture folder opens")
		_phase = "earned-title-history"
		StadiumPennantRewardRebuildChecks.run(_check)
		var fixture: Dictionary = StadiumPennantRewardRebuildChecks.fixture(2)
		_operands = {"ok": fixture.get("ok", false), "error": fixture.get("error", "")}
		_check(
			fixture.get("ok", false),
			"two complete synthetic championship proofs supply earned authority"
		)
		if fixture.get("ok", false):
			_awards = fixture.pennants_authority.duplicate(true)
			_ownership()
			if not _layout.is_empty():
				await _property()
				await _models()
				await _views()
	_phase = "completion"
	_check(
		_images == ["straight-hosts.png", "straight-mounts.png"],
		"two shared originals, with no per-item harness or game run"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_completed_title_proofs": true,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"earned_copies": _awards.keys(),
		"paid_copy_ids": _copies,
		"layout": _layout,
		"source_only_prior_acceptance": false
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("straight-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "finite shared evidence file opens")
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "shared evidence fully written")
		file.close()
	print(
		(
			"STRAIGHT_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _buy(item: String, quantity: int, price_version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "straight-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var entry: Dictionary = StadiumCatalog.item(item)
	var expected: int = (
		int(entry.copy_price) * quantity
		+ (0 if _paid.construction().blueprints.has(item) else int(entry.blueprint_price))
	)
	var before: int = _paid.balance()
	var result: Dictionary = _paid.commit(command)
	_operands = {
		"item": item,
		"ok": result.get("ok", false),
		"error": result.get("error", ""),
		"expected_cost": expected
	}
	_check(
		result.ok and _paid.balance() == before - expected,
		"exact Working blueprint plus copy cost " + item
	)
	_check(
		_paid.commit(command).get("replayed", false) and _paid.balance() == before - expected,
		"purchase retry cannot duplicate or recharge " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:straight-buy:%d:%d" % [revision, index])


func _place(item: String, index: int, option: int) -> void:
	var options: Array = StadiumStraightItemsUI.options(
		_layout, _paid.construction(), item, "mogul"
	)
	_check(
		option >= 0 and option < options.size(),
		"real shared selector offers required exact support for " + item
	)
	if option >= 0 and option < options.size():
		_layout = StadiumStraightItemsUI.select(
			_layout, _paid.construction(), _copies[item][index], options[option].row
		)


func _ownership() -> void:
	_phase = "shared-paid-support-chain"
	for index in range(20):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(61, _credits, _progress, _awards)
	var legacy: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	for id: String in _awards:
		var command: Dictionary = {
			"id": id,
			"rev": _paid.revision(),
			"op": "stadium_pennant",
			"earned": _awards[id].duplicate(true)
		}
		_check(
			_paid.commit(command).ok, "earned title enters storage before any eligible host or land"
		)
	var inventory: StadiumStock = _paid.construction()
	_check(
		(
			inventory.copies.size() == 5
			and not inventory.blueprints.has("ST-044")
			and _paid.balance() == 20000
		),
		"two titles are separate free earned copies, never saleable blueprints"
	)
	_check(
		StadiumLayoutSnapshot.matches(legacy, _paid),
		"reward delivery preserves the pre-grant frozen ownership prefix"
	)
	var rough: ClubAssetLedger = ClubAssetLedger.new_club(62, _credits, _progress)
	var rough_layout: Dictionary = StadiumStraightItems.upgrade(
		rough.view().stadium_active, rough.surface_owned()
	)
	_check(
		(
			rough
			. commit({"id": "rough-draft", "rev": 0, "op": "stadium_draft", "layout": rough_layout})
			. ok
		),
		"new rough-origin clubs accept the explicit host family without losing their surface"
	)
	var terrain_base: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		rough.view().stadium_active, rough.surface_owned()
	)
	var terrain: Dictionary = StadiumStraightItems.upgrade(terrain_base, rough.surface_owned())
	_check(
		(
			not terrain.is_empty()
			and StadiumStraightItems.is_terrain(terrain)
			and StadiumStraightItems.validate(terrain, rough.construction(), "backyard").ok
		),
		"playable dirt family survives host adoption without a new host or terrain grant"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "land-" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 20,
				"progress_through": 20,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(result.ok, "ordinary paid property prerequisite " + tier)
	for item: String in StadiumStraightItems.PRICES:
		_buy(
			item,
			2 if item in ["ST-029", "ST-030", "ST-031"] else 4 if item == "ST-042" else 1,
			StadiumStraightItems.PRICE_VERSION
		)
	_buy("ST-039", 2, StadiumPurchases.DISPLAY_VERSION)
	_buy("ST-043", 1, StadiumFlagItems.PRICE_VERSION)
	_buy("ST-015", 1, StadiumGroundPropsItems.PRICE_VERSION)
	_buy("ST-008", 1, StadiumGroundPropsItems.PRICE_VERSION)
	_layout = StadiumStraightItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(
		not _layout.is_empty(), "ordinary existing layout upgrades without dropping ground channels"
	)
	if _layout.is_empty():
		return
	_layout.flags = [{"copy": _copies["ST-043"][0], "site": "FLAG-GROUND-L"}]
	_layout.props = [
		{"copy": _copies["ST-008"][0], "site": "O-L1"},
		{"copy": _copies["ST-015"][0], "site": "PLANT-L1"}
	]
	_layout.displays = [{"copy": _copies["ST-039"][0], "site": "SCORE-SMALL"}]
	_place("ST-029", 0, 0)
	_place("ST-029", 1, 2)
	_place("ST-031", 0, 0)
	_place("ST-031", 1, 1)
	_place("ST-030", 0, 0)
	_place("ST-030", 1, 1)
	_place("ST-035", 0, 0)
	# Four different supported crest hosts: lower, upper, gate, original scoreboard.
	for index in range(4):
		var host: String = [
			_copies["ST-029"][0], _copies["ST-030"][0], _copies["ST-035"][0], _copies["ST-039"][0]
		][index]
		_layout = StadiumStraightItemsUI.select(
			_layout,
			_paid.construction(),
			_copies["ST-042"][index],
			{"copy": "", "host": host, "socket": "crest", "support": ""}
		)
	var ids: Array = _awards.keys()
	ids.sort()
	for index in range(2):
		_layout = StadiumStraightItemsUI.select(
			_layout,
			_paid.construction(),
			ids[index],
			{
				"copy": "",
				"host": _copies["ST-029"][index],
				"socket": "pennant",
				"support": _copies["ST-031"][index]
			}
		)
	var checked: Dictionary = StadiumStraightItems.validate(_layout, _paid.construction(), "mogul")
	_operands = {"error": checked.get("error"), "hosts": _layout.hosts, "mounts": _layout.mounts}
	_check(
		checked.ok,
		"two distinct complete structural chains and six mounted displays validate together"
	)
	if not checked.ok:
		return
	var before: int = _paid.balance()
	_check(_apply(_layout), "shared draft/apply journals the combined exact-copy field")
	_check(_paid.balance() == before, "placement never charges or grants an income benefit")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
		"ordinary snapshot binds full owned layout20 and its current journal prefix"
	)
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 61, _credits, _progress, _awards
	)
	_operands = {
		"restored": restored != null,
		"ledger_version": _paid.to_data().version,
		"revision": _paid.revision()
	}
	_check(
		restored != null and ClubCareer.same(restored.to_data(), _paid.to_data()),
		"cold JSON replay preserves exact paid supports and earned eras"
	)
	_check(
		restored != null and StadiumLayoutSnapshot.matches(snapshot, restored),
		"cold restored journal authenticates the frozen field"
	)
	for mode: String in [
		"wrong-lower",
		"wrong-concourse",
		"missing-host",
		"wrong-support",
		"duplicate-mount",
		"foreign-copy",
		"unknown-socket"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		match mode:
			"wrong-lower":
				bad.hosts[1].lower = _copies["ST-029"][1]
			"wrong-concourse":
				bad.hosts[1].concourse = _copies["ST-031"][1]
			"missing-host":
				bad.mounts[0].host = _copies["ST-039"][1]
			"wrong-support":
				for row: Dictionary in bad.mounts:
					if row.socket == "pennant":
						row.support = (
							_copies["ST-031"][1]
							if row.support == _copies["ST-031"][0]
							else _copies["ST-031"][0]
						)
			"duplicate-mount":
				bad.mounts.append(bad.mounts[0].duplicate(true))
			"foreign-copy":
				bad.mounts[0].copy = "not-owned"
			"unknown-socket":
				bad.mounts[0].socket = "random-flat-wall"
		_check(
			not StadiumStraightItems.validate(bad, _paid.construction(), "mogul").ok,
			"invalid exact support/mount rejected: " + mode
		)
	var removed: Dictionary = StadiumStraightItemsUI.select(
		_layout, _paid.construction(), _copies["ST-029"][0], {}
	)
	var preview: Dictionary = StadiumOwnedLayout.preview(
		_layout,
		removed,
		_paid.construction(),
		_paid.wall_pieces(),
		_paid.surface_owned(),
		"mogul",
		_paid.scoreboards()
	)
	var expected: Array = [
		_copies["ST-029"][0],
		_copies["ST-031"][0],
		_copies["ST-030"][0],
		_copies["ST-042"][0],
		_copies["ST-042"][1],
		ids[0]
	]
	expected.sort()
	_operands = {
		"error": preview.get("error"), "actual": preview.get("displaced"), "expected": expected
	}
	_check(
		preview.ok and preview.displaced == expected and preview.cost == 0,
		"removing one lower stores exactly its support chain and children, leaving other hosts intact"
	)
	_check(
		_apply(removed) and _apply(_layout) and _paid.balance() == before,
		"storing and free remount preserve exact receipts and historical data"
	)
	var board_removed: Dictionary = _layout.duplicate(true)
	board_removed.displays[0].copy = _copies["ST-039"][1]
	board_removed = StadiumStraightItems.prune(board_removed)
	_check(
		(
			board_removed.mounts.size() == _layout.mounts.size() - 1
			and (
				board_removed
				. mounts
				. filter(func(row: Dictionary) -> bool: return row.host == _copies["ST-039"][0])
				. is_empty()
			)
		),
		"scoreboard replacement cannot inherit the old exact-copy crest"
	)
	_check(
		StadiumLayoutSnapshot.matches(legacy, _paid),
		"old saved branch still authenticates after all new paid/free operations"
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {
			"ok": draft.get("ok", false),
			"error": draft.get("error", ""),
			"revision": _paid.revision()
		}
		return false
	var result: Dictionary = _paid.commit(
		{
			"id": "apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("mogul", layout)
		}
	)
	_operands = {
		"ok": result.get("ok", false),
		"error": result.get("error", ""),
		"revision": _paid.revision()
	}
	return result.ok


func _property() -> void:
	_phase = "combined-property"
	var root: Node3D = _world()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = property.build("mogul", _layout, _paid.construction())
	_check(built, "shared full-size property assembles all exact supported copies")
	if built:
		root.add_child(property)
		_check(
			StadiumBoundaryRuntime.assemble(property) != null,
			"unchanged complete boundary remains installed"
		)
		var checked: Dictionary = StadiumStraightItems.validate(
			_layout, _paid.construction(), "mogul"
		)
		for row: Dictionary in checked.placements:
			var model: Node3D = property.objects.get(row.copy)
			_check(
				(
					model != null
					and model.get_meta("owned_copy", "") == row.copy
					and model.position == row.position
				),
				"installed exact copy and position " + row.copy
			)
			for field: String in ["lower", "concourse", "host", "support"]:
				if row.has(field):
					_check(
						model.get_meta(field + "_copy", "!") == row[field],
						"installed support metadata binds " + field
					)
		_check(
			property.props_intact(),
			"existing furnishing contact integrity remains intact with structures"
		)
		var lab: PitchBatLab = PitchBatLab.new()
		lab._match_state = MatchState.new()
		lab._match_state.phase = MatchState.Phase.PLAY_DEAD
		lab._pitch_actor = PitchFlightActor.new()
		lab.set_meta("stadium_property", property)
		for model: Node3D in property.objects.values():
			if not model is StadiumPennantMotion:
				continue
			var motion: StadiumPennantMotion = model
			_check(
				motion.bind_match(lab._match_state, lab),
				"production pennant binds exact paid property and match"
			)
			motion._process(0.1)
			var angle: float = motion._angle
			lab._match_state.phase = MatchState.Phase.PITCH_IN_FLIGHT
			motion._process(0.1)
			_check(motion._angle == angle, "earned cloth freezes during actionable pitch")
			lab._match_state.phase = MatchState.Phase.PLAY_DEAD
			motion._process(0.1)
			_check(
				motion._angle != angle and absf(motion._angle) <= StadiumPennantMotion.MAX_ANGLE,
				"between-play cloth resumes only inside its declared envelope"
			)
			motion.set_meta("owned_copy", "wrong-copy")
			motion._process(0.1)
			_check(
				not motion.is_processing(), "wrong exact ownership permanently stops pennant motion"
			)
		lab._pitch_actor.free()
		lab.free()

		for obstacle: Dictionary in property.route_obstacles():
			_check(
				not StadiumStraightItems.HOSTS.has(_paid.construction().copies[obstacle.copy].item),
				"outside-play hosts do not become live defender obstacles"
			)
	else:
		property.free()
	await _close_view()


func _visible(root: Node3D, node: Node) -> AABB:
	var box: AABB
	var first: bool = true
	if node is MeshInstance3D or node is Label3D:
		box = root.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		first = false
	for child: Node in node.get_children():
		var part: AABB = _visible(root, child)
		if part.size.is_zero_approx():
			continue
		box = part if first else box.merge(part)
		first = false
	return box


func _models() -> void:
	_phase = "complete-model-bounds"
	var root: Node3D = _world()
	for item: String in StadiumStraightOwnedModels.ITEMS:
		var model: Node3D = StadiumStraightOwnedModels.create(
			item, _awards.values()[0] if item == "ST-044" else {}
		)
		_check(model != null, "complete supported model exists " + item)
		if model == null:
			continue
		root.add_child(model)
		await get_tree().process_frame
		if model is StadiumPennantMotion:
			_check(
				(model as StadiumPennantMotion).bind_preview(),
				"earned cloth preview binds exact final pose"
			)
			(model as StadiumPennantMotion)._process(0.1)
		var visible: AABB = _visible(model, model)
		var envelope: AABB = StadiumStraightOwnedModels.envelope(item)
		_operands = {"item": item, "visible": str(visible), "envelope": str(envelope)}
		_check(
			envelope.grow(0.01).encloses(visible),
			"all visible geometry and actual labels fit " + item
		)
		var collision: Node3D = model.get_node("Collision")
		for body: StaticBody3D in collision.get_children():
			_check(
				body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL",
				"host stays outside-play scenery " + item
			)
		if model is StadiumPennantMotion:
			var motion: StadiumPennantMotion = model
			_check(
				absf(motion._angle) <= StadiumPennantMotion.MAX_ANGLE and motion._intact(),
				"bounded cloth and era print stay joined"
			)
			motion.position.x += 1.0
			motion._process(0.1)
			_check(
				not motion.is_processing(), "detaching exact owned pose fails cloth motion quiet"
			)
		model.free()
	await _close_view()


func _views() -> void:
	_phase = "combined-readable-originals"
	var root: Node3D = _world()
	_studio(root, Vector3(-22, 20, 31), Vector3(0, 4.8, 3.0), 20)
	for item: String in ["ST-029", "ST-031", "ST-030"]:
		var model: Node3D = StadiumStraightOwnedModels.create(item)
		model.position = Vector3(-7, 0, 0)
		root.add_child(model)
	for item: String in ["ST-035", "ST-039"]:
		var model: Node3D = StadiumStraightOwnedModels.create(item)
		model.position = Vector3(5.0 if item == "ST-035" else 12.0, 0, 0)
		root.add_child(model)
		var crest: Node3D = StadiumStraightOwnedModels.create("ST-042")
		root.add_child(crest)
		crest.transform = (
			model.transform * StadiumStraightOwnedModels.socket(item, "crest").transform
		)
	for host: String in ["ST-029", "ST-030"]:
		var crest: Node3D = StadiumStraightOwnedModels.create("ST-042")
		root.add_child(crest)
		crest.transform = (
			Transform3D(Basis.IDENTITY, Vector3(-7, 0, 0))
			* StadiumStraightOwnedModels.socket(host, "crest").transform
		)
	var pennant: Node3D = StadiumStraightOwnedModels.create("ST-044", _awards.values()[0])
	root.add_child(pennant)
	pennant.transform = (
		Transform3D(Basis.IDENTITY, Vector3(-7, 0, 0))
		* StadiumStraightOwnedModels.socket("ST-029", "pennant").transform
	)
	_label(
		root,
		"STRAIGHT HOSTS | Original full-size models and grounded display sockets",
		Vector2(22, 18),
		21
	)
	_label(
		root,
		(
			"ST029 lower + ST031 concourse + ST030 upper                 ST035 gate                "
			+ " Existing ST039"
		),
		Vector2(25, 660),
		18
	)
	await _capture("straight-hosts.png")
	await _close_view()
	root = _world()
	_studio(root, Vector3(0, 0.0, 9), Vector3(0, -0.45, 0), 3.6)
	var crest: Node3D = StadiumStraightOwnedModels.create("ST-042")
	root.add_child(crest)
	crest.position = Vector3(-1.8, -0.35, 0)
	var history: Array = _awards.values()
	for index in range(2):
		var model: Node3D = StadiumStraightOwnedModels.create("ST-044", history[index])
		root.add_child(model)
		model.position = Vector3(index * 1.8 + 0.1, 0.35, 0)
	_label(
		root,
		"CLUB CREST & EARNED PENNANTS | Current identity / frozen title-era records",
		Vector2(22, 18),
		21
	)
	_label(
		root,
		(
			"ST042 mounted metal crest                  ST044 season 1                         "
			+ "ST044 season 2"
		),
		Vector2(80, 660),
		19
	)
	await _capture("straight-mounts.png")
	await _close_view()
