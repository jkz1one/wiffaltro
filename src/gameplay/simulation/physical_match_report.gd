class_name PhysicalMatchReport
extends RefCounted
## Standalone versioned evidence, not a season save or authority to award anything.
# gdlint: disable=max-returns

const VERSION: int = 1
const RESOLVER: String = "physical-ai-v1"
const CHOICE_VERSION: int = 2
const CHOICE_RESOLVER: String = "physical-ai-choices-v1"


static func capture(lab: PitchBatLab) -> Dictionary:
	var state: MatchState = lab._match_state
	var result: Dictionary = {
		"version": VERSION, "resolver": RESOLVER, "seed": lab._automation.seed,
		"field": String(lab._field_id), "elapsed": state.elapsed_seconds,
		"inning": state.inning, "top": state.top_half,
		"away_runs": state.away_team.runs, "home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state), "teams": [],
		"releases": lab._automation.releases.duplicate(true), "plays": []
	}
	if state.away_team.ai_sponsor_choices or state.home_team.ai_sponsor_choices:
		result.version = CHOICE_VERSION
		result.resolver = CHOICE_RESOLVER
		result["choices"] = {"version": 1, "clubs": [state.away_team.ai_sponsor_choices,
			state.home_team.ai_sponsor_choices], "events": state.ai_choice_events.duplicate(true)}
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var row: Dictionary = {
			"name": team.display_name, "roster": [], "recipes": {}, "workload": {},
			"batting": state.cold.evidence(team), "stances": state.sides.evidence(team),
			"pitching": state.sure_shot.evidence(team),
			"fielding": state.clean_outs.evidence(team)
		}
		for player: PlayerMatchState in team.roster:
			var id: String = String(player.definition.id)
			row.roster.append(id)
			row.recipes[id] = player.definition.starting_pitches.map(
				func(pitch: PitchDefinition) -> String: return String(pitch.id))
			var paid: float = 0.0
			for release: Dictionary in result.releases:
				if release.player == id:
					paid += float(release.paid)
			row.workload[id] = {
				"capacity": player.stamina_max, "initial": lab._automation.initial[id],
				"remaining": player.stamina_remaining, "paid": paid,
				"pitches": player.pitch_count, "retired": player.pitching_finished
			}
		result.teams.append(row)
	for play: PlayRecord in lab._play_records:
		result.plays.append({
			"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
			"batter": String(play.batter_id), "pitcher": String(play.pitcher_id),
			"recipe": String(play.pitch_id), "read": play.ai_decision_recorded,
			"swung": play.ai_swung, "contact": play.contact_outcome,
			"exit_speed": play.exit_speed_mps, "result": String(play.result)
		})
	return result


static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var keys: Array = [
		"version", "resolver", "seed", "field", "elapsed", "inning", "top",
		"away_runs", "home_runs", "performance", "teams", "releases", "plays"]
	if value.get("version") == CHOICE_VERSION:
		keys.append("choices")
	if not SeasonOwnership._keys(value, keys):
		return false
	var data: Dictionary = value
	if (not SeasonOwnership._whole(data.version, VERSION, CHOICE_VERSION)
		or data.resolver != (
			CHOICE_RESOLVER if data.version == CHOICE_VERSION else RESOLVER) or not data.field is String
		or ContentDB.get_field(StringName(data.field)) == null
		or not SeasonOwnership._whole(data.seed, 0, 2147483647)
		or not number(data.elapsed, 0.0, PhysicalMatchRunner.MAX_SECONDS + 1.0)
		or not SeasonOwnership._whole(data.inning, 1, 9999) or not data.top is bool
		or not SeasonOwnership._whole(data.away_runs, 0, 9999)
		or not SeasonOwnership._whole(data.home_runs, 0, 9999)
		or data.away_runs == data.home_runs or not data.teams is Array
		or data.teams.size() != 2 or not data.releases is Array
		or not data.plays is Array or data.releases.size() > 9999
		or data.releases.is_empty() or data.plays.size() != data.releases.size()):
		return false
	for release: Variant in data.releases:
		if not release is Dictionary or not SeasonOwnership._keys(
			release, ["pa", "half", "player", "recipe", "paid"]):
			return false
		if not release.player is String:
			return false
	var ids: Array = []
	for team: Variant in data.teams:
		if not _team_shape(team):
			return false
		for id: Variant in team.roster:
			if not id is String or id.is_empty() or ids.has(id):
				return false
			ids.append(id)
	if not SeasonPerformance.valid(data.performance, ids):
		return false
	var appearances: Dictionary = {}
	for index in range(2):
		if not PhysicalMatchEvidence.team(data, index, appearances):
			return false
	var total: int = 0
	for line: Dictionary in data.performance.values():
		total += int(line.pa)
	if appearances.size() != total:
		return false
	for pa in range(1, total + 1):
		if not appearances.has(pa):
			return false
		if pa > 1 and (appearances[pa].half < appearances[pa - 1].half
			or appearances[pa].half > appearances[pa - 1].half + 1):
			return false
	if (total == 0 or appearances[1].half != 0
		or appearances[total].half != (int(data.inning) - 1) * 2 + (0 if data.top else 1)):
		return false
	if data.version == CHOICE_VERSION and not PhysicalChoiceEvidence.valid(data, appearances):
		return false
	var costs: Dictionary = {}
	var counts: Dictionary = {}
	var previous_pa: int = 0
	for index in range(data.releases.size()):
		var row: Variant = data.releases[index]
		if not _release(data, row, appearances) or row.pa < previous_pa:
			return false
		previous_pa = int(row.pa)
		costs[row.player] = costs.get(row.player, 0.0) + float(row.paid)
		counts[row.player] = counts.get(row.player, 0) + 1
		if not _play(data.plays[index], row, appearances[int(row.pa)].player):
			return false
	for team: Dictionary in data.teams:
		for id: String in team.roster:
			if (counts.get(id, 0) != data.performance[id].pitches
				or not is_equal_approx(float(costs.get(id, 0.0)), float(team.workload[id].paid))):
				return false
	return PhysicalMatchEvidence.credited(data, appearances)


static func number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and (
		float(value) >= low and float(value) <= high)


static func _team_shape(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"name", "roster", "recipes", "workload", "batting", "stances", "pitching", "fielding"]):
		return false
	return (value.name is String and value.roster is Array and value.roster.size() == 4
		and value.recipes is Dictionary and value.workload is Dictionary
		and value.batting is Dictionary and value.stances is Array
		and value.pitching is Dictionary and value.fielding is Array)


static func _release(data: Dictionary, row: Variant, appearances: Dictionary) -> bool:
	if not row is Dictionary or not SeasonOwnership._keys(
		row, ["pa", "half", "player", "recipe", "paid"]):
		return false
	if (not SeasonOwnership._whole(row.pa, 1, appearances.size())
		or not row.half is float and not row.half is int
		or not row.player is String or not row.recipe is String
		or not number(row.paid, 0.0, 1000000.0)):
		return false
	if not appearances.has(int(row.pa)) or row.half != appearances[int(row.pa)].half:
		return false
	var defense: Dictionary = data.teams[1 - int(row.half) % 2]
	return defense.roster.has(row.player) and defense.recipes[row.player].has(row.recipe)


static func _play(value: Variant, release: Dictionary, batter: String) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"half", "batter", "pitcher", "recipe", "read", "swung", "contact", "exit_speed", "result"]):
		return false
	return (value.half == release.half and value.batter == batter
		and value.pitcher == release.player and value.recipe == release.recipe
		and value.read is bool and value.swung is bool
		and SeasonOwnership._whole(value.contact, -1, 20)
		and number(value.exit_speed, 0.0, 1000.0)
		and value.result is String and value.result not in ["", "pending"])
