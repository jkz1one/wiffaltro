class_name SeasonFreezers
extends RefCounted
## Working E10: prospective completed-game evidence, separately purchased seasonal power.

const ITEMS: Dictionary = {
	"E10":
	{
		"name": "Frankie's Freezers",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Each hitter gains Cold after a hitless at-bat, max two. Each stack adds 3% "
			+ "fair Power exit speed and subtracts 4% Contact X/Y coverage. Walks are "
			+ "neutral; a hit uses then clears Cold. Resets next game."
		)
	}
}


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("batting"):
		return ""
	if build._format < 29 or build._freezer_start == null:
		return "Batting streak evidence starts with a new Working season."
	var evidence: Variant = command.batting
	if not valid(evidence, build.roster(), command.get("performance", {})):
		return "Batting streaks must match the completed game's individual statistics."
	for outcomes: Array in evidence.values():
		build._freezer_earned = build._freezer_earned or breakout(outcomes)
	return ""


static func valid(evidence: Variant, roster: Array, stats: Dictionary) -> bool:
	if not evidence is Dictionary or evidence.size() != roster.size():
		return false
	for id: String in roster:
		if not evidence.get(id) is Array or not stats.get(id) is Dictionary:
			return false
		var outcomes: Array = evidence[id]
		var line: Dictionary = stats[id]
		if outcomes.size() != line.get("pa", -1) or outcomes.size() > 9999:
			return false
		var counts: Dictionary = {"h": 0, "double": 0, "triple": 0, "hr": 0, "bb": 0, "k": 0}
		for outcome: Variant in outcomes:
			if (
				not outcome is String
				or outcome not in ["walk", "out", "strikeout", "single", "double", "triple", "hr"]
			):
				return false
			if outcome in ["single", "double", "triple", "hr"]:
				counts.h += 1
			if outcome in ["double", "triple", "hr"]:
				counts[outcome] += 1
			elif outcome == "walk":
				counts.bb += 1
			elif outcome == "strikeout":
				counts.k += 1
		for key: String in counts:
			if counts[key] != line.get(key, -1):
				return false
	return true


static func breakout(outcomes: Array) -> bool:
	var cold: int = 0
	for outcome: String in outcomes:
		if outcome in ["out", "strikeout"]:
			cold = mini(2, cold + 1)
		elif outcome in ["single", "double", "triple", "hr"]:
			if cold == 2:
				return true
			cold = 0
	return false


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.freezer_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.freezer_earned != null) != (build._freezer_start != null):
		return false
	return (
		build._freezer_start == null
		or (
			build._freezer_start == access(club, true)
			and (not exact or run.freezer_earned == build._freezer_earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		"Frankie's Freezers • " + ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED"),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			(
				"Game: one hitter records a hit after two consecutive hitless at-bats. Walks "
				+ "are neutral. Complete the game; no win required. 12 Season Cash • Uncommon • "
				+ "Working."
			)
			+ ITEMS.E10.effect
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._freezer_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
