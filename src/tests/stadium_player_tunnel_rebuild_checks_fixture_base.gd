extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One bounded native ST-058 qualification. Explicit synthetic funds/progress; zero games.

const SEED: int = 161
const ITEM: String = "ST-058"
# Source-frozen success path; never inferred from native result.
const EXPECTED_NON_GEOMETRY_CHECKS: int = 301
const EXPECTED_PHASE_CHECKS: Dictionary = {"ownership": 160, "fit": 10, "runtime_and_views": 124}
const HANDS: Array[String] = ["R", "L"]
var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _empty: Dictionary = {}
var _layouts: Dictionary = {}
var _snapshots: Dictionary = {}
var _receipts: Array[Dictionary] = []
var _lifecycle: Array[Dictionary] = []
var _refusals: Array[Dictionary] = []
var _fit: Array[Dictionary] = []
var _runtime: Array[Dictionary] = []
var _cameras: Array[Dictionary] = []
var _focus: Array[Dictionary] = []
var _phases: Dictionary = {}
var _tunnel_geometry: Dictionary = {}
var _model_checks: int = 0
var _outcomes: Array = []
var _last_draft: Dictionary = {}
var _last_apply: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"PLAYER_TUNNEL_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _checked(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.validate(layout, _paid.construction(), tier)
	_operands = {
		"tier": tier,
		"version": layout.get("version", -1),
		"error": result.get("error", ""),
		"tunnels": layout.get("player_tunnels", [])
	}
	return result


func _fit_checks() -> void:
	_phase = "complete-hand-reservation-and-property-gates"
	for hand: String in HANDS:
		for tier: String in ["backyard", "expanded", "club", "mogul"]:
			var checked: Dictionary = _checked(_layouts[hand], tier)
			var eligible: bool = tier in ["club", "mogul"]
			_check(
				checked.ok == eligible,
				"full exact host assembly admits only Club and Mogul " + hand + ":" + tier
			)
			_fit.append(
				{
					"hand": hand,
					"tier": tier,
					"eligible": eligible,
					"accepted": checked.ok,
					"error": checked.get("error", "")
				}
			)
		var row: Dictionary = _checked(_layouts[hand]).player_tunnel_placements[0]
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position
		)
		var reserve: AABB = pose * StadiumPlayerTunnelModels.ENVELOPE
		_check(
			(
				pose.basis.determinant() > 0.9999
				and pose.basis.get_scale().is_equal_approx(Vector3.ONE)
				and StadiumProperty.contains("club", reserve)
				and StadiumClubSites._outside(reserve)
			),
			"whole roof supports and closed port stay full-size outside live play " + hand
		)


func _apply(layout: Dictionary) -> bool:
	_last_draft = {
		"id": "tunnel-draft:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_draft",
		"layout": layout
	}
	var draft: Dictionary = _paid.commit(_last_draft)
	if not draft.ok:
		_operands = {"stage": "draft", "error": draft.get("error", "")}
		return false
	_last_apply = {
		"id": "tunnel-apply:%d" % _paid.revision(),
		"rev": _paid.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(_paid.view().land, layout)
	}
	var applied: Dictionary = _paid.commit(_last_apply)
	_operands = {"stage": "apply", "error": applied.get("error", "")}
	return applied.ok


func _buy(item: String, quantity: int, version: int, cost: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "tunnel-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var balance: int = _paid.balance()
	var count: int = _paid.construction().copies.size()
	var result: Dictionary = _paid.commit(command)
	_copies[item] = []
	var exact: bool = result.ok
	for index: int in range(quantity):
		var copy: String = "purchase:tunnel-buy:%d:%d" % [revision, index]
		_copies[item].append(copy)
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
		"ordinary purchase charges exact unchanged blueprint and copy prices " + item
	)
	_check(
		exact and _paid.construction().blueprints.has(item),
		"every requested paid copy retains exact item price and source " + item
	)
	var before: Dictionary = _paid.to_data().duplicate(true)
	var replay: Dictionary = _paid.commit(command)
	_check(
		replay.get("replayed", false) and ClubCareer.same(before, _paid.to_data()),
		"immutable purchase retry preserves complete journal " + item
	)
	_receipts.append(
		{
			"item": item,
			"copies": _copies[item].duplicate(),
			"quantity": quantity,
			"command_revision": revision,
			"price_version": version,
			"charged": cost,
			"copy_paid": StadiumCatalog.item(item).copy_price,
			"source": "purchase-v1",
			"retry_replayed": replay.get("replayed", false)
		}
	)


func _host(
	layout: Dictionary, hand: String, kind: String, copy: String, remove: bool = false
) -> Dictionary:
	if kind == "dugout":
		return StadiumBoundaryItems.select(
			layout,
			_paid.construction(),
			copy,
			(
				{}
				if remove
				else {
					"copy": "",
					"item": _paid.construction().copies[copy].item,
					"site": "DUGOUT-" + hand,
					"host": ""
				}
			)
		)
	return StadiumStraightItemsUI.select(
		layout,
		_paid.construction(),
		copy,
		{} if remove else {"copy": "", "site": "BASE-" + hand + "1", "lower": "", "concourse": ""}
	)


func _place(layout: Dictionary, hand: String, copy: String) -> Dictionary:
	return StadiumPlayerTunnelItems.place(
		layout, _paid.construction(), copy, "TUNNEL-" + hand, 0.0, _paid.surface_owned()
	)


func _refused(label: String, layout: Dictionary, stale: bool = false) -> void:
	var before: Dictionary = _paid.to_data().duplicate(true)
	var generation: int = _paid.mutation_generation()
	var result: Dictionary = _paid.commit(
		{
			"id": "tunnel-refuse:" + label,
			"rev": _paid.revision() - (1 if stale else 0),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	var unchanged: bool = (
		ClubCareer.same(before, _paid.to_data()) and generation == _paid.mutation_generation()
	)
	_operands = {"case": label, "error": result.get("error", ""), "unchanged": unchanged}
	_check(
		not result.ok and unchanged,
		"ordinary draft refuses without journal or generation mutation " + label
	)
	_refusals.append(
		{
			"case": label,
			"rejected": not result.ok,
			"unchanged": unchanged,
			"error": result.get("error", "")
		}
	)


func _negatives(common: Dictionary) -> void:
	for copy: String in ["starter-v1:ST-003", _copies["ST-032"][0], "purchase:foreign:0"]:
		var bad: Dictionary = _layouts.R.duplicate(true)
		bad.player_tunnels[0].copy = copy
		_check(
			not _checked(bad).ok and ClubCareer.same(_place(common, "R", copy), common),
			"wrong or foreign paid identity cannot become tunnel " + copy
		)
	for kind: String in [
		"duplicate-copy",
		"unknown-site",
		"unknown-field",
		"wrong-version",
		"missing-copy",
		"non-array",
		"wrong-dugout",
		"wrong-lower"
	]:
		var bad: Dictionary = _layouts.R.duplicate(true)
		match kind:
			"duplicate-copy":
				bad.player_tunnels.append(bad.player_tunnels[0].duplicate(true))
			"unknown-site":
				bad.player_tunnels[0].site = "TUNNEL-R2"
			"unknown-field":
				bad.player_tunnels[0]["yaw"] = 0
			"wrong-version":
				bad.version = 36
			"missing-copy":
				bad.player_tunnels[0].erase("copy")
			"non-array":
				bad.player_tunnels = {}
			"wrong-dugout":
				bad.player_tunnels[0].dugout = _copies["ST-074"][1]
			"wrong-lower":
				bad.player_tunnels[0].lower = _copies["ST-029"][1]
		_check(not _checked(bad).ok, "exact bounded placement grammar rejects " + kind)
	var timber: Dictionary = _host(common, "R", "dugout", _copies["ST-032"][0])
	_check(
		_checked(timber).ok and ClubCareer.same(_place(timber, "R", _copies[ITEM][0]), timber),
		"open timber cannot host a covered player tunnel"
	)
	var base2: Dictionary = common.duplicate(true)
	for row: Dictionary in base2.hosts:
		if row.copy == _copies["ST-029"][0]:
			row.site = "BASE-R2"
	_check(
		(
			not StadiumPlayerTunnelItems.host_info(base2, _paid.construction(), "TUNNEL-R").ok
			and ClubCareer.same(_place(base2, "R", _copies[ITEM][0]), base2)
		),
		"BASE2 cannot substitute for same-side BASE1"
	)
	_check(
		ClubCareer.same(_place(_empty, "R", _copies[ITEM][0]), _empty),
		"bare template side cannot host a tunnel"
	)
	for yaw: float in [45.0, 180.0, INF]:
		_check(
			ClubCareer.same(
				StadiumPlayerTunnelItems.place(
					common,
					_paid.construction(),
					_copies[ITEM][0],
					"TUNNEL-R",
					yaw,
					_paid.surface_owned()
				),
				common
			),
			"arbitrary or nonfinite yaw cannot escape host frame " + str(yaw)
		)
	_check(
		ClubCareer.same(_place(_layouts.R, "R", _copies[ITEM][0]), _layouts.R),
		"exact mounted-copy reselect is idempotent"
	)
	_refused("stale-current-copy", _layouts.R, true)


func _record(label: String, layout: Dictionary) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			not snapshot.is_empty()
			and StadiumLayoutSnapshot.matches(snapshot, _paid)
			and ClubCareer.same(snapshot.layout, layout)
		),
		"exact frozen paid layout snapshot " + label
	)
	_lifecycle.append(
		{
			"case": label,
			"revision": _paid.revision(),
			"layout": layout.duplicate(true),
			"snapshot_version": snapshot.get("version", -1),
			"snapshot_sha256": JSON.stringify(snapshot, "", true, true).sha256_text()
		}
	)


func _ownership() -> void:
	_phase = "exact-paid-hosts-store-first-and-cold-journal"
	for index: int in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4})
	_check(
		StadiumCareerProgress.valid(_progress, _credits),
		"synthetic closed metrics are valid without an earned career claim"
	)
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"adoption grants no tunnel or required hosts"
	)
	var entry: Dictionary = StadiumCatalog.item(ITEM)
	var gate: Dictionary = {"seasons": 12, "wins": 36}
	_check(
		(
			entry.blueprint_price == 420
			and entry.copy_price == 110
			and ClubCareer.same(entry.requires, gate)
		),
		"unchanged ST058 exact S12 W36 and 420 plus110 prices"
	)
	_check(
		StadiumPurchases.quote(_paid.construction(), ITEM, 2, "tunnel-gate", 28, gate).ok,
		"current price28 accepts exact unlock threshold"
	)
	for key: String in gate:
		var below: Dictionary = gate.duplicate(true)
		below[key] -= 1
		_check(
			not (
				StadiumPurchases
				. quote(_paid.construction(), ITEM, 2, "tunnel-below:" + key, 28, below)
				. ok
			),
			"each just below unlock operand refuses " + key
		)
	_check(
		not StadiumPurchases.quote(_paid.construction(), ITEM, 2, "tunnel-old-price", 27, gate).ok,
		"older price27 route cannot purchase tunnel"
	)
	_buy(ITEM, 2, 28, 640)
	_buy("ST-074", 3, 15, 920)
	_buy("ST-029", 3, 12, 720)
	_buy("ST-032", 1, 15, 550)
	_buy("ST-043", 1, 10, 245)
	if _failures != 0:
		return
	_check(
		_paid.construction().copies.size() == 13 and StadiumLayoutSnapshot.matches(starter, _paid),
		"five normal purchases create exactly ten paid copies and preserve starter prefix"
	)
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "tunnel-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == 13,
			"ordinary land purchase grants no construction copies " + tier
		)
	var inherited: Dictionary = StadiumWallTopTerraceItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	inherited.flags = [{"copy": _copies["ST-043"][0], "site": "FLAG-GROUND-L"}]
	_check(
		_checked(inherited).ok and _apply(inherited),
		"accepted family36 applies with nonempty exact paid flag control"
	)
	_record("inherited-family36", inherited)
	if _failures != 0:
		return
	var prefix: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_empty = StadiumPlayerTunnelItems.upgrade(inherited, _paid.surface_owned())
	_check(
		(
			_empty.get("version", -1) == 37
			and _empty.get("player_tunnels") is Array
			and _empty.player_tunnels.is_empty()
			and ClubCareer.same(StadiumPlayerTunnelItems.base(_empty), inherited)
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"empty family37 preserves every inherited channel and paid flag"
	)
	_record("empty-tunnel-family", _empty)
	if _failures != 0:
		return
	var balance: int = _paid.balance()
	for hand: String in HANDS:
		var index: int = HANDS.find(hand)
		for first: String in ["dugout", "lower"]:
			var second: String = "lower" if first == "dugout" else "dugout"
			var host_ids: Dictionary = {
				"dugout": _copies["ST-074"][index], "lower": _copies["ST-029"][index]
			}
			_check(
				_apply(_empty),
				"explicit stored baseline begins finite host order " + hand + ":" + first
			)
			var one: Dictionary = _host(_empty, hand, first, host_ids[first])
			_check(
				_checked(one).ok and _apply(one),
				"first exact host installs independently " + hand + ":" + first
			)
			_check(
				ClubCareer.same(_place(one, hand, _copies[ITEM][index]), one),
				"single host cannot fabricate missing tunnel dependency " + hand + ":" + first
			)
			var both: Dictionary = _host(one, hand, second, host_ids[second])
			_check(
				_checked(both).ok and _apply(both),
				"second exact host completes same side dependency order " + hand + ":" + first
			)
			var mounted: Dictionary = _place(both, hand, _copies[ITEM][index])
			_check(
				(
					_checked(mounted).ok
					and mounted.player_tunnels.size() == 1
					and mounted.player_tunnels[0].dugout == host_ids.dugout
					and mounted.player_tunnels[0].lower == host_ids.lower
					and _apply(mounted)
				),
				"tunnel binds exact paid host identities " + hand + ":" + first
			)
			_record("mounted:" + hand + ":" + first, mounted)
			if _failures != 0:
				return
			for removed_kind: String in ["dugout", "lower"]:
				var missing: Dictionary = _host(
					mounted, hand, removed_kind, host_ids[removed_kind], true
				)
				_check(
					(
						not _checked(missing).ok
						and ClubCareer.same(missing.player_tunnels, mounted.player_tunnels)
					),
					(
						"removing required host preserves tunnel row and refuses "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
				_refused("host-remove:" + hand + ":" + first + ":" + removed_kind, missing)
				var replacement: String = _copies[
					"ST-074" if removed_kind == "dugout" else "ST-029"
				][2]
				var changed: Dictionary = _host(mounted, hand, removed_kind, replacement)
				_refused("host-replace:" + hand + ":" + first + ":" + removed_kind, changed)
				var rebound: Dictionary = _place(
					StadiumPlayerTunnelItems.store_copy(changed, _copies[ITEM][index]),
					hand,
					_copies[ITEM][index]
				)
				_check(
					(
						_checked(rebound).ok
						and not StadiumPlayerTunnelItems.transition(mounted, rebound).ok
					),
					(
						"valid direct paid host rebinding requires explicit prior Store "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
				_refused("host-rebind:" + hand + ":" + first + ":" + removed_kind, rebound)
				var stored: Dictionary = StadiumPlayerTunnelItems.store_copy(
					mounted, _copies[ITEM][index]
				)
				_check(
					(
						ClubCareer.same(stored, both)
						and _checked(stored).stored.has(_copies[ITEM][index])
						and _apply(stored)
					),
					(
						"Store retains all other channels and exact host copies "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
				var removed: Dictionary = _host(
					stored, hand, removed_kind, host_ids[removed_kind], true
				)
				_check(
					_checked(removed).ok and _apply(removed),
					(
						"host removal succeeds after explicit saved tunnel Store "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
				var restored: Dictionary = _host(
					removed, hand, removed_kind, host_ids[removed_kind]
				)
				_check(
					(
						_checked(restored).ok
						and restored.player_tunnels.is_empty()
						and _apply(restored)
					),
					(
						"host restoration keeps tunnel stored "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
				_check(
					(
						ClubCareer.same(_place(restored, hand, _copies[ITEM][index]), mounted)
						and _apply(mounted)
					),
					(
						"same paid tunnel explicitly remounts with exact hosts "
						+ hand
						+ ":"
						+ first
						+ ":"
						+ removed_kind
					)
				)
			_check(
				(
					_apply(both)
					and _paid.balance() == balance
					and _paid.construction().copies.size() == 13
				),
				"finite dependency orders add no charge or copies " + hand + ":" + first
			)
	var common: Dictionary = _empty.duplicate(true)
	for hand: String in HANDS:
		var index: int = HANDS.find(hand)
		common = _host(common, hand, "dugout", _copies["ST-074"][index])
		common = _host(common, hand, "lower", _copies["ST-029"][index])
	_check(
		_checked(common).ok and _apply(common),
		"both paid host pairs coexist with unchanged flag and template remaining walls"
	)
	if _failures != 0:
		return
	for hand: String in HANDS:
		var layout: Dictionary = _place(common, hand, _copies[ITEM][HANDS.find(hand)])
		_check(
			_checked(layout).ok and _apply(layout), "current paid handed assembly applies " + hand
		)
		_layouts[hand] = layout.duplicate(true)
		_record("current:" + hand, layout)
		_snapshots[hand] = StadiumLayoutSnapshot.capture(_paid)
		_check(_apply(common), "explicit Store separates native capture handed layouts " + hand)
	_check(_apply(_layouts.R), "right handed current layout restored before refusal probes")
	_negatives(common)
	var retry: Dictionary = _paid.to_data().duplicate(true)
	_check(
		(
			_paid.commit(_last_draft).get("replayed", false)
			and _paid.commit(_last_apply).get("replayed", false)
			and ClubCareer.same(retry, _paid.to_data())
		),
		"exact draft and apply retries preserve complete journal"
	)
	_snapshots.R = StadiumLayoutSnapshot.capture(_paid)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data(), "", true, true)),
		SEED,
		_credits,
		_progress
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and _paid.to_data().version == 45
			and StadiumLayoutSnapshot.matches(prefix, cold)
			and StadiumLayoutSnapshot.matches(_snapshots.R, cold)
			and StadiumLayoutSnapshot.matches(_snapshots.L, cold)
		),
		"full cold ledger45 replay authenticates family36 prefix and both exact handed snapshots"
	)
	_check(
		(
			_paid.balance() == balance
			and _paid.construction().copies.size() == 13
			and ClubCareer.same(_layouts.R.flags, inherited.flags)
			and ClubCareer.same(_layouts.L.flags, inherited.flags)
		),
		"cold lifecycle retains exact price inventory and nonempty unrelated paid flag channel"
	)


func _project_rect(camera: Camera3D, box: AABB) -> Rect2:
	var result: Rect2 = Rect2()
	var started: bool = false
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		result = result.expand(pixel) if started else Rect2(pixel, Vector2.ZERO)
		started = true
	return result


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func _camera_clearance(lab: PitchBatLab, model: Node3D, hand: String) -> void:
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	var old_pose: Transform3D = lab._camera.transform
	for left: bool in [false, true]:
		for zoom: bool in [false, true]:
			director.set_batter_handedness(left)
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.set_presentation_motion(
				(
					MatchCameraDirector.PresentationMotion.ZOOM_IN
					if zoom
					else MatchCameraDirector.PresentationMotion.STILL
				),
				1.0
			)
			var pose: Transform3D = director._desired_transform(PitchBatLab.MOUND_ORIGIN, 0.0)
			lab._camera.transform = pose
			director._apply_projection(lab._camera)
			lab._camera.reset_physics_interpolation()
			lab._camera.force_update_transform()
			await RenderingServer.frame_post_draw
			var protected: Rect2 = (
				_project_rect(
					lab._camera,
					AABB(PitchBatLab.MOUND_ORIGIN + Vector3(-1.6, 0, -0.8), Vector3(3.2, 3.6, 1.6))
				)
				. grow(16)
			)
			var reserve: AABB = model.global_transform * StadiumPlayerTunnelModels.ENVELOPE
			var target: Vector3 = PitchBatLab.MOUND_ORIGIN + Vector3.UP
			var blocked: bool = (
				reserve.has_point(pose.origin)
				or reserve.intersects_segment(pose.origin, target) != null
			)
			var clear: bool = true
			var visible: int = 0
			var count: int = 0
			for node: Node in model.get_node("Visual").find_children(
				"*", "MeshInstance3D", true, false
			):
				var mesh: MeshInstance3D = node as MeshInstance3D
				count += 1
				var projected: Rect2 = _project_rect(
					lab._camera, mesh.global_transform * mesh.get_aabb()
				)
				if projected.has_area():
					visible += 1
					clear = clear and not projected.intersects(protected)
			_operands = {
				"hand": hand,
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"pitcher_target": _v3(target),
				"blocked": blocked,
				"backdrop_clear": clear,
				"visible_meshes": visible,
				"checked_meshes": count
			}
			_check(
				not blocked and clear and protected.has_area(),
				(
					"actual normal and zoom batting camera clears complete tunnel and pitcher backdrop "
					+ hand
				)
			)
			_cameras.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose
	director._apply_projection(lab._camera)
	lab._camera.reset_physics_interpolation()
	lab._camera.force_update_transform()


func _moving_ball(
	lab: PitchBatLab, property: StadiumPropertyGeometry, model: Node3D, hand: String, kind: String
) -> Dictionary:
	_phase = "native-unchanged-dugout-front:" + hand + ":" + kind
	var left: bool = hand == "L"
	var foul: bool = kind == "foul-opening"
	var live: bool = kind == "live-face"
	var expected_role: String = (
		"DUGOUT_FACE_LIVE"
		if live
		else "DUGOUT_ROOF_TERMINAL" if kind == "roof" else "DUGOUT_OPENING_DEAD"
	)
	var from: Vector3 = (
		StadiumDugoutRecipe.rail_point(11 if live else 13, -0.8, left)
		+ Vector3.UP * (2.38 if kind == "roof" else 0.5)
	)
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.segment_observer = lab._ball_play_resolver.segment_observer
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	lab.add_child(ball)
	ball.position = from
	_check(
		(
			resolver.segment_observer.is_valid()
			and StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		),
		"ordinary runtime binds fresh native moving ball to installed boundary " + hand + ":" + kind
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = StadiumDugoutRecipe.placement(left).basis.z * 20
	ball.launch(launch)
	for frame: int in range(45):
		await get_tree().physics_frame
		resolver.advance_time(1.0 / 60.0)
		if not resolver.state.stadium_contacts.is_empty():
			break
	var events: Array = resolver.state.stadium_contacts.duplicate(true)
	_operands = {
		"hand": hand,
		"case": kind,
		"events": events,
		"outcomes": _outcomes.size(),
		"at": _v3(ball.global_position)
	}
	_check(
		events.size() == 1 and events[0].role == expected_role and events[0].source == "boundary",
		"native front hit retains existing paid dugout boundary role " + hand + ":" + kind
	)
	var expected_result: int = (
		BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.SINGLE
	)
	var result_ok: bool = (
		not resolver.state.dead and _outcomes.is_empty()
		if live
		else (
			resolver.state.dead and _outcomes.size() == 1 and _outcomes[0].result == expected_result
		)
	)
	_check(
		result_ok,
		(
			"fair terminal keeps minimum Single foul remains Foul and front barrier stays live "
			+ hand
			+ ":"
			+ kind
		)
	)
	var result_before: int = int(_outcomes[0].result) if _outcomes.size() == 1 else -1
	var dead_before: bool = resolver.state.dead
	var count_before: int = _outcomes.size()
	for body: Node in model.find_children("*", "StaticBody3D", true, false):
		property._ball_contact(body, ball, resolver)
	_check(
		(
			_outcomes.size() == count_before
			and resolver.state.dead == dead_before
			and ClubCareer.same(events, resolver.state.stadium_contacts)
			and (result_before == -1 or int(_outcomes[0].result) == result_before)
		),
		(
			"issued tunnel callbacks cannot create award change result or revive terminal ball "
			+ hand
			+ ":"
			+ kind
		)
	)
	var result_name: String = "out" if live else "foul" if foul else "single"
	var reason: String = str(_outcomes[0].reason) if _outcomes.size() == 1 else ""
	var rows: Array = [{"play": 0, "reason": reason, "events": events}]
	var plays: Array = [
		{
			"result": result_name,
			"contact": ContactResult.Outcome.FOUL if foul else ContactResult.Outcome.CONTACT,
			"exit_speed": 20.0
		}
	]
	var accepted: bool = PhysicalStadiumContacts.valid(rows, plays, _snapshots[hand])
	_check(
		not events.is_empty() and accepted,
		"ordinary report accepts actual exact front contact " + hand + ":" + kind
	)
	var forged: Array = rows.duplicate(true)
	if not events.is_empty():
		forged[0].events[0].surface = "INVENTED-TUNNEL-SCORE"
	var rejected: bool = (
		not events.is_empty() and not PhysicalStadiumContacts.valid(forged, plays, _snapshots[hand])
	)
	_check(
		rejected, "same actual report rejects invented tunnel scoring surface " + hand + ":" + kind
	)
	var evidence: Dictionary = {
		"case": kind,
		"launch_position": _v3(from),
		"launch_velocity": _v3(launch.velocity),
		"registration_physics_frames": 2,
		"expected_role": expected_role,
		"expected_result": result_name,
		"actual_result": result_before,
		"reason": reason,
		"events": events,
		"terminal": resolver.state.dead,
		"outcome_count": _outcomes.size(),
		"later_callbacks_unchanged": result_ok and count_before == _outcomes.size(),
		"report_accepted": accepted,
		"forged_surface_rejected": rejected,
		"complete_game_claim": false
	}
	ball.free()
	await get_tree().physics_frame
	return evidence
