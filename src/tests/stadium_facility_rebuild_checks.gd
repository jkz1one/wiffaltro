extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One shared paid/cold/service-support/facility batch with two combined original views.

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
				"FACILITY_REBUILD_FAILURE "
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
		"shared facility fixture requires rendering and explicit output folder"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture folder opens")
		_ownership()
		if not _layout.is_empty():
			await _property()
			_phase = "bounded-model-geometry"
			var root: Node3D = _world()
			await StadiumFacilityGeometryRebuildChecks.run(root, _check)
			await _close_view()
			await _views()
	_phase = "completion"
	_check(
		_images == ["facilities-overview.png", "service-rooms.png"],
		"two combined facility originals without per-item harness or game runs"
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
		directory.path_join("facilities-rebuild.json"), FileAccess.WRITE
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
			"FACILITY_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _buy(item: String, quantity: int, version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "facility-buy:%d" % revision,
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
		_copies[item].append("purchase:facility-buy:%d:%d" % [revision, index])


func _place(item: String, index: int, site: String) -> void:
	var choices: Array = []
	if StadiumFacilityItems.PRICES.has(item):
		choices = StadiumFacilityItemsUI.options(_layout, _paid.construction(), item, "mogul")
	elif StadiumRoofItems.PRICES.has(item):
		choices = StadiumRoofItemsUI.options(_layout, _paid.construction(), item, "mogul")
	else:
		choices = StadiumStraightItemsUI.options(_layout, _paid.construction(), item, "mogul")
	var found: Dictionary = {}
	for option: Dictionary in choices:
		if option.row.get("site", "") == site:
			found = option.row
			break
	_check(not found.is_empty(), "shared selector offers exact " + item + " " + site)
	if found.is_empty():
		return
	if StadiumFacilityItems.PRICES.has(item):
		_layout = StadiumFacilityItemsUI.select(
			_layout, _paid.construction(), _copies[item][index], found
		)
	elif StadiumRoofItems.PRICES.has(item):
		_layout = StadiumRoofItemsUI.select(
			_layout, _paid.construction(), _copies[item][index], found
		)
	else:
		_layout = StadiumStraightItemsUI.select(
			_layout, _paid.construction(), _copies[item][index], found
		)


func _valid(layout: Dictionary, message: String) -> bool:
	var result: Dictionary = StadiumFacilityItems.validate(layout, _paid.construction(), "mogul")
	_operands = {
		"error": result.get("error", ""),
		"hosts": layout.hosts.size(),
		"roofs": layout.roofs.size(),
		"facilities": layout.facilities.size()
	}
	_check(result.ok, message)
	return result.ok


func _ownership() -> void:
	_phase = "paid-facilities-and-exact-supports"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(71, _credits, _progress)
	_legacy = StadiumLayoutSnapshot.capture(_paid)
	_buy("ST-055", 3, StadiumFacilityItems.PRICE_VERSION)
	var early: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 71, _credits, _progress
	)
	_check(
		early != null and ClubCareer.same(early.to_data(), _paid.to_data()),
		"facility-only purchase cold replays without inventing older optional headers"
	)
	_check(
		StadiumLayoutSnapshot.matches(_legacy, _paid),
		"pre-facility ownership prefix remains authentic"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var land: Dictionary = _paid.commit(
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
		_check(land.ok, "ordinary purchased land prerequisite " + tier)
	for item: String in ["ST-057", "ST-033", "ST-034", "ST-056", "ST-059"]:
		_buy(
			item,
			2 if item in ["ST-057", "ST-033", "ST-034"] else 1,
			StadiumFacilityItems.PRICE_VERSION
		)
	for item: String in ["ST-029", "ST-031", "ST-030"]:
		_buy(item, 5 if item != "ST-030" else 1, StadiumStraightItems.PRICE_VERSION)
	_buy("ST-053", 1, StadiumRoofItems.PRICE_VERSION)
	for item: String in ["ST-081", "ST-083", "ST-085", "ST-086", "ST-088", "ST-089"]:
		_buy(item, 5 if item in ["ST-081", "ST-083"] else 1, StadiumRoofItems.PRICE_VERSION)
	_layout = StadiumFacilityItems.upgrade(_paid.view().stadium_active, _paid.surface_owned())
	_check(not _layout.is_empty(), "facility wrapper adopts original field without free inventory")
	if _layout.is_empty():
		return
	_check(
		StadiumFacilityItemsUI.options(_layout, _paid.construction(), "ST-055", "mogul").is_empty(),
		"rooms stay stored until exact separately owned hosts exist"
	)
	for index in range(4):
		_place("ST-029", index, StadiumBaselineSites.SITES[index])
		_place("ST-031", index, StadiumBaselineSites.SITES[index])
	for index in range(5):
		_place("ST-081", index, StadiumCurvedLowerSites.SITES[index])
		_place("ST-083", index, StadiumCurvedLowerSites.SITES[index])
	for item: String in ["ST-085", "ST-086", "ST-088", "ST-089"]:
		_place(item, 0, "JOIN-R" if item in ["ST-085", "ST-086"] else "JOIN-L")
	for index in range(4):
		_place(
			"ST-055" if index % 2 == 0 else "ST-057", index / 2, StadiumBaselineSites.SITES[index]
		)
	_place("ST-033", 0, "SERVICE-A")
	_place("ST-033", 1, "SERVICE-B")
	_valid(_layout, "two separately paid concession copies occupy independent service pads")
	_place("ST-034", 0, "SERVICE-B")
	_place("ST-056", 0, "ANNOUNCER-A")
	_place("ST-059", 0, "TICKET-APPROACH")
	if not _valid(
		_layout, "all four complete rooms, both handed neighbors and new ticket approach coexist"
	):
		return
	var checked: Dictionary = StadiumFacilityItems.validate(_layout, _paid.construction(), "mogul")
	_check(
		checked.stored.has(_copies["ST-033"][1]) and _layout.facilities.size() == 8,
		"replacing a kiosk stores its original copy without duplicating the pad"
	)
	_check(
		_apply(_layout), "ordinary draft/apply installs complete facilities and exact support links"
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
		"shared snapshot binds facility22 and its journal prefix"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), 71, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"cold JSON replay preserves full rooms, new ticket site and every exact host"
	)
	_check(
		cold != null and StadiumLayoutSnapshot.matches(snapshot, cold),
		"cold restored layout authenticates its snapshot"
	)
	for mode: String in [
		"wrong-lower",
		"wrong-concourse",
		"curved-substitute",
		"missing-concourse",
		"unknown-site",
		"unknown-field",
		"duplicate-copy",
		"double-pad"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		var target: Dictionary = _room(bad, "BASE-L1")
		match mode:
			"wrong-lower":
				target.lower = _copies["ST-029"][1]
			"wrong-concourse":
				target.concourse = _copies["ST-031"][1]
			"curved-substitute":
				target.concourse = _copies["ST-083"][4]
			"missing-concourse":
				target.concourse = ""
			"unknown-site":
				target.site = "TICKET-YARD"
			"unknown-field":
				target["free_extension"] = true
			"duplicate-copy":
				bad.facilities.append(target.duplicate(true))
			"double-pad":
				bad.facilities.append(
					{
						"copy": _copies["ST-034"][1],
						"site": "SERVICE-A",
						"lower": "",
						"concourse": ""
					}
				)
		_check(
			not StadiumFacilityItems.validate(bad, _paid.construction(), "mogul").ok,
			"malformed facility record refuses " + mode
		)
	_dependencies()
	_exclusions()
	var rough: ClubAssetLedger = ClubAssetLedger.new_club(72, _credits, _progress)
	var terrain: Dictionary = StadiumFacilityItems.upgrade(
		StadiumSurfaceLayout.terrain_upgrade(rough.view().stadium_active, rough.surface_owned()),
		rough.surface_owned()
	)
	_check(
		(
			not terrain.is_empty()
			and StadiumFacilityItems.is_terrain(terrain)
			and StadiumFacilityItems.validate(terrain, rough.construction(), "backyard").ok
		),
		"empty facility wrapper preserves optional rough-origin terrain"
	)


func _room(layout: Dictionary, site: String) -> Dictionary:
	for entry: Dictionary in layout.facilities:
		if entry.site == site:
			return entry
	return {}


func _dependencies() -> void:
	_phase = "room-displacement-and-exact-support-removal"
	var balance: int = _paid.balance()
	var removed: Dictionary = StadiumStraightItemsUI.select(
		_layout, _paid.construction(), _copies["ST-031"][0], {}
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
	var expected: Array = [_copies["ST-031"][0], _copies["ST-055"][0], _copies["ST-089"][0]]
	expected.sort()
	_operands = {
		"error": preview.get("error", ""),
		"actual": preview.get("displaced", []),
		"expected": expected
	}
	_check(
		preview.ok and preview.displaced == expected and preview.cost == 0,
		"removing left concourse previews only its room and exact left crossing"
	)
	_check(
		_apply(removed) and _apply(_layout) and _paid.balance() == balance,
		"storage and exact free remount commit atomically through ordinary journal"
	)
	removed = StadiumStraightItemsUI.select(_layout, _paid.construction(), _copies["ST-029"][2], {})
	preview = StadiumOwnedLayout.preview(
		_layout,
		removed,
		_paid.construction(),
		_paid.wall_pieces(),
		_paid.surface_owned(),
		"mogul",
		_paid.scoreboards()
	)
	expected = [
		_copies["ST-029"][2], _copies["ST-031"][2], _copies["ST-055"][1], _copies["ST-086"][0]
	]
	expected.sort()
	_check(
		preview.ok and preview.displaced == expected and preview.cost == 0,
		"right lower removal stores only exact room/concourse/crossing dependents"
	)
	_check(
		(
			_room(removed, "BASE-L1").copy == _copies["ST-055"][0]
			and _room(removed, "TICKET-APPROACH").copy == _copies["ST-059"][0]
		),
		"unrelated rooms and complete ticket facility survive support removal"
	)
	var replacement: Dictionary = StadiumStraightItemsUI.select(
		_layout,
		_paid.construction(),
		_copies["ST-029"][4],
		{"copy": "", "site": "BASE-L1", "lower": "", "concourse": ""}
	)
	var verified: Dictionary = StadiumFacilityItems.validate(
		replacement, _paid.construction(), "mogul"
	)
	_check(
		(
			verified.ok
			and verified.stored.has(_copies["ST-055"][0])
			and verified.stored.has(_copies["ST-031"][0])
		),
		"replacement lower cannot adopt another copy's service room or concourse"
	)
	var next_room: Dictionary = _room(_layout, "BASE-L2").duplicate(true)
	replacement = StadiumFacilityItemsUI.select(
		_layout, _paid.construction(), _copies["ST-055"][2], next_room
	)
	preview = StadiumOwnedLayout.preview(
		_layout,
		replacement,
		_paid.construction(),
		_paid.wall_pieces(),
		_paid.surface_owned(),
		"mogul",
		_paid.scoreboards()
	)
	_check(
		preview.ok and preview.displaced == [_copies["ST-057"][0]] and preview.cost == 0,
		"press replaces suite with one displaced exact owned room and no detached platform stock"
	)
	_check(
		_apply(replacement) and _apply(_layout) and _paid.balance() == balance,
		"explicit replacement and restoration are free atomic operations"
	)


func _exclusions() -> void:
	_phase = "symmetric-room-upper-roof-contract"
	var lower: String = _copies["ST-029"][0]
	var concourse: String = _copies["ST-031"][0]
	var upper_row: Dictionary = {
		"copy": "", "site": "BASE-L1", "lower": lower, "concourse": concourse
	}
	var blocked: Dictionary = StadiumStraightItemsUI.select(
		_layout, _paid.construction(), _copies["ST-030"][0], upper_row
	)
	var result: Dictionary = StadiumFacilityItems.validate(blocked, _paid.construction(), "mogul")
	_check(
		(
			not result.ok
			and "Store the service room" in result.error
			and _room(blocked, "BASE-L1").copy == _copies["ST-055"][0]
		),
		"adding upper to occupied service bay refuses without silently storing room"
	)
	_check(
		(
			(
				StadiumStraightItemsUI
				. options(_layout, _paid.construction(), "ST-030", "mogul")
				. is_empty()
			)
			and (
				StadiumRoofItemsUI
				. options(_layout, _paid.construction(), "ST-053", "mogul")
				. is_empty()
			)
		),
		"all four occupied service sockets disable upper and both roof options"
	)
	var clear: Dictionary = StadiumFacilityItemsUI.select(
		_layout, _paid.construction(), _copies["ST-055"][0], {}
	)
	_check(
		StadiumStraightItemsUI.options(clear, _paid.construction(), "ST-030", "mogul").size() == 1,
		"explicit room storage re-enables that bay's upper"
	)
	for state: String in ["lower", "upper"]:
		var base_field: Dictionary = clear.duplicate(true)
		if state == "upper":
			base_field = StadiumStraightItemsUI.select(
				base_field, _paid.construction(), _copies["ST-030"][0], upper_row
			)
		var roof: Dictionary = StadiumRoofItems.row("BASE-L1")
		roof.lower = lower
		roof.roof_state = state
		if state == "upper":
			roof.concourse = concourse
			roof.upper = _copies["ST-030"][0]
		base_field = StadiumRoofItemsUI.select(
			base_field, _paid.construction(), _copies["ST-053"][0], roof
		)
		_valid(
			base_field, "stored room permits independently legal " + state + " roof configuration"
		)
		blocked = StadiumFacilityItemsUI.select(
			base_field, _paid.construction(), _copies["ST-055"][0], _room(_layout, "BASE-L1")
		)
		result = StadiumFacilityItems.validate(blocked, _paid.construction(), "mogul")
		_check(
			not result.ok and "Store the service room" in result.error,
			"room placement refuses existing " + state + " roof without adopting or storing it"
		)
		_check(
			(
				StadiumFacilityItemsUI
				. options(base_field, _paid.construction(), "ST-055", "mogul")
				. filter(func(option: Dictionary) -> bool: return option.row.site == "BASE-L1")
				. is_empty()
			),
			"roof-occupied service socket remains disabled " + state
		)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "facility-draft:%d" % _paid.revision(),
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
			"id": "facility-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("mogul", layout)
		}
	)
	_operands = {"error": result.get("error", "")}
	return result.ok


func _property() -> void:
	_phase = "shared-property-and-label-ready-authority"
	var root: Node3D = _world()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = property.build("mogul", _layout, _paid.construction())
	_check(built, "shared property assembles complete facilities, rooms and both handed joins")
	if built:
		root.add_child(property)
		await get_tree().process_frame
		_check(
			StadiumBoundaryRuntime.assemble(property) != null and property.props_intact(),
			"boundary and captured authority remain intact after Label3D meshes become ready"
		)
		var checked: Dictionary = StadiumFacilityItems.validate(
			_layout, _paid.construction(), "mogul"
		)
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
		_check(
			property.route_obstacles().is_empty(),
			"complete off-field facilities and structural layers add no live defender obstacles"
		)
		var room: Node3D = property.objects[_copies["ST-055"][0]]
		room.set_meta("concourse_copy", _copies["ST-031"][1])
		_check(
			not property.props_intact(),
			"runtime authority rejects a room rebound to another concourse copy"
		)
		room.set_meta("concourse_copy", _copies["ST-031"][0])
		_check(
			property.props_intact(),
			"restoring exact support metadata restores unchanged property authority"
		)
	else:
		property.free()
	await _close_view()


func _views() -> void:
	_phase = "two-combined-originals"
	var root: Node3D = _world()
	_studio(root, Vector3(0, 9, -19), Vector3(0, 1.4, 0), 26)
	var items: Array[String] = ["ST-033", "ST-034", "ST-056", "ST-059"]
	for index in range(items.size()):
		var model: Node3D = StadiumFacilityOwnedModels.create(items[index])
		root.add_child(model)
		model.position.x = -9 + index * 6
	_label(
		root,
		"OWNED FACILITIES | Concession • Merchandise • Announcer • Ticket approach",
		Vector2(22, 18),
		21
	)
	_label(
		root,
		(
			"Complete signs, doors, roofs and included bases • Fixed off-field sites • No income "
			+ "or gameplay effects"
		),
		Vector2(22, 677),
		17
	)
	await _capture("facilities-overview.png")
	await _close_view()
	root = _world()
	_studio(root, Vector3(23, 21, -27), Vector3(0, 5, 8), 34)
	for side: int in [-1, 1]:
		var point: Vector3 = Vector3(side * 7, 0, 0)
		for item: String in ["ST-029", "ST-031", "ST-055" if side == -1 else "ST-057"]:
			var model: Node3D = (
				StadiumFacilityOwnedModels.create(item)
				if StadiumFacilityItems.PRICES.has(item)
				else StadiumStraightOwnedModels.create(item)
			)
			root.add_child(model)
			model.position = point
	_label(
		root,
		"FULL SERVICE ROOMS | Press room and suite on exact frozen lower + concourse hosts",
		Vector2(22, 18),
		20
	)
	_label(
		root,
		(
			"Full 5.5 × 4 × 3 m rooms • Owned rear platforms, landing, stairs and grounded "
			+ "supports • Working art"
		),
		Vector2(22, 677),
		17
	)
	await _capture("service-rooms.png")
	await _close_view()
