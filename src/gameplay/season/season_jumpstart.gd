class_name SeasonJumpstart
extends RefCounted
# gdlint: disable=max-returns
## Working J04: prospective clean Primary outs and a precommitted first step.

const ITEMS: Dictionary = {
	"J04":
	{
		"name": "Jumpstart Auto",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Before an opposing PA, choose Normal or Left/Right/In/Out for the Primary Fielder. "
			+ "At fair contact, step that way for 0.20s at normal speed, then pursue after both "
			+ "the step and normal reaction delay. A wrong guess costs position. No Cornerstone anchor."
		)
	}
}
const MODES: Array[String] = ["normal", "left", "right", "in", "out"]
const STEP_SECONDS: float = 0.20


static func choose(state: MatchState, mode: String) -> bool:
	if (
		mode not in MODES
		or not state.can_change_defense()
		or not state.fielder().definition.season_sponsors.get("J04", false)
		or (mode != "normal" and state.cornerstone_anchored)
	):
		return false
	state.jumpstart_mode = mode
	return true


static func direction(state: MatchState) -> Vector3:
	if not state.fielder().definition.season_sponsors.get("J04", false):
		return Vector3.ZERO
	# Field Left/Right match the existing anchor names, viewed from home plate.
	match state.jumpstart_mode:
		"left":
			return Vector3.RIGHT
		"right":
			return Vector3.LEFT
		"in":
			return Vector3.FORWARD
		"out":
			return Vector3.BACK
	return Vector3.ZERO


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("fielding"):
		return ""
	if build._format < 31 or build._jump_start == null:
		return "Clean-out tracking starts with a new Working season."
	if not valid(build, command.fielding, command.get("performance", {})):
		return "Fielded-out evidence must match the completed game's statistics."
	build._jump_earned = build._jump_earned or qualifies(command.fielding)
	return ""


static func valid(build: SeasonBuild, evidence: Variant, stats: Dictionary) -> bool:
	if not evidence is Array or evidence.size() > 9999 or stats.is_empty():
		return false
	var total_pa: int = 0
	for line: Dictionary in stats.values():
		total_pa += int(line.get("pa", 0))
	var counts: Dictionary = {}
	var halves: Dictionary = {}
	var previous: Dictionary = {}
	for row: Variant in evidence:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row, ["pa", "half", "player", "pitcher", "primary", "air", "clean"]
			)
		):
			return false
		if (
			not SeasonOwnership._whole(row.pa, 1, total_pa)
			or not SeasonOwnership._whole(row.half, 0, 9999)
			or not row.player is String
			or not build.roster().has(row.player)
			or not row.pitcher is String
			or not build.roster().has(row.pitcher)
			or not row.primary is bool
			or not row.air is bool
			or not row.clean is bool
		):
			return false
		if row.primary == (row.player == row.pitcher):
			return false
		if (
			not previous.is_empty()
			and (
				row.pa <= previous.pa
				or row.half < previous.half
				or int(row.half) % 2 != int(previous.half) % 2
			)
		):
			return false
		counts[row.pitcher] = counts.get(row.pitcher, 0) + 1
		var half: int = int(row.half)
		halves[half] = halves.get(half, 0) + 1
		if halves[half] > 3:
			return false
		previous = row
	for id: String in build.roster():
		if not stats.get(id) is Dictionary:
			return false
		if counts.get(id, 0) != stats[id].get("outs", 0) - stats[id].get("p_k", 0):
			return false
	return true


static func qualifies(rows: Array) -> bool:
	var counts: Dictionary = {}
	for row: Dictionary in rows:
		if row.primary and row.clean:
			counts[row.player] = counts.get(row.player, 0) + 1
			if counts[row.player] >= 3:
				return true
	return false


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.jump_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.jump_earned != null) != (build._jump_start != null):
		return false
	return (
		build._jump_start == null
		or (
			build._jump_start == access(club, true)
			and (not exact or run.jump_earned == build._jump_earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		"Jumpstart Auto • " + ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED"),
		22
	)
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Game: one Primary Fielder records three clean fielded outs in a completed game. "
				+ "No Ks, foul catches or prior bobbles. No win required. 12 Cash • Uncommon • Working. "
				+ ITEMS.J04.effect
			)
		)
	)
	if menu.app.season.build == null or menu.app.season.build._jump_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
