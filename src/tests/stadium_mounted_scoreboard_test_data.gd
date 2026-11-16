extends RefCounted
## Test-only paid fixtures. Every owned copy still comes through the original journal operations.

const SEED: int = 31
const HEADER_VERSIONS: Dictionary = {
	"starter_grant": 2, "starter_catalog": 2, "draft_catalog": 3, "property_catalog": 4,
	"construction_catalog": 5, "seating_catalog": 6, "seating_layout_catalog": 6,
	"land_catalog": 7, "style_catalog": 8, "appearance_catalog": 8,
	"display_catalog": 9, "display_layout_catalog": 9,
	"ground_catalog": 10, "ground_layout_catalog": 10,
	"bleacher_catalog": 11, "bleacher_layout_catalog": 11,
	"target_catalog": 12, "target_layout_catalog": 12,
	"net_catalog": 13, "net_layout_catalog": 13,
	"light_catalog": 14, "light_layout_catalog": 14,
	"infield_catalog": 15, "infield_layout_catalog": 15,
	"wall_catalog": 16, "wall_layout_catalog": 16,
	"surface_catalog": 17, "surface_origin": 17, "surface_layout_catalog": 17,
	"wall_piece_catalog": 18, "advanced_layout_catalog": 19,
	"scoreboard_catalog": 20, "scoreboard_layout_catalog": 21,
	"mounted_scoreboard_layout_catalog": 22, "pool_catalog": 23, "pool_layout_catalog": 23}


static func credits() -> Array:
	var result: Array = []
	result.resize(22)
	result.fill(100000)
	return result


static func progress() -> Array:
	var result: Array = []
	for index in range(22):
		result.append({"seasons": 1, "wins": 4})
	return result


static func fund() -> ClubAssetLedger:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(SEED, credits(), progress())
	for tier: String in ["expanded", "club", "mogul"]:
		if not ledger.commit({"id": "land-" + tier, "rev": ledger.revision(),
			"op": "stadium_land", "tier": tier, "through": 22, "progress_through": 22,
			"price_version": StadiumLand.VERSION}).ok:
			return null
	if not ledger.commit(buy(ledger, "stadium_buy", "ST-024", 27, 8)).ok:
		return null
	for item: String in ["ST-024-L", "ST-024-T"]:
		if not ledger.commit(buy(ledger, "stadium_wall_piece", item, 12)).ok:
			return null
	for item: String in StadiumScoreboardCatalog.IDS:
		if not ledger.commit(buy(ledger, "stadium_scoreboard", item, 2)).ok:
			return null
	return ledger


static func layout14(ledger: ClubAssetLedger, shape: String = "straight") -> Dictionary:
	var result: Dictionary = StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)))
	if shape in ["straight", "deeper_center"]:
		result.walls = StadiumWallLayout.propose(
			result.walls, ledger.construction(), "back", "ST-024", shape).walls
	else:
		result.advanced_back = StadiumAdvancedWallManifest.suggest(
			shape, "ST-024", ledger.construction(), ledger.wall_pieces().stock).manifest
	result.receiver = "starter-v1:ST-079"
	return result


static func mounted(ledger: ClubAssetLedger, shape: String = "straight") -> Dictionary:
	var result: Dictionary = StadiumMountedScoreboardLayout.upgrade(layout14(ledger, shape),
		ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land,
		ledger.scoreboards())
	if result.is_empty():
		return {}
	result.scoreboards = [{"copy": copy_id(ledger.scoreboards().copies, "ST-090"),
		"item": "ST-090", "model": "electronic-v2",
		"site": StadiumScoreboardMountCatalog.CENTER_SITE,
		"mount_profile": StadiumScoreboardMountCatalog.CENTER_PROFILE}]
	return result


static func apply(ledger: ClubAssetLedger, layout: Dictionary) -> bool:
	var revision: int = ledger.revision()
	if not ledger.commit({"id": "draft%d" % revision, "rev": revision,
		"op": "stadium_draft", "layout": layout}).ok:
		return false
	var geometry: String = StadiumMountedScoreboardLayout.geometry(ledger.view().land, layout) \
		if int(layout.version) == 15 else StadiumOwnedLayout.geometry(ledger.view().land, layout)
	return ledger.commit({"id": "apply%d" % revision, "rev": ledger.revision(),
		"op": "stadium_apply", "layout": layout, "geometry": geometry}).ok


static func buy(ledger: ClubAssetLedger, op: String, item: String,
	quantity: int, price: int = 1) -> Dictionary:
	var result: Dictionary = {"id": "buy%d" % ledger.revision(), "rev": ledger.revision(),
		"op": op, "item": item, "quantity": quantity, "through": 22,
		"progress_through": 22, "price_version": price}
	if op == "stadium_buy" and price == 1:
		result.erase("progress_through")
	return result


static func copy_id(copies: Dictionary, item: String) -> String:
	for key: String in copies:
		if copies[key].item == item:
			return key
	return ""


static func historical(data: Dictionary, version: int) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result.version = version
	for field: String in HEADER_VERSIONS:
		if HEADER_VERSIONS[field] > version:
			result.erase(field)
	return result


static func restore(data: Dictionary) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(data)),
		SEED, credits(), progress())


static func state(ledger: ClubAssetLedger) -> Dictionary:
	return {"view": ledger.view(), "stock": ledger.construction().to_data(),
		"pieces": ledger.wall_pieces().to_data(), "boards": ledger.scoreboards().to_data(),
		"data": ledger.to_data()}
