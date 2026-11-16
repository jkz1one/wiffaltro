extends Node
## Pure data regression. No mounted model construction, runtime admission or scene activation.

const ACCESS: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY
const PROGRESS: Dictionary = {"seasons": 50, "wins": 200}
const SHAPES: Array[String] = [
	"straight", "deeper_center", "left_loft", "right_shelf", "offset_gables"]
const MATERIALS: Array[String] = ["ST-024", "ST-065", "ST-077", "ST-078"]
var _failures: int = 0
var _stock: StadiumStock
var _pieces: StadiumWallPieceOwnership
var _boards: StadiumScoreboardOwnership


func _ready() -> void:
	_fund()
	var signatures: Array[String] = _signatures()
	_catalog()
	_matrix()
	_clearance_rejections()
	_upgrades()
	_storage()
	_malformed()
	_resolved_rows()
	_ownership()
	_frozen_sources()
	_check(_signatures() == signatures, "all old signatures and frozen keys remain unchanged")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard data passed: frozen catalog1 and complete layout15.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund() -> void:
	_stock = StadiumStock.new_club()
	for id: String in ["ST-039", "ST-040", "ST-041"] + MATERIALS:
		_stock = StadiumStock.from_data(_stock.quote(id, 27 if MATERIALS.has(id) else 2,
			PROGRESS, id).state)
	_pieces = StadiumWallPieceOwnership.new()
	for material: String in MATERIALS:
		for suffix: String in ["-L", "-T"]:
			var id: String = material + suffix
			_pieces = StadiumWallPieceOwnership.from_data(_pieces.quote(
				id, 12, id, PROGRESS, _stock.copies.size()).state, _stock.copies.size())
	_boards = StadiumScoreboardOwnership.new()
	_boards = StadiumScoreboardOwnership.from_data(_boards.quote(2, "electronic", PROGRESS,
		_stock.copies.size() + _pieces.stock.copies.size()).state,
		_stock.copies.size() + _pieces.stock.copies.size())


func _base() -> Dictionary:
	return StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ACCESS, true)))


func _upgrade(layout: Dictionary, tier: String = "mogul") -> Dictionary:
	return StadiumMountedScoreboardLayout.upgrade(layout, _stock, _pieces, ACCESS, tier, _boards)


func _validate(layout: Variant, tier: String = "mogul") -> Dictionary:
	return StadiumMountedScoreboardLayout.validate(layout, _stock, _pieces, ACCESS, tier, _boards)


func _row(item: String, site: String, center: bool = false, index: int = 0) -> Dictionary:
	return {"copy": "scoreboard:electronic:%d" % index if item == "ST-090" else (
		"purchase:%s:%d" % [item, index]), "item": item,
		"model": StadiumScoreboardModels.MODELS[item], "site": site,
		"mount_profile": StadiumScoreboardMountCatalog.CENTER_PROFILE if center else ""}


func _center() -> Dictionary:
	var layout: Dictionary = _upgrade(_base())
	layout.scoreboards = [_row("ST-090", StadiumScoreboardMountCatalog.CENTER_SITE, true)]
	return layout


func _catalog() -> void:
	var signature: String = StadiumScoreboardMountCatalog.signature(1)
	var legacy_upright: Dictionary = {"ST-039": false, "ST-090": true, "ST-040": true}
	var profile: Dictionary = StadiumScoreboardMountCatalog.profile(
		StadiumScoreboardMountCatalog.CENTER_PROFILE, 1)
	_check(profile.support.size() == 12 and profile.lift == 2.4 and profile.cost == 0
		and not profile.blueprint and not profile.grant and not profile.collision
		and profile.day_only and not profile.allow_upright,
		"mount is zero-cost, nongranting, noncollision, day-only and camera-upright-disabled")
	_check(profile.envelope == [[-4.4, 0, -1.1], [8.8, 10.8, 2.2]]
		and profile.support_envelope == [[-3.4, 0, -1.1], [6.8, 7.8, 2.2]]
		and profile.cabinet_envelope == [[-4.4, 7.6, -0.4], [8.8, 3.2, 0.8]]
		and profile.display_path == "Visual/ElectronicV2Cabinet/Visual/ScoreDisplay",
		"exact full/support/cabinet envelopes and display path are signature inputs")
	profile.support[0].size[0] = 1000
	profile.envelope[0][0] = -1000
	profile.remove_model_nodes.clear()
	_check(StadiumScoreboardMountCatalog.signature(1) == signature,
		"returned nested mount data cannot mutate catalog1")
	for version: Variant in [0, 2, 1.25, "1", true, null]:
		_check(StadiumScoreboardMountCatalog.signature(version).is_empty()
			and StadiumScoreboardMountCatalog.profile(
				StadiumScoreboardMountCatalog.CENTER_PROFILE, version).is_empty(),
			"unknown/future/nonexact catalog versions reject")
	for site: String in StadiumScoreboardSites.SITES:
		for item: String in StadiumScoreboardSites.SITES[site].items:
			var tier: String = StadiumScoreboardCatalog.TIERS[item]
			var model: String = StadiumScoreboardModels.MODELS[item]
			var record: Dictionary = StadiumScoreboardMountCatalog.record(item, model, site, "", 1)
			_check(record.allow_upright == legacy_upright[item]
				and record.allow_upright == (not StadiumPurchases.DISPLAYS.has(item)),
				"empty-profile manual/electronic/video preserve frozen camera upright policy")
			var old: Dictionary = StadiumScoreboardTiers.readouts(tier)
			old.merge(StadiumScoreboardTiers.detail_slots(tier))
			var regions: Dictionary = StadiumScoreboardMountCatalog.readouts(item, model, site, "", 1)
			_check(ClubCareer.same(regions, old), "frozen v2 readout/font regions match every old item")
			_check(StadiumScoreboardMountCatalog.pose(item, model, site, "", 1)
				== StadiumScoreboardSites.pose(site), "empty mount profile keeps exact v2 socket pose")
			regions.clear()
	var center: Dictionary = StadiumScoreboardMountCatalog.record("ST-090", "electronic-v2",
		StadiumScoreboardMountCatalog.CENTER_SITE, StadiumScoreboardMountCatalog.CENTER_PROFILE, 1)
	_check(not center.allow_upright,
		"raised electronic profile overrides only its own model's legacy upright policy")
	var regions: Dictionary = StadiumScoreboardMountCatalog.readouts("ST-090", "electronic-v2",
		StadiumScoreboardMountCatalog.CENTER_SITE, StadiumScoreboardMountCatalog.CENTER_PROFILE, 1)
	_check(regions.size() == 9 and is_equal_approx(regions.home.point.y, 8.35),
		"all nine electronic regions are lifted exactly2.4m")
	regions.home.point = Vector3.ZERO
	_check(StadiumScoreboardMountCatalog.signature(1) == signature, "region reads are detached")
	_check(StadiumScoreboardMountCatalog.sites(1).size() == 4
		and StadiumScoreboardSites.SITES.size() == 3, "new site exists only in mount catalog1")


func _matrix() -> void:
	var setbacks: Array[float] = [5.90, 3.30, 2.30, 1.791302, 1.30]
	for shape: String in SHAPES:
		for material: String in MATERIALS:
			var before: Dictionary = _base()
			if shape in ["straight", "deeper_center"]:
				before.walls = StadiumWallLayout.propose(before.walls, _stock, "back", material, shape).walls
			else:
				before.advanced_back = StadiumAdvancedWallManifest.suggest(
					shape, material, _stock, _pieces.stock).manifest
			var layout: Dictionary = _upgrade(before)
			layout.scoreboards = [_row("ST-090", StadiumScoreboardMountCatalog.CENTER_SITE, true)]
			for land: String in StadiumLand.TIERS:
				var checked: Dictionary = _validate(layout, land)
				_check(checked.ok, "complete center/material/shape/land: %s/%s/%s" % [material, shape, land])
				if not checked.ok:
					continue
				_partition(checked)
				_check(not checked.night_qualified, "mount is never a night qualification")
			var graph: StadiumRecipeBoundary = StadiumMountedScoreboardLayout.graph_for(layout)
			var site: Dictionary = StadiumScoreboardMountCatalog.inspect("ST-090", "electronic-v2",
				StadiumScoreboardMountCatalog.CENTER_SITE, StadiumScoreboardMountCatalog.CENTER_PROFILE,
				1, "backyard", graph)
			_check(site.ok and absf(site.outer_wall_setback - setbacks[SHAPES.find(shape)]) < 0.0001,
				"joined wall miter setback is exact: " + shape)
			_check(StadiumMountedScoreboardLayout.boundary_signature(layout)
				== StadiumOwnedLayout.boundary_signature(before), "mount never changes boundary identity")
			_check(_validate(JSON.parse_string(JSON.stringify(layout))).ok, "JSON layout15 round trip")
			if material == "ST-024":
				_old_socket_matrix(graph)
	var checked: Dictionary = _validate(_center(), "backyard")
	var box: AABB = StadiumMountedScoreboardLayout.bounds(checked.board_placements[0])
	_check(box.position.is_equal_approx(Vector3(-4.4, 0, 29.65))
		and box.end.is_equal_approx(Vector3(4.4, 10.8, 31.85))
		and is_equal_approx(32 - box.end.z, 0.15), "tight backyard rear margin is exactly0.15m")
	_check(not StadiumProperty.contains("backyard", box.grow(0.151)),
		"slightly larger unapproved support violates backyard property")
	_check(not StadiumScoreboardLayout._walls_clear(
		AABB(Vector3(24.577, 0.2, 23.743), Vector3(0.005, 0.2, 0.005)), checked,
		StadiumRecipeBoundary.create("straight")), "actual acute joined outer miter rejects overlap")


func _old_socket_matrix(graph: StadiumRecipeBoundary) -> void:
	for site: String in StadiumScoreboardSites.SITES:
		for item: String in StadiumScoreboardCatalog.IDS:
			for tier: String in StadiumLand.TIERS:
				var old: Dictionary = StadiumScoreboardSites.inspect(item, site, tier, graph)
				var next: Dictionary = StadiumScoreboardMountCatalog.inspect(item,
					StadiumScoreboardModels.MODELS[item], site, "", 1, tier, graph)
				_check(next.ok == old.ok, "all old model/site/shape/property verdicts stay exact")
				if old.ok:
					_check(next.bounds == old.bounds and next.pose == old.pose,
						"old accepted socket full bounds and pose stay exact")


func _upgrades() -> void:
	var before: Dictionary = _base()
	before.scoreboards = [_row("ST-040", "BOARD-LARGE-v2"), _row("ST-039", "BOARD-LEFT-v2"),
		_row("ST-090", "BOARD-RIGHT-v2")]
	for row: Dictionary in before.scoreboards:
		row.erase("mount_profile")
	var original: Dictionary = before.duplicate(true)
	var after: Dictionary = _upgrade(before)
	var round_trip: Dictionary = after.duplicate(true)
	round_trip.erase("mount_catalog")
	round_trip.version = 14
	round_trip.family = StadiumScoreboardLayout.FAMILY
	for row: Dictionary in round_trip.scoreboards:
		row.erase("mount_profile")
	_check(ClubCareer.same(round_trip, before) and ClubCareer.same(before, original),
		"old three-board grammar upgrades and round trips with every field unchanged")
	var preview: Dictionary = StadiumMountedScoreboardLayout.preview(
		before, after, _stock, _pieces, ACCESS, "mogul", _boards)
	_check(preview.ok and preview.cost == 0 and preview.displaced.is_empty()
		and preview.moved.is_empty(), "empty profiles preserve physical comparison identity")
	_check(StadiumMountedScoreboardLayout.geometry("mogul", after)
		!= StadiumScoreboardLayout.geometry("mogul"), "new mount family has a distinct geometry key")
	_check(_upgrade(StadiumScoreboardLayout.base(before)).is_empty(),
		"direct13 and silent historical upgrades reject")
	var bad: Dictionary = before.duplicate(true)
	bad["unknown"] = true
	_check(_upgrade(bad).is_empty(), "upgrade validates every exact14 field")
	bad = before.duplicate(true)
	bad.scoreboards[0].copy = "unowned"
	_check(_upgrade(bad).is_empty(), "upgrade requires exact ownership before adding mount grammar")
	after.scoreboards[0].copy = "changed"
	_check(ClubCareer.same(before, original), "upgrade return is deeply detached")


func _storage() -> void:
	var before: Dictionary = _base()
	before.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"},
		{"copy": "purchase:ST-041:0", "site": "SIGN-GROUND-R"}]
	var after: Dictionary = _upgrade(before)
	after.displays.remove_at(0)
	after.scoreboards = [_row("ST-090", StadiumScoreboardMountCatalog.CENTER_SITE, true)]
	var preview: Dictionary = StadiumMountedScoreboardLayout.preview(
		before, after, _stock, _pieces, ACCESS, "mogul", _boards)
	_check(preview.ok and preview.cost == 0 and preview.displaced == ["purchase:ST-039:0"]
		and preview.stored.has("purchase:ST-039:0")
		and not preview.scoreboards_stored.has("scoreboard:electronic:0")
		and after.displays == [before.displays[1]], "replacement stores exact old copy and keeps sign")
	_partition(preview.placement)
	var empty: Dictionary = after.duplicate(true)
	empty.scoreboards = []
	preview = StadiumMountedScoreboardLayout.preview(
		after, empty, _stock, _pieces, ACCESS, "mogul", _boards)
	_check(preview.ok and preview.displaced == ["scoreboard:electronic:0"]
		and preview.scoreboards_stored.size() == 2, "stored center copy returns to electronic inventory")
	var old_site: Dictionary = after.duplicate(true)
	old_site.scoreboards = [_row("ST-090", "BOARD-RIGHT-v2")]
	preview = StadiumMountedScoreboardLayout.preview(after, old_site,
		_stock, _pieces, ACCESS, "mogul", _boards)
	_check(preview.ok and preview.moved == ["scoreboard:electronic:0"]
		and preview.displaced.is_empty(), "same owned copy moves from center back to original socket")
	var multiple: Dictionary = _center()
	multiple.scoreboards.append_array([_row("ST-040", "BOARD-LARGE-v2"),
		_row("ST-039", "BOARD-LEFT-v2"), _row("ST-090", "BOARD-RIGHT-v2", false, 1)])
	var checked: Dictionary = _validate(multiple)
	_check(checked.ok and checked.board_placements.size() == 4,
		"historical multiboard grammar accepts four distinct compatible sockets")
	_partition(checked)
	checked.board_placements[0].position = Vector3.ZERO
	checked.stored.clear()
	_check(_validate(multiple).ok, "mutating returned placements and storage cannot change inputs")
	var overlap: Dictionary = _upgrade(before)
	overlap.scoreboards = [_row("ST-039", "BOARD-LEFT-v2", false, 1)]
	_check(not _validate(overlap).ok, "distinct copies cannot overlap retained legacy furniture")
	overlap.scoreboards[0].site = "BOARD-RIGHT-v2"
	_check(_validate(overlap).ok, "retained old board/sign coexist with nonoverlapping right board")
	overlap.scoreboards[0].copy = "purchase:ST-039:0"
	_check(not _validate(overlap).ok, "same manual copy cannot appear in legacy and mount channels")


func _malformed() -> void:
	var source: Dictionary = _center()
	for field: String in ["family", "extra", "version", "catalog", "rows", "copy", "item", "model",
		"site", "profile", "position", "yaw", "lift", "validated"]:
		var bad: Dictionary = source.duplicate(true)
		match field:
			"family": bad.family = "other"
			"extra": bad["unknown"] = true
			"version": bad.version = 16
			"catalog": bad.mount_catalog = 2
			"rows": bad.scoreboards = {}
			"copy": bad.scoreboards[0].copy = "unowned"
			"item": bad.scoreboards[0].item = "ST-039"
			"model": bad.scoreboards[0].model = "electronic-v3"
			"site": bad.scoreboards[0].site = "BOARD-RIGHT-v2"
			"profile": bad.scoreboards[0].mount_profile = "unknown"
			"position": bad.scoreboards[0]["position"] = [0, 0, 31]
			"yaw": bad.scoreboards[0]["yaw"] = 0
			"lift": bad.scoreboards[0]["lift"] = 9
			"validated": bad["already_valid"] = true
		_check(not _validate(bad).ok, "strict layout/profile/pose rejection: " + field)
	for value: Variant in ["", null, 1, true]:
		var bad: Dictionary = source.duplicate(true)
		bad.scoreboards[0].mount_profile = value
		_check(not _validate(bad).ok, "center requires the one exact typed profile")
	var duplicate: Dictionary = source.duplicate(true)
	duplicate.scoreboards.append(_row("ST-090", "BOARD-RIGHT-v2"))
	_check(not _validate(duplicate).ok, "center and original socket cannot consume same copy")
	duplicate.scoreboards[1].copy = "scoreboard:electronic:1"
	_check(_validate(duplicate).ok, "separate paid electronic copies may occupy distinct sockets")
	duplicate.scoreboards.reverse()
	_check(not _validate(duplicate).ok, "canonical site ordering remains required")
	duplicate.scoreboards = [source.scoreboards[0], source.scoreboards[0].duplicate(true)]
	duplicate.scoreboards[1].copy = "scoreboard:electronic:1"
	_check(not _validate(duplicate).ok, "one center reservation cannot hold two copies")
	var placement: Dictionary = _validate(source).board_placements[0]
	placement.position.z += 0.01
	_check(StadiumScoreboardMountCatalog.bounds(placement, 1) == AABB(),
		"geometry helpers reject a supplied pose instead of accepting altered center")


func _resolved_rows() -> void:
	var saved_rows: Array[Dictionary] = [
		_row("ST-090", StadiumScoreboardMountCatalog.CENTER_SITE, true),
		_row("ST-039", "BOARD-LEFT-v2"), _row("ST-090", "BOARD-RIGHT-v2"),
		_row("ST-040", "BOARD-LARGE-v2")]
	var malformed: Array = [null, false, true, "bad", [], [0, 0, 30.75], {}, {"x": 0},
		Vector2.ZERO, Vector3.ZERO, Vector3i.ZERO, Vector4.ZERO, 0, 1.25, -180, 540, INF, -INF, NAN,
		Vector3(INF, 0, 30.75), Vector3(0, -INF, 30.75), Vector3(0, 0, NAN)]
	for saved: Dictionary in saved_rows:
		var pose: Transform3D = StadiumScoreboardMountCatalog.pose(saved.item, saved.model,
			saved.site, saved.mount_profile, 1)
		var resolved: Dictionary = saved.duplicate(true)
		resolved.merge({"position": pose.origin, "yaw": 180, "role": StadiumScoreboardMountCatalog.ROLE})
		var expected: AABB = StadiumScoreboardMountCatalog.bounds(saved, 1)
		_check(expected != AABB() and StadiumScoreboardMountCatalog.bounds(resolved, 1) == expected,
			"exact resolved center and three old board tiers preserve saved bounds")
		resolved.yaw = 180.0
		_check(StadiumScoreboardMountCatalog.bounds(resolved, 1) == expected,
			"finite whole-valued float yaw retains legitimate JSON numeric parity")
		for field: String in ["role", "position", "yaw"]:
			for value: Variant in malformed:
				var bad: Dictionary = resolved.duplicate(true)
				bad[field] = value
				_check(StadiumScoreboardMountCatalog.bounds(bad, 1) == AABB(),
					"malformed resolved field rejects without a script error: " + field)
			var missing: Dictionary = resolved.duplicate(true)
			missing.erase(field)
			_check(StadiumScoreboardMountCatalog.bounds(missing, 1) == AABB(),
				"partial resolved row is not a legitimate persisted row")
		resolved["approved"] = true
		_check(StadiumScoreboardMountCatalog.bounds(resolved, 1) == AABB(),
			"resolved row still rejects unrecognized extra keys")


func _ownership() -> void:
	var layout: Dictionary = _center()
	var no_copy: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	no_copy.blueprints = ["ST-090"]
	_check(not StadiumMountedScoreboardLayout.validate(layout, _stock, _pieces,
		ACCESS, "mogul", no_copy).ok, "blueprint is not an owned electronic copy")
	_check(not StadiumMountedScoreboardLayout.validate(layout, _stock, _pieces,
		ACCESS, "mogul", null).ok, "complete electronic inventory is mandatory")
	var bad_boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(
		_boards.to_data())
	bad_boards.copies["scoreboard:electronic:0"].paid = 0
	_check(not StadiumMountedScoreboardLayout.validate(layout, _stock, _pieces,
		ACCESS, "mogul", bad_boards).ok, "corrupted electronic payment receipt rejects")
	var bad_stock: StadiumStock = StadiumStock.from_data(_stock.to_data())
	bad_stock.copies["purchase:ST-039:0"].paid = 0
	_check(not StadiumMountedScoreboardLayout.validate(layout, bad_stock, _pieces,
		ACCESS, "mogul", _boards).ok, "even unused corrupted standard copy rejects")
	var bad_pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(_pieces.to_data())
	bad_pieces.stock.copies[bad_pieces.stock.copies.keys()[0]].paid = 0
	_check(not StadiumMountedScoreboardLayout.validate(layout, _stock, bad_pieces,
		ACCESS, "mogul", _boards).ok, "even unused corrupted wall piece rejects")
	bad_pieces.stock = null
	_check(not StadiumMountedScoreboardLayout.validate(layout, _stock, bad_pieces,
		ACCESS, "mogul", _boards).ok, "null nested piece inventory fails closed")
	var count: int = StadiumStock.MAX_COPIES - _stock.copies.size() \
		- _pieces.stock.copies.size() - _boards.copies.size()
	var filled: StadiumStock = StadiumStock.from_data(_stock.quote("ST-001", count,
		PROGRESS, "capacity").state)
	_check(StadiumMountedScoreboardLayout.validate(
		layout, filled, _pieces, ACCESS, "mogul", _boards).ok,
		"three-inventory4096 limit is accepted exactly")
	filled = StadiumStock.from_data(filled.quote("ST-001", 1, PROGRESS, "overflow").state)
	_check(not StadiumMountedScoreboardLayout.validate(layout, filled, _pieces,
		ACCESS, "mogul", _boards).ok, "three-inventory4097 cannot hide in stored copies")


func _partition(checked: Dictionary) -> void:
	if not checked.ok:
		return
	var seen: Dictionary = {}
	for row: Dictionary in checked.placements + checked.board_placements \
		+ checked.wall_panels + checked.advanced_panels:
		_check(not seen.has(row.copy), "one exact placed copy appears once")
		seen[row.copy] = true
	for channel: String in ["stored", "pieces_stored", "scoreboards_stored"]:
		for key: String in checked[channel]:
			_check(not seen.has(key), "one exact stored copy appears once")
			seen[key] = true
	_check(seen.size() == _stock.copies.size() + _pieces.stock.copies.size() + _boards.copies.size(),
		"every physical copy is placed or stored exactly once across all inventories")


func _signatures() -> Array[String]:
	return [StadiumCatalog.signature(), StadiumScoreboardCatalog.signature(),
		StadiumScoreboardSites.signature(), StadiumScoreboardModels.signature(),
		StadiumScoreboardLayout.signature(), StadiumAdvancedWallLayout.signature(),
		StadiumScoreboardLayout.geometry("mogul"), StadiumOwnedLayout.boundary_signature(_base()),
		StadiumScoreboardMountCatalog.signature(1)]


func _frozen_sources() -> void:
	var gameplay: String = "res://src/gameplay/stadium/stadium_scoreboard_"
	var art: String = "res://src/presentation/stadium/stadium_scoreboard_"
	var hashes: Dictionary = {
		gameplay + "catalog.gd": "30482f13892d0245109e9cf9b7f63558620a53da433eda7542380257198d39ad",
		gameplay + "sites.gd": "1e06360bdbc88fb45cc4321b84a6393c6f90bbefa8c74a1e30757a2d6d3e18af",
		gameplay + "tier_sites.gd": "2877a534dce360a82dd15e54b6c81259042dfe6f0077889cee864d227fad6908",
		gameplay + "layout.gd": "2c0664a2acb6d81638f5d7cb3457d3414f98cb3d242351957ddec0a772a5bb2d",
		gameplay + "ownership.gd": "392fcff1d2c6a6c35cc9978a04fa1f47b916eee178ee58145874ac8e89d5abe0",
		art + "models.gd": "ab5d5f2c6b49d6d9f47830cf4e83dd7acd1611f92bfddaca8b087c50490851d1",
		art + "tiers.gd": "b8ffe92afcf58cd0ec684d42006f5a86ab4fddd7683d80480ca276c4323bb921",
		art + "tier_display.gd": "42f93d4acd2d8b4dfc9b25d8fdb40c9df2fa2128dac02e720184df6e703317fb"}
	for path: String in hashes:
		_check(FileAccess.get_sha256(path) == hashes[path], "qualified complete14 bytes frozen: " + path)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


class OccludingWall extends StadiumRecipeBoundary:
	func segments() -> Array[Dictionary]:
		var rows: Array[Dictionary] = super.segments()
		rows[3].height = 20.0
		return rows


class NearSupportWall extends StadiumRecipeBoundary:
	func outer_vertex(index: int) -> Vector2:
		var point: Vector2 = super.outer_vertex(index)
		point.y = 29.2 if index == 3 else point.y
		return point


func _clearance_rejections() -> void:
	for graph: StadiumRecipeBoundary in [OccludingWall.new(), NearSupportWall.new()]:
		var checked: Dictionary = StadiumScoreboardMountCatalog.inspect("ST-090", "electronic-v2",
			StadiumScoreboardMountCatalog.CENTER_SITE, StadiumScoreboardMountCatalog.CENTER_PROFILE,
			1, "mogul", graph)
		_check(not checked.ok, "full readout occlusion and joined support setback fail closed")
	var placement: Dictionary = _validate(_center()).board_placements[0]
	placement["approved"] = true
	_check(StadiumScoreboardMountCatalog.bounds(placement, 1) == AABB(),
		"bounds cannot accept extra caller-supplied approval fields")
