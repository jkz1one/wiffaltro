extends Node3D
## Synthetic trusted career rows isolate land accounting; UI tests use actual career saves.

var _failures: int = 0


func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(20):
		credits.append(500)
		progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(16, credits, progress)
	var placed: Dictionary = StadiumStarterLayout.empty()
	placed.receiver = "starter-v1:ST-079"
	placed.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	_check(ledger.commit({"id": "initial-draft", "rev": 0, "op": "stadium_draft",
		"layout": placed}).ok, "stage existing exact owned items before expansion")
	_check(ledger.commit({"id": "initial-apply", "rev": 1, "op": "stadium_apply",
		"layout": placed, "geometry": StadiumProperty.signature("backyard")}).ok,
		"apply existing receiver and live cone before expanding")
	var initial: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var stock: Dictionary = ledger.construction().to_data()
	_check(StadiumLand.quote("backyard", "club", {"seasons": 99, "wins": 99}).ok == false,
		"higher tiers require the previous property")
	_check(not StadiumLand.quote("backyard", "expanded", {"seasons": 3, "wins": 10}).ok
		and not StadiumLand.quote("backyard", "expanded", {"seasons": 4, "wins": 9}).ok,
		"both exact completed-season and regular-win gates are required")
	var total: int = 0
	for tier: String in ["expanded", "club", "mogul"]:
		var command: Dictionary = _buy(ledger, tier)
		var before: Dictionary = ledger.to_data()
		var quote: Dictionary = ledger.preview(command)
		_check(quote.ok and ledger.to_data() == before, "land quote is pure")
		total += int(StadiumCatalog.LAND[tier].price)
		_check(ledger.commit(command).ok and ledger.balance() == 10000 - total,
			"only the incremental land price is charged")
		_check(ledger.commit(command).replayed and ledger.balance() == 10000 - total,
			"same expansion request cannot charge twice")
		_check(ledger.construction().to_data() == stock, "no free or consumed physical copies")
		_check(ledger.view().stadium_active == placed and ledger.view().stadium_draft == placed,
			"each expansion preserves exact active and draft placements without moving them")
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		_check(snapshot.version == 4 and snapshot.tier == tier
			and StadiumLayoutSnapshot.matches(snapshot, ledger), "owned expanded tier freezes exactly")
		_check(StadiumLayoutSnapshot.matches(initial, ledger), "old Backyard stays bound to its prefix")
		_geometry(tier)
	_check(total == 6400 and ledger.view().land == "mogul", "exact cumulative land price")
	_check(StadiumLayoutSnapshot.capture(ledger, false).is_empty(),
		"expanded property cannot impersonate an old backwall-only profile")
	_check(not ledger.commit(_buy(ledger, "expanded")).ok, "no land downgrade or repeat purchase")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 16, credits, progress)
	_check(restored != null and ClubCareer.same(restored.view(), ledger.view()),
		"full ordered land replay through JSON numeric conversion")
	var bad: Dictionary = ledger.to_data()
	bad.version = 6
	bad.erase("land_catalog")
	bad.erase("style_catalog")
	bad.erase("appearance_catalog")
	bad.erase("display_catalog")
	bad.erase("display_layout_catalog")
	bad.erase("ground_catalog")
	bad.erase("ground_layout_catalog")
	bad.erase("bleacher_catalog")
	bad.erase("bleacher_layout_catalog")
	bad.erase("target_catalog")
	bad.erase("target_layout_catalog")
	bad.erase("net_catalog")
	bad.erase("net_layout_catalog")
	bad.erase("light_catalog")
	bad.erase("light_layout_catalog")
	bad.erase("infield_catalog")
	bad.erase("infield_layout_catalog")
	bad.erase("wall_catalog")
	bad.erase("wall_layout_catalog")
	bad.erase("surface_catalog")
	bad.erase("surface_layout_catalog")
	bad.erase("surface_origin")
	bad.erase("wall_piece_catalog")
	bad.erase("advanced_layout_catalog")
	bad.erase("scoreboard_catalog")
	bad.erase("scoreboard_layout_catalog")
	bad.erase("mounted_scoreboard_layout_catalog")
	bad.erase("pool_catalog")
	bad.erase("pool_layout_catalog")
	_check(ClubAssetLedger.from_data(bad, 16, credits, progress) == null,
		"old journal cannot smuggle a paid expansion")
	_tamper(credits, progress)
	_seat(ledger)
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro land checks passed: ordered costs, exact ownership and fixed playing geometry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, tier: String) -> Dictionary:
	return {"id": "land:%d" % ledger.revision(), "rev": ledger.revision(), "op": "stadium_land",
		"through": 20, "progress_through": 20, "price_version": 1, "tier": tier}


func _geometry(tier: String) -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build(tier, StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"expanded property geometry builds")
	_check(property.objects.is_empty() and property.route_obstacles().is_empty(),
		"expansion creates no placed items or live obstacles")
	var reference: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	_check(property.field.back_wall_z_m == reference.back_wall_z_m
		and property.field.home_run_height_m == reference.home_run_height_m
		and property.field.safe_hit_z_m == reference.safe_hit_z_m, "sport dimensions never scale")
	var ground: BoxShape3D = property.get_node("PropertyGround").get_child(0).shape
	_check(ground.size == StadiumProperty.ground_bounds(tier).size, "actual land collider expands")
	_check(StadiumBoundaryRuntime.assemble(property) != null,
		"same complete reference boundary fits every land stage")
	property.queue_free()


func _tamper(credits: Array, progress: Array) -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(16, credits, progress)
	var old: Dictionary = ledger.to_data()
	old.version = 6
	old.erase("land_catalog")
	old.erase("style_catalog")
	old.erase("appearance_catalog")
	old.erase("display_catalog")
	old.erase("display_layout_catalog")
	old.erase("ground_catalog")
	old.erase("ground_layout_catalog")
	old.erase("bleacher_catalog")
	old.erase("bleacher_layout_catalog")
	old.erase("target_catalog")
	old.erase("target_layout_catalog")
	old.erase("net_catalog")
	old.erase("net_layout_catalog")
	old.erase("light_catalog")
	old.erase("light_layout_catalog")
	old.erase("infield_catalog")
	old.erase("infield_layout_catalog")
	old.erase("wall_catalog")
	old.erase("wall_layout_catalog")
	old.erase("surface_catalog")
	old.erase("surface_layout_catalog")
	old.erase("surface_origin")
	old.erase("wall_piece_catalog")
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	var migrated: ClubAssetLedger = ClubAssetLedger.from_data(old, 16, credits, progress)
	_check(migrated != null and migrated.view().land == "backyard"
		and migrated.balance() == 10000, "old seating journal gains no free land or charge")
	for patch: Dictionary in [{"tier": true}, {"tier": "club"}, {"tier": "unknown"},
		{"progress_through": true}, {"progress_through": 1}, {"progress_through": 21},
		{"price_version": true}, {"price_version": 99}, {"through": 0}, {"price": 0}]:
		var command: Dictionary = _buy(ledger, "expanded")
		command.merge(patch, true)
		_check(not ledger.commit(command).ok and ledger.revision() == 0 and ledger.balance() == 10000,
			"malformed, stale or unauthorized land request preserves all funds")
	var poor: Array = []
	poor.resize(20)
	poor.fill(1)
	ledger = ClubAssetLedger.new(16, poor, progress)
	_check(not ledger.commit(_buy(ledger, "expanded")).ok, "eligibility alone does not pay for land")


func _seat(ledger: ClubAssetLedger) -> void:
	var command: Dictionary = {"id": "seat", "rev": ledger.revision(), "op": "stadium_buy",
		"through": 20, "progress_through": 20, "price_version": 2, "item": "ST-080", "quantity": 1}
	_check(ledger.commit(command).ok, "seating uses the remaining common wallet")
	var layout: Dictionary = StadiumHomeLayout.upgrade(StadiumStarterLayout.empty())
	layout.seating = [{"copy": "purchase:seat:0", "site": "SC-L3"}]
	_check(not StadiumHomeLayout.validate(layout, ledger.construction()).ok
		and StadiumHomeLayout.validate(layout, ledger.construction(), "expanded").ok,
		"third chair site is a land capability, not an automatically granted copy")
	_check(ledger.commit({"id": "draft", "rev": ledger.revision(), "op": "stadium_draft",
		"layout": layout}).ok, "owned higher land supports the actual third-site draft")
	_check(ledger.commit({"id": "apply", "rev": ledger.revision(), "op": "stadium_apply",
		"layout": layout, "geometry": StadiumHomeLayout.geometry("mogul", layout)}).ok,
		"applied geometry binds exact owned land")
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(StadiumLayoutSnapshot.matches(snapshot, ledger), "expanded seating snapshot validates")
	snapshot.tier = "expanded"
	snapshot.geometry = StadiumHomeLayout.geometry("expanded", layout)
	_check(StadiumLayoutSnapshot.valid(snapshot)
		and not StadiumLayoutSnapshot.matches(snapshot, ledger),
		"structural property declaration cannot change the exact owned tier at its prefix")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
