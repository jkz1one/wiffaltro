extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded ST-047 qualification. Synthetic funding/source statistics; zero completed games.

const SEED: int = 160
const ITEM: String = "ST-047"
const SITE: String = "LANDMARK-A"
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
# Exact format-only successor; admitted only under the reviewed whole-source profile.
const FORMATTED_INNER_SOURCE_SHA256: String = \
	"fbedaaea728e65a327589622dc27e24643227bada19659223421c7f078b91d90"
# Fresh phase1 adds an explicit overhead reset witness and its two native PNG checks.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 186
const PHASE1_CHECKS: int = 267
const PHASE2_CHECKS: int = 39
const UNION_CHECKS: int = 306
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"progression": 20,
	"ownership": 74,
	"fit": 17,
	"workshop_controls": 5,
	"terrain_support": 27,
	"runtime_and_views": 36
}

# Exact f00 version-1 producer context, not an allowlist of later or invented producers.
const APPLE_F00_SOURCE_CONTEXT: Dictionary = {
	"res://src/tests/stadium_rising_apple_rebuild_checks.gd":
	"1b85e178babb7404631eb6a05235e614345122eacb40691a85af439bc73bd51c",
	"res://src/tests/stadium_rising_apple_geometry_rebuild_checks.gd":
	"70d2e94b343713e184ea2b9716656d772cd12b82044e56a7379ee0d61e09e9d2",
	"res://src/gameplay/stadium/stadium_rising_apple_items.gd":
	"e8f5cf3c8a291cf24aa3adf984c764565ca82fbeab823163ce2cc70e632da4c6",
	"res://src/gameplay/stadium/stadium_career_progress.gd":
	"85b9a3ce70e11c500ea82678f5a5d45ba73805316bc5e030da6db04ee323fbf8",
	"res://src/gameplay/season/club_asset_ledger.gd":
	"e80b370a0e8375c6432fe71d04892be8099a0bad2b388cfad7d5ab5657960d9c",
	"res://src/gameplay/stadium/stadium_layout_snapshot.gd":
	"d18181a31ec90f1a39d39ad55350ab9a51dee411ce475af24f028c2dffb2039b",
	"res://src/gameplay/stadium/stadium_catalog.gd":
	"4238ab349401e32921b1bdc0a5ba85fb51b21ccf4c80c5200fbf55041bebb78f",
	"res://src/gameplay/stadium/stadium_purchases.gd":
	"833e149cf579db381c90514861b525f13a3cdf3c2ad4e839a361fdf521b52d82",
	"res://src/gameplay/stadium/stadium_home_layout.gd":
	"cf39a6a17ea13735ad3c37cfbd6ac21a533316caaa99837f2707957fe6d2e2de",
	"res://src/gameplay/stadium/stadium_owned_layout.gd":
	"4bf22076db37b8e5d5836f34a1db547ae470cc0d112c9e4a009e5ed60176f129",
	"res://src/presentation/stadium/stadium_rising_apple_models.gd":
	"371fd970efc2007fdad33479acac5cb04b45e3fbe02fe53516405dde2b53ad86",
	"res://src/presentation/stadium/stadium_rising_apple_runtime.gd":
	"fd7449fabd3df227048a0740d9a78fcfa16e699c6b86d7cc4441653e8a3768a0",
	"res://src/presentation/stadium/stadium_property_geometry.gd":
	"b7b515848b7d3ff1ad209268f2324da7609fffb8db68aba04c54ccfdd049c6c0",
	"res://src/presentation/stadium/stadium_property_runtime.gd":
	"4a0fd51bf15b75bbfd429aa905f9a186b0d45d2356583a2287fedeba283f3da7",
	"res://src/presentation/stadium/stadium_rising_apple_items_ui.gd":
	"903bada8085facbb8af3d1afe03a62e2b793b74596de7e568b6678d6b62daa13",
	"res://src/presentation/stadium/stadium_draft_preview.gd":
	"a1fab691adc97365c6963c1e62fb58484637539be9de846ccad4f783904fb7ed",
	"res://src/presentation/camera/ball_tracking_visibility.gd":
	"3726a1ef22c579e719992a0a1f6cef7279a50cb5a8477cfe80a711d79e363462",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd":
	"ba4fea54ce149c64fc9f9c0bc6ee2e0171d5605c58289932937e3cbdbc2e1006",
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_home_run.gd":
	"901b065aacfba8a6fb0e671d1baff1c37b9818a7eed712f9518e23d040819cd1"
}

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _inherited: Dictionary = {}
var _empty: Dictionary = {}
var _layout: Dictionary = {}
var _snapshot: Dictionary = {}
var _old_prefix: Dictionary = {}
var _records: Array[Dictionary] = []
var _receipts: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _progress_cases: Array[Dictionary] = []
var _fit_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _camera_cases: Array[Dictionary] = []
var _phase_counts: Dictionary = {}
var _ui_cases: Dictionary = {}
var _runtime: Dictionary = {}
var _model_checks: int = 0
var _phase_timings_ms: Dictionary = {}
var _lab_setup_timings: Array[Dictionary] = []
var _run_started_us: int = 0
var _setup_error_text: String = ""


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"RISING_APPLE_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _source_context() -> Dictionary:
	# Bind every original source and every helper holding code relocated from those roots.
	var result: Dictionary = {}
	for path: String in [
		"res://src/tests/stadium_rising_apple_rebuild_checks.gd",
		"res://src/tests/stadium_rising_apple_geometry_rebuild_checks.gd",
		"res://src/gameplay/stadium/stadium_rising_apple_items.gd",
		"res://src/gameplay/stadium/stadium_career_progress.gd",
		"res://src/gameplay/season/club_asset_ledger.gd",
		"res://src/gameplay/stadium/stadium_layout_snapshot.gd",
		"res://src/gameplay/stadium/stadium_catalog.gd",
		"res://src/gameplay/stadium/stadium_purchases.gd",
		"res://src/gameplay/stadium/stadium_home_layout.gd",
		"res://src/gameplay/stadium/stadium_owned_layout.gd",
		"res://src/presentation/stadium/stadium_rising_apple_models.gd",
		"res://src/presentation/stadium/stadium_rising_apple_runtime.gd",
		"res://src/presentation/stadium/stadium_property_geometry.gd",
		"res://src/presentation/stadium/stadium_property_runtime.gd",
		"res://src/presentation/stadium/stadium_rising_apple_items_ui.gd",
		"res://src/presentation/stadium/stadium_draft_preview.gd",
		"res://src/presentation/camera/ball_tracking_visibility.gd",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_home_run.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_1.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_10.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_11.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_12.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_13.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_2.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_3.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_4.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_5.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_6.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_7.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_8.gd",
		"res://src/gameplay/season/club_asset_ledger_operations_9.gd",
		"res://src/gameplay/stadium/stadium_layout_snapshot_operations_1.gd",
		"res://src/gameplay/stadium/stadium_layout_snapshot_operations_2.gd",
		"res://src/gameplay/stadium/stadium_layout_snapshot_operations_3.gd",
		"res://src/presentation/stadium/stadium_property_geometry_operations_1.gd",
		"res://src/presentation/stadium/stadium_property_geometry_operations_2.gd",
		"res://src/presentation/stadium/stadium_property_geometry_operations_3.gd",
		"res://src/tests/stadium_rising_apple_rebuild_checks_fixture_base.gd",
		"res://src/tests/stadium_rising_apple_rebuild_checks_scenario_base.gd",
		"res://src/tests/stadium_rising_apple_rebuild_checks_runtime_base.gd"
	]:
		var digest: String = FileAccess.get_sha256(path)
		if digest.length() != 64 or not digest.is_valid_hex_number():
			return {}
		result[path] = digest
	return result


func _buy(item: String, price_version: int, cost: int) -> String:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "apple-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": 1,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	var copy: String = "purchase:apple-buy:%d:0" % revision
	var receipt: Dictionary = _paid.construction().copies.get(copy, {})
	_operands = {"item": item, "revision": revision, "error": result.get("error", ""), "cost": cost}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"ordinary paid command adds exactly one complete purchased copy " + item
	)
	_check(
		(
			ClubCareer.same(
				receipt,
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
			and _paid.construction().blueprints.has(item)
		),
		"exact copy receipt preserves item copy price and paid source " + item
	)
	_check(
		(
			_paid.commit(command).get("replayed", false)
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + 1
		),
		"exact paid retry neither charges nor duplicates " + item
	)
	_receipts.append(
		{
			"copy": copy,
			"item": item,
			"command_revision": revision,
			"charged": cost,
			"copy_paid": receipt.get("paid", -1),
			"source": receipt.get("source", ""),
			"retry_replayed": true
		}
	)
	return copy if result.ok else ""


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"rising_apple": layout.get("rising_apple", [])
	}
	return result


func _place(layout: Dictionary, copy: String, site: String = "LANDMARK-A") -> Dictionary:
	return StadiumRisingAppleItems.place(
		layout, _paid.construction(), copy, site, 0.0, _paid.surface_owned()
	)


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "apple-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "apple-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
		}
	)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen owned-parent snapshot " + label
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(snapshot, cold)
		),
		"cold journal preserves exact purchased identity and placement " + label
	)
	_records.append(
		{
			"case": label,
			"layout": layout.duplicate(true),
			"paid_revision": _paid.revision(),
			"snapshot_version": snapshot.get("version", -1),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text(),
			"cold_exact": cold != null and StadiumLayoutSnapshot.matches(snapshot, cold)
		}
	)


func _refused(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _paid.to_data().duplicate(true)
	var result: Dictionary = _paid.commit(
		{
			"id": "apple-refuse:" + label,
			"rev": _paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = ClubCareer.same(before, _paid.to_data())
	_check(
		not result.ok and unchanged,
		"ordinary transaction refuses without changing paid journal " + label
	)
	_ownership_cases.append(
		{
			"case": label,
			"rejected": not result.ok,
			"unchanged": unchanged,
			"error": result.get("error", "")
		}
	)


func _light_layout(layout: Dictionary, profile: String, site: String, copy: String) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.floodlight_profile = profile
	result.floodlights = [
		{"copy": copy, "item": "ST-076" if profile == "MOGUL4-PREMIUM" else "ST-038", "site": site}
	]
	return result


func _corners(box: AABB) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(box.position.x, box.position.z),
			Vector2(box.end.x, box.position.z),
			Vector2(box.end.x, box.end.z),
			Vector2(box.position.x, box.end.z)
		]
	)


func _polygon_gap(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var gap: float = INF
	for a in range(first.size()):
		for b in range(second.size()):
			gap = minf(
				gap,
				StadiumLandscapeOwnedItems._segment_distance(
					first[a],
					first[(a + 1) % first.size()],
					second[b],
					second[(b + 1) % second.size()]
				)
			)
	return gap


func _intersection_area(first: PackedVector2Array, second: PackedVector2Array) -> float:
	var area: float = 0
	for part: PackedVector2Array in Geometry2D.intersect_polygons(first, second):
		var signed_area: float = 0
		for index in range(part.size()):
			signed_area += part[index].cross(part[(index + 1) % part.size()])
		area += absf(signed_area) * 0.5
	return area


func _clearance(box: AABB, graph: StadiumRecipeBoundary) -> Dictionary:
	var footprint: PackedVector2Array = _corners(box)
	var polygon: PackedVector2Array = graph.polygon()
	var distance: float = _polygon_gap(footprint, polygon)
	var slab_distance: float = INF
	var overlap: float = 0
	for index in range(polygon.size()):
		var next: int = (index + 1) % polygon.size()
		var slab: PackedVector2Array = PackedVector2Array(
			[polygon[index], polygon[next], graph.outer_vertex(next), graph.outer_vertex(index)]
		)
		slab_distance = minf(slab_distance, _polygon_gap(footprint, slab))
		overlap += _intersection_area(footprint, slab)
	return {"graph_line_m": distance, "slab_gap_m": slab_distance, "slab_overlap_m2": overlap}


func _ownership() -> void:
	_phase = "exact-paid-copy-gates-and-lifecycle"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4, "homers": 2})
	_check(
		StadiumCareerProgress.valid(_progress, _credits),
		"explicit synthetic closed metrics support paid qualification without earned-career claim"
	)
	# This frozen ledger43 fixture uses the supported pre-salvage constructor.
	_paid = ClubAssetLedger.new(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
			and not _paid.construction().blueprints.has(ITEM)
		),
		"adoption grants no rising apple or CO4 shortcut"
	)
	var entry: Dictionary = StadiumCatalog.item(ITEM)
	_check(
		(
			entry.blueprint_price == 900
			and entry.copy_price == 240
			and ClubCareer.same(entry.requires, {"seasons": 20, "homers": 40})
		),
		"unchanged exact 900 plus 240 price and S20 R40 gate"
	)
	_check(
		(
			StadiumPurchases
			. quote(
				_paid.construction(),
				ITEM,
				1,
				"apple-exact",
				StadiumRisingAppleItems.PRICE_VERSION,
				{"seasons": 20, "homers": 40}
			)
			. ok
		),
		"exact recorded S20 R40 threshold admits ordinary paid quote"
	)
	for metrics: Dictionary in [
		{"seasons": 19, "homers": 40},
		{"seasons": 20, "homers": 39},
		{"seasons": 20},
		{"seasons": 0, "homers": 75}
	]:
		_check(
			not (
				StadiumPurchases
				. quote(
					_paid.construction(),
					ITEM,
					1,
					"apple-below",
					StadiumRisingAppleItems.PRICE_VERSION,
					metrics
				)
				. ok
			),
			"just-below missing or archived CO4 metrics cannot bypass S20 R40"
		)
	_check(
		not (
			StadiumPurchases
			. quote(
				_paid.construction(),
				ITEM,
				1,
				"apple-old",
				StadiumOutfieldBleacherItems.PRICE_VERSION,
				{"seasons": 20, "homers": 40}
			)
			. ok
		),
		"older outfield price route cannot buy the apple"
	)
	_copies.append(_buy(ITEM, StadiumRisingAppleItems.PRICE_VERSION, 1140))
	_copies.append(_buy(ITEM, StadiumRisingAppleItems.PRICE_VERSION, 240))
	_inherited["ST-048"] = _buy("ST-048", StadiumLandmarkItems.PRICE_VERSION, 760)
	_inherited["ST-038"] = _buy("ST-038", StadiumFloodlightOwnedItems.PRICE_VERSION, 640)
	_inherited["ST-076"] = _buy("ST-076", StadiumFloodlightOwnedItems.PRICE_VERSION, 930)
	_check(
		_paid.construction().copies.size() == 8 and StadiumLayoutSnapshot.matches(starter, _paid),
		"five explicit purchases retain starter prefix and grant no unpurchased copy"
	)
	if _copies.has("") or _inherited.values().has("") or _paid.construction().copies.size() != 8:
		return
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "apple-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == 8,
			"ordinary property upgrade grants no apples " + tier
		)
	var base34: Dictionary = StadiumOutfieldBleacherItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_check(
		_checked(base34).ok and _apply(base34),
		"accepted exact empty family34 applies before apple adoption"
	)
	_record("inherited-family34", base34)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	_empty = StadiumRisingAppleItems.upgrade(base34, _paid.surface_owned())
	_check(
		(
			_empty.version == 35
			and _empty.rising_apple.is_empty()
			and ClubCareer.same(StadiumRisingAppleItems.base(_empty), base34)
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"empty family35 preserves all earlier exact channels"
	)
	_record("empty-apple-family", _empty)
	var balance: int = _paid.balance()
	_layout = _place(_empty, _copies[0])
	_check(
		_checked(_layout).ok and _apply(_layout) and _paid.balance() == balance,
		"one exact paid complete apple applies without another charge"
	)
	_record("paid-apple-placed", _layout)
	var stored: Dictionary = StadiumRisingAppleItems.store_copy(_layout, _copies[0])
	_check(
		(
			ClubCareer.same(stored, _empty)
			and _checked(stored).stored.has(_copies[0])
			and _apply(stored)
		),
		"Store vacates the exclusive site while retaining exact paid apple"
	)
	_record("paid-apple-stored", stored)
	_check(
		(
			ClubCareer.same(_place(stored, _copies[0]), _layout)
			and _apply(_layout)
			and _paid.balance() == balance
		),
		"same exact paid copy remounts without charge"
	)
	_record("same-paid-copy-remounted", _layout)
	var swapped: Dictionary = _place(
		StadiumRisingAppleItems.store_copy(_layout, _copies[0]), _copies[1]
	)
	_check(
		_checked(swapped).ok and _checked(swapped).stored.has(_copies[0]) and _apply(swapped),
		"explicit Store first swaps to the independently paid second copy"
	)
	_record("store-first-second-copy", swapped)
	_negatives()
	_check(
		(
			_checked(_layout).ok
			and _apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 43
			and _paid.construction().copies.size() == 8
		),
		"final paid installation keeps ledger43 exact with no bonus or extra copy"
	)
	_record("final-exclusive-apple", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			StadiumLayoutSnapshot.matches(_old_prefix, _paid)
			and cold != null
			and StadiumLayoutSnapshot.matches(_old_prefix, cold)
		),
		"accepted family34 prefix remains authenticated warm and cold"
	)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not _checked(_layout).get("night_qualified", true)
		),
		"frozen apple fixture retains daylight-only admission"
	)


func _negatives() -> void:
	_check(
		StadiumRisingAppleItems.sites() == [SITE] and StadiumRisingAppleItems.yaws() == [0],
		"only exclusive LANDMARK-A and zero yaw are offered"
	)
	for copy: String in ["starter-v1:ST-003", _inherited["ST-048"], "purchase:foreign:0"]:
		var bad: Dictionary = _empty.duplicate(true)
		bad.rising_apple = [{"copy": copy, "site": SITE}]
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy), _empty),
			"wrong-item or foreign identity cannot become an apple " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"second-copy",
		"plaza",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"wrong-family",
		"missing-copy",
		"non-array"
	]:
		var bad: Dictionary = _layout.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.rising_apple.append(bad.rising_apple[0].duplicate())
			"second-copy":
				bad.rising_apple.append({"copy": _copies[1], "site": SITE})
			"plaza":
				bad.rising_apple[0].site = "ODDITY-PLAZA"
			"unknown-site":
				bad.rising_apple[0].site = "LANDMARK-B"
			"unknown-field":
				bad.rising_apple[0]["yaw"] = 0
			"wrong-version":
				bad.version = 34
			"wrong-family":
				bad.family = "reference-starter-v1"
			"missing-copy":
				bad.rising_apple[0].erase("copy")
			"non-array":
				bad.rising_apple = {}
		_check(not _checked(bad).ok, "exact bounded apple grammar rejects " + kind)
	_check(
		(
			ClubCareer.same(_place(_layout, _copies[0]), _layout)
			and ClubCareer.same(_place(_empty, _copies[0], "ODDITY-PLAZA"), _empty)
		),
		"same-copy reselect is idempotent and plaza cannot be offered by placement"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			(
				StadiumRisingAppleItems.row(_copies[0], ITEM, SITE, yaw).is_empty()
				and ClubCareer.same(
					StadiumRisingAppleItems.place(
						_empty, _paid.construction(), _copies[0], SITE, yaw
					),
					_empty
				)
			),
			"arbitrary or nonfinite rotation cannot escape full site reservation " + str(yaw)
		)
	for reverse: bool in [false, true]:
		var conflict: Dictionary = _place(
			_place(_empty, _copies[1] if reverse else _copies[0]),
			_copies[0] if reverse else _copies[1]
		)
		_check(
			conflict.rising_apple.size() == 2 and not _checked(conflict).ok,
			"two independently paid copies reject both simultaneous site-occupancy orders"
		)
		_refused("second-paid-copy:" + str(reverse), conflict)
	_refused("stale-current-copy-draft", _layout, true)
	_check(
		(
			ClubCareer.same(StadiumRisingAppleItems.prune(_layout), _layout)
			and StadiumRisingAppleItems.base(_layout).version == 34
		),
		"pruning preserves current exact copy and inherited family34"
	)


func _fit_and_conflicts() -> void:
	_phase = "whole-site-field-and-both-order-conflicts"
	var row: Dictionary = StadiumRisingAppleItems.row(_copies[0], ITEM, SITE)
	var box: AABB = StadiumRisingAppleItems.bounds(row)
	_check(
		(
			box == AABB(Vector3(30, 0, 39), Vector3(13, 8, 10))
			and row.position == Vector3(36.5, 0, 44)
			and row.yaw == 0
		),
		"apple reserves the entire exclusive landmark site throughout full 8 metre motion height"
	)
	for tier: String in ["backyard", "expanded", "club"]:
		_check(
			not _checked(_layout, tier).ok,
			"earlier property tier refuses the complete apple " + tier
		)
	_check(
		StadiumProperty.contains("mogul", box) and _checked(_layout).ok,
		"whole swept reservation fits Mogul without scaling"
	)
	for shape: String in ["straight", "deeper_center"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape)
		var clearance: Dictionary = _clearance(box, graph)
		_check(
			(
				StadiumGroundBoxItems._outside_play(box, graph)
				and clearance.graph_line_m > 0
				and clearance.slab_gap_m > 0
				and clearance.slab_overlap_m2 <= 0.000001
			),
			"whole apple reservation clears current boundary line and miter slabs " + shape
		)
		_fit_cases.append(
			{
				"case": shape,
				"bounds": str(box),
				"gap_m": clearance.slab_gap_m,
				"overlap_m2": clearance.slab_overlap_m2,
				"clear": true,
				"details": "whole swept LANDMARK-A reservation"
			}
		)
	var landmark_first: Dictionary = StadiumLandmarkItems.place(
		_empty, _paid.construction(), _inherited["ST-048"], SITE
	)
	var order_a: Dictionary = _place(landmark_first, _copies[0])
	var order_b: Dictionary = StadiumLandmarkItems.place(
		_layout, _paid.construction(), _inherited["ST-048"], SITE
	)
	_check(
		(
			_checked(landmark_first).ok
			and ClubCareer.same(order_a, order_b)
			and not _checked(order_a).ok
			and order_a.rising_apple == _layout.rising_apple
			and order_a.landmarks == landmark_first.landmarks
		),
		"apple and existing complete landmark conflict in both orders without moving either paid copy"
	)
	_refused("landmark-first", order_a)
	_refused("apple-before-landmark", order_b)
	var light_first: Dictionary = _light_layout(
		_empty, "CLUB4-LOW", "CLIGHT-OR", _inherited["ST-038"]
	)
	order_a = _place(light_first, _copies[0])
	order_b = _light_layout(_layout, "CLUB4-LOW", "CLIGHT-OR", _inherited["ST-038"])
	_check(
		(
			_checked(light_first).ok
			and ClubCareer.same(order_a, order_b)
			and not _checked(order_a).ok
			and order_a.rising_apple == _layout.rising_apple
			and order_a.floodlights == light_first.floodlights
		),
		"Club outer-right tower and apple conflict in both orders without displacement"
	)
	_refused("club-tower-first", order_a)
	_refused("apple-before-club-tower", order_b)
	for profile: String in ["MOGUL6-STANDARD", "MOGUL4-PREMIUM"]:
		var premium: bool = profile == "MOGUL4-PREMIUM"
		var site: String = "PLIGHT-OR" if premium else "MLIGHT-OR"
		var copy: String = _inherited["ST-076" if premium else "ST-038"]
		var candidate: Dictionary = _light_layout(_layout, profile, site, copy)
		var light: Dictionary = StadiumFloodlightOwnedItems.row(copy, profile, site)
		var radius: float = StadiumFloodlightOwnedItems.bounds(light).size.x * 0.5
		var nearest: Vector2 = Vector2(
			clampf(light.position.x, box.position.x, box.end.x),
			clampf(light.position.z, box.position.z, box.end.z)
		)
		var gap: float = nearest.distance_to(Vector2(light.position.x, light.position.z)) - radius
		_check(
			(
				_checked(candidate).ok
				and absf(gap - (1.412277660 if premium else 1.812277660)) < 0.0001
				and candidate.rising_apple == _layout.rising_apple
				and candidate.floodlights[0].copy == copy
			),
			"Mogul full circular tower reservation clears full swept apple " + profile
		)
		_fit_cases.append(
			{
				"case": profile,
				"bounds": str(StadiumFloodlightOwnedItems.bounds(light)),
				"gap_m": gap,
				"overlap_m2": 0,
				"clear": true,
				"details": "whole circular tower and swept landmark reservations"
			}
		)
	var plaza: Dictionary = StadiumLandmarkItems.place(
		_layout, _paid.construction(), _inherited["ST-048"], "ODDITY-PLAZA"
	)
	_check(
		(
			_checked(plaza).ok
			and plaza.rising_apple == _layout.rising_apple
			and plaza.landmarks[0].site == "ODDITY-PLAZA"
		),
		"unrelated paid plaza landmark remains available while apple stays exclusive to LANDMARK-A"
	)
	_check(
		(
			not StadiumGroundBoxItems._outside_play(
				AABB(Vector3(-2, 0, 8), Vector3(13, 8, 10)),
				StadiumRisingAppleItems.graph_for(_layout)
			)
			and not StadiumGroundBoxItems._outside_play(box, null)
		),
		"field-reaching reservation and absent complete graph fail closed"
	)


func _detached_controls() -> void:
	_phase = "actual-workshop-controls-without-season-save-claim"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumRisingAppleItemsUI.choices() == ["Stored", SITE],
		"actual Workshop offers Store and only exclusive LANDMARK-A"
	)
	var cards: Array[Dictionary] = []
	for index in range(2):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumRisingAppleItemsUI.card(
			menu, panel, _layout, _copies[index], _paid.revision(), false
		)
		var options: Array[Node] = panel.find_children("*", "OptionButton", true, false)
		var choice: OptionButton = options[0] as OptionButton if options.size() == 1 else null
		var names: Array[String] = []
		if choice != null:
			for option in range(choice.item_count):
				names.append(choice.get_item_text(option))
		_check(
			(
				choice != null
				and choice.disabled
				and names == ["Stored", SITE]
				and choice.selected == (1 if index == 0 else 0)
				and choice.item_selected.get_connections().size() == 1
			),
			"actual locked card distinguishes exact placed and stored paid apple " + str(index)
		)
		cards.append(
			{
				"copy": _copies[index],
				"names": names,
				"selected": choice.selected if choice != null else -1,
				"disabled": choice != null and choice.disabled,
				"connected_actions":
				choice.item_selected.get_connections().size() if choice != null else 0
			}
		)
	StadiumRisingAppleItemsUI.purchases(menu, _paid, _layout, _paid.revision(), false)
	var text: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	_check(
		(
			text.contains("900")
			and text.contains("240")
			and text.contains("20")
			and text.contains("40")
			and text.contains("2 owned copies")
			and not text.contains("ODDITY-PLAZA")
		),
		"actual Workshop states exact price gate paid count and exclusive route"
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == ITEM
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"ordinary locked purchase control cannot bypass season policy"
	)
	_ui_cases = {
		"cards": cards,
		"copy_count_text": text,
		"ledger_paid_purchases_executed": true,
		"ledger_layout_transactions_executed": true,
		"accepted_seasonstate_purchase_executed": false,
		"editable_callback_executed": false,
		"native_preview": false,
		"focus_cases": [],
		"night_eligible": false
	}
	menu.free()
	app.free()


func _apple_source_version_supported(value: Variant) -> bool:
	# JSON numbers may be floats; preserve the original numeric version-1 comparison.
	return (value is int or value is float) and (value == 1 or value == 2)


func _apple_source_context_matches(
	version: Variant, producer_context: Dictionary, executor_context: Dictionary
) -> bool:
	if not _apple_source_version_supported(version) or executor_context.is_empty():
		return false
	if version == 1:
		return ClubCareer.same(producer_context, APPLE_F00_SOURCE_CONTEXT)
	return ClubCareer.same(producer_context, executor_context)


func _apple_terrain_source_matches() -> bool:
	var digest: String = FileAccess.get_sha256(
		"res://src/gameplay/stadium/stadium_surface_terrain.gd"
	)
	return (
		digest == INNER_SOURCE_SHA256
		or (
			digest == FORMATTED_INNER_SOURCE_SHA256
			and StadiumPoolPartyAI22RetainedContract.inventory_matches()
			and StadiumNpcSourceQualification.matches_current(StadiumNpcPublicRuntime.SOURCE_PINS)
		)
	)
