extends RefCounted
## A bound session checkpoint, not authority for shared income or progression.
## OwnerV2 qualifies the exact reference and shared Career28 in one transaction.

const VERSION: int = 83
const TIER_VERSION: int = 85
const RAW_TIER_VERSION: int = 84
const TIER_CHECKPOINT_VERSION: int = 86
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
const FIELDS: Array[String] = [
	"owner_id", "lineage_id", "generation", "ordinal", "session_id", "seed", "tier",
	"league", "access_sha256"
]


static func binding(value: Variant) -> Dictionary:
	if not Profile.keys(value, FIELDS):
		return {}
	for field: String in ["owner_id", "lineage_id", "session_id"]:
		if not Profile.token(value[field]):
			return {}
	if (
		not Profile.whole(value.generation, 0, Profile.MAX_ORDINAL - 1)
		or not Profile.whole(value.ordinal, 1, Profile.MAX_ORDINAL)
		or value.generation != value.ordinal - 1
		or not Profile.whole(value.seed, 0, 2147483647)
		or not Profile.whole(value.tier, 0, 4)
		or not value.league is String
		or LeagueRules.capture_tier(value.league, int(value.tier),
			value.seed if value.league == "scramble"
			else null).is_empty()
		or not ClosedContentAccess._digest_valid(value.access_sha256)
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	for field: String in ["generation", "ordinal", "seed", "tier"]:
		result[field] = int(result[field])
	return result


static func binding_for(
	season: SeasonState, owner_id: String, lineage_id: String,
	generation: int, ordinal: int, session_id: String
) -> Dictionary:
	if season == null or season._closed_access.is_empty() or season.league_rules.is_empty():
		return {}
	return binding({"owner_id": owner_id, "lineage_id": lineage_id,
		"generation": generation, "ordinal": ordinal, "session_id": session_id,
		"seed": season.season_seed, "tier": season.league_rules.tier,
		"league": season.league_rules.league,
		"access_sha256": ClosedContentAccess.digest(season._closed_access)})


static func snapshot_reference(value: Dictionary) -> Dictionary:
	# New bound-session objects use transport-canonical numeric bytes so the
	# reference survives JSON parsing. Legacy owner-v1 objects are unchanged.
	var encoded: String = JSON.stringify(
		JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)
	return {"sha256": encoded.sha256_text(), "bytes": encoded.to_utf8_buffer().size()}


static func _matches(season: SeasonState, context: Dictionary) -> bool:
	if (
		season == null or context.is_empty() or season.career != null or season.league_career
		or not LeagueRules.season_matches(season.league_rules, context.seed)
		or season.season_seed != context.seed or season.league_rules.league != context.league
		or season.league_rules.tier != context.tier or season._closed_access.is_empty()
		or season._closed_access.owner_id != context.owner_id
		or ClosedContentAccess.digest(season._closed_access) != context.access_sha256
	):
		return false
	if context.league != "dynasty":
		return season._dynasty_start.is_empty()
	var start: Dictionary = Profile.normalize(season._dynasty_start)
	return not start.is_empty() and start.owner_id == context.owner_id \
		and start.lineage_id == context.lineage_id and start.season_ordinal == context.ordinal \
		and context.session_id == "%s:%d" % [context.lineage_id, context.ordinal]


static func wrap_checkpoint(inner: Dictionary, context: Dictionary) -> Dictionary:
	var owned: Dictionary = Owned.unpack(inner) if inner.get("version") == Owned.VERSION else {}
	var raw: Dictionary = owned.checkpoint if not owned.is_empty() else inner
	var normalized: Dictionary = binding(context)
	if normalized.is_empty() or raw.get("version") != (
		RAW_TIER_VERSION if normalized.tier > 0 else 80
	):
		return {}
	var season: SeasonState = (
		Owned.decode_setup(inner) if not owned.is_empty() else SeasonSave._decode(raw))
	if not _matches(season, normalized):
		return {}
	var result: Dictionary = {"version": TIER_VERSION if normalized.tier > 0 else VERSION,
		"session": normalized, "checkpoint": raw.duplicate(true)}
	return Owned.envelope(result, owned.players) if not owned.is_empty() else result


static func qualify(value: Variant) -> Dictionary:
	if not value is Dictionary or snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return {}
	var original: Dictionary = value
	var owned: Dictionary = Owned.unpack(value) if value.get("version") == Owned.VERSION else {}
	if value.get("version") == Owned.VERSION:
		if owned.is_empty():
			return {}
		value = owned.checkpoint
	if (
		not Profile.keys(value, ["version", "session", "checkpoint"])
		or not Owned.version_in(value.version, [VERSION, TIER_VERSION])
		or not value.checkpoint is Dictionary
	):
		return {}
	var context: Dictionary = binding(value.session)
	if context.is_empty() or (value.version == TIER_VERSION) != (context.tier > 0) \
		or value.checkpoint.get("version") != (RAW_TIER_VERSION if context.tier > 0 else 80):
		return {}
	var raw: Dictionary = value.checkpoint.duplicate(true)
	var season: SeasonState = (
		decode_raw(raw, owned.players) if not owned.is_empty() else SeasonSave._decode(raw))
	if not _matches(season, context):
		return {}
	season._dynasty_career_session = context.duplicate(true)
	if not owned.is_empty():
		raw = Owned.envelope(raw, owned.players)
	return {"inner": raw, "season": season, "session": context,
		"raw_reference": snapshot_reference(raw), "reference": snapshot_reference(original)}


static func decode_raw(value: Dictionary, player_access: Array = []) -> SeasonState:
	var fields: Array = ["version", "access", "inventory_rules", "checkpoint"]
	if value.has("dynasty_start"):
		fields.append("dynasty_start")
	var raw: Dictionary = (
		Owned.envelope(value, player_access) if not player_access.is_empty() else value)
	if not Profile.keys(value, fields) \
		or not Owned.version_in(value.version, [80, RAW_TIER_VERSION]
			if not player_access.is_empty() else [RAW_TIER_VERSION]) \
		or core(raw).is_empty() or not value.inventory_rules is Dictionary \
		or (not value.inventory_rules.is_empty()
			and not SeasonInventoryRules.valid(value.inventory_rules)):
		return null
	var access: Dictionary = ClosedContentAccess.normalize(value.access)
	if access.is_empty():
		return null
	return SeasonSave._decode_closed_league(value.checkpoint, value.inventory_rules,
		value.get("dynasty_start"), access, null, player_access)


static func core(inner: Dictionary) -> Dictionary:
	# Structural extraction only, never source qualification or owner authority.
	var owned: Dictionary = Owned.unpack(inner) if inner.get("version") == Owned.VERSION else {}
	if inner.get("version") == Owned.VERSION:
		if owned.is_empty():
			return {}
		inner = owned.checkpoint
	if not Owned.version_in(inner.get("version"), [80, RAW_TIER_VERSION]) \
		or not inner.get("checkpoint") is Dictionary:
		return {}
	var closed: Dictionary = inner.checkpoint
	var fields: Array = ["version", "league_rules", "checkpoint"]
	if not owned.is_empty():
		fields.append("owned_draft")
		if closed.get("owned_draft") != Owned.marker(owned.players) or closed.get("version") == 75:
			return {}
	if not Profile.keys(closed, fields) \
		or not closed.checkpoint is Dictionary or closed.checkpoint.get("version") != 57:
		return {}
	var tiered: bool = inner.version == RAW_TIER_VERSION
	if (tiered and closed.version != TIER_CHECKPOINT_VERSION) \
		or (not tiered and not Owned.version_in(closed.version, [75, 76, 77])) \
		or LeagueRules.normalized(closed.league_rules).is_empty() \
		or tiered != LeagueRules.tiered(closed.league_rules):
		return {}
	return closed.checkpoint


static func unwrap(value: Variant) -> Dictionary:
	return qualify(value).get("inner", {})


static func decode(value: Variant) -> SeasonState:
	return qualify(value).get("season")


static func capture(season: SeasonState) -> Dictionary:
	if season == null or not _matches(season, binding(season._dynasty_career_session)):
		return {}
	# Snapshot a detached state view. Never temporarily remove live owner authority.
	var raw: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			raw.set(property.name, season.get(property.name))
	raw._dynasty_career_session = {}
	raw._dynasty_owner_binding = {}
	var inner: Dictionary = SeasonSave._ac02_passive_15_snapshot(raw)
	return wrap_checkpoint(inner, season._dynasty_career_session)
