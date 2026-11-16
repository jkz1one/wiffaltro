extends RefCounted
## Explicit92 replay; carried access/start are independent of the asset grant.
const VERSION: int = 92
# Route-local implementation scope. Runtime qualification remains separate.
# A future shared adapter never enters this route just because Save 91 accepts it.
const FLAT_LAYOUTS: Array[int] = [12, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
	28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]
# Historical entry3/4/6 keeps its grammar, including original Yard fixtures5/7.
const LEGACY_LAYOUTS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
# Exact independent entry12/14/16/28/34 contracts, never snapshot8 aliases.
const SEPARATE_LAYOUTS: Array[int] = [14, 15, 16, 17, 47]
const Proposal = preload("res://src/gameplay/season/dynasty_carried_home_proposal.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Alternate = preload("res://src/gameplay/season/dynasty_league_home_live.gd")

static func header(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("checkpoint")
	return result

static func header_valid(value: Variant, session: Dictionary) -> bool:
	if not Profile.keys(value, ["version", "owner_id", "owner_revision", "owner_reference",
		"source_reference", "lineage", "session", "grant", "home_property"]) \
		or not Profile.whole(value.version, VERSION, VERSION) \
		or not Profile.whole(value.owner_revision, 1, Profile.MAX_ORDINAL) \
		or not ClubCareer.same(value.session, session) or session.get("league") != "dynasty" \
		or value.owner_id != session.get("owner_id") \
		or not value.lineage is Dictionary or not value.grant is Dictionary \
		or not value.home_property is Dictionary:
		return false
	var lineage: Dictionary = load("res://src/gameplay/season/dynasty_career_lineage.gd").normalize(value.lineage)
	var grant: Dictionary = Grant._claim(value.grant)
	if lineage.is_empty() or grant.is_empty() or grant.owner_id != session.owner_id \
		or lineage.id != session.lineage_id or lineage.generation != session.generation \
		or lineage.ordinal != session.ordinal or lineage.state != "active" \
		or session.seed != lineage.start_profile.seed \
		or not load("res://src/gameplay/season/dynasty_owner.gd").reference_valid(value.owner_reference) \
		or not load("res://src/gameplay/season/dynasty_owner.gd").reference_valid(value.source_reference):
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history))
	return paid != null and supported_home(value.home_property, session) \
		and ClubCareer.same(value.home_property, StadiumLayoutSnapshot.capture(paid, true)) \
		and (not Alternate.modern_cleared(value.home_property) or Alternate.paid_modern_clearance(paid))

static func supported_home(home: Dictionary, session: Dictionary) -> bool:
	if session.get("league") != "dynasty" or not Profile.whole(session.get("tier"), 0, 4):
		return false
	if not home.get("layout") is Dictionary: return false
	var version: Variant = home.layout.get("version")
	if version in FLAT_LAYOUTS: return Alternate.flat_shared_home(home)
	if version in SEPARATE_LAYOUTS: return Alternate.separate_shared_home(home)
	if version in LEGACY_LAYOUTS:
		return Alternate.legacy_shared_home(home) or Alternate.legacy_night_shared_home(home)
	# Closed13/46, wrapped terrain and modern owned_surface_night stay excluded.
	return false

static func qualify(value: Variant, expected: Dictionary) -> Dictionary:
	if not value is Dictionary or not value.get("checkpoint") is Dictionary \
		or not ClubCareer.same(header(value), expected) \
		or not header_valid(expected, Save.binding(expected.get("session"))) \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return {}
	var session: Dictionary = expected.session
	var bound: Dictionary = value.checkpoint
	var binding_version: int = Save.TIER_VERSION if int(session.tier) > 0 else Save.VERSION
	var raw_version: int = Save.RAW_TIER_VERSION if int(session.tier) > 0 else 80
	var closed_version: int = Save.TIER_CHECKPOINT_VERSION if int(session.tier) > 0 else 76
	if not Profile.keys(bound, ["version", "session", "checkpoint"]) \
		or not Profile.whole(bound.version, binding_version, binding_version) \
		or not ClubCareer.same(bound.session, session) or not bound.checkpoint is Dictionary:
		return {}
	var raw: Dictionary = bound.checkpoint
	if not Profile.keys(raw, ["version", "access", "inventory_rules", "dynasty_start", "checkpoint"]) \
		or not Profile.whole(raw.version, raw_version, raw_version) \
		or not ClubCareer.same(raw.dynasty_start, expected.lineage.start_profile) \
		or not ClubCareer.same(raw.access, raw.dynasty_start.get("access")) \
		or not raw.inventory_rules is Dictionary or not SeasonInventoryRules.valid(raw.inventory_rules) \
		or not raw.checkpoint is Dictionary \
		or not Profile.whole(raw.checkpoint.get("version"), closed_version, closed_version) \
		or not ClubCareer.same(raw.checkpoint.get("league_rules"), LeagueRules.capture_tier("dynasty", int(session.tier))):
		return {}
	var core: Dictionary = Save.core(raw)
	if core.is_empty(): return {}
	var context: Dictionary = {"format": VERSION, "header": expected.duplicate(true),
		"session": session.duplicate(true), "grant": expected.grant.duplicate(true),
		"home_property": expected.home_property.duplicate(true)}
	var season: SeasonState = SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		core, {}, false, LeagueRules.capture_tier("dynasty", int(session.tier)), true, raw.inventory_rules,
		Profile.normalize(raw.dynasty_start), ClosedContentAccess.normalize(raw.access), null, [], {}, context)
	if season == null: return {}
	return {"session": session, "season": season, "inner": raw,
		"dynasty_home": expected, "reference": Save.snapshot_reference(value),
		"raw_reference": Save.snapshot_reference(raw)}

static func install_replay(season: SeasonState, context: Dictionary) -> bool:
	if season == null or not Profile.keys(context, ["format", "header", "session", "grant", "home_property"]) \
		or context.format != VERSION or not header_valid(context.header, Save.binding(context.session)) \
		or not ClubCareer.same(context.grant, context.header.grant) \
		or not ClubCareer.same(context.home_property, context.header.home_property) \
		or not ClubCareer.same(season._dynasty_start, context.header.lineage.start_profile) \
		or not ClubCareer.same(season._closed_access, season._dynasty_start.get("access")):
		return false
	season.home_property = context.home_property.duplicate(true)
	season._league_home_context = context.duplicate(true)
	season._dynasty_career_session = context.session.duplicate(true)
	season._pool_replay_ledger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(context.grant.history))
	return season._pool_replay_ledger != null

static func matches(season: SeasonState) -> bool:
	if season == null or season._league_home_context.get("format") != VERSION \
		or season.career != null or not season.npc_venues.is_empty() \
		or not season.final_venue.is_empty() or not season.owned_surface_night.is_empty(): return false
	var context: Dictionary = season._league_home_context
	if not Profile.keys(context, ["format", "header", "session", "grant", "home_property"]) \
		or not header_valid(context.header, Save.binding(context.session)) \
		or not ClubCareer.same(context.grant, context.header.grant) \
		or not ClubCareer.same(context.home_property, context.header.home_property) \
		or not ClubCareer.same(season.home_property, context.home_property) \
		or not ClubCareer.same(season._dynasty_career_session, context.session) \
		or not ClubCareer.same(season._dynasty_start, context.header.lineage.start_profile) \
		or not ClubCareer.same(season._closed_access, season._dynasty_start.get("access")) \
		or not Save._matches(season, context.session): return false
	return Alternate.detached_state(season).league_context_consistent()

static func capture(season: SeasonState) -> Dictionary:
	if not matches(season): return {}
	var context: Dictionary = season._league_home_context
	var raw: Dictionary = SeasonSave.snapshot(Alternate.detached_state(season))
	var value: Dictionary = context.header.duplicate(true)
	value["checkpoint"] = {"version": Save.TIER_VERSION if int(context.session.tier) > 0 else Save.VERSION,
		"session": context.session.duplicate(true), "checkpoint": raw}
	return value if not qualify(value, context.header).is_empty() else {}

static func decode_current(value: Dictionary) -> SeasonState:
	if not SeasonSave.dynasty_owner_bound(): return null
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	if found.get("status") not in ["ready", "recoverable"] or owner.get("selected") != "dynasty": return null
	var entry: Dictionary = owner.get("career", {}).get("sessions", {}).get(owner.dynasty.session_id, {})
	return qualify(value, entry.get("dynasty_home", {})).get("season")
