extends RefCounted
## Actual paid journal transforms on an explicitly authored-history fixture.
static func apply(club: ClubCareer, version: int = 45) -> bool:
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	if paid == null:
		print("FLAT_ROUTE_FIXTURE no paid source")
		return false
	if not commit(club, {"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY,
		"through": ClubPlayers.income_through(club), "price_version": 1}): return false
	paid = ClubPlayers.assets(club)
	var purchase: Dictionary = ClubConstruction.copy_command(club, "ST-001", paid.revision())
	var bought: Dictionary = ClubPlayers.command(club, purchase)
	if not bought.ok:
		print("FLAT_ROUTE_FIXTURE buy ", bought)
		return false
	paid = ClubPlayers.assets(club)
	var layout: Dictionary = StadiumMasteryBannerItems.upgrade(paid.view().stadium_active, paid.surface_owned())
	if version == 45: layout = StadiumWaterfallLiveItems.upgrade(layout, paid.surface_owned())
	layout.obstacles = [{"copy": "purchase:" + purchase.id + ":0", "site": "O-L1", "yaw": 0}]
	if not commit(club, {"op": "stadium_draft", "layout": layout}): return false
	if not commit(club, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(paid.view().land, layout)}): return false
	var valid: bool = ClubCareer.from_data(club.to_data()) != null
	if not valid: print("FLAT_ROUTE_FIXTURE final history refused")
	return valid
static func commit(club: ClubCareer, fields: Dictionary) -> bool:
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	var command: Dictionary = fields.duplicate(true)
	command.id = "flat-route:" + str(paid.revision())
	command.rev = paid.revision()
	var applied: Dictionary = ClubPlayers.command(club, command)
	if not applied.ok: print("FLAT_ROUTE_FIXTURE ", command.op, " ", applied)
	return applied.ok
