class_name WorkingPitchLeagueSave
extends RefCounted
## Save99 admits current ordinary alternate League careers explicitly. The full
## authority header is bound into the leaf; historical wrappers cannot borrow it.
const VERSION: int = 99
const WORKER_VERSION: int = 9
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const TimeCandidate = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
const FIELDS: Array = ["version", "pitch_catalog", "career", "player_access",
	"inventory_rules", "home_context", "checkpoint"]


static func leaf_valid(data: Variant, catalog: String, career: ClubCareer, rules: Dictionary) -> bool:
	return data is Dictionary and WorkingPitchProgression.is_version(data.get("version"), 57) \
		and catalog == WorkingPitchCatalog.signature() and career != null \
		and career._pitch_catalog == catalog and not rules.is_empty() \
		and not LeagueRules.dynasty(rules) and not data.has("career") \
		and data.get("build") is Dictionary \
		and not WorkingPitchProgression.unwrap_build(data.build).is_empty()


static func authority_key(value: Dictionary) -> String:
	var header: Dictionary = value.duplicate(true)
	header.erase("checkpoint")
	# Hash a detached JSON-normalized view, so in-memory integer fields and
	# their cold JSON float equivalents bind to the same authority identity.
	var canonical: Variant = JSON.parse_string(JSON.stringify(header, "", true, true))
	return JSON.stringify(canonical, "", true, true).sha256_text()


static func capture(season: SeasonState) -> Dictionary:
	if season == null or season.career == null or season.build == null \
		or not season.build.pitch_catalog_current() or not season.league_career \
		or season.career._pitch_catalog != WorkingPitchCatalog.signature() \
		or season.league_rules.is_empty() or LeagueRules.dynasty(season.league_rules) \
		or not season._dynasty_owner_binding.is_empty() or not season._dynasty_career_session.is_empty() \
		or not season._standard_live_context.is_empty() or not season._closed_access.is_empty() \
		or not season._dynasty_start.is_empty():
		return {}
	var context: Dictionary = season._league_home_context
	var raw: SeasonState
	if context.is_empty():
		raw = Normal.detached(season)
		# No unbound home may disappear through the serialization view.
		if not season.home_property.is_empty():
			return {}
	elif context.get("format") == Normal.VERSION and Normal.matches(season):
		raw = Normal.detached(season)
	elif context.get("format") == TimeCandidate.VERSION and TimeCandidate.matches(season):
		raw = TimeCandidate.detached(season)
	else:
		return {}
	if not ClubPlayerDraft.matches(season):
		return {}
	# Existing serialization builds the complete journals. Only the authority and
	# policy are moved to this explicit header, never erased from the saved record.
	raw.player_access = []
	var checkpoint: Dictionary = SeasonSave._ac02_passive_15_snapshot(raw)
	if checkpoint.get("version") == 78:
		checkpoint = checkpoint.get("checkpoint", {})
	if not checkpoint.get("checkpoint") is Dictionary:
		return {}
	var leaf: Dictionary = checkpoint.checkpoint
	if not leaf.get("career") is Dictionary:
		return {}
	var result: Dictionary = {"version": VERSION, "pitch_catalog": WorkingPitchCatalog.signature(),
		"career": leaf.career, "player_access": season.player_access.duplicate(),
		"inventory_rules": season.inventory_rules.duplicate(true),
		"home_context": context.duplicate(true), "checkpoint": checkpoint}
	leaf.erase("career")
	checkpoint["owned_draft"] = Owned.marker(season.player_access)
	leaf["current_league_authority"] = authority_key(result)
	return result if not parts(result).is_empty() else {}


static func parts(value: Variant) -> Dictionary:
	if not value is Dictionary or not SeasonOwnership._keys(value, FIELDS) \
		or not WorkingPitchProgression.is_version(value.version, VERSION) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or not value.career is Dictionary \
		or not WorkingPitchProgression.is_version(value.career.get("version"), WorkingPitchCareerProgress.CAREER_VERSION) \
		or not WorkingPitchProgression.is_version(value.career.get("base_version"), 27) \
		or not ClubPlayerCatalog.valid_ids(value.player_access) \
		or not value.inventory_rules is Dictionary \
		or (not value.inventory_rules.is_empty() and not SeasonInventoryRules.valid(value.inventory_rules)) \
		or not value.home_context is Dictionary or not value.checkpoint is Dictionary:
		return {}
	var career: ClubCareer = ClubCareer.from_data(value.career)
	if career == null or career.current <= 0 or career.current != career.runs.size():
		return {}
	var rules: Dictionary = career.runs[-1].get("league_rules", {})
	var checkpoint: Dictionary = value.checkpoint.duplicate(true)
	var expected: int = 82 if LeagueRules.tiered(rules) else (77 if LeagueRules.doubleheader(rules) else 76)
	if not SeasonOwnership._keys(checkpoint, ["version", "league_rules", "checkpoint", "owned_draft"]) \
		or not WorkingPitchProgression.is_version(checkpoint.version, expected) \
		or not ClubCareer.same(checkpoint.league_rules, rules) \
		or checkpoint.owned_draft != Owned.marker(value.player_access) \
		or not checkpoint.checkpoint is Dictionary \
		or checkpoint.checkpoint.get("current_league_authority") != authority_key(value):
		return {}
	checkpoint.checkpoint.erase("current_league_authority")
	if not leaf_valid(checkpoint.checkpoint, value.pitch_catalog, career, rules):
		return {}
	var home: Dictionary = value.home_context.duplicate(true)
	if not home.is_empty():
		# Reject nonnumeric and nonwhole discriminators before Variant equality:
		# bool == int is a script error, not a safe false result.
		if not Owned.version_in(home.get("format"), [Normal.VERSION, TimeCandidate.VERSION]):
			return {}
		if home.get("format") == Normal.VERSION:
			if not SeasonOwnership._keys(home, ["format", "home_property"]) \
				or not home.home_property is Dictionary \
				or not Normal._supported(home.home_property, rules) \
				or not StadiumLayoutSnapshot.matches(home.home_property, ClubPlayers.assets(career)):
				return {}
		elif home.get("format") == TimeCandidate.VERSION:
			if not SeasonOwnership._keys(home, ["format", "header"]) or not TimeCandidate._header_valid(home.header):
				return {}
		else:
			return {}
		# Historical93/94 decoders construct this runtime discriminator from their
		# integer constants. JSON transports it as a float; forwarding that raw
		# value breaks integer-array dispatch in SeasonState. Normalize only this
		# validated discriminator, never the paid home, policy or build journals.
		home.format = int(home.format)
	return {"career": career, "checkpoint": checkpoint, "home_context": home}


static func restore(value: Dictionary) -> SeasonState:
	var unpacked: Dictionary = parts(value)
	if unpacked.is_empty():
		return null
	var season: SeasonState = SeasonSave._decode_closed_league(unpacked.checkpoint,
		value.inventory_rules, null, {}, unpacked.career, value.player_access,
		unpacked.home_context, value.pitch_catalog, VERSION)
	return season if season != null and not capture(season).is_empty() else null


static func decode_worker(value: Dictionary, token: String) -> SeasonState:
	if not SeasonOwnership._keys(value, ["version", "token", "request", "fixture", "season", "pitch_catalog"]) \
		or not WorkingPitchProgression.is_version(value.version, WORKER_VERSION) \
		or not value.token is String or value.token != token \
		or not value.request is String or value.request.length() != 64 \
		or not SeasonOwnership._whole(value.fixture, 0, 32) \
		or not value.pitch_catalog is String or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or parts(value.season).is_empty():
		return null
	return restore(value.season)


static func prepare_time(season: SeasonState, profile: String) -> Dictionary:
	if not TimeCandidate._prephysical(season) or not Normal.matches(season) \
		or profile not in ["day", "sunset", "night", "fixed_night"]:
		return {}
	var value: Dictionary = capture(season)
	if value.is_empty():
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	var policy: Dictionary = TimeCandidate._policy(season, paid, profile)
	if policy.is_empty():
		return {}
	value.home_context = {"format": TimeCandidate.VERSION, "header": {
		"version": TimeCandidate.VERSION, "family": TimeCandidate.FAMILY,
		"home_property": season.home_property.duplicate(true),
		"starting_profile": profile, "owned_surface_night": policy}}
	value.checkpoint.checkpoint.current_league_authority = authority_key(value)
	return value if restore(value) != null else {}


static func qualify_time(value: Dictionary) -> Dictionary:
	var season: SeasonState = restore(value)
	if not TimeCandidate._prephysical(season) or not TimeCandidate.matches(season):
		return {}
	# Only a pristine chooser candidate can return to its paid day source. Played
	# records always restore with their original policy installed before replay.
	var source_data: Dictionary = value.duplicate(true)
	source_data.home_context = {"format": Normal.VERSION,
		"home_property": season.home_property.duplicate(true)}
	source_data.checkpoint.checkpoint.current_league_authority = authority_key(source_data)
	var source: SeasonState = restore(source_data)
	if source == null or not Normal.matches(source):
		return {}
	return {"source": source, "policy": season.owned_surface_night.duplicate(true),
		"reference": TimeCandidate.Save.snapshot_reference(value),
		"header_key": TimeCandidate.header_key(value.home_context.header)}
