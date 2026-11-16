class_name SeasonSureShot
extends RefCounted
# gdlint: disable=max-returns
## Working F08: actual repeated-recipe strikeouts earn future paid access.

const ITEMS: Dictionary = {
	"F08":
	{
		"name": "Sure Shot Signworks",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Twice per game, announce one known recipe before an opposing PA. "
			+ "Only that recipe may be thrown until the PA ends; location and effort remain free. "
			+ "Execution direction error is 20% smaller. Fatigue, lapses and other errors are unchanged."
		)
	}
}


const _MEMO_SOURCE_PINS: Dictionary = {
	"src/gameplay/season/season_build.gd":
	"e939b05034c6137c0e25cb394d2495c822ff89e4599d06088b32d48d9ffb9d10",
	"src/gameplay/season/season_build_context.gd":
	"811a0cd683a45e74008abc0002c76b03689dd07161ecf319ac3c362cc345759a",
	"src/gameplay/season/season_development.gd":
	"11ad6cbce2ddd79a4511f9da92f5a51a74f846ad1865ffdd022be6cec31f26b3",
	"src/gameplay/season/season_ownership.gd":
	"ce139bccb0bcca359a9914a846da2db62ab77e4d3e5d16f61c1373480d8a113a",
	"src/gameplay/season/season_abilities.gd":
	"91e2274ce713d44dd1f6434540bd83ad14d8ceb095ec6e820315754ec193584d",
	"src/gameplay/season/progression_match_adapter.gd":
	"5cdb8fb2f75be833b94935d779d9b3a03bb0fc4b85ef51708b5d3feb178107d3",
	"src/gameplay/season/season_gear_catalog.gd":
	"f198939ebd88961e518730bd3927af3cb87b61ba5ee62000afc4739a67ceb975",
	"src/gameplay/season/season_sponsor_effects.gd":
	"24e4cf7580bfa7715a1e84fdff1cbcff283a105f2a483e2650d00afe40c91a3b",
	"src/gameplay/season/season_physical_fixtures.gd":
	"722819cc18617689043af61ec1d88a1c9f520c0b2e2fde4144c6d4f05b48b710",
}


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if not command.has("pitching"):
		return ""
	if build._format < 33 or build._sure_start == null:
		return "Recipe tracking starts with a new Working season."
	if not valid(build, command.pitching, command.get("performance", {})):
		return "Pitching evidence must match the completed game's statistics."
	if not command.pitching.calls.is_empty():
		var sponsors: Array = build._match_inventory.get("sponsors", build._bank.view().sponsors)
		if not sponsors.any(func(copy: Dictionary) -> bool: return copy.item == "F08"):
			return "Sure Shot announcements require a paid copy for this attempt."
	build._sure_earned = build._sure_earned or qualifies(command.pitching)
	return ""


static func own_halves(evidence: Dictionary, away_defense: bool) -> bool:
	for key: String in ["releases", "calls", "strikeouts"]:
		if not evidence.get(key) is Array:
			return false
		if not SeasonLeftRight.own_halves(evidence[key], away_defense):
			return false
	return true


static func valid(build: SeasonBuild, evidence: Variant, stats: Dictionary) -> bool:
	var memo: Dictionary = {}
	var eligible: bool = _memo_eligible_scope(build, evidence, stats)
	if not eligible:
		return _valid_uncached(build, evidence, stats)
	if not evidence is Dictionary or stats.is_empty():
		return false
	if not SeasonOwnership._keys(evidence, ["releases", "calls", "strikeouts"]):
		return false
	var total_pa: int = 0
	for line: Dictionary in stats.values():
		total_pa += int(line.get("pa", 0))
	var counts: Dictionary = {}
	var ks: Dictionary = {}
	var groups: Dictionary = {}
	var halves: Dictionary = {}
	for key: String in ["releases", "calls", "strikeouts"]:
		if not evidence[key] is Array or evidence[key].size() > 9999:
			return false
		var previous: Dictionary = {}
		for row: Variant in evidence[key]:
			var fields: Array = ["pa", "half", "player"]
			if key != "strikeouts":
				fields.append("recipe")
			if key == "calls":
				fields.append("time")
			if not row is Dictionary or not SeasonOwnership._keys(row, fields):
				return false
			if (
				not SeasonOwnership._whole(row.pa, 1, total_pa)
				or not SeasonOwnership._whole(row.half, 0, 9999)
				or not row.player is String
				or not build.roster().has(row.player)
			):
				return false
			if key != "strikeouts":
				if not row.recipe is String:
					return false
				var known: bool
				if memo.has(row.player) and memo[row.player].has(row.recipe):
					known = memo[row.player][row.recipe]
				else:
					var definition: PlayerDefinition = build.definition(row.player)
					known = definition.starting_pitches.any(
						func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe
					)
					if known and _memo_reusable_definition(definition):
						if not memo.has(row.player): memo[row.player] = {}
						memo[row.player][row.recipe] = known
				if not known:
					return false
			if key == "calls":
				if (
					not (row.time is float or row.time is int)
					or not is_finite(row.time)
					or row.time < 0
				):
					return false
				if not previous.is_empty() and row.time < previous.time:
					return false
			if not previous.is_empty():
				if (
					row.pa < previous.pa
					or row.half < previous.half
					or int(row.half) % 2 != int(previous.half) % 2
					or (row.pa == previous.pa and key != "releases")
				):
					return false
			if halves.has(int(row.pa)) and halves[int(row.pa)] != row.half:
				return false
			halves[int(row.pa)] = row.half
			if key == "releases":
				counts[row.player] = counts.get(row.player, 0) + 1
				if not groups.has(int(row.pa)):
					groups[int(row.pa)] = []
				groups[int(row.pa)].append(row)
			elif key == "strikeouts":
				ks[row.player] = ks.get(row.player, 0) + 1
			previous = row
	if evidence.calls.size() > 2:
		return false
	for call: Dictionary in evidence.calls:
		if not groups.has(int(call.pa)):
			return false
		for release: Dictionary in groups[int(call.pa)]:
			if release.player != call.player or release.recipe != call.recipe:
				return false
	for id: String in build.roster():
		if not stats.get(id) is Dictionary:
			return false
		if (
			counts.get(id, 0) != stats[id].get("pitches", 0)
			or ks.get(id, 0) != stats[id].get("p_k", 0)
		):
			return false
	return true


static func qualifies(evidence: Dictionary) -> bool:
	for strikeout: Dictionary in evidence.strikeouts:
		var pitches: Array = evidence.releases.filter(
			func(row: Dictionary) -> bool:
				return row.pa == strikeout.pa and row.player == strikeout.player
		)
		if pitches.size() < 3:
			continue
		var recipe: String = pitches[0].recipe
		if pitches.all(func(row: Dictionary) -> bool: return row.recipe == recipe):
			return true
	return false


static func access(club: ClubCareer, before_current: bool = false) -> bool:
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.sure_earned == true:
			return true
	return false


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.sure_earned != null) != (build._sure_start != null):
		return false
	return (
		build._sure_start == null
		or (
			build._sure_start == access(club, true)
			and (not exact or run.sure_earned == build._sure_earned)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(
		card,
		(
			"Sure Shot Signworks • "
			+ ("SHOP ELIGIBLE" if access(menu.app.season.career) else "LOCKED")
		),
		22
	)
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Game: earn a strikeout after that pitcher actually throws at least three pitches, "
				+ "all the same exact recipe in that PA. No win required. 12 Cash • Uncommon • Working. "
				+ ClubCollectionUI.effect(menu, "F08")
			)
		)
	)
	if menu.app.season.build == null or menu.app.season.build._sure_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")


static func _valid_uncached(build: SeasonBuild, evidence: Variant, stats: Dictionary) -> bool:
	if not evidence is Dictionary or stats.is_empty():
		return false
	if not SeasonOwnership._keys(evidence, ["releases", "calls", "strikeouts"]):
		return false
	var total_pa: int = 0
	for line: Dictionary in stats.values():
		total_pa += int(line.get("pa", 0))
	var counts: Dictionary = {}
	var ks: Dictionary = {}
	var groups: Dictionary = {}
	var halves: Dictionary = {}
	for key: String in ["releases", "calls", "strikeouts"]:
		if not evidence[key] is Array or evidence[key].size() > 9999:
			return false
		var previous: Dictionary = {}
		for row: Variant in evidence[key]:
			var fields: Array = ["pa", "half", "player"]
			if key != "strikeouts":
				fields.append("recipe")
			if key == "calls":
				fields.append("time")
			if not row is Dictionary or not SeasonOwnership._keys(row, fields):
				return false
			if (
				not SeasonOwnership._whole(row.pa, 1, total_pa)
				or not SeasonOwnership._whole(row.half, 0, 9999)
				or not row.player is String
				or not build.roster().has(row.player)
			):
				return false
			if key != "strikeouts":
				if not row.recipe is String:
					return false
				if not build.definition(row.player).starting_pitches.any(
					func(pitch: PitchDefinition) -> bool: return String(pitch.id) == row.recipe
				):
					return false
			if key == "calls":
				if (
					not (row.time is float or row.time is int)
					or not is_finite(row.time)
					or row.time < 0
				):
					return false
				if not previous.is_empty() and row.time < previous.time:
					return false
			if not previous.is_empty():
				if (
					row.pa < previous.pa
					or row.half < previous.half
					or int(row.half) % 2 != int(previous.half) % 2
					or (row.pa == previous.pa and key != "releases")
				):
					return false
			if halves.has(int(row.pa)) and halves[int(row.pa)] != row.half:
				return false
			halves[int(row.pa)] = row.half
			if key == "releases":
				counts[row.player] = counts.get(row.player, 0) + 1
				if not groups.has(int(row.pa)):
					groups[int(row.pa)] = []
				groups[int(row.pa)].append(row)
			elif key == "strikeouts":
				ks[row.player] = ks.get(row.player, 0) + 1
			previous = row
	if evidence.calls.size() > 2:
		return false
	for call: Dictionary in evidence.calls:
		if not groups.has(int(call.pa)):
			return false
		for release: Dictionary in groups[int(call.pa)]:
			if release.player != call.player or release.recipe != call.recipe:
				return false
	for id: String in build.roster():
		if not stats.get(id) is Dictionary:
			return false
		if (
			counts.get(id, 0) != stats[id].get("pitches", 0)
			or ks.get(id, 0) != stats[id].get("p_k", 0)
		):
			return false
	return true


static func _memo_reusable_definition(value: PlayerDefinition) -> bool:
	if value.get_script() != PlayerDefinition: return false
	for pitch: PitchDefinition in value.starting_pitches:
		if pitch == null or pitch.get_script() != PitchDefinition: return false
	return true

static func _memo_eligible_scope(build: SeasonBuild, evidence: Variant, stats: Dictionary) -> bool:
	if build == null or build.get_script() != SeasonBuild or build._book == null \
		or build._book.get_script() != SeasonDevelopment or build._bank == null \
		or build._bank.get_script() != SeasonOwnership or build._abilities == null \
		or build._abilities.get_script() != SeasonAbilities:
		return false
	if build._format != 41 or build._book._pitch_catalog_version != 6 \
		or not build._league_rules.is_empty() or not build._dynasty_start.is_empty() \
		or not build._book._league_rules.is_empty() or not build._book._dynasty_start.is_empty():
		return false
	for path: String in _MEMO_SOURCE_PINS:
		if FileAccess.get_sha256("res://" + path) != _MEMO_SOURCE_PINS[path]: return false
	var budget: Array[int] = [100000, 8 * 1024 * 1024]
	return SeasonPhysicalFixtures._current_report_value_graph([
		evidence, stats, build._roster, build._book._players, build._bank._state,
		build._bank._catalog, build._abilities.learned, build._legends], budget, 0)

