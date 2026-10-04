class_name PhysicalHeatEvidence
extends RefCounted
## Report4: replay exact paid offensive/defensive copies against completed PAs/releases.
# gdlint: disable=max-returns


static func valid(row: Variant, roster: Array, performance: Dictionary, parity: int) -> bool:
	if row is Dictionary and row.has("terminal"):
		return PhysicalHeatTerminal.valid(row, roster, performance, parity)
	if not row is Dictionary or not SeasonOwnership._keys(row, ["version", "featured", "plan",
		"initial", "consumed", "remaining", "stances", "opposition", "pitching"]):
		return false
	if not SeasonOwnership._whole(row.version, 2, 2) or not row.initial is Array \
		or row.initial.size() > 2 or not row.consumed is Array or not row.remaining is Array \
		or not row.pitching is Array or row.pitching.size() > 9999 \
		or not row.opposition is Dictionary or not SeasonOwnership._keys(
			row.opposition, ["roster", "target", "stances"]):
		return false
	var other: Dictionary = row.opposition
	if not other.roster is Array or other.roster.size() != 4 or not other.target is String \
		or not other.roster.has(other.target):
		return false
	var ids: Array = []
	for id: Variant in other.roster:
		if not id is String or id.is_empty() or roster.has(id) or ids.has(id):
			return false
		ids.append(id)
	var copies: Dictionary = {}
	for copy: Variant in row.initial:
		if not copy is Dictionary or not SeasonOwnership._keys(copy, ["id", "item", "paid", "kind"]):
			return false
		if not copy.id is String or copy.id.is_empty() or copies.has(copy.id) \
			or copy.item not in SeasonOpponentTactics.supported(9) or copy.kind != "held" \
			or not SeasonOwnership._whole(copy.paid, SeasonTacticalCatalog.item(copy.item).price,
				SeasonTacticalCatalog.item(copy.item).price):
			return false
		copies[copy.id] = copy.item
	var offense: Dictionary = {}
	for key: String in ["featured", "plan", "initial", "consumed", "remaining", "stances"]:
		offense[key] = row[key]
	offense.version = 1
	offense.initial = row.initial.filter(func(copy: Dictionary) -> bool:
		return copy.item != SeasonTacticalCatalog.HEAT)
	for key: String in ["consumed", "remaining"]:
		if not row[key] is Array:
			return false
		for copy: Variant in row[key]:
			if not copy is Dictionary:
				return false
			var id: Variant = copy.get("receipt" if key == "consumed" else "id")
			if not id is String or not copies.has(id):
				return false
		offense[key] = row[key].filter(func(copy: Dictionary) -> bool:
			return copies[copy.get("receipt" if key == "consumed" else "id")] != SeasonTacticalCatalog.HEAT)
	if not PhysicalTacticalEvidence.valid(offense, roster, performance, parity) \
		or not PhysicalTacticalEvidence.valid({"version": 1, "featured": other.target,
			"plan": "swing.contact", "initial": [], "consumed": [], "remaining": [],
			"stances": other.stances}, other.roster, performance, 1 - parity):
		return false
	var appearances: Dictionary = {}
	for stance: Dictionary in other.stances:
		appearances[int(stance.pa)] = stance
	var pitchers: Dictionary = {}
	var counts: Dictionary = {}
	var previous: int = 0
	for release: Variant in row.pitching:
		if not release is Dictionary or not SeasonOwnership._keys(
			release, ["pa", "half", "player", "recipe"]):
			return false
		if not SeasonOwnership._whole(release.pa, maxi(1, previous), 99999) \
			or not appearances.has(int(release.pa)) or release.half != appearances[int(release.pa)].half \
			or not release.player is String or not roster.has(release.player) \
			or not release.recipe is String or release.recipe.is_empty():
			return false
		previous = int(release.pa)
		if not pitchers.has(previous):
			pitchers[previous] = release.player
		counts[release.player] = counts.get(release.player, 0) + 1
	for id: String in roster:
		if counts.get(id, 0) != performance[id].pitches:
			return false
	if pitchers.size() != appearances.size():
		return false
	var order: Array = row.stances.duplicate(true)
	order.append_array(other.stances)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pa < b.pa)
	for index in range(order.size()):
		if not SeasonOwnership._whole(order[index].pa, index + 1, index + 1):
			return false
		if index == 0 and order[index].half != 0:
			return false
		if index > 0 and (order[index].half < order[index - 1].half
			or order[index].half > order[index - 1].half + 1):
			return false
	var held: Array = row.initial.duplicate(true)
	var expected: Array = []
	for stance: Dictionary in order:
		var action: Dictionary = {}
		if stance.player == other.target:
			for copy: Dictionary in held:
				if copy.item == SeasonTacticalCatalog.HEAT:
					action = {"receipt": copy.id, "swing": ""}
					break
		elif roster.has(stance.player):
			action = SeasonOpponentTactics.select(held, stance.player, row.featured, row.plan)
		if action.is_empty():
			continue
		expected.append({"receipt": action.receipt, "player": pitchers[int(stance.pa)]
			if stance.player == other.target else stance.player, "pa": stance.pa, "swing": action.swing})
		held = held.filter(func(copy: Dictionary) -> bool: return copy.id != action.receipt)
	return ClubCareer.same(expected, row.consumed) and ClubCareer.same(held, row.remaining)


static func matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	if other == null or row.get("version") != 2:
		return false
	var offense: Dictionary = row.duplicate(true)
	offense.version = 1
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	if fresh == null:
		return false
	fresh.ai_heat = false
	if not PhysicalTacticalEvidence.matches(offense, fresh) or row.opposition.target != (
		SeasonOpponentHeat.target(other)) or row.opposition.roster != other.roster.map(
			func(player: PlayerMatchState) -> String: return String(player.definition.id)):
		return false
	for release: Dictionary in row.pitching:
		var player: PlayerDefinition = null
		for candidate: PlayerMatchState in team.roster:
			if String(candidate.definition.id) == release.player:
				player = candidate.definition
		if player == null or not player.starting_pitches.any(func(pitch: PitchDefinition) -> bool:
			return String(pitch.id) == release.recipe):
			return false
	return true


static func report_valid(data: Dictionary) -> bool:
	var value: Variant = data.get("tactics")
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "clubs", "teams"]):
		return false
	if not SeasonOwnership._whole(value.version, 2, 2) or not value.clubs is Array \
		or value.clubs.size() != 2 or not value.teams is Array or value.teams.size() != 2 \
		or not value.clubs[0] is bool or not value.clubs[1] is bool \
		or not (value.clubs[0] or value.clubs[1]):
		return false
	for index in range(2):
		var proof: Variant = value.teams[index]
		if value.clubs[index]:
			if (proof is Dictionary and proof.has("terminal")) \
				or not valid(proof, data.teams[index].roster, data.performance, index) \
				or not ClubCareer.same(proof.stances, data.teams[index].stances) \
				or not ClubCareer.same(proof.pitching, data.teams[index].pitching.releases) \
				or not ClubCareer.same(proof.opposition.roster, data.teams[1 - index].roster) \
				or not ClubCareer.same(proof.opposition.stances, data.teams[1 - index].stances):
				return false
		elif not proof is Dictionary or not proof.is_empty():
			return false
	return true


static func report_matches(data: Dictionary, state: MatchState) -> bool:
	if data.version != PhysicalMatchReport.HEAT_VERSION:
		return false
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool: return team.ai_heat)
	if data.tactics.clubs != flags:
		return false
	for index in range(2):
		if flags[index] and not matches(data.tactics.teams[index], teams[index], teams[1 - index]):
			return false
	return true


static func replay_team(build: SeasonBuild, game: int, roster: Array) -> TeamMatchState:
	# Complete from_data validation precedes this read-only pre-reward reconstruction.
	var prefix: SeasonBuild = SeasonBuildRestore.restore(build.to_data(), build._seed,
		build._initial_roster, build._pool, build._blocked, game)
	if prefix == null:
		return null
	var players: Array[PlayerDefinition] = []
	for id: String in roster:
		if not prefix.roster().has(id):
			return null
		players.append(prefix.definition(id))
	return TeamMatchState.create("Recorded opposing roster", players)
