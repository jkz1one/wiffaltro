extends Node
## Finite source/runtime contract checks. No rendered or authentic-earned qualification.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("SALVAGE_LAYOUT_FAILURE " + label)


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(175, [1000])
	var stock: StadiumStock = ledger.construction()
	var layout: Dictionary = ledger.view().stadium_active
	var checked: Dictionary = StadiumHomeLayout.validate(layout, stock)
	check(checked.ok, "fresh fixed car layout validates: " + checked.get("error", ""))
	if not checked.ok:
		_finish()
		return
	check(
		checked.live_units == 4 and checked.salvage_car_placements.size() == 1,
		"exact four-unit single car"
	)
	check(not checked.night_qualified, "no unmeasured night admission")
	check(
		checked.placements.size() == 1 and checked.stored.size() == 3,
		"original three copies kept stored"
	)
	check(
		StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"],
		"unchanged three starter identity list"
	)
	var pos: Vector3 = StadiumSalvageCarItems.POSITION
	var slope: float = tan(deg_to_rad(42.0))
	check(absf(pos.x + pos.z * slope) < 0.02, "candidate centered on left foul line")
	var corners: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		StadiumSalvageCarItems.row(StadiumStock.SALVAGE_COPY), StadiumJunkCarModels.envelope()
	)
	var fair: int = 0
	for point: Vector2 in corners:
		if absf(point.x) < point.y * slope:
			fair += 1
	check(fair > 0 and fair < 4, "actual visible silhouette straddles foul line")
	var snap: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	check(
		not snap.is_empty() and StadiumLayoutSnapshot.valid(snap),
		"new car included in valid snapshot"
	)
	check(
		StadiumLayoutSnapshot.matches(snap, ledger), "snapshot bound to exact paid journal origin"
	)
	check(not StadiumLayoutSnapshot.key(snap).is_empty(), "snapshot produces replay key")
	check(
		StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(snap))),
		"snapshot cold JSON grammar"
	)
	var original: Dictionary = layout.duplicate(true)
	for altered: Dictionary in [
		{"site": "O-L1"}, {"copy": "fake"}, {"yaw": 90}, {"item": "ST-005"}
	]:
		var bad: Dictionary = layout.duplicate(true)
		bad.salvage_cars[0].merge(altered, true)
		check(
			not StadiumHomeLayout.validate(bad, stock).ok,
			"reject malformed fixed-car row " + str(altered)
		)
	var bad: Dictionary = layout.duplicate(true)
	bad.salvage_cars.append(bad.salvage_cars[0].duplicate(true))
	check(not StadiumHomeLayout.validate(bad, stock).ok, "no double placement")
	bad = layout.duplicate(true)
	bad.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-R1", "yaw": 0}]
	check(not StadiumHomeLayout.validate(bad, stock).ok, "car plus fifth capacity unit refused")
	bad = layout.duplicate(true)
	bad["unknown"] = true
	check(not StadiumHomeLayout.validate(bad, stock).ok, "unknown wrapper field refused")
	var stored: Dictionary = StadiumSalvageCarItems.store_copy(layout, StadiumStock.SALVAGE_COPY)
	var stored_checked: Dictionary = StadiumHomeLayout.validate(stored, stock)
	check(
		(
			stored_checked.ok
			and stored_checked.live_units == 0
			and stored_checked.stored.has(StadiumStock.SALVAGE_COPY)
		),
		"pure stored candidate preserves exact copy"
	)
	check(
		ClubCareer.same(
			StadiumSalvageCarItems.place(stored, stock, StadiumStock.SALVAGE_COPY), original
		),
		"same-copy placement round trip"
	)
	check(ClubCareer.same(layout, original), "pure editing leaves input unchanged")
	var extra_stock: StadiumStock = StadiumStock.from_data(
		stock.quote("ST-005", 1, {"seasons": 7, "wins": 20}, "extra-car").state
	)
	var double_candidate: Dictionary = StadiumSalvageCarItems.place(
		layout, extra_stock, "purchase:extra-car:0"
	)
	check(
		(
			double_candidate.salvage_cars.size() == 2
			and not StadiumHomeLayout.validate(double_candidate, extra_stock).ok
		),
		"occupied site refuses second copy without silently storing first"
	)
	var geometry: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(geometry)
	check(geometry.build("backyard", layout, stock), "complete property assembly")
	if geometry.objects.has(StadiumStock.SALVAGE_COPY):
		check(geometry.props_intact(), "initial sealed car geometry intact")
		check(
			geometry.route_obstacles().size() == 1,
			"one defender car detour, no invisible duplicate"
		)
		check(geometry.has_meta("salvage_car_layout"), "runtime gets exact active car layout")
		var model: Node3D = geometry.objects[StadiumStock.SALVAGE_COPY]
		check(model.position == pos and model.rotation.is_zero_approx(), "model exact fixed pose")
		model.position.x += 0.01
		check(not geometry.props_intact(), "moved model retires sealed contacts")
	geometry.free()
	_finish()


func _finish() -> void:
	print(
		(
			"SALVAGE_LAYOUT_RESULT "
			+ JSON.stringify(
				{"checks": checks, "failures": failures, "visual_qualified": false, "games": 0}
			)
		)
	)
	get_tree().quit(0 if failures == 0 else 1)
