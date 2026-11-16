class_name StadiumMountedScoreboardSnapshot
extends RefCounted
## Exact data-only entry/fixture declarations; official production dispatch remains separate.

const VERSION: int = 14
const FIXTURE_VERSION: int = 15


static func capture(ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null or not SeasonOwnership._whole(
		ledger.view().stadium_active.get("version"), 15, 15):
		return {}
	var layout: Dictionary = ledger.view().stadium_active
	var tier: String = ledger.view().land
	return normalized({"version": VERSION, "tier": tier, "revision": ledger.revision(),
		"geometry": StadiumMountedScoreboardLayout.geometry(tier, layout), "layout": layout,
		"inventory": ledger.construction().to_data(),
		"wall_piece_inventory": ledger.wall_pieces().to_data(),
		"scoreboard_inventory": ledger.scoreboards().to_data(), "surface_access": ledger.surface_owned(),
		"boundary": StadiumMountedScoreboardLayout.boundary_signature(layout)})


static func valid(value: Variant) -> bool:
	return not _validated_ownership(value).is_empty()


# A nonempty result belongs only to this fully validated value in the current call.
static func _validated_ownership(value: Variant) -> Dictionary:
	if not _fields(value) or not value.tier is String or not StadiumLand.TIERS.has(value.tier) \
		or not SeasonOwnership._whole(value.revision, 0, ClubAssetLedger.MAX_EVENTS) \
		or not value.geometry is String or not value.boundary is String \
		or not StadiumSurfaceProgression.valid_owned(value.surface_access):
		return {}
	var owners: Dictionary = ownership(value)
	if owners.is_empty():
		return {}
	var access: Array[String] = []
	access.assign(value.surface_access)
	if not StadiumMountedScoreboardLayout.validate(value.layout, owners.stock, owners.pieces,
		access, value.tier, owners.boards).ok:
		return {}
	if value.geometry != StadiumMountedScoreboardLayout.geometry(value.tier, value.layout) \
		or value.boundary != StadiumMountedScoreboardLayout.boundary_signature(value.layout):
		return {}
	if int(value.version) == FIXTURE_VERSION \
		and not StadiumAdvancedSnapshot._environment(value.environment):
		return {}
	return owners


static func ownership(value: Dictionary) -> Dictionary:
	var stock: StadiumStock = StadiumStock.from_data(value.get("inventory"))
	if stock == null:
		return {}
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(
		value.get("wall_piece_inventory"), stock.capacity_count())
	if pieces == null:
		return {}
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(
		value.get("scoreboard_inventory"), stock.capacity_count() + pieces.stock.copies.size())
	if boards == null:
		return {}
	return {"stock": stock, "pieces": pieces, "boards": boards}


static func normalized(value: Variant) -> Dictionary:
	var owners: Dictionary = _validated_ownership(value)
	if owners.is_empty():
		return {}
	return _normalized_validated(value, owners)


# Call only with ownership returned by _validated_ownership for this same value.
static func _normalized_validated(value: Dictionary, owners: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.inventory = owners.stock.to_data()
	for copy: Dictionary in result.inventory.copies.values():
		copy.paid = int(copy.paid)
		# Stock2/3 preserve legacy receipt bytes. Freeze their snapshot counters in
		# the historical JSON-cold representation, retaining existing cold hashes.
		if result.inventory.version < StadiumStock.MASTERY_VERSION and copy.has("earned"):
			for field: String in ["version", "season_id", "season_number"]:
				copy.earned[field] = float(copy.earned[field])
			copy.earned.era.version = float(copy.earned.era.version)
	result.wall_piece_inventory = owners.pieces.to_data()
	result.scoreboard_inventory = owners.boards.to_data()
	result.version = int(result.version)
	result.revision = int(result.revision)
	result.layout.version = int(result.layout.version)
	result.layout.mount_catalog = int(result.layout.mount_catalog)
	for row: Dictionary in result.layout.obstacles:
		row.yaw = int(row.yaw)
	if result.version == FIXTURE_VERSION:
		for field: String in ["version", "seed", "fixture"]:
			result.environment[field] = int(result.environment[field])
	return result


static func key(value: Variant) -> String:
	var canonical: Dictionary = normalized(value)
	return "" if canonical.is_empty() else JSON.stringify(canonical, "", true, true).sha256_text()


static func matches(value: Variant, ledger: ClubAssetLedger) -> bool:
	var owners: Dictionary = _validated_ownership(value)
	if ledger == null or owners.is_empty() or value.revision > ledger.revision():
		return false
	var prefix: ClubAssetLedger = ledger.prefix(int(value.revision))
	if prefix == null:
		return false
	return value.tier == prefix.view().land \
		and ClubCareer.same(value.layout, prefix.view().stadium_active) \
		and ClubCareer.same(value.inventory, prefix.construction().to_data()) \
		and ClubCareer.same(value.wall_piece_inventory, prefix.wall_pieces().to_data()) \
		and ClubCareer.same(value.scoreboard_inventory, prefix.scoreboards().to_data()) \
		and ClubCareer.same(value.surface_access, prefix.surface_owned())


static func fixture(value: Variant, seed: int, index: int) -> Dictionary:
	var owners: Dictionary = _validated_ownership(value)
	if owners.is_empty() or int(value.version) != VERSION or seed < 0 or seed > 2147483647 \
		or index < 0 or index > 32:
		return {}
	var result: Dictionary = _normalized_validated(value, owners)
	result.version = FIXTURE_VERSION
	result["environment"] = {"version": StadiumFixtureEnvironment.VERSION,
		"seed": seed, "fixture": index, "mode": "day", "profile": ""}
	return result


static func _fields(value: Variant) -> bool:
	if not value is Dictionary \
		or not SeasonOwnership._whole(value.get("version"), VERSION, FIXTURE_VERSION):
		return false
	var keys: Array = ["version", "tier", "revision", "geometry", "layout", "inventory",
		"wall_piece_inventory", "scoreboard_inventory", "surface_access", "boundary"]
	if int(value.version) == FIXTURE_VERSION:
		keys.append("environment")
	return SeasonOwnership._keys(value, keys) and value.layout is Dictionary \
		and SeasonOwnership._whole(value.layout.get("version"), 15, 15) \
		and SeasonOwnership._whole(value.layout.get("mount_catalog"), 1, 1)
