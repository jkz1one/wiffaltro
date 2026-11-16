extends Node3D
## Exact new-origin layouts and immutable fixture/access binding; synthetic credited income.

var _failures: int = 0
var _terrain_checks: int = 0
var _terrain_mode: bool = false
var _credits: Array = []
var _progress: Array = []


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--surface-terrain"):
		_terrain_mode = true
		await _terrain_owned()
		return
	for index in range(8):
		_credits.append(125)
		_progress.append({"seasons": 1, "wins": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(21, _credits, _progress)
	var initial: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		(
			initial.version == 8
			and initial.surface_access.is_empty()
			and initial.layout.surface.foundation == "dirt"
			and initial.layout.surface.condition == "rough"
		),
		"new-origin snapshot captures rough dirt with no purchased upgrade"
	)
	_check(
		StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(initial))),
		"new snapshot survives JSON numeric conversion"
	)
	var old_escape: Dictionary = StadiumStarterLayout.empty()
	_check(
		not ledger.commit(_draft(ledger, old_escape)).ok, "new club cannot bypass surface ownership"
	)
	var forged: Dictionary = initial.layout.duplicate(true)
	forged.surface.foundation = "grass"
	_check(not ledger.commit(_draft(ledger, forged)).ok, "unpaid grass draft rejects")
	_buy(ledger, "grass")
	_buy(ledger, "ground_prep")
	_check(
		StadiumLayoutSnapshot.matches(initial, ledger),
		"old rough field remains bound to old prefix"
	)
	for style: String in ["ST-063a", "ST-063g"]:
		var command: Dictionary = {
			"id": "style:%d" % ledger.revision(),
			"rev": ledger.revision(),
			"op": "stadium_style",
			"item": style,
			"through": 8,
			"progress_through": 8,
			"price_version": 3 if style == "ST-063g" else 1
		}
		_check(ledger.commit(command).ok, "earned pattern/cut purchase after separate upgrades")
	var layout: Dictionary = initial.layout.duplicate(true)
	layout.surface = StadiumSurfaceProgression.selection(ledger.surface_owned(), true, "long")
	layout.styles.grass = "ST-063a"
	layout.ground = "ST-063g"
	_check(ledger.commit(_draft(ledger, layout)).ok, "exact paid surface draft")
	_check(
		(
			ledger
			. commit(
				{
					"id": "apply:%d" % ledger.revision(),
					"rev": ledger.revision(),
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumHomeLayout.geometry("backyard", layout)
				}
			)
			. ok
		),
		"exact free surface apply"
	)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		StadiumLayoutSnapshot.matches(snapshot, ledger),
		"current field binds exact access and stock"
	)
	var fixture: Dictionary = snapshot.duplicate(true)
	fixture.version = 9
	fixture["environment"] = StadiumFixtureEnvironment.capture(fixture, 77, 0)
	_check(
		(
			StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(fixture)))
			and fixture.environment.mode == "day"
		),
		"new finish freezes its verified daylight-only mode"
	)
	var bad: Dictionary = fixture.duplicate(true)
	bad.surface_access = []
	_check(not StadiumLayoutSnapshot.valid(bad), "grass fixture cannot strip upgrade declaration")
	bad = initial.duplicate(true)
	bad.surface_access = ["grass", "ground_prep"]
	_check(
		StadiumLayoutSnapshot.valid(bad) and not StadiumLayoutSnapshot.matches(bad, ledger),
		"structural declaration cannot borrow future purchases into an earlier prefix"
	)
	bad = fixture.duplicate(true)
	bad.version = 7
	_check(not StadiumLayoutSnapshot.valid(bad), "old snapshot cannot carry new surface fields")
	bad = fixture.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumLayoutSnapshot.valid(bad), "unverified night appearance cannot be claimed")
	var stock: StadiumStock = ledger.construction()
	for selected: Dictionary in [initial.layout, layout]:
		var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		add_child(property)
		_check(
			property.build("backyard", selected, stock), "real property assembles selected finish"
		)
		_check(
			property.has_node("OwnedSurfaceFinish") and property.has_node("PropertyGround"),
			"appearance overlays unchanged ground collision"
		)
		_check(
			(
				property
				. get_node("OwnedSurfaceFinish")
				. find_children("*", "CollisionObject3D", true, false)
				. is_empty()
			),
			"finish adds no hidden physics"
		)
		property.free()
	_check(
		(
			ClubAssetLedger.from_data(
				JSON.parse_string(JSON.stringify(ledger.to_data())), 21, _credits, _progress
			)
			!= null
		),
		"whole layout journal replays"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro owned surface checks passed: exact access, immutable snapshots and assembly."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(ledger: ClubAssetLedger, item: String) -> void:
	_check(
		(
			ledger
			. commit(
				{
					"id": "surface:%d" % ledger.revision(),
					"rev": ledger.revision(),
					"op": "stadium_surface",
					"through": 8,
					"price_version": 1,
					"item": item
				}
			)
			. ok
		),
		"separate paid upgrade"
	)


func _draft(ledger: ClubAssetLedger, layout: Dictionary) -> Dictionary:
	return {
		"id": "draft:%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": "stadium_draft",
		"layout": layout
	}


func _check(ok: bool, message: String) -> void:
	if _terrain_mode:
		_terrain_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _terrain_owned() -> void:
	# Explicit pre-salvage rough-origin unit fixture, constructed before any events.
	# Synthetic300CB remains the original test input; no modern grant is stripped.
	var ledger: ClubAssetLedger = ClubAssetLedger.new(21, [300])
	ledger._initialize_surface_origin(StadiumSurfaceProgression.ROUGH_ORIGIN)
	var historical: Dictionary = ledger.to_data()
	ledger = ClubAssetLedger.from_data(historical, 21, [300])
	_check(ledger != null, "historical rough-origin fixture cold restores without modern grants")
	if ledger == null:
		get_tree().quit(1)
		return
	var modern: ClubAssetLedger = ClubAssetLedger.new_club(21, [300])
	var modern_before: Dictionary = modern.to_data()
	_check(
		(
			modern.view().stadium_active.version == StadiumSalvageCarItems.LAYOUT_VERSION
			and modern_before.has("salvage_origin")
			and (
				StadiumSurfaceLayout
				. terrain_upgrade(modern.view().stadium_active, modern.surface_owned())
				. is_empty()
			)
			and ClubCareer.same(modern_before, modern.to_data())
		),
		"current salvage origin cannot silently enter historical flat terrain adapter"
	)
	var old: Dictionary = ledger.to_data()
	var initial: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		old.version == 23 and initial.version == 8,
		"historical pre-salvage rough fixture remains the flat family"
	)
	var rough: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		initial.layout, ledger.surface_owned()
	)
	_check(
		rough.get("version") == 17 and initial.layout.version == 12,
		"explicit free opt-in is isolated from the old installed field"
	)
	var forged: Dictionary = rough.duplicate(true)
	forged.surface.condition = "prepared"
	_check(not ledger.preview(_draft(ledger, forged)).ok, "unpaid leveling refuses")
	var draft: Dictionary = _draft(ledger, rough)
	_check(
		(
			ledger.commit(draft).ok
			and ledger.balance() == 300
			and ledger.to_data().version == 24
			and ledger.view().stadium_active.version == 12
		),
		"draft changes no installed field or wallet"
	)
	var after_draft: Dictionary = ledger.to_data()
	var stale: Dictionary = _draft(ledger, rough)
	stale.rev = 0
	_check(
		not ledger.commit(stale).ok and ClubCareer.same(after_draft, ledger.to_data()),
		"stale draft is atomic"
	)
	_check(
		ledger.commit(draft).replayed and ClubCareer.same(after_draft, ledger.to_data()),
		"same draft replay is exact"
	)
	_check(
		(
			(
				ledger
				. commit(
					{
						"id": "apply:1",
						"rev": 1,
						"op": "stadium_apply",
						"layout": rough,
						"geometry": StadiumOwnedLayout.geometry("backyard", rough)
					}
				)
				. ok
			)
			and ledger.balance() == 300
		),
		"explicit apply is free"
	)
	var entry: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		entry.get("version") == 28 and StadiumLayoutSnapshot.matches(entry, ledger),
		"entry binds complete paid prefix"
	)
	_check(
		StadiumLayoutSnapshot.valid(JSON.parse_string(JSON.stringify(entry))),
		"terrain entry cold numeric roundtrip"
	)
	var fixture: Dictionary = StadiumLayoutSnapshot.terrain_fixture(entry, 77, 3)
	_check(
		(
			fixture.get("version") == 29
			and fixture.environment.mode == "day"
			and StadiumLayoutSnapshot.valid(fixture)
		),
		"fixture is exact daylight only"
	)
	for field: String in ["height", "step", "mode", "surface"]:
		var bad: Dictionary = fixture.duplicate(true)
		bad.terrain[field] = false
		_check(
			not StadiumLayoutSnapshot.valid(bad),
			"reject altered complete terrain contract " + field
		)
	var bad: Dictionary = fixture.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumLayoutSnapshot.valid(bad), "active rough terrain cannot claim night")
	bad = fixture.duplicate(true)
	bad.version = 9
	_check(not StadiumLayoutSnapshot.valid(bad), "old flat fixture cannot carry terrain")
	bad = ledger.to_data()
	bad.version = 23
	bad.erase("terrain_catalog")
	bad.erase("leveled_terrain_catalog")
	_check(ClubAssetLedger.from_data(bad, 21, [300]) == null, "old journal rejects terrain events")
	bad = old.duplicate(true)
	bad.version = 24
	bad["terrain_catalog"] = StadiumSurfaceTerrain.signature("rough")
	bad["leveled_terrain_catalog"] = StadiumSurfaceTerrain.signature("leveled")
	_check(
		ClubAssetLedger.from_data(bad, 21, [300]) == null,
		"new journal requires actual terrain adoption"
	)
	_check(
		(
			ledger.prefix(0) != null
			and ClubCareer.same(ledger.prefix(0).to_data(), old)
			and StadiumLayoutSnapshot.matches(initial, ledger)
		),
		"old prefix stays exact after opt-in"
	)
	_check(
		(
			(
				ledger
				. commit(
					{
						"id": "prep:2",
						"rev": 2,
						"op": "stadium_surface",
						"through": 1,
						"price_version": 1,
						"item": "ground_prep"
					}
				)
				. ok
			)
			and ledger.balance() == 220
		),
		"existing preparation has its existing one debit"
	)
	_check(
		ledger.view().stadium_active.surface.condition == "rough",
		"purchase does not silently level"
	)
	var leveled: Dictionary = rough.duplicate(true)
	leveled.surface.condition = "prepared"
	_check(
		ledger.commit(_draft(ledger, leveled)).ok and ledger.balance() == 220,
		"owned leveling draft is free"
	)
	_check(
		(
			(
				ledger
				. commit(
					{
						"id": "apply:4",
						"rev": 4,
						"op": "stadium_apply",
						"layout": leveled,
						"geometry": StadiumOwnedLayout.geometry("backyard", leveled)
					}
				)
				. ok
			)
			and ledger.balance() == 220
		),
		"owned leveling applies without a second charge"
	)
	var prepared: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		(
			prepared.terrain.mode == "leveled"
			and prepared.terrain.height == 0
			and StadiumLayoutSnapshot.matches(prepared, ledger)
			and StadiumLayoutSnapshot.matches(entry, ledger)
		),
		"both immutable historical terrain states keep their own paid prefixes"
	)
	_check(
		entry.geometry != prepared.geometry and entry.terrain.height > prepared.terrain.height,
		"geometry signature distinguishes rough and leveled"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 21, [300]
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), ledger.to_data()),
		"new journal canonical cold replay"
	)
	# Larger property terrain support is now explicit (completion ledger, molded-seat support).
	# This structural probe grants no land and does not replace paid ledger admission.
	for tier: String in StadiumProperty.BOUNDS:
		_check(
			StadiumSurfaceLayout.validate_terrain(rough, ledger.construction(), tier).ok,
			"rough terrain schema supports documented property bounds: " + tier
		)
	_check(
		not StadiumSurfaceLayout.validate_terrain(rough, ledger.construction(), "invented").ok,
		"terrain rejects unsupported property bounds"
	)
	bad = rough.duplicate(true)
	bad.surface.foundation = "grass"
	_check(
		not StadiumSurfaceLayout.validate_terrain(bad, ledger.construction(), "backyard").ok,
		"terrain refuses grass mechanics"
	)
	bad = rough.duplicate(true)
	bad.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	_check(
		not StadiumSurfaceLayout.validate_terrain(bad, ledger.construction(), "backyard").ok,
		"first terrain family refuses live obstacles"
	)
	var flat: Dictionary = StadiumSurfaceLayout.terrain_base(leveled)
	_check(
		ledger.commit(_draft(ledger, flat)).ok, "explicit return to unchanged flat family is legal"
	)
	_check(
		(
			ledger
			. commit(
				{
					"id": "apply:6",
					"rev": 6,
					"op": "stadium_apply",
					"layout": flat,
					"geometry": StadiumOwnedLayout.geometry("backyard", flat)
				}
			)
			. ok
		),
		"flat return uses ordinary apply"
	)
	_check(
		(
			ledger.to_data().version == 24
			and StadiumLayoutSnapshot.capture(ledger).version == 8
			and ledger.balance() == 220
		),
		"history remains terrain24 while current field becomes flat"
	)
	print(
		(
			"STADIUM_SURFACE_TERRAIN_OWNED checks=%d failures=%d games=0 synthetic_income=true"
			% [_terrain_checks, _failures]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
