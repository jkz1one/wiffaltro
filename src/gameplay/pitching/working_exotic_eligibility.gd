class_name WorkingExoticEligibility
extends RefCounted
## Derived prospective completed-game evidence, never a self-authorizing unlock blob.
## The new career owner must compare capture(season), preserve its committed prefix,
## and aggregate permanent earned access. valid() validates shape, not provenance.
# gdlint: disable=max-returns

const VERSION: int = 1
const DROP_IDS: Array[String] = ["pitch.drop", "pitch.three_quarter_drop"]
const PRICES: Dictionary = {"switchback": 18, "corkscrew": 20, "trapdoor": 18}


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.build == null or season.build._market != 0 \
		or not season.build.has_method("pitch_catalog_current") \
		or season.build.call("pitch_catalog_current") != true:
		return {}
	var games: Array = []
	for game: Dictionary in season.player_results:
		var reward: Dictionary = {}
		for event: Dictionary in season.build._events:
			if event.get("op") == "reward" and event.get("game") == game.get("id"):
				if not reward.is_empty():
					return {}
				reward = event
		if reward.is_empty() or not game.get("pitching") is Dictionary \
			or not ClubCareer.same(game.pitching, reward.get("pitching")):
			return {}  # Pending games and report-only claims cannot earn anything.
		if game.has("pitching_current") != reward.has("pitching_current"):
			return {}
		if game.has("pitching_current") and not ClubCareer.same(
			game.pitching_current, reward.pitching_current):
			return {}
		var row: Dictionary = _capture_game(game)
		if row.is_empty():
			return {}
		games.append(row)
	var result: Dictionary = {"version": VERSION, "catalog": WorkingPitchCatalog.signature(),
		"season": season.build._book._season_key, "games": games}
	return result if valid(result) else {}


static func current_proof_valid(value: Variant, legacy: Variant) -> bool:
	if not value is Dictionary or not legacy is Dictionary \
		or not SeasonOwnership._keys(value, ["version", "pitching", "called_strikeouts"]) \
		or not SeasonOwnership._whole(value.version, 2, 2) \
		or not value.pitching is Dictionary or not ClubCareer.same(value.pitching, legacy) \
		or not value.called_strikeouts is Array or not legacy.get("strikeouts") is Array:
		return false
	var previous: int = 0
	for row: Variant in value.called_strikeouts:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["pa", "half", "player"]) \
			or not SeasonOwnership._whole(row.pa, 1, 99999) \
			or not SeasonOwnership._whole(row.half, 0, 9999) or not row.player is String \
			or row.pa <= previous:
			return false
		previous = int(row.pa)
		if not legacy.strikeouts.any(func(strikeout: Variant) -> bool:
			return ClubCareer.same(row, strikeout)):
			return false
	return true


static func _capture_game(game: Dictionary) -> Dictionary:
	if not SeasonOwnership._whole(game.get("id"), 0, 32) \
		or not game.get("pitching") is Dictionary or not game.get("performance") is Dictionary \
		or not _roster(game.get("club_roster")):
		return {}
	var pitching: Dictionary = game.pitching
	if not SeasonOwnership._keys(pitching, ["releases", "calls", "strikeouts"]) \
		or not pitching.releases is Array or not pitching.calls is Array \
		or not pitching.strikeouts is Array or pitching.releases.size() > 9999:
		return {}
	var known_called: bool = game.has("pitching_current")
	if known_called and not current_proof_valid(game.pitching_current, pitching):
		return {}
	var sequences: Dictionary = {}
	var final: Dictionary = {}
	var previous: int = 0
	for release: Variant in pitching.releases:
		if not release is Dictionary \
			or not SeasonOwnership._keys(release, ["pa", "half", "player", "recipe"]) \
			or not SeasonOwnership._whole(release.pa, 1, 99999) \
			or not SeasonOwnership._whole(release.half, 0, 9999) \
			or not release.player is String or not game.club_roster.has(release.player) \
			or not release.recipe is String or not WorkingPitchCatalog.supports(release.recipe) \
			or release.pa < previous:
			return {}
		previous = int(release.pa)
		var key: String = "%d:%s" % [int(release.pa), release.player]
		if not sequences.has(key):
			sequences[key] = []
		if not sequences[key].has(release.recipe):
			sequences[key].append(release.recipe)
		final[int(release.pa)] = release
	var strikeouts: Array = []
	var counts: Dictionary = {}
	previous = 0
	for strikeout: Variant in pitching.strikeouts:
		if not strikeout is Dictionary \
			or not SeasonOwnership._keys(strikeout, ["pa", "half", "player"]) \
			or not SeasonOwnership._whole(strikeout.pa, 1, 99999) \
			or not SeasonOwnership._whole(strikeout.half, 0, 9999) \
			or not strikeout.player is String or not game.club_roster.has(strikeout.player) \
			or strikeout.pa <= previous or not final.has(int(strikeout.pa)):
			return {}
		previous = int(strikeout.pa)
		var finish: Dictionary = final[int(strikeout.pa)]
		if finish.player != strikeout.player or finish.half != strikeout.half:
			return {}
		var called: Variant = null
		if known_called:
			called = game.pitching_current.called_strikeouts.any(func(row: Variant) -> bool:
				return ClubCareer.same(row, strikeout))
		strikeouts.append({"pa": int(strikeout.pa), "half": int(strikeout.half),
			"pitcher": strikeout.player, "finish": finish.recipe,
			"sequence": sequences["%d:%s" % [int(strikeout.pa), strikeout.player]].duplicate(),
			"called": called})
		counts[strikeout.player] = counts.get(strikeout.player, 0) + 1
	for id: String in game.club_roster:
		if not game.performance.get(id) is Dictionary \
			or not SeasonOwnership._whole(game.performance[id].get("p_k"), 0, 9999) \
			or game.performance[id].p_k != counts.get(id, 0):
			return {}
	# JSON roundtrip canonicalizes integer-looking numbers before hashing, so a
	# cold decode's float2.0 cannot change an otherwise identical proof identity.
	var canonical: Variant = JSON.parse_string(JSON.stringify(
		[pitching, game.get("pitching_current")], "", true))
	return {"game": int(game.id), "roster": game.club_roster.duplicate(), "strikeouts": strikeouts,
		"evidence_hash": JSON.stringify(canonical, "", true).sha256_text()}


static func valid(value: Variant) -> bool:
	if not value is Dictionary \
		or not SeasonOwnership._keys(value, ["version", "catalog", "season", "games"]) \
		or not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or not value.catalog is String or value.catalog != WorkingPitchCatalog.signature() \
		or not value.season is String or value.season.is_empty() or value.season.length() > 120 \
		or not value.games is Array or value.games.size() > 12:
		return false
	var previous: int = -1
	for game: Variant in value.games:
		if not game is Dictionary \
			or not SeasonOwnership._keys(game, ["game", "roster", "strikeouts", "evidence_hash"]) \
			or not SeasonOwnership._whole(game.game, 0, 32) or game.game <= previous \
			or not _roster(game.roster) or not game.strikeouts is Array \
			or game.strikeouts.size() > 9999 or not _sha(game.evidence_hash):
			return false
		previous = int(game.game)
		var previous_pa: int = 0
		for row: Variant in game.strikeouts:
			if not row is Dictionary or not SeasonOwnership._keys(
				row, ["pa", "half", "pitcher", "finish", "sequence", "called"]):
				return false
			if not SeasonOwnership._whole(row.pa, 1, 99999) or row.pa <= previous_pa \
				or not SeasonOwnership._whole(row.half, 0, 9999) \
				or not row.pitcher is String or not game.roster.has(row.pitcher) \
				or not row.finish is String or not WorkingPitchCatalog.supports(row.finish) \
				or not row.sequence is Array or row.sequence.is_empty() \
				or row.sequence.size() > WorkingPitchCatalog.known_ids().size() \
				or not row.sequence.has(row.finish) or (row.called != null and not row.called is bool):
				return false
			previous_pa = int(row.pa)
			var seen: Array = []
			for id: Variant in row.sequence:
				if not id is String or not WorkingPitchCatalog.supports(id) or seen.has(id):
					return false
				seen.append(id)
	return true


static func eligible_ids(value: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if not valid(value):
		return result
	var mixed: bool = false
	var finishes: Dictionary = {}
	var called_drop: int = 0
	for game: Dictionary in value.games:
		for strikeout: Dictionary in game.strikeouts:
			finishes[strikeout.finish] = true
			var arm: bool = false
			var glove: bool = false
			for id: String in strikeout.sequence:
				var pitch: PitchDefinition = WorkingPitchCatalog.get_recipe(id)
				arm = arm or pitch.tags.has(&"arm_side")
				glove = glove or pitch.tags.has(&"glove_side")
			mixed = mixed or (arm and glove)
			if strikeout.called == true and DROP_IDS.has(strikeout.finish):
				called_drop += 1
	for pair: Array in [[mixed, "Switchback"], [finishes.size() >= 4, "Corkscrew"],
		[called_drop >= 3, "Trapdoor"]]:
		if pair[0]:
			result.append_array(WorkingPitchCatalog.RESERVED_EXOTICS[pair[1]])
	return result


static func _roster(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	var seen: Array = []
	for id: Variant in value:
		if not id is String or not SeasonPlayerCatalog.ROWS.has(id) or seen.has(id):
			return false
		seen.append(id)
	return true


static func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true
