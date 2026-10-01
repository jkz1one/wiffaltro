class_name SeasonCarbonCopy
extends RefCounted
## Working E09: exact pregame source; shared events and separate bounded contributions.

# gdlint: disable=max-returns

const ITEMS: Dictionary = {
	"E09":
	{
		"name": "Carbon Copy Printing",
		"price": 20,
		"rarity": "Rare",
		"weight": 0.25,
		"effect":
		(
			"Before a game, copy one active Deli or Take Your Base. Both occupy a slot. "
			+ "Deli's shared Single chain gives +8.16% fair Contact exit speed combined; "
			+ "Take Your Base pays 2 extra Cash for each of the first two credited walks. "
			+ "The exact source must remain active. No extra events or recursive copies."
		)
	}
}

var start: Variant = null
var earned: bool = false
var selections: Dictionary = {}


func fork() -> SeasonCarbonCopy:
	var result: SeasonCarbonCopy = SeasonCarbonCopy.new()
	result.start = start
	result.earned = earned
	result.selections = selections.duplicate(true)
	return result


static func sources(build: SeasonBuild) -> Array:
	return build._bank.view().sponsors.filter(
		func(receipt: Dictionary) -> bool: return receipt.item in ["A07", "D01"]
	)


static func commit(build: SeasonBuild, command: Dictionary) -> String:
	if (
		build._format < 35
		or build._market != 0
		or not build._keys(command, ["game", "receipt"])
		or not SeasonOwnership._whole(command.game, 0, 32)
		or not command.receipt is String
	):
		return "Choose an exact Carbon Copy source for this game."
	var game: String = str(int(command.game))
	if (
		build._copy.selections.has(game)
		or build._pregames.has(game)
		or build._bank.view().rewards.has(game)
	):
		return "Carbon Copy is locked for this game."
	var sponsor: Dictionary = SeasonSchoolSponsors.active(build, "E09")
	if sponsor.is_empty():
		return "Carbon Copy must be active."
	var source: Dictionary = SeasonOwnership._owned(build._bank.view(), command.receipt)
	if command.receipt == "":
		if not sources(build).is_empty():
			return "Choose the active Deli or Take Your Base source."
	elif source.get("kind") != "sponsor" or source.get("item") not in ["A07", "D01"]:
		return "Only an active Deli or Take Your Base can be copied."
	build._copy.selections[game] = {
		"source": command.receipt, "item": source.get("item", ""), "copy": sponsor.id
	}
	return ""


static func choose(app: SeasonApp, build: SeasonBuild, game: int) -> String:
	if (
		build._copy.selections.has(str(game))
		or SeasonSchoolSponsors.active(build, "E09").is_empty()
	):
		return ""
	if not sources(build).is_empty() and (app.copy_game != game or app.copy_receipt == "?"):
		return "Choose Carbon Copy's source in Prepare Next Game before playing."
	var result: Dictionary = build.commit(
		{
			"id": "copy-select:%d" % game,
			"rev": build.revision(),
			"op": "copy_select",
			"game": game,
			"receipt": "" if sources(build).is_empty() else app.copy_receipt
		}
	)
	return "" if result.ok else result.error


static func target(build: SeasonBuild, game: int) -> String:
	var mark: Dictionary = build._copy.selections.get(str(game), {})
	if mark.is_empty() or mark.item == "":
		return ""
	if (
		SeasonSchoolSponsors.active(build, "E09").get("id", "") != mark.copy
		or SeasonSchoolSponsors.active(build, mark.item).get("id", "") != mark.source
	):
		return ""
	return mark.item


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if target(build, int(command.game)) != "D01":
		return ""
	var source: Dictionary = SeasonSchoolSponsors.active(build, "D01")
	var income: int = (
		SeasonSponsorCatalog
		. earnings([source], build.roster(), command.get("performance", {}))
		. get("D01", 0)
	)
	if income == 0:
		return ""
	var paid: Dictionary = build._bank.commit(
		{
			"id": "carbon-income:%d" % int(command.game),
			"rev": build._bank.revision(),
			"op": "sponsor_income",
			"amount": income
		}
	)
	if not paid.ok:
		return paid.error
	build._income_by_game[int(command.game)]["E09"] = income
	return ""


static func deli_bonus(state: MatchState) -> float:
	if not SeasonSponsorEffects.deli_active(state):
		return 0.0
	if (
		state.batting_team().copy_source == "A07"
		and state.batter().definition.season_sponsors.get("E09", false)
	):
		# Only the paired Deli contribution compounds. Preserve other additive modifiers.
		return 1.04 * 1.04 - 1.0
	return 0.04


static func count(build: SeasonBuild) -> int:
	var distinct: Dictionary = {}
	for receipt: Dictionary in build._bank.view().sponsors:
		distinct[receipt.item] = true
	return distinct.size()


static func earn(build: SeasonBuild, command: Dictionary) -> void:
	if build._format < 35 or build._copy.start == null:
		return
	if command.op in ["sponsor_buy", "sponsor_sell", "wholesale"] and count(build) >= 4:
		build._copy.earned = true


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.copy_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.copy_earned != null) != (build._copy.start != null):
		return false
	return (
		build._copy.start == null
		or (
			build._copy.start == access(club, true)
			and (not exact or run.copy_earned == build._copy.earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Carbon Copy Printing • "
			+ ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Season: confirm four distinct sponsors active together in a saved legal "
			+ "loadout. 20 Season Cash • Rare • Working. "
			+ ITEMS.E09.effect
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._copy.start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
	else:
		SeasonPages.wrapped(card, "Active sponsors: %d / 4" % mini(4, count(build)))
