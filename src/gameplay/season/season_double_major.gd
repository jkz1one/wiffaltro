class_name SeasonDoubleMajor
extends RefCounted
# gdlint: disable=max-returns
## Working F09. The journal owns nomination and explicit permanent forgetting.

const ITEMS: Dictionary = {
	"F09":
	{
		"name": "Double Major Academy",
		"price": 18,
		"rarity": "Rare",
		"weight": 0.5,
		"effect":
		(
			"Nominate one player for two different paid Fielding abilities. Shared "
			+ "held capacity −1. No free learning. Reassignment, departure or sale "
			+ "requires explicit forgetting of excess learning, with no refund."
		)
	}
}
const OPS: Array[String] = [
	"sponsor_buy", "sponsor_sell", "wholesale", "sign", "match_sell", "major_assign"
]
var start: Variant = null
var earned: bool = false
var player: String = ""


func fork() -> SeasonDoubleMajor:
	var result: SeasonDoubleMajor = SeasonDoubleMajor.new()
	result.start = start
	result.earned = earned
	result.player = player
	return result


func apply(build: SeasonBuild, command: Dictionary) -> String:
	var clean: Dictionary = command.duplicate(true)
	var choice: Variant = clean.get("major", null)
	if choice != null or clean.has("major"):
		if build._format < 37 or command.get("op", "") not in OPS:
			return "Double Major choices only accompany a legal loadout change."
		if not choice is Dictionary or not SeasonOwnership._keys(choice, ["player", "forget"]):
			return "Review the exact Double Major nomination and forgotten receipt."
		if not choice.player is String or not choice.forget is String:
			return "Choose a legal Double Major player and ability."
		clean.erase("major")
	var old: String = player
	var owned: Dictionary = SeasonSchoolSponsors.active(build, "F09")
	var error: String = build._apply(clean)
	if not error.is_empty():
		return error
	if build._format < 37:
		return ""
	var active: Dictionary = SeasonSchoolSponsors.active(build, "F09")
	var target: String = old
	if active.is_empty() or not build.roster().has(old):
		target = ""
	if choice != null:
		target = choice.player
		if (
			(active.is_empty() and target != "")
			or (target != "" and not build.roster().has(target))
		):
			return "Choose a current Double Major beneficiary; removed sponsors have none."
		if command.op == "match_sell" and (target != "" or not active.is_empty()):
			return "Double Major cannot be reassigned during a game."
	if active != owned and not active.is_empty() and (choice == null or target.is_empty()):
		return "Double Major needs an explicit nominated player before purchase."
	if command.op == "major_assign" and (active.is_empty() or target.is_empty() or choice == null):
		return "Choose a current player for Double Major."
	var excess: Array = build._abilities.in_slot(old, "Fielding") if old != target else []
	var forgotten: String = choice.forget if choice != null else ""
	if excess.size() > 1:
		var exact: Array = excess.filter(func(row: Dictionary) -> bool: return row.id == forgotten)
		if exact.size() != 1:
			return "Double Major requires choosing which excess Fielding ability to forget."
		build._abilities.learned[old].erase(exact[0])
	elif forgotten != "":
		return "No excess Double Major ability matches that forgetting choice."
	player = target
	for owner: String in build._abilities.learned:
		if build._abilities.in_slot(owner, "Fielding").size() > (2 if owner == player else 1):
			return "Resolve Double Major excess learning explicitly."
	return ""


func settle(build: SeasonBuild, command: Dictionary) -> String:
	if start == null or not command.has("fielding"):
		return ""
	if not SeasonJumpstart.valid(build, command.fielding, command.get("performance", {})):
		return "Invalid Double Major fielding evidence."
	earned = earned or qualifies(command.fielding)
	return ""


static func qualifies(rows: Array) -> bool:
	var styles: Dictionary = {}
	for row: Dictionary in rows:
		if row.clean and row.primary:
			styles[row.player] = int(styles.get(row.player, 0)) | (2 if row.air else 1)
			if styles[row.player] == 3:
				return true
	return false


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.major_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var major: SeasonDoubleMajor = season.build._major
	var run: Dictionary = club.runs[-1]
	if (run.major_earned != null) != (major.start != null):
		return false
	return (
		major.start == null
		or (major.start == access(club, true) and (not exact or run.major_earned == major.earned))
	)


static func review(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("major"):
		return ""
	var choice: Dictionary = command.major
	var text: String = (
		"\nDouble Major beneficiary: "
		+ ("none" if choice.player == "" else build.definition(choice.player).display_name)
	)
	for receipt: Dictionary in build._abilities.in_slot(build._major.player, "Fielding"):
		if receipt.id == choice.forget:
			text += (
				"\nForget %s from %s permanently this season. No refund or stored copy."
				% [
					SeasonAbilities.ITEMS[receipt.item].name,
					build.definition(build._major.player).display_name
				]
			)
	if command.op == "match_sell":
		text += (
			" Ownership and forgetting save now; the current PA retains its effect "
			+ "until the safe next-batter boundary."
		)
	return text


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Double Major Academy • "
			+ ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			(
				"Game: the same Primary Fielder makes a clean grounded out and clean "
				+ "airborne catch out in one completed game. No pitcher catches, prior "
				+ "bobbles or win requirement. 18 Cash • Rare • Working."
			)
			+ ClubCollectionUI.effect(menu, "F09")
		)
	)
	if menu.app.season.build == null or menu.app.season.build._major.start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
