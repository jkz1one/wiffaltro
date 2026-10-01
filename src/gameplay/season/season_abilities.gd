class_name SeasonAbilities
extends RefCounted
# gdlint: disable=max-returns
## Working learned slots; purchases replay into player-local, season-only receipts.

const COUNT: String = "ability.A05"
const HANDS: String = "ability.A06"
const SKY: String = "ability.C01"
const ITEMS: Dictionary = {
	COUNT:
	{
		"name": "Work the Count",
		"slot": "Hitting",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect": "After two actual called balls in this PA, spatial X/Y radii gain +6%."
	},
	HANDS:
	{
		"name": "Soft Hands",
		"slot": "Fielding",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Grounded clean-control margin +0.10 after reach, height and reaction eligibility. "
			+ "Primary Fielder or pitcher."
		)
	},
	SKY:
	{
		"name": "Sky Reader",
		"slot": "Fielding",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Primary Fielder initial reaction delay ×0.60 on fair launches at least 25°. "
			+ "No speed or reach bonus."
		)
	}
}

var from_visit: int = 1
var start: Variant = null
var earned: int = 0
var learned: Dictionary = {}


func fork() -> SeasonAbilities:
	var result: SeasonAbilities = SeasonAbilities.new()
	result.from_visit = from_visit
	result.start = start
	result.earned = earned
	result.learned = learned.duplicate(true)
	return result


func ids(player: String) -> Array[String]:
	var result: Array[String] = []
	for receipt: Dictionary in learned.get(player, []):
		result.append(receipt.item)
	return result


func occupied(player: String, slot: String) -> Dictionary:
	for receipt: Dictionary in learned.get(player, []):
		if receipt.slot == slot:
			return receipt.duplicate()
	return {}


func targets(build: SeasonBuild, item: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not ITEMS.has(item):
		return result
	for player: String in build.roster():
		if not ids(player).has(item):
			result.append(
				{"player": player, "replace": occupied(player, ITEMS[item].slot).get("id", "")}
			)
	return result


func pool(build: SeasonBuild) -> Dictionary:
	var result: Dictionary = {}
	if build._format < 36 or build._market != 0 or build._visit.number < from_visit:
		return result
	for item: String in ITEMS:
		if item == SKY and (start == null or int(start) + earned < 3):
			continue
		if not targets(build, item).is_empty():
			result[item] = ITEMS[item].weight
	return result


func buy(build: SeasonBuild, command: Dictionary) -> String:
	if not build._keys(command, ["offer", "player", "replace"]):
		return "Review the exact ability, player and replacement."
	for key: String in ["offer", "player", "replace"]:
		if not command[key] is String:
			return "Choose a legal learned-ability slot."
	var item: String = build._visit.offers.get(command.offer, "")
	if not pool(build).has(item):
		return "This ability offer is no longer eligible."
	if not targets(build, item).has({"player": command.player, "replace": command.replace}):
		return "Choose the exact current slot; duplicate learning is not allowed."
	var error: String = build._charge(ITEMS[item].price)
	if not error.is_empty():
		return error
	var receipts: Array = learned.get(command.player, []).duplicate(true)
	for receipt: Dictionary in receipts.duplicate():
		if receipt.id == command.replace:
			receipts.erase(receipt)
	receipts.append(
		{
			"id": "ability:%d" % build.revision(),
			"item": item,
			"slot": ITEMS[item].slot,
			"paid": ITEMS[item].price
		}
	)
	learned[command.player] = receipts
	build._visit.offers.erase(command.offer)
	return ""


func settle(build: SeasonBuild, command: Dictionary) -> String:
	if start == null or not command.has("fielding"):
		return ""
	if not SeasonJumpstart.valid(build, command.fielding, command.get("performance", {})):
		return "Invalid Sky Reader catch evidence."
	for row: Dictionary in command.fielding:
		if row.clean and row.primary and row.air:
			earned = mini(3, earned + 1)
	return ""


static func access(club: ClubCareer, before_current: bool = false) -> int:
	var total: int = 0
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.sky_outs != null:
			total = mini(3, total + int(run.sky_outs))
	return total


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var abilities: SeasonAbilities = season.build._abilities
	var run: Dictionary = club.runs[-1]
	if (run.sky_outs != null) != (abilities.start != null):
		return false
	return (
		abilities.start == null
		or (
			abilities.start == access(club, true)
			and (not exact or run.sky_outs == abilities.earned)
		)
	)


static func description(player: PlayerDefinition) -> String:
	var lines: PackedStringArray = []
	for item: String in player.season_abilities:
		if ITEMS.has(item):
			lines.append("%s • %s: %s" % [ITEMS[item].slot, ITEMS[item].name, ITEMS[item].effect])
	return "\n".join(lines)
