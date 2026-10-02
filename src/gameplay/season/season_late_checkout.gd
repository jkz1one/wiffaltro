class_name SeasonLateCheckout
extends RefCounted
## Working source contract; earned access is separate from paid seasonal ownership.

const ITEMS: Dictionary = {
	"G03":
	{
		"name": "Late Checkout Motel",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Once per game, after a walk with active Tape or Plan, choose one effect for "
			+ "the immediate next batter in the same half. Keep Plan's exact swing. "
			+ "Uses that PA's supply allowance; no copy, extra consumption or chain."
		)
	}
}


static func valid_walk(
	build: SeasonBuild, action: Dictionary, owned: Dictionary, performance: Dictionary
) -> bool:
	return (
		build._format >= 27
		and build._checkout_start != null
		and action.walked is bool
		and action.walked
		and owned.item in ["A10", "C03"]
		and action.get("player") is String
		and performance.get(action.player, {}).get("bb", 0) >= 1
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var earned: bool = access(menu.app.season.career)
	menu._label(card, "Late Checkout Motel • " + ("SHOP ELIGIBLE" if earned else "LOCKED"), 22)
	SeasonPages.wrapped(
		card,
		(
			"Game: earn a credited walk while an original Tape or Plan is active. "
			+ "Complete the game to retain access. Inherited effects do not count. "
			+ "12 Season Cash • Uncommon • Working. "
			+ ClubCollectionUI.effect(menu, "G03")
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._checkout_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.checkout_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.checkout_earned != null) != (build._checkout_start != null):
		return false
	return (
		build._checkout_start == null
		or (
			build._checkout_start == access(club, true)
			and (not exact or run.checkout_earned == build._checkout_earned)
		)
	)
