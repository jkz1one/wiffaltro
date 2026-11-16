class_name PhysicalBaseReport
extends RefCounted
## Report7 stores one shared occupancy proof, enriched only at team-proof boundaries.
# gdlint: disable=max-returns


static func flow_valid(data: Dictionary) -> bool:
	var value: Variant = data.get("tactics")
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "clubs", "teams", "base"]) or value.version != 5 \
		or not value.clubs is Array or value.clubs.size() != 2 \
		or not value.teams is Array or value.teams.size() != 2 \
		or not value.clubs[0] is bool or not value.clubs[1] is bool \
		or not (value.clubs[0] or value.clubs[1]):
		return false
	return PhysicalBaseFlow.valid(value.base,
		[data.teams[0].roster, data.teams[1].roster], data.performance)


static func valid(data: Dictionary) -> bool:
	return _valid(data, [])


static func league_valid(data: Dictionary, rules: Dictionary, ownership: Array) -> bool:
	if ownership.size() != 2:
		return false
	return _valid(data, ownership, rules)


static func _valid(data: Dictionary, ownership: Array, rules: Dictionary = {}) -> bool:
	# PhysicalMatchReport validates the shared flow once before checking RBI totals.
	var value: Dictionary = data.tactics
	for index in range(2):
		var team: Dictionary = data.teams[index]
		var other: Dictionary = data.teams[1 - index]
		if not value.teams[index] is Dictionary or value.teams[index].has("base"):
			return false
		if not value.clubs[index]:
			if not value.teams[index].is_empty():
				return false
			continue
		var row: Dictionary = PhysicalBaseEvidence.enriched(value.teams[index], value.base)
		var proof_valid: bool = PhysicalBaseEvidence.valid(
			row, team.roster, data.performance, index, true) if ownership.is_empty() else \
			PhysicalBaseEvidence.league_valid(row, team.roster, data.performance, index,
				rules, ownership[index], true)
		if not proof_valid \
			or not ClubCareer.same(row.stances, team.stances) \
			or not ClubCareer.same(row.pitching, team.pitching.releases) \
			or not ClubCareer.same(row.opposition.roster, other.roster) \
			or not ClubCareer.same(row.opposition.stances, other.stances) \
			or not ClubCareer.same(row.recovery.strikeouts, team.pitching.strikeouts) \
			or not ClubCareer.same(row.recovery.costs, data.releases.filter(
				func(release: Dictionary) -> bool: return team.roster.has(release.player))):
			return false
		for id: String in team.roster:
			if not ClubCareer.same(row.recovery.initial[id], {
				"capacity": team.workload[id].capacity, "initial": team.workload[id].initial}) \
				or not PhysicalRecoveryFlow.near(row.recovery.remaining[id], team.workload[id].remaining):
				return false
	return links(data)


static func links(data: Dictionary) -> bool:
	var flow: Dictionary = data.tactics.base
	if flow.final.away != data.away_runs or flow.final.home != data.home_runs \
		or flow.final.half != (int(data.inning) - 1) * 2 + (0 if data.top else 1):
		return false
	var releases: Dictionary = {}
	for release: Dictionary in data.releases:
		if not SeasonOwnership._whole(release.pa, 1, 99999):
			return false
		releases[int(release.pa)] = release
	var offsets: Dictionary = {}
	for result: Dictionary in flow.results:
		var released: Dictionary = releases.get(int(result.pa), {})
		if released.get("player") != result.pitcher or released.get("half") != result.half:
			return false
		var team: Dictionary = data.teams[int(result.half) % 2]
		var offset: int = offsets.get(result.player, 0)
		if not team.batting.has(result.player) or offset >= team.batting[result.player].size() \
			or team.batting[result.player][offset] != result.outcome:
			return false
		offsets[result.player] = offset + 1
	var expected: Dictionary = {}
	for team: Dictionary in data.teams:
		for fielded: Dictionary in team.fielding:
			var pa: int = int(fielded.pa)
			if pa > flow.ready.size():
				return false
			if fielded.air and flow.ready[pa - 1].outs < 2:
				expected[pa] = fielded
	if expected.size() != flow.tags.size():
		return false
	for tag: Dictionary in flow.tags:
		var fielded: Dictionary = expected.get(int(tag.pa), {})
		if fielded.get("player") != tag.defender or fielded.get("half") != tag.half:
			return false
	return true


static func runs(data: Dictionary, parity: int) -> int:
	var total: int = 0
	for advance: Dictionary in data.tactics.base.advances:
		if int(advance.after.half) % 2 == parity and advance.advance.to == 4:
			total += 1
	return total


static func appearances(data: Dictionary, ordinary: Dictionary) -> Dictionary:
	var flow: Dictionary = data.tactics.base
	if flow.ready.size() == flow.results.size():
		return ordinary
	var result: Dictionary = ordinary.duplicate()
	result[int(flow.final.pa)] = {"half": flow.final.half, "player": flow.final.player}
	return result


static func matches(data: Dictionary, state: MatchState) -> bool:
	if data.version != PhysicalMatchReport.BASE_VERSION:
		return false
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool: return team.ai_base)
	if data.tactics.clubs != flags:
		return false
	for index in range(2):
		if flags[index] and not PhysicalBaseEvidence.matches(PhysicalBaseEvidence.enriched(
			data.tactics.teams[index], data.tactics.base), teams[index], teams[1 - index]):
			return false
	return true
