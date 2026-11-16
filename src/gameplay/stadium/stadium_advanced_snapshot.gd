class_name StadiumAdvancedSnapshot
extends RefCounted
## Pure exact-data qualification only. Production snapshot/report gates remain separate.

const VERSION: int = 10
const FIXTURE_VERSION: int = 11


static func capture(ledger: ClubAssetLedger) -> Dictionary:
	if ledger == null or not SeasonOwnership._whole(
		ledger.view().stadium_active.get("version"), 13, 13):
		return {}
	var layout: Dictionary = ledger.view().stadium_active
	var tier: String = ledger.view().land
	var result: Dictionary = {"version": VERSION, "tier": tier, "revision": ledger.revision(),
		"geometry": StadiumOwnedLayout.geometry(tier, layout), "layout": layout,
		"inventory": ledger.construction().to_data(),
		"wall_piece_inventory": ledger.wall_pieces().to_data(),
		"surface_access": ledger.surface_owned(),
		"boundary": StadiumOwnedLayout.boundary_signature(layout)}
	return normalized(result)


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._whole(
		value.get("version"), VERSION, FIXTURE_VERSION):
		return false
	var fields: Array = ["version", "tier", "revision", "geometry", "layout", "inventory",
		"wall_piece_inventory", "surface_access", "boundary"]
	if int(value.version) == FIXTURE_VERSION:
		fields.append("environment")
	if not SeasonOwnership._keys(value, fields) or not value.tier is String \
		or not StadiumLand.TIERS.has(value.tier) \
		or not SeasonOwnership._whole(value.revision, 0, ClubAssetLedger.MAX_EVENTS) \
		or not value.layout is Dictionary \
		or not SeasonOwnership._whole(value.layout.get("version"), 13, 13) \
		or not value.geometry is String or not value.boundary is String \
		or not StadiumSurfaceProgression.valid_owned(value.surface_access):
		return false
	var stock: StadiumStock = StadiumStock.from_data(value.inventory)
	var pieces: StadiumWallPieceOwnership = piece_ownership(value, stock)
	var access: Array[String] = []
	access.assign(value.surface_access)
	if stock == null or pieces == null or not StadiumOwnedLayout.validate(
		value.layout, stock, pieces, access, value.tier).ok:
		return false
	if value.geometry != StadiumOwnedLayout.geometry(value.tier, value.layout) \
		or value.boundary != StadiumOwnedLayout.boundary_signature(value.layout):
		return false
	return int(value.version) != FIXTURE_VERSION or _environment(value.environment)


static func piece_ownership(value: Dictionary, stock: StadiumStock) -> StadiumWallPieceOwnership:
	return null if stock == null else StadiumWallPieceOwnership.from_data(
		value.get("wall_piece_inventory"), stock.capacity_count())


static func normalized(value: Variant) -> Dictionary:
	if not valid(value):
		return {}
	var result: Dictionary = value.duplicate(true)
	var stock: StadiumStock = StadiumStock.from_data(result.inventory)
	result.inventory = stock.to_data()
	for copy: Dictionary in result.inventory.copies.values():
		copy.paid = int(copy.paid)
		# Keep legacy earned snapshots stable across live and JSON-cold inputs.
		# Strict ownership validation has already completed; raw stock is untouched.
		if result.inventory.version < StadiumStock.MASTERY_VERSION and copy.has("earned"):
			for field: String in ["version", "season_id", "season_number"]:
				copy.earned[field] = float(copy.earned[field])
			copy.earned.era.version = float(copy.earned.era.version)
	result.wall_piece_inventory = piece_ownership(result, stock).to_data()
	result.version = int(result.version)
	result.revision = int(result.revision)
	result.layout.version = int(result.layout.version)
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
	if ledger == null or not valid(value) or value.revision > ledger.revision():
		return false
	var prefix: ClubAssetLedger = ledger.prefix(int(value.revision))
	if prefix == null:
		return false
	return value.tier == prefix.view().land \
		and ClubCareer.same(value.layout, prefix.view().stadium_active) \
		and ClubCareer.same(value.inventory, prefix.construction().to_data()) \
		and ClubCareer.same(value.wall_piece_inventory, prefix.wall_pieces().to_data()) \
		and ClubCareer.same(value.surface_access, prefix.surface_owned())


static func fixture(value: Variant, seed: int, index: int) -> Dictionary:
	if not valid(value) or int(value.version) != VERSION or seed < 0 or seed > 2147483647 \
		or index < 0 or index > 32:
		return {}
	var result: Dictionary = normalized(value)
	result.version = FIXTURE_VERSION
	result["environment"] = {"version": StadiumFixtureEnvironment.VERSION,
		"seed": seed, "fixture": index, "mode": "day", "profile": ""}
	return result


static func _environment(value: Variant) -> bool:
	return value is Dictionary and SeasonOwnership._keys(value,
		["version", "seed", "fixture", "mode", "profile"]) \
		and SeasonOwnership._whole(value.version, StadiumFixtureEnvironment.VERSION,
			StadiumFixtureEnvironment.VERSION) \
		and SeasonOwnership._whole(value.seed, 0, 2147483647) \
		and SeasonOwnership._whole(value.fixture, 0, 32) \
		and value.mode is String and value.mode == "day" \
		and value.profile is String and value.profile.is_empty()
