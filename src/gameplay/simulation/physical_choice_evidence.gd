class_name PhysicalChoiceEvidence
extends RefCounted
## Report2 completeness and committed-ownership binding; report1 stays byte-for-byte shaped.
# gdlint: disable=max-returns


static func valid(data: Dictionary, appearances: Dictionary) -> bool:
	var value: Variant = data.get("choices")
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "clubs", "events"]):
		return false
	if not SeasonOwnership._whole(value.version, 1, 1) or not value.clubs is Array \
		or value.clubs.size() != 2 \
		or not value.events is Array or value.events.size() > 19998:
		return false
	if not value.clubs[0] is bool or not value.clubs[1] is bool \
		or not (value.clubs[0] or value.clubs[1]):
		return false
	var cursor: int = 0
	var field: FieldDefinition = ContentDB.get_field(StringName(data.field))
	for pa: int in range(1, appearances.size() + 1):
		var appearance: Dictionary = appearances[pa]
		for role: String in ["bat", "field"]:
			var index: int = int(appearance.half) % 2 if role == "bat" else 1 - int(appearance.half) % 2
			if not value.clubs[index]:
				continue
			if cursor >= value.events.size():
				return false
			var row: Variant = value.events[cursor]
			cursor += 1
			if not row is Dictionary or not SeasonOwnership._keys(row,
				["pa", "half", "role", "player", "mode", "spot"]):
				return false
			if not SeasonOwnership._whole(row.pa, pa, pa) \
				or not SeasonOwnership._whole(row.half, int(appearance.half), int(appearance.half)) \
				or not row.role is String or not row.mode is String or row.role != role \
				or not row.player is String or not data.teams[index].roster.has(row.player):
				return false
			if role == "bat":
				if row.player != appearance.player or row.mode not in ["wide", "normal"] or row.spot != -1:
					return false
			elif row.mode not in ["anchor", "normal"] or not SeasonOwnership._whole(row.spot, 0, 99) \
				or not field.is_fielder_anchor_available(int(row.spot)):
				return false
	return cursor == value.events.size()


static func matches(data: Dictionary, state: MatchState) -> bool:
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var flags: Array = teams.map(func(team: TeamMatchState) -> bool: return team.ai_sponsor_choices)
	if not (flags[0] or flags[1]):
		return data.version == PhysicalMatchReport.VERSION
	if (data.version != PhysicalMatchReport.CHOICE_VERSION
		and data.version != PhysicalMatchReport.TACTICAL_VERSION
		and data.version != PhysicalMatchReport.HEAT_VERSION) or data.choices.clubs != flags:
		return false
	var fielders: Array[int] = [state.away_team.fielder_index, state.home_team.fielder_index]
	var batters: Dictionary = {}
	var pitchers: Dictionary = {}
	for index in range(data.releases.size()):
		var release: Dictionary = data.releases[index]
		if not batters.has(int(release.pa)):
			batters[int(release.pa)] = data.plays[index].batter
			pitchers[int(release.pa)] = release.player
	for row: Dictionary in data.choices.events:
		var index: int = int(row.half) % 2 if row.role == "bat" else 1 - int(row.half) % 2
		var item: String = "F03" if row.role == "bat" else "F01"
		var player: PlayerMatchState = null
		for candidate: PlayerMatchState in teams[index].roster:
			if String(candidate.definition.id) == row.player:
				player = candidate
		if player == null:
			return false
		if row.role == "field":
			var pitching: int = data.teams[index].roster.find(pitchers[int(row.pa)])
			if fielders[index] == pitching:
				fielders[index] = (fielders[index] + 1) % teams[index].roster.size()
			if row.player != String(teams[index].roster[fielders[index]].definition.id):
				return false
			var batter: PlayerDefinition = null
			for candidate: PlayerMatchState in teams[1 - index].roster:
				if String(candidate.definition.id) == batters[int(row.pa)]:
					batter = candidate.definition
			if batter == null or row.player == pitchers[int(row.pa)] or row.spot != (
				MatchLabSupport.ai_fielder_anchor(batter, int(int(row.half) / 2) + 1, int(row.pa),
					ContentDB.get_field(StringName(data.field)))):
				return false
		var mode: String = "wide" if row.role == "bat" else "anchor"
		if row.mode != (mode if player.definition.season_sponsors.get(item, false) else "normal"):
			return false
	return true
