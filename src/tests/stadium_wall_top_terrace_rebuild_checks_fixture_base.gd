extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded combined ST-087 qualification. Synthetic funding/progress; zero games.

const SEED: int = 160
const ITEM: String = "ST-087"
const SITE: String = "TERRACE-R-A"
const INNER_SOURCE_SHA256: String = \
	"1c076efa17f27a3a4d9d0a0f15192535661955534663a34fe370e2c4c490ac75"
const EXPECTED_NON_GEOMETRY_CHECKS: int = 321  # Source-derived success path; frozen before binding.
const EXPECTED_PHASE_CHECKS: Dictionary = {
	"ownership": 94, "fit": 51, "workshop_controls": 5, "support": 97, "runtime_and_views": 67
}
const HOST_ITEMS: Array[String] = ["ST-065", "ST-077"]
const TIERS: Array[String] = ["backyard", "expanded", "club", "mogul"]
const SUPPORTED_TIERS: Array[String] = ["club", "mogul"]
const GROUND_POINTS: Array[Vector3] = [
	Vector3(-5, 0, 6.65), Vector3(3, 0, 6.65), Vector3(5.2, 0, 5.875), Vector3(5.2, 0, 6.5)
]

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Array[String] = []
var _wall_copies: Dictionary = {}
var _controls: Dictionary = {}
var _empty: Dictionary = {}
var _layouts: Dictionary = {}
var _snapshots: Dictionary = {}
var _old_prefix: Dictionary = {}
var _last_draft: Dictionary = {}
var _last_apply: Dictionary = {}
var _receipts: Array[Dictionary] = []
var _records: Array[Dictionary] = []
var _ownership_cases: Array[Dictionary] = []
var _fit_cases: Array[Dictionary] = []
var _support_matrix: Array[Dictionary] = []
var _camera_cases: Array[Dictionary] = []
var _runtime: Array[Dictionary] = []
var _ui_cases: Dictionary = {}
var _phase_counts: Dictionary = {}
var _model_checks: int = 0
var _outcomes: Array = []
var _terrain_dispatch: Dictionary = {}
var _timing_apply_calls: int = 0  # TERRACE_TIMING_ONLY
var _timing_apply_usec: int = 0  # TERRACE_TIMING_ONLY
var _timing_snapshot_calls: int = 0  # TERRACE_TIMING_ONLY
var _timing_snapshot_usec: int = 0  # TERRACE_TIMING_ONLY


# TERRACE_TIMING_ONLY
func _timing_mark(stage: String, event: String, started: int = 0) -> int:  # TERRACE_TIMING_ONLY
	var now: int = Time.get_ticks_usec()  # TERRACE_TIMING_ONLY
	print(
		(
			"WALL_TOP_TERRACE_TIMING "
			+ JSON.stringify(
				{
					"stage": stage,
					"event": event,
					"elapsed_usec": now - started if started > 0 else 0,
					"checks": _checks,
					"revision": _paid.revision() if _paid != null else -1,
					"apply_calls": _timing_apply_calls,
					"apply_usec": _timing_apply_usec,
					"snapshot_calls": _timing_snapshot_calls,
					"snapshot_usec": _timing_snapshot_usec
				},
				"",
				true,
				true
			)
		)
	)  # TERRACE_TIMING_ONLY
	return now  # TERRACE_TIMING_ONLY


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"WALL_TOP_TERRACE_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _detached_controls() -> void:
	_phase = "actual-locked-workshop-copy-and-purchase-controls"
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	_check(
		StadiumWallTopTerraceItemsUI.choices() == ["Stored", SITE],
		"actual Workshop offers Store and only one exact terrace site"
	)
	var cards: Array[Dictionary] = []
	for index in range(2):
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumWallTopTerraceItemsUI.card(
			menu, panel, _layouts["ST-065"], _copies[index], _paid.revision(), false
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
			"locked real card preserves exact placed or stored terrace identity " + str(index)
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
	StadiumWallTopTerraceItemsUI.purchases(menu, _paid, _layouts["ST-065"], _paid.revision(), false)
	var wording: String = ""
	for node: Node in menu._body.find_children("*", "Label", true, false):
		wording += (node as Label).text + "\n"
	_check(
		(
			wording.contains("950 blueprint + 280 per copy")
			and wording.contains("2 owned copies")
			and wording.contains("14 seasons / 44 validated wins")
			and wording.contains("23 independently paid")
			and wording.contains("Store the terrace first")
			and wording.contains("never places it automatically")
		),
		"actual purchase copy explains paid counts exact gate complete hosts and Store-first restoration"
	)
	var buys: Array[Node] = menu._body.find_children("*", "Button", true, false).filter(
		func(node: Node) -> bool: return node.get_meta("stadium_buy", "") == ITEM
	)
	_check(
		buys.size() == 1 and (buys[0] as Button).disabled,
		"locked ordinary purchase button cannot bypass season policy"
	)
	_ui_cases = {
		"cards": cards,
		"copy_count_text": wording,
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


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"terrace": layout.get("wall_top_terrace", [])
	}
	return result


func _place(layout: Dictionary, copy: String) -> Dictionary:
	return StadiumWallTopTerraceItems.place(
		layout, _paid.construction(), copy, SITE, 0.0, _paid.surface_owned()
	)


func _refused(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _paid.to_data().duplicate(true)
	var result: Dictionary = _paid.commit(
		{
			"id": "terrace-refuse:" + label,
			"rev": _paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = ClubCareer.same(before, _paid.to_data())
	_operands = {"case": label, "error": result.get("error", ""), "unchanged": unchanged}
	_check(not result.ok and unchanged, "ordinary draft refuses without journal mutation " + label)
	_ownership_cases.append(
		{
			"case": label,
			"rejected": not result.ok,
			"unchanged": unchanged,
			"error": result.get("error", "")
		}
	)


func _apply(layout: Dictionary) -> bool:
	var timing_started: int = Time.get_ticks_usec()  # TERRACE_TIMING_ONLY
	_timing_apply_calls += 1  # TERRACE_TIMING_ONLY
	_last_draft = {
		"id": "terrace-draft:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var draft: Dictionary = _paid.commit(_last_draft)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		_timing_apply_usec += Time.get_ticks_usec() - timing_started  # TERRACE_TIMING_ONLY
		return false
	_last_apply = {
		"id": "terrace-apply:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
	}
	var applied: Dictionary = _paid.commit(_last_apply)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	_timing_apply_usec += Time.get_ticks_usec() - timing_started  # TERRACE_TIMING_ONLY
	return applied.ok


func _store_then_apply(layout: Dictionary) -> bool:
	# Fixture action sequence is explicit: save Store before any replacement row.
	var stored: Dictionary = _paid.view().stadium_active.duplicate(true)
	for copy: String in _copies:
		stored = StadiumWallTopTerraceItems.store_copy(stored, copy)
	return _apply(stored) and _apply(layout)


func _wall(layout: Dictionary, item: String, shape: String = "straight") -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	var proposal: Dictionary = StadiumWallLayout.propose(
		result.walls, _paid.construction(), "back", item, shape
	)
	if proposal.ok:
		result.walls = proposal.walls
	return result


func _fit_and_conflicts() -> void:
	_phase = "full-reservation-paid-conflicts-in-both-orders"
	var row: Dictionary = StadiumWallTopTerraceItems.row(_copies[0], ITEM, SITE)
	var box: AABB = StadiumWallTopTerraceItems.bounds(row)
	_check(
		(
			(
				box
				== (
					Transform3D(Basis.IDENTITY, Vector3(15, 0, 23.4))
					* AABB(Vector3(-6, 0, 0), Vector3(12, 4.8, 7))
				)
			)
			and row.position == Vector3(15, 0, 23.4)
			and row.yaw == 0
		),
		"unchanged full reservation includes hosts deck guards rear supports and access"
	)
	for tier: String in TIERS:
		var padded: Dictionary = _checked(_layouts["ST-065"], tier)
		var brick: Dictionary = _checked(_layouts["ST-077"], tier)
		var supported: bool = tier in SUPPORTED_TIERS
		var refused: bool = (
			not padded.ok
			and not brick.ok
			and padded.error.contains("requires Club or Mogul property")
			and brick.error.contains("requires Club or Mogul property")
		)
		_operands = {
			"tier": tier,
			"expected_supported": supported,
			"padded": padded.get("error", ""),
			"brick": brick.get("error", "")
		}
		_check(
			(
				StadiumProperty.contains(tier, box)
				and (padded.ok and brick.ok if supported else refused)
			),
			(
				"full paid terrace admits only settled Club/Mogul and explicitly refuses smaller properties "
				+ tier
			)
		)
		_fit_cases.append(
			{
				"case": "property-tier",
				"tier": tier,
				"expected_supported": supported,
				"padded_accepted": padded.ok,
				"brick_accepted": brick.ok,
				"padded_error": padded.get("error", ""),
				"brick_error": brick.get("error", ""),
				"full_reservation_inside": StadiumProperty.contains(tier, box)
			}
		)
	for mode: String in ["rough", "leveled"]:
		var access: Array[String] = []
		if mode == "leveled":
			access.append("ground_prep")
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, false), access
		)
		var candidate: Dictionary = _wall(
			StadiumWallTopTerraceItems.upgrade(terrain, access), "ST-065"
		)
		candidate = StadiumWallTopTerraceItems.place(
			candidate, _paid.construction(), _copies[0], SITE, 0.0, access
		)
		_check(
			not _checked(candidate).ok,
			"existing rough or leveled no-paid-wall admission remains closed " + mode
		)
	var surface: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), [], false)
	var legacy: Dictionary = StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(surface)
	)
	for version in [14, 15]:
		var separate: Dictionary = legacy.duplicate(true)
		if version == 15:
			separate.version = 15
			separate.family = StadiumMountedScoreboardLayout.FAMILY
			separate["mount_catalog"] = 1
		var before: Dictionary = separate.duplicate(true)
		_check(
			(
				not separate.is_empty()
				and StadiumWallTopTerraceItems.upgrade(separate, []).is_empty()
				and ClubCareer.same(before, separate)
			),
			(
				"separate scoreboard family stays unsupported without an invented adapter "
				+ str(version)
			)
		)
		_fit_cases.append(
			{
				"case": "separate-scoreboard-family",
				"version": version,
				"terrace_adoption_refused": true,
				"input_unchanged": ClubCareer.same(before, separate)
			}
		)
	var small: Dictionary = StadiumClubSites.SITES["SCORE-SMALL"]
	var small_box: AABB = (
		Transform3D(Basis(Vector3.UP, deg_to_rad(small.yaw)), small.position)
		* StadiumClubSites.envelope(small.item)
	)
	_check(
		not StadiumPracticeFacilityItems._horizontal_overlap(box, small_box),
		"accepted current SCORE-SMALL full reservation remains clear"
	)
	_fit_cases.append(
		{
			"case": "current-score-small-reservation",
			"clear": true,
			"scoreboard_purchase_claim": false
		}
	)
	var inventory: Dictionary = _paid.construction().to_data().duplicate(true)
	var first: Dictionary = _layouts["ST-065"]
	var host_only: Dictionary = StadiumWallTopTerraceItems.store_copy(first, _copies[0])
	for site: String in ["TREE-R", "HEDGE-R1", "HEDGE-R2", "HEDGE-R3"]:
		var item: String = "ST-013" if site == "TREE-R" else "ST-014"
		var copy: String = _controls[item]
		var control: Dictionary = StadiumLandscapeOwnedItems.place(
			host_only, _paid.construction(), copy, site
		)
		var control_row: Dictionary = StadiumLandscapeOwnedItems.row(copy, item, site)
		_check(
			StadiumRisingAppleItems._overlaps(box, control_row),
			"actual whole reservation overlaps existing paid site " + site
		)
		for reverse: bool in [false, true]:
			# TERRACE_TIMING_ONLY
			var fit_started: int = _timing_mark("fit:" + site + ":" + str(reverse), "begin")
			var initial: Dictionary = first if reverse else control
			_check(
				_checked(initial).ok and _store_then_apply(initial),
				"each paid occupant installs alone before conflict " + site + ":" + str(reverse)
			)
			var conflict: Dictionary = (
				StadiumLandscapeOwnedItems.place(first, _paid.construction(), copy, site)
				if reverse
				else _place(control, _copies[0])
			)
			_check(
				(
					not _checked(conflict).ok
					and conflict.wall_top_terrace == first.wall_top_terrace
					and conflict.landscape == control.landscape
				),
				(
					"both paid placement rows remain visible on rejected conflict "
					+ site
					+ ":"
					+ str(reverse)
				)
			)
			_refused("reservation:" + site + ":" + str(reverse), conflict)
			var restored: Dictionary = (
				StadiumWallTopTerraceItems.store_copy(conflict, _copies[0])
				if reverse
				else StadiumLandscapeOwnedItems.store_copy(conflict, copy)
			)
			_check(
				(
					_checked(restored).ok
					and _store_then_apply(restored)
					and ClubCareer.same(_paid.construction().to_data(), inventory)
				),
				(
					"explicit Store selects one occupant without losing either paid copy "
					+ site
					+ ":"
					+ str(reverse)
				)
			)
			_fit_cases.append(
				{
					"case": site,
					"reverse": reverse,
					"actual_reservation_overlap": true,
					"both_rows_preserved":
					(
						conflict.wall_top_terrace == first.wall_top_terrace
						and conflict.landscape == control.landscape
					),
					"rejected": not _checked(conflict).ok,
					"stored_channel": "wall_top_terrace" if reverse else "landscape",
					"inventory_unchanged":
					ClubCareer.same(_paid.construction().to_data(), inventory)
				}
			)
			_timing_mark("fit:" + site + ":" + str(reverse), "end", fit_started)  # TERRACE_TIMING_ONLY
	var compatible: Dictionary = StadiumLandscapeOwnedItems.place(
		first, _paid.construction(), _controls["ST-013"], "TREE-L"
	)
	compatible = StadiumLandscapeOwnedItems.place(
		compatible, _paid.construction(), _controls["ST-014"], "HEDGE-L1"
	)
	_check(
		(
			_checked(compatible).ok
			and _store_then_apply(compatible)
			and compatible.landscape.size() == 2
		),
		"accepted opposite-side tree and hedge coexist with complete paid terrace"
	)
	for profile: String in ["CLUB4-LOW", "MOGUL6-STANDARD", "MOGUL4-PREMIUM"]:
		var clear: bool = true
		var sites: Array[String] = []
		for site: String in StadiumFloodlightOwnedItems.sites(profile):
			var tower: Dictionary = StadiumFloodlightOwnedItems.row(
				"clearance-only-not-a-paid-copy", profile, site
			)
			clear = (
				clear
				and not StadiumPracticeFacilityItems._horizontal_overlap(
					box, StadiumFloodlightOwnedItems.bounds(tower)
				)
			)
			sites.append(site)
		_check(
			clear and sites.size() == StadiumFloodlightOwnedItems.PROFILES[profile].count,
			"full terrace reservation leaves every authored whole tower site clear " + profile
		)
		_fit_cases.append(
			{
				"case": "tower-reservations",
				"profile": profile,
				"sites": sites,
				"clear": clear,
				"tower_purchase_claim": false
			}
		)
	_check(
		_store_then_apply(first) and ClubCareer.same(_paid.construction().to_data(), inventory),
		"original paid terrace and exact host run restored after conflict controls"
	)
	_snapshots["ST-065"] = StadiumLayoutSnapshot.capture(_paid)


func _buy(item: String, price_version: int, quantity: int, cost: int) -> Array[String]:
	var timing_started: int = _timing_mark("buy:" + item, "begin")  # TERRACE_TIMING_ONLY
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "terrace-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	var copies: Array[String] = []
	var exact: bool = result.ok
	for index in range(quantity):
		var copy: String = "purchase:terrace-buy:%d:%d" % [revision, index]
		copies.append(copy)
		exact = (
			exact
			and ClubCareer.same(
				_paid.construction().copies.get(copy, {}),
				{
					"item": item,
					"paid": StadiumCatalog.item(item).copy_price,
					"source": "purchase-v1"
				}
			)
		)
	_operands = {"item": item, "quantity": quantity, "cost": cost, "error": result.get("error", "")}
	_check(
		(
			result.ok
			and _paid.balance() == balance - cost
			and _paid.construction().copies.size() == count + quantity
		),
		"one ordinary bulk command charges exactly and adds only requested copies " + item
	)
	_check(
		exact and _paid.construction().blueprints.has(item),
		"every purchased receipt retains exact item paid-copy price and source " + item
	)
	var before: Dictionary = _paid.to_data().duplicate(true)
	var replay: Dictionary = _paid.commit(command)
	_check(
		replay.get("replayed", false) and ClubCareer.same(before, _paid.to_data()),
		"immutable purchase retry neither charges nor changes any journal field " + item
	)
	_receipts.append(
		{
			"item": item,
			"copies": copies.duplicate(),
			"quantity": quantity,
			"command_revision": revision,
			"price_version": price_version,
			"charged": cost,
			"copy_paid": StadiumCatalog.item(item).copy_price,
			"source": "purchase-v1",
			"retry_replayed": replay.get("replayed", false)
		}
	)
	_timing_mark("buy:" + item, "end", timing_started)  # TERRACE_TIMING_ONLY
	return copies if exact else []


func _negatives(first: Dictionary) -> void:
	_check(
		StadiumWallTopTerraceItems.sites() == [SITE] and StadiumWallTopTerraceItems.yaws() == [0],
		"only fixed terrace site and zero yaw are offered"
	)
	for copy: String in ["starter-v1:ST-003", _controls["ST-013"], "purchase:foreign:0"]:
		var bad: Dictionary = first.duplicate(true)
		bad.wall_top_terrace[0].copy = copy
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(_empty, copy), _empty),
			"wrong or foreign paid identity cannot become a terrace " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"second-copy",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"missing-copy",
		"non-array"
	]:
		var bad: Dictionary = first.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.wall_top_terrace.append(bad.wall_top_terrace[0].duplicate(true))
			"second-copy":
				var second: Dictionary = bad.wall_top_terrace[0].duplicate(true)
				second.copy = _copies[1]
				bad.wall_top_terrace.append(second)
			"unknown-site":
				bad.wall_top_terrace[0].site = "TERRACE-L-A"
			"unknown-field":
				bad.wall_top_terrace[0]["yaw"] = 0
			"wrong-version":
				bad.version = 35
			"missing-copy":
				bad.wall_top_terrace[0].erase("copy")
			"non-array":
				bad.wall_top_terrace = {}
		_check(not _checked(bad).ok, "exact bounded placement grammar rejects " + kind)
	for kind: String in [
		"missing", "partial-six", "mixed", "replaced", "angled", "unsupported", "forged-six"
	]:
		var bad: Dictionary = first.duplicate(true)
		match kind:
			"missing":
				bad.walls.back = {}
			"partial-six":
				bad.walls.back.copies = bad.wall_top_terrace[0].host_copies.duplicate()
			"mixed":
				bad.walls.back.copies[1] = _wall_copies["ST-077"][1]
			"replaced":
				bad = _wall(bad, "ST-077")
			"angled":
				bad = _wall(bad, "ST-065", "deeper_center")
			"unsupported":
				bad.walls.back.item = "ST-078"
			"forged-six":
				bad.wall_top_terrace[0].host_copies[0] = bad.walls.back.copies[0]
		_check(
			(
				not _checked(bad).ok
				and ClubCareer.same(
					StadiumWallTopTerraceItems.prune(bad).wall_top_terrace, bad.wall_top_terrace
				)
			),
			"invalid dependencies refuse without pruning current terrace " + kind
		)
		_refused("host-" + kind, bad)
	var rebound: Dictionary = _layouts["ST-077"].duplicate(true)
	_check(
		_checked(rebound).ok and not StadiumWallTopTerraceItems.transition(first, rebound).ok,
		"geometrically valid direct host rebinding still requires explicit Store"
	)
	_refused("direct-host-rebind", rebound)
	_check(
		ClubCareer.same(_place(first, _copies[0]), first),
		"exact mounted-copy reselect remains idempotent"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			StadiumWallTopTerraceItems.row(_copies[0], ITEM, SITE, yaw).is_empty(),
			"arbitrary or nonfinite yaw cannot escape fixed host sockets " + str(yaw)
		)
	_refused("stale-current-copy", first, true)


func _record(label: String, layout: Dictionary) -> void:
	var timing_started: int = _timing_mark("snapshot:" + label, "begin")  # TERRACE_TIMING_ONLY
	_timing_snapshot_calls += 1  # TERRACE_TIMING_ONLY
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen paid-parent snapshot " + label
	)
	_records.append(
		{
			"case": label,
			"layout": layout.duplicate(true),
			"paid_revision": _paid.revision(),
			"snapshot_version": snapshot.get("version", -1),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text()
		}
	)
	_timing_snapshot_usec += Time.get_ticks_usec() - timing_started  # TERRACE_TIMING_ONLY
	_timing_mark("snapshot:" + label, "end", timing_started)  # TERRACE_TIMING_ONLY


static func _legacy_terrain_events(events: Variant) -> bool:
	if not events is Array:
		return false
	for event: Variant in events:
		if (
			event is Dictionary
			and event.get("layout") is Dictionary
			and (
				event.layout.get("version") == 17
				or StadiumFlagItems.is_terrain(event.layout)
				or StadiumGroundPropsItems.is_terrain(event.layout)
				or StadiumStraightItems.is_terrain(event.layout)
				or StadiumRoofItems.is_terrain(event.layout)
				or StadiumFacilityItems.is_terrain(event.layout)
				or (
					StadiumBoundaryItems.is_terrain(event.layout)
					or (
						StadiumReceiverOwnedItems.is_terrain(event.layout)
						or (
							StadiumFloodlightOwnedItems.is_terrain(event.layout)
							or (
								StadiumLandscapeOwnedItems.is_terrain(event.layout)
								or (
									StadiumLiveFurnishingItems.is_terrain(event.layout)
									or (
										StadiumSmallYardSceneryItems.is_terrain(event.layout)
										or (
											StadiumMoldedSeatItems.is_terrain(event.layout)
											or (
												StadiumGroundBoxItems.is_terrain(event.layout)
												or (
													StadiumPracticeFacilityItems.is_terrain(
														event.layout
													)
													or (
														StadiumTreehouseItems.is_terrain(
															event.layout
														)
														or (
															StadiumLandmarkItems.is_terrain(
																event.layout
															)
															or (
																(
																	StadiumOutfieldBleacherItems
																	. is_terrain(event.layout)
																)
																or (
																	(
																		StadiumRisingAppleItems
																		. is_terrain(event.layout)
																	)
																	or (
																		StadiumWallTopTerraceItems
																		. is_terrain(event.layout)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		):
			return true
	return false
func _terrain_dispatch_case(label: String, events: Variant, expected: bool) -> void:
	var started: int = Time.get_ticks_usec()
	var legacy: bool = _legacy_terrain_events(events)
	_terrain_dispatch.legacy_usec += Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var current: bool = ClubAssetLedger._has_terrain_events(events)
	_terrain_dispatch.current_usec += Time.get_ticks_usec() - started
	var same: bool = legacy == current and current == expected
	_terrain_dispatch.cases.append(
		{"case": label, "expected": expected, "legacy": legacy, "current": current, "same": same}
	)
	_terrain_dispatch.all_equal = _terrain_dispatch.all_equal and same


func _terrain_public_rejection(label: String, version: Variant) -> void:
	# The old raw equality is undefined for String/bool. Exercise normal admission
	# instead; an invalid layout is rejected before any event can reach that scan.
	var probe: ClubAssetLedger = ClubAssetLedger.new_club(SEED)
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.version = version
	var before: Dictionary = probe.to_data().duplicate(true)
	var generation: int = probe.mutation_generation()
	var revision: int = probe.revision()
	var result: Dictionary = probe.commit(
		{
			"id": "terrace-malformed:" + label,
			"rev": revision,
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = ClubCareer.same(before, probe.to_data())
	var same_generation: bool = generation == probe.mutation_generation()
	var rejected: bool = not result.ok and result.error == "Unknown layout version or field family."
	_terrain_dispatch.malformed_rejections.append(
		{
			"case": label,
			"version_type": "String" if version is String else "bool",
			"public_route": "ClubAssetLedger.commit:stadium_draft",
			"error": result.get("error", ""),
			"rejected": rejected,
			"revision_before": revision,
			"revision_after": probe.revision(),
			"generation_unchanged": same_generation,
			"journal_unchanged": unchanged,
			"legacy_invoked": false
		}
	)
	_terrain_dispatch.all_rejected = (
		_terrain_dispatch.all_rejected
		and rejected
		and unchanged
		and same_generation
		and revision == probe.revision()
	)
