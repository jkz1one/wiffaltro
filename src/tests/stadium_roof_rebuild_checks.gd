extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One shared paid/cold/host-removal/roof-remount batch with two combined original views.

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _layout: Dictionary = {}
var _legacy: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"ROOF_REBUILD_FAILURE "
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
		"shared roof fixture requires rendering and explicit output folder"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture folder opens")
		_ownership()
		if not _layout.is_empty():
			await _property()
			_phase = "bounded-model-geometry"
			var root: Node3D = _world()
			await StadiumRoofGeometryRebuildChecks.run(root, _check)
			await _close_view()
			await _views()
	_phase = "completion"
	_check(
		_images == ["roof-states.png", "handed-transitions.png"],
		"two combined originals without per-item harness or game runs"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"paid_copy_ids": _copies,
		"layout": _layout,
		"source_only_prior_acceptance": false
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("roof-rebuild.json"), FileAccess.WRITE
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
			"ROOF_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _buy(item: String, quantity: int, version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "roof-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var entry: Dictionary = StadiumCatalog.item(item)
	var cost: int = (
		int(entry.copy_price) * quantity
		+ (0 if _paid.construction().blueprints.has(item) else int(entry.blueprint_price))
	)
	var before: int = _paid.balance()
	var result: Dictionary = _paid.commit(command)
	_operands = {
		"item": item,
		"ok": result.get("ok", false),
		"error": result.get("error", ""),
		"expected_cost": cost
	}
	_check(
		result.ok and _paid.balance() == before - cost,
		"unchanged Working blueprint and copy purchase " + item
	)
	_check(
		_paid.commit(command).get("replayed", false) and _paid.balance() == before - cost,
		"purchase retry neither duplicates nor charges " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:roof-buy:%d:%d" % [revision, index])


func _place(item: String, index: int, site: String, state: String = "") -> void:
	var choices: Array = (
		StadiumRoofItemsUI.options(_layout, _paid.construction(), item, "mogul")
		if StadiumRoofItems.PRICES.has(item)
		else StadiumStraightItemsUI.options(_layout, _paid.construction(), item, "mogul")
	)
	var found: Dictionary = {}
	for option: Dictionary in choices:
		if option.row.get("site", "") == site and option.row.get("roof_state", "") == state:
			found = option.row
			break
	_check(not found.is_empty(), "shared selector offers exact " + item + " " + site + " " + state)
	if found.is_empty():
		return
	_layout = (
		StadiumRoofItemsUI.select(_layout, _paid.construction(), _copies[item][index], found)
		if StadiumRoofItems.PRICES.has(item)
		else StadiumStraightItemsUI.select(
			_layout, _paid.construction(), _copies[item][index], found
		)
	)


func _valid(layout: Dictionary, message: String) -> bool:
	var result: Dictionary = StadiumRoofItems.validate(layout, _paid.construction(), "mogul")
	_operands = {
		"error": result.get("error", ""),
		"host_count": layout.hosts.size(),
		"roof_count": layout.roofs.size()
	}
	_check(result.ok, message)
	return result.ok


func _ownership() -> void:
	_phase = "paid-ownership-and-exact-hosts"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(71, _credits, _progress)
	_legacy = StadiumLayoutSnapshot.capture(_paid)
	# Roof purchase alone exercises ledger29 without inventing optional older family headers.
	_buy("ST-084", 5, StadiumRoofItems.PRICE_VERSION)
	var early: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 71, _credits, _progress
	)
	_check(
		early != null and ClubCareer.same(early.to_data(), _paid.to_data()),
		"roof-only purchase cold replays optional ledger headers"
	)
	_check(
		StadiumLayoutSnapshot.matches(_legacy, _paid),
		"pre-roof ownership prefix still authenticates"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "land-" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(result.ok, "ordinary purchased land prerequisite " + tier)
	for item: String in StadiumRoofItems.PRICES:
		if item == "ST-084":
			continue
		_buy(
			item,
			5 if item in ["ST-081", "ST-083", "ST-082"] else 4 if item == "ST-053" else 1,
			StadiumRoofItems.PRICE_VERSION
		)
	for item: String in ["ST-029", "ST-031", "ST-030", "ST-042"]:
		_buy(item, 4 if item != "ST-042" else 2, StadiumStraightItems.PRICE_VERSION)
	_buy("ST-039", 1, StadiumPurchases.DISPLAY_VERSION)
	_layout = StadiumRoofItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(not _layout.is_empty(), "roof family adopts the original field without grants")
	if _layout.is_empty():
		return
	# Both independently complete handed lowers remain legal with every neighbor absent.
	_place("ST-085", 0, "JOIN-R")
	_place("ST-088", 0, "JOIN-L")
	_valid(_layout, "both independently owned handed lowers need no neighboring stands")
	for index in range(4):
		_place("ST-029", index, StadiumBaselineSites.SITES[index])
		_place("ST-031", index, StadiumBaselineSites.SITES[index])
	for index in range(5):
		_place("ST-081", index, StadiumCurvedLowerSites.SITES[index])
		_place("ST-083", index, StadiumCurvedLowerSites.SITES[index])
		_place("ST-084", index, StadiumCurvedLowerSites.SITES[index], "lower")
	_valid(
		_layout,
		"all five independent adjacent lower canopies coexist with their own lowers and concourses"
	)
	var lower_state: Dictionary = _layout.duplicate(true)
	# Existing same owned canopy must be stored, then remounted over its newly purchased upper.
	_place("ST-082", 2, "BOWL-03")
	var blocked: Dictionary = StadiumRoofItems.validate(_layout, _paid.construction(), "mogul")
	_check(
		not blocked.ok and "Remount this same canopy" in blocked.error,
		"adding an upper cannot silently move or store its mounted lower roof"
	)
	_layout = lower_state
	var before: int = _paid.balance()
	for index: int in [1, 2, 3]:
		_layout = StadiumRoofItemsUI.select(
			_layout, _paid.construction(), _copies["ST-084"][index], {}
		)
		_place("ST-082", index, StadiumCurvedLowerSites.SITES[index])
		_place("ST-084", index, StadiumCurvedLowerSites.SITES[index], "upper")
	for index in range(4):
		if index in [0, 2]:
			_place("ST-030", index, StadiumBaselineSites.SITES[index])
		_place(
			"ST-053",
			index,
			StadiumBaselineSites.SITES[index],
			"upper" if index in [0, 2] else "lower"
		)
	_place("ST-086", 0, "JOIN-R")
	_place("ST-089", 0, "JOIN-L")
	if not _valid(
		_layout,
		"both exact five-host transition concourses and adjacent mixed-height roofs coexist"
	):
		return
	_check(_paid.balance() == before, "roof storage and same-copy lower-to-upper remount are free")
	_check(
		_apply(_layout), "shared draft/apply journals all curved, handed and straight roof copies"
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
		"shared snapshot binds full roof21 and journal prefix"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 71, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"cold JSON replay preserves both hands, named neighbors and roof states"
	)
	_check(
		cold != null and StadiumLayoutSnapshot.matches(snapshot, cold),
		"cold replay authenticates the exact applied roof field"
	)
	for mode: String in [
		"wrong-hand",
		"wrong-base-site",
		"wrong-bowl-copy",
		"wrong-upper",
		"duplicate-copy",
		"unknown-state",
		"unknown-field"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		var target: Dictionary
		for candidate: Dictionary in bad.roofs:
			if _paid.construction().copies[candidate.copy].item == "ST-086":
				target = candidate
		match mode:
			"wrong-hand":
				target.site = "JOIN-L"
			"wrong-base-site":
				target.base = _copies["ST-029"][3]
			"wrong-bowl-copy":
				target.bowl = _copies["ST-081"][4]
			"wrong-upper":
				for entry: Dictionary in bad.roofs:
					if entry.copy == _copies["ST-084"][2]:
						entry.upper = _copies["ST-082"][1]
			"duplicate-copy":
				bad.roofs.append(bad.roofs[0].duplicate(true))
			"unknown-state":
				target.roof_state = "canopy"
			"unknown-field":
				target["mirror"] = true
		_check(
			not StadiumRoofItems.validate(bad, _paid.construction(), "mogul").ok,
			"malformed exact support record rejects " + mode
		)
	var removed: Dictionary = StadiumStraightItemsUI.select(
		_layout, _paid.construction(), _copies["ST-029"][2], {}
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
		_copies["ST-029"][2],
		_copies["ST-031"][2],
		_copies["ST-030"][2],
		_copies["ST-053"][2],
		_copies["ST-086"][0]
	]
	expected.sort()
	_operands = {
		"error": preview.get("error", ""), "actual": preview.get("displaced"), "expected": expected
	}
	_check(
		preview.ok and preview.displaced == expected and preview.cost == 0,
		"BASE-R1 removal stores only its exact dependent chain and right concourse"
	)
	_check(
		(
			(
				(
					removed
					. roofs
					. filter(
						func(entry: Dictionary) -> bool: return entry.copy == _copies["ST-085"][0]
					)
					. size()
				)
				== 1
			)
			and (
				(
					removed
					. roofs
					. filter(
						func(entry: Dictionary) -> bool: return entry.copy == _copies["ST-089"][0]
					)
					. size()
				)
				== 1
			)
		),
		"right independent lower and entire unrelated left transition survive support removal"
	)
	_check(
		_apply(removed) and _apply(_layout) and _paid.balance() == before,
		"dependent storage and free remount survive ordinary journal operations"
	)
	var bowl_removed: Dictionary = StadiumRoofItemsUI.select(
		_layout, _paid.construction(), _copies["ST-081"][0], {}
	)
	var bowl_check: Dictionary = StadiumRoofItems.validate(
		bowl_removed, _paid.construction(), "mogul"
	)
	_check(
		(
			bowl_check.ok
			and bowl_check.stored.has(_copies["ST-083"][0])
			and bowl_check.stored.has(_copies["ST-084"][0])
			and bowl_check.stored.has(_copies["ST-086"][0])
		),
		"BOWL-01 removal stores exact curved descendants and right crossing"
	)
	var left_removed: Dictionary = StadiumStraightItemsUI.select(
		_layout, _paid.construction(), _copies["ST-031"][0], {}
	)
	var left_checked: Dictionary = StadiumRoofItems.validate(
		left_removed, _paid.construction(), "mogul"
	)
	_check(
		(
			left_checked.ok
			and left_checked.stored.has(_copies["ST-089"][0])
			and left_checked.stored.has(_copies["ST-053"][0])
			and not left_checked.stored.has(_copies["ST-088"][0])
			and not left_checked.stored.has(_copies["ST-086"][0])
		),
		(
			"BASE-L1 concourse removal stores left crossing and roof only, preserving independent "
			+ "lower and right hand"
		)
	)
	var left_bowl: Dictionary = StadiumRoofItemsUI.select(
		_layout, _paid.construction(), _copies["ST-083"][4], {}
	)
	var left_bowl_checked: Dictionary = StadiumRoofItems.validate(
		left_bowl, _paid.construction(), "mogul"
	)
	_check(
		(
			left_bowl_checked.ok
			and left_bowl_checked.stored.has(_copies["ST-089"][0])
			and not left_bowl_checked.stored.has(_copies["ST-084"][4])
		),
		"BOWL-05 concourse removal stores left crossing but keeps independently supported lower canopy"
	)
	var replace: Dictionary = StadiumRoofItemsUI.select(
		bowl_removed, _paid.construction(), _copies["ST-081"][1], StadiumRoofItems.row("BOWL-01")
	)
	_check(
		(
			replace
			. roofs
			. filter(func(entry: Dictionary) -> bool: return entry.copy == _copies["ST-086"][0])
			. is_empty()
		),
		"replacement lower never adopts old exact-copy transition descendants"
	)
	_check(
		StadiumLayoutSnapshot.matches(_legacy, _paid),
		"old frozen snapshot survives all new family operations"
	)
	_crests()
	var rough: ClubAssetLedger = ClubAssetLedger.new_club(72, _credits, _progress)
	var terrain: Dictionary = StadiumRoofItems.upgrade(
		StadiumSurfaceLayout.terrain_upgrade(rough.view().stadium_active, rough.surface_owned()),
		rough.surface_owned()
	)
	_check(
		(
			not terrain.is_empty()
			and StadiumRoofItems.is_terrain(terrain)
			and StadiumRoofItems.validate(terrain, rough.construction(), "backyard").ok
		),
		"empty roof wrapper preserves optional rough-origin terrain without inventing structures"
	)


func _crests() -> void:
	_phase = "obstructed-lower-crest-socket"
	var field: Dictionary = _layout.duplicate(true)
	# Right inner bay's left facade faces the independently placed right outer bay.
	field = StadiumStraightItemsUI.select(field, _paid.construction(), _copies["ST-029"][3], {})
	var crest_row: Dictionary = {
		"copy": "", "host": _copies["ST-029"][2], "socket": "crest", "support": ""
	}
	field = StadiumStraightItemsUI.select(
		field, _paid.construction(), _copies["ST-042"][0], crest_row
	)
	_valid(field, "unobstructed exact lower facade accepts its owned crest")
	var adjacent: Dictionary = StadiumStraightItemsUI.select(
		field,
		_paid.construction(),
		_copies["ST-029"][3],
		{"copy": "", "site": "BASE-R2", "lower": "", "concourse": ""}
	)
	var conflict: Dictionary = StadiumRoofItems.validate(adjacent, _paid.construction(), "mogul")
	_check(
		not conflict.ok and "Store this crest first" in conflict.error,
		"placing neighboring bay refuses with clear store-this-crest-first message"
	)
	_check(
		adjacent.mounts.size() == field.mounts.size(),
		"neighbor selection never silently stores the crest"
	)
	field = StadiumStraightItemsUI.select(field, _paid.construction(), _copies["ST-042"][0], {})
	field = StadiumStraightItemsUI.select(
		field,
		_paid.construction(),
		_copies["ST-029"][3],
		{"copy": "", "site": "BASE-R2", "lower": "", "concourse": ""}
	)
	_valid(field, "explicit crest storage permits independent neighboring bay")
	var choices: Array = StadiumStraightItemsUI.options(
		field, _paid.construction(), "ST-042", "mogul"
	)
	_check(
		(
			choices
			. filter(
				func(option: Dictionary) -> bool: return option.row.host == _copies["ST-029"][2]
			)
			. is_empty()
		),
		"occupied lower socket stays disabled while neighboring bay exists"
	)
	_check(
		(
			(
				choices
				. filter(
					func(option: Dictionary) -> bool: return option.row.host == _copies["ST-030"][2]
				)
				. size()
			)
			== 1
		),
		"unobstructed upper crest host remains available"
	)
	field = StadiumStraightItemsUI.select(field, _paid.construction(), _copies["ST-029"][3], {})
	choices = StadiumStraightItemsUI.options(field, _paid.construction(), "ST-042", "mogul")
	_check(
		(
			(
				choices
				. filter(
					func(option: Dictionary) -> bool: return option.row.host == _copies["ST-029"][2]
				)
				. size()
			)
			== 1
		),
		"clearing neighbor restores that exact lower socket"
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "roof-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"error": draft.get("error", "")}
		return false
	var result: Dictionary = _paid.commit(
		{
			"id": "roof-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("mogul", layout)
		}
	)
	_operands = {"error": result.get("error", "")}
	return result.ok


func _property() -> void:
	_phase = "shared-runtime-property"
	var root: Node3D = _world()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = property.build("mogul", _layout, _paid.construction())
	_check(built, "shared property assembles full owned mixed-height and both-handed field")
	if built:
		root.add_child(property)
		_check(
			StadiumBoundaryRuntime.assemble(property) != null and property.props_intact(),
			"unchanged complete boundary and property integrity remain intact"
		)
		var checked: Dictionary = StadiumRoofItems.validate(_layout, _paid.construction(), "mogul")
		for entry: Dictionary in checked.placements:
			var model: Node3D = property.objects.get(entry.copy)
			_check(
				(
					model != null
					and model.get_meta("owned_copy", "") == entry.copy
					and model.position == entry.position
				),
				"runtime exact owned copy and canonical pose " + entry.copy
			)
			for field: String in StadiumRoofItems.SUPPORTS:
				if entry.has(field):
					_check(
						model.get_meta(field + "_copy", "!") == entry[field],
						"runtime retains exact support " + field
					)
		for obstacle: Dictionary in property.route_obstacles():
			_check(
				not StadiumRoofItems.PRICES.has(_paid.construction().copies[obstacle.copy].item),
				"outside-play roofs and joins never become live defender obstacles"
			)
	else:
		property.free()
	await _close_view()


func _views() -> void:
	_phase = "combined-original-views"
	var root: Node3D = _world()
	_studio(root, Vector3(0, 26, -34), Vector3(0, 4.8, 12), 46)
	# Two adjacent owned lower bays and two adjacent upper bays, same unscaled models.
	for group in range(2):
		for side: int in [-1, 1]:
			var transform: Transform3D = Transform3D(
				Basis(Vector3.UP, deg_to_rad(side * 15.0)), Vector3(-17 if group == 0 else 17, 0, 0)
			)
			for item: String in (
				["ST-081", "ST-084"] if group == 0 else ["ST-081", "ST-083", "ST-082", "ST-084"]
			):
				var model: Node3D = StadiumRoofOwnedModels.create(
					item, "lower" if group == 0 else "upper"
				)
				root.add_child(model)
				model.transform = transform
	for index in range(4):
		var point: Vector3 = Vector3(-9 + index * 6, 0, -8)
		for item: String in (
			["ST-029", "ST-053"] if index in [0, 3] else ["ST-029", "ST-031", "ST-030", "ST-053"]
		):
			var model: Node3D = (
				StadiumRoofOwnedModels.create(item, "lower" if index in [0, 3] else "upper")
				if item == "ST-053"
				else StadiumStraightOwnedModels.create(item)
			)
			root.add_child(model)
			model.position = point
	_label(
		root,
		"OWNED ROOF STATES | Adjacent independent curved bays + mixed straight roofs",
		Vector2(22, 18),
		21
	)
	_label(
		root,
		(
			"Same ST084 copy remounts lower / upper • Full-size surviving supports • Working "
			+ "geometry, final art review pending"
		),
		Vector2(22, 677),
		17
	)
	await _capture("roof-states.png")
	await _close_view()
	root = _world()
	_studio(root, Vector3(0, 25, 26), Vector3(0, 4.0, -9), 46)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	if property.build("mogul", _layout, _paid.construction()):
		root.add_child(property)
	else:
		property.free()
		_check(false, "both-handed original uses actual shared owned property")
	_label(
		root,
		"BOTH HANDED JOINS | Exact BASE-L1 / BOWL-05 and BASE-R1 / BOWL-01 support chains",
		Vector2(22, 18),
		20
	)
	_label(
		root,
		(
			"ST088 + ST089 on left • ST085 + ST086 on right • Both neighbors remain separately "
			+ "owned • No game or final-art acceptance"
		),
		Vector2(22, 677),
		16
	)
	await _capture("handed-transitions.png")
	await _close_view()
