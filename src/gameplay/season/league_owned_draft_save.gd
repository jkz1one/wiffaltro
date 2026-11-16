extends RefCounted
## Explicit frozen human access. Old closed envelopes never infer ownership from pool size.
const VERSION: int = 87


static func version_in(value: Variant, versions: Array) -> bool:
	# JSON transports integer versions as floats; validate before comparing.
	for expected: Variant in versions:
		if not expected is int:
			return false
	for expected: int in versions:
		if SeasonOwnership._whole(value, expected, expected):
			return true
	return false


static func unpack(value: Variant) -> Dictionary:
	if not value is Dictionary \
		or not SeasonOwnership._keys(value, ["version", "player_access", "checkpoint"]) \
		or value.version != VERSION or not ClubPlayerCatalog.valid_ids(value.player_access) \
		or not value.checkpoint is Dictionary or value.checkpoint.get("version") == VERSION:
		return {}
	return {"players": value.player_access.duplicate(), "checkpoint": value.checkpoint}


static func marker(players: Array) -> String:
	return JSON.stringify(players, "", true, true).sha256_text()


static func envelope(checkpoint: Dictionary, players: Array) -> Dictionary:
	if checkpoint.is_empty() or not ClubPlayerCatalog.valid_ids(players):
		return {}
	return {"version": VERSION, "player_access": players.duplicate(), "checkpoint": checkpoint}


static func closed(value: Dictionary) -> Dictionary:
	var payload: Dictionary = value
	for versions: Array in [[81, 83, 85], [78, 80, 84]]:
		if version_in(payload.get("version"), versions):
			if not payload.get("checkpoint") is Dictionary:
				return {}
			payload = payload.checkpoint
	return payload if version_in(payload.get("version"), [76, 77, 82, 86]) else {}


static func snapshot(season: SeasonState) -> Dictionary:
	if not ClubPlayerDraft.matches(season) or LeagueRules.dynasty(season.league_rules) \
		or not season.league_context_consistent() \
		or (season.career == null and season._closed_access.is_empty()):
		return {}
	# Detached serialization only. The inner discriminator makes this intermediate
	# payload unplayable if the new ownership wrapper is removed.
	var raw: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			raw.set(property.name, season.get(property.name))
	raw.player_access = []
	var checkpoint: Dictionary = SeasonSave.LeagueCareerSave.wrap(
		SeasonSave._ac02_passive_15_snapshot(raw))
	var profile: Dictionary = closed(checkpoint)
	if profile.is_empty():
		return {}
	profile["owned_draft"] = marker(season.player_access)
	return envelope(checkpoint, season.player_access)


static func decode(value: Dictionary) -> SeasonState:
	var parts: Dictionary = unpack(value)
	if parts.is_empty():
		return null
	if parts.checkpoint.get("version") == 81:
		return SeasonSave.LeagueCareerSave.decode(parts.checkpoint, parts.players)
	if version_in(parts.checkpoint.get("version"), [83, 85]):
		return SeasonSave.DynastyCareerSave.decode(value)
	return null


static func decode_setup(value: Dictionary) -> SeasonState:
	var parts: Dictionary = unpack(value)
	if parts.is_empty() or not version_in(parts.checkpoint.get("version"), [80, 84]):
		return null
	return SeasonSave.DynastyCareerSave.decode_raw(parts.checkpoint, parts.players)
