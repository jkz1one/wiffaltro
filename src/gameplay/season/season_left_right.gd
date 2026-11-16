class_name SeasonLeftRight
extends RefCounted
## Working F06: actual committed batting sides and paid seasonal ownership.

const ITEMS: Dictionary = {
	"F06":
	{
		"name": "Left Right Moving Co.",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"When this batter's committed side differs from the previous completed PA in "
			+ "this half, fair Contact exit speed +4% and Power −4%. Walks set the prior "
			+ "side. First batter of a half gets neither modifier."
		)
	}
}


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("stances"):
		return ""
	if build._format < 30 or build._sides_start == null:
		return "Batting-side tracking starts with a new Working season."
	if not valid(build, command.stances, command.get("performance", {})):
		return "Committed batting sides must match the completed game's player statistics."
	build._sides_earned = build._sides_earned or transitions(command.stances) >= 3
	return ""


static func valid(build: SeasonBuild, evidence: Variant, stats: Dictionary) -> bool:
	if not evidence is Array or evidence.size() > 9999:
		return false
	var counts: Dictionary = {}
	var previous: Dictionary = {}
	for value: Variant in evidence:
		if (
			not value is Dictionary
			or not SeasonOwnership._keys(value, ["pa", "half", "player", "left"])
		):
			return false
		if (
			not SeasonOwnership._whole(value.pa, 1, 99999)
			or not SeasonOwnership._whole(value.half, 0, 9999)
		):
			return false
		if (
			not value.left is bool
			or not value.player is String
			or not build.roster().has(value.player)
		):
			return false
		if not previous.is_empty():
			if (
				value.pa <= previous.pa
				or value.half < previous.half
				or int(value.half) % 2 != int(previous.half) % 2
			):
				return false
			if value.half == previous.half and value.pa != previous.pa + 1:
				return false
		var player: PlayerDefinition = build.definition(value.player)
		if (
			not player.switch_hitter
			and value.left != (player.bats == PlayerDefinition.Handedness.LEFT)
		):
			return false
		counts[value.player] = counts.get(value.player, 0) + 1
		previous = value
	for id: String in build.roster():
		if not stats.get(id) is Dictionary or counts.get(id, 0) != stats[id].get("pa", -1):
			return false
	return true


static func transitions(rows: Array) -> int:
	var count: int = 0
	for index in range(1, rows.size()):
		if rows[index].half == rows[index - 1].half and rows[index].left != rows[index - 1].left:
			count += 1
	return count


static func own_halves(rows: Array, home: bool) -> bool:
	for row: Variant in rows:
		if not row is Dictionary or not SeasonOwnership._whole(row.get("half"), 0, 9999):
			return false
		if int(row.half) % 2 != (1 if home else 0):
			return false
	return true


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.sides_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.sides_earned != null) != (build._sides_start != null):
		return false
	return (
		build._sides_start == null
		or (
			build._sides_start == access(club, true)
			and (not exact or run.sides_earned == build._sides_earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Left Right Moving Co. • "
			+ ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED")
		),
		22
	)
	SeasonPages.wrapped(
		card,
		(
			"Game: complete three opposite-side transitions between consecutive club PAs "
			+ "within offensive halves. No win required. 12 Season Cash • Uncommon • Working. "
			+ ClubCollectionUI.effect(menu, "F06")
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._sides_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")


static func lineup(menu: SeasonMenu) -> void:
	if (
		menu.app.season.build == null
		or SeasonSchoolSponsors.active(menu.app.season.build, "F06").is_empty()
	):
		return
	var labels: Array[String] = []
	var roster: Array = menu.app.season.teams[0].roster
	for index in range(4):
		var current: PlayerDefinition = menu.app.season.player_definition(roster[index])
		var prior: PlayerDefinition = menu.app.season.player_definition(
			roster[posmod(index - 1, 4)]
		)
		var hint: String = (
			"Choose side at the plate"
			if current.switch_hitter or prior.switch_hitter
			else ("Alternates" if current.bats != prior.bats else "Same side")
		)
		labels.append(current.display_name + ": " + hint)
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				"LEFT RIGHT MOVING • Cyclic lineup preview\n"
				+ "\n".join(labels)
				+ "\nThe first batter of each half has no modifier. Actual committed sides decide each PA."
			)
		)
	)
