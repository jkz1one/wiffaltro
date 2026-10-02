class_name PhysicalMatchEvidence
extends RefCounted
# gdlint: disable=max-returns


static func team(data: Dictionary, index: int, appearances: Dictionary) -> bool:
	var row: Dictionary = data.teams[index]
	var keys: Array = row.roster
	for field: String in ["batting", "recipes", "workload"]:
		if not SeasonOwnership._keys(row[field], keys):
			return false
	var runs: int = 0
	for id: String in keys:
		var stats: Dictionary = data.performance[id]
		runs += int(stats.rbi)
		if not _batting(row.batting[id], stats) or not _workload(row.workload[id], stats):
			return false
		if not row.recipes[id] is Array or row.recipes[id].is_empty():
			return false
		for recipe: Variant in row.recipes[id]:
			if not recipe is String or recipe.is_empty():
				return false
	if runs != data["away_runs" if index == 0 else "home_runs"]:
		return false
	var counts: Dictionary = {}
	var previous: int = 0
	var offsets: Dictionary = {}
	var ordinal: int = 0
	for stance: Variant in row.stances:
		if not stance is Dictionary or not SeasonOwnership._keys(
			stance, ["pa", "half", "player", "left"]):
			return false
		if (not _row(stance, keys, index) or not stance.left is bool
			or stance.pa <= previous or appearances.has(int(stance.pa))):
			return false
		if stance.player != keys[ordinal % 4]:
			return false
		ordinal += 1
		previous = int(stance.pa)
		var offset: int = int(offsets.get(stance.player, 0))
		if offset >= row.batting[stance.player].size():
			return false
		appearances[int(stance.pa)] = {
			"half": int(stance.half), "player": stance.player,
			"outcome": row.batting[stance.player][offset]}
		offsets[stance.player] = offset + 1
		counts[stance.player] = counts.get(stance.player, 0) + 1
	for id: String in keys:
		if counts.get(id, 0) != data.performance[id].pa:
			return false
	return _pitching(data, row, index) and _fielding(row.fielding, keys, 1 - index)


static func _batting(value: Variant, stats: Dictionary) -> bool:
	if not value is Array or value.size() != stats.pa:
		return false
	var counts: Dictionary = {}
	for outcome: Variant in value:
		if outcome not in ["single", "double", "triple", "hr", "walk", "out", "strikeout"]:
			return false
		counts[outcome] = counts.get(outcome, 0) + 1
	return (counts.get("walk", 0) == stats.bb and counts.get("strikeout", 0) == stats.k
		and counts.get("double", 0) == stats.double and counts.get("triple", 0) == stats.triple
		and counts.get("hr", 0) == stats.hr
		and counts.get("single", 0) + stats.double + stats.triple + stats.hr == stats.h)


static func _workload(value: Variant, stats: Dictionary) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value, [
		"capacity", "initial", "remaining", "paid", "pitches", "retired"]):
		return false
	return (PhysicalMatchReport.number(value.capacity, 0.001, 1000000.0)
		and PhysicalMatchReport.number(value.initial, 0.0, float(value.capacity))
		and PhysicalMatchReport.number(value.remaining, 0.0, float(value.capacity))
		and PhysicalMatchReport.number(value.paid, 0.0, 1000000.0)
		and SeasonOwnership._whole(value.pitches, 0, 9999)
		and value.pitches == stats.pitches and value.retired is bool)


static func _row(value: Dictionary, roster: Array, parity: int) -> bool:
	return (SeasonOwnership._whole(value.get("pa"), 1, 99999)
		and SeasonOwnership._whole(value.get("half"), 0, 9999)
		and int(value.half) % 2 == parity and value.get("player") is String
		and roster.has(value.player))


static func _pitching(data: Dictionary, team_row: Dictionary, index: int) -> bool:
	var proof: Dictionary = team_row.pitching
	if not SeasonOwnership._keys(proof, ["releases", "calls", "strikeouts"]):
		return false
	# Automated announcements are a separate, still-gated use policy.
	if not proof.calls is Array or not proof.calls.is_empty():
		return false
	if not proof.releases is Array or not proof.strikeouts is Array:
		return false
	var expected: Array = data.releases.filter(
		func(release: Dictionary) -> bool: return team_row.roster.has(release.player))
	if proof.releases.size() != expected.size():
		return false
	for offset in range(expected.size()):
		var release: Variant = proof.releases[offset]
		if not release is Dictionary or not SeasonOwnership._keys(
			release, ["pa", "half", "player", "recipe"]):
			return false
		for key: String in release:
			if release[key] != expected[offset].get(key):
				return false
	var counts: Dictionary = {}
	var previous: int = 0
	for strikeout: Variant in proof.strikeouts:
		if not strikeout is Dictionary or not SeasonOwnership._keys(strikeout, ["pa", "half", "player"]):
			return false
		if not _row(strikeout, team_row.roster, 1 - index) or strikeout.pa <= previous:
			return false
		previous = int(strikeout.pa)
		counts[strikeout.player] = counts.get(strikeout.player, 0) + 1
	for id: String in team_row.roster:
		if counts.get(id, 0) != data.performance[id].p_k:
			return false
	return true


static func _fielding(value: Array, roster: Array, parity: int) -> bool:
	var previous: int = 0
	for row: Variant in value:
		if not row is Dictionary or not SeasonOwnership._keys(row, [
			"pa", "half", "player", "pitcher", "primary", "air", "clean"]):
			return false
		if (not _row(row, roster, parity) or row.pa <= previous
			or not row.pitcher is String or not roster.has(row.pitcher)
			or not row.primary is bool or not row.air is bool or not row.clean is bool):
			return false
		previous = int(row.pa)
	return true


static func credited(data: Dictionary, appearances: Dictionary) -> bool:
	var final_release: Dictionary = {}
	for release: Dictionary in data.releases:
		final_release[int(release.pa)] = release
	if final_release.size() != appearances.size():
		return false
	var expected: Dictionary = {}
	for id: String in data.performance:
		expected[id] = {"p_h": 0, "p_bb": 0, "p_k": 0, "outs": 0}
	for pa: int in appearances:
		var pitcher: String = final_release[pa].player
		var outcome: String = appearances[pa].outcome
		if outcome == "walk":
			expected[pitcher].p_bb += 1
		elif outcome in ["single", "double", "triple", "hr"]:
			expected[pitcher].p_h += 1
		else:
			expected[pitcher].outs += 1
			if outcome == "strikeout":
				expected[pitcher].p_k += 1
	for id: String in expected:
		for key: String in expected[id]:
			if data.performance[id][key] != expected[id][key]:
				return false
	for row: Dictionary in data.teams:
		for strikeout: Dictionary in row.pitching.strikeouts:
			var pa: int = int(strikeout.pa)
			if (not appearances.has(pa) or appearances[pa].outcome != "strikeout"
				or appearances[pa].half != strikeout.half
				or final_release[pa].player != strikeout.player):
				return false
		for fielded: Dictionary in row.fielding:
			var pa: int = int(fielded.pa)
			if (not appearances.has(pa) or appearances[pa].outcome != "out"
				or appearances[pa].half != fielded.half
				or final_release[pa].player != fielded.pitcher):
				return false
	return true
