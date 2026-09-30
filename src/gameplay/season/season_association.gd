class_name SeasonAssociation
extends RefCounted
## Working earned access; the purchased seasonal copy supplies capacity, not free sponsors.

const ITEMS: Dictionary = {
	"J05":
	{
		"name": "Neighborhood Association",
		"price": 14,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Add two active sponsor slots, including this copy. Every other active sponsor "
			+ "must be Common. Removing this sponsor requires choosing any extra sales "
			+ "needed to fit the final capacity."
		)
	}
}


static func commons(build: SeasonBuild) -> int:
	var distinct: Dictionary = {}
	for receipt: Dictionary in build._bank.view().sponsors:
		if SeasonSponsorCatalog.item(receipt.item).get("rarity") == "Common":
			distinct[receipt.item] = true
	return distinct.size()


static func earn(build: SeasonBuild, command: Dictionary) -> void:
	if build._format < 28 or build._association_start == null:
		return
	if command.op in ["sponsor_buy", "sponsor_sell", "wholesale"] and commons(build) >= 5:
		build._association_earned = true


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.association_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.association_earned != null) != (build._association_start != null):
		return false
	return (
		build._association_start == null
		or (
			build._association_start == access(club, true)
			and (not exact or run.association_earned == build._association_earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Neighborhood Association • "
			+ ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Season: confirm five distinct Common sponsors active together in a saved legal "
			+ "loadout. 14 Season Cash • Uncommon • Working. "
			+ ITEMS.J05.effect
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._association_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
	else:
		SeasonPages.wrapped(card, "Active Commons: %d / 5" % mini(5, commons(build)))
