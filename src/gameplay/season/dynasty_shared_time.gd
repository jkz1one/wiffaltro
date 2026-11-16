extends RefCounted
## Explicit95/96 only. Paid public12/25, full policy, no ordinary shared wallet.
const ALTERNATE: int = 95
const CARRIED: int = 96
const FAMILY: String = "shared-league-owned-time-v1"
const ENTRY_ENABLED: bool = false
const PROFILES: Array[String] = ["day", "sunset", "night", "fixed_night"]
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Alternate = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Carried = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
const Normal = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
const FIELDS: Array[String] = ["version", "family", "session", "base_header", "time_run",
	"source_reference", "starting_profile", "owned_surface_night", "checkpoint"]

static func version(value: Variant) -> bool:
	return Save.Owned.version_in(value, [ALTERNATE, CARRIED])

static func header(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result.erase("checkpoint")
	return result

static func key(value: Dictionary) -> String:
	return Save.snapshot_reference(header(value)).sha256

static func header_valid(value: Variant) -> bool:
	var fields: Array = FIELDS.duplicate()
	fields.erase("checkpoint")
	if not Profile.keys(value, fields) or not version(value.version) or value.family != FAMILY \
		or Save.binding(value.session).is_empty() or not value.base_header is Dictionary \
		or not Profile.whole(value.time_run, 1, ClubCareer.MAX_RUNS) \
		or not Grant.Authority._reference_valid(value.source_reference) \
		or value.starting_profile not in PROFILES or not StadiumSurfaceNightSnapshot.policy_shape(value.owned_surface_night):
		return false
	var base: Dictionary = value.base_header
	if not ClubCareer.same(base.get("session"), value.session): return false
	if value.version == CARRIED:
		if not Carried.header_valid(base, value.session): return false
	else:
		if not Profile.keys(base, ["version", "session", "grant", "home_property"]) \
			or not Profile.whole(base.version, Alternate.VERSION, Alternate.VERSION) \
			or not base.home_property is Dictionary or not Alternate.supported(base.home_property, value.session): return false
		var grant: Dictionary = Grant._claim(base.grant)
		if grant.is_empty() or value.session.owner_id != grant.owner_id \
			or value.session.access_sha256 != ClosedContentAccess.digest(grant.access): return false
	var paid: ClubAssetLedger = _paid(base)
	if paid == null or not Normal.supported_home(base.home_property) \
		or not ClubCareer.same(base.home_property, StadiumLayoutSnapshot.capture(paid, true)): return false
	var probe: SeasonState = SeasonState.new()
	probe.season_seed = int(value.session.seed)
	probe.home_property = base.home_property.duplicate(true)
	probe._npc_replay_run = int(value.time_run)
	var policy: Dictionary = _policy(probe, paid, value.starting_profile)
	return not policy.is_empty() and ClubCareer.same(value.owned_surface_night, policy)

static func _paid(base: Dictionary) -> ClubAssetLedger:
	var grant: Dictionary = Grant._claim(base.get("grant"))
	return null if grant.is_empty() else ClubPlayers.assets(Grant.history_club(grant.history))

static func _policy(season: SeasonState, paid: ClubAssetLedger, selected: String) -> Dictionary:
	return StadiumSurfaceNightSnapshot.capture_policy(season, paid) if selected == "fixed_night" \
		else StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, selected)

static func prepare_alternate(authority: Dictionary, session: Dictionary, selected: String) -> Dictionary:
	var base: Dictionary = Alternate.prepare(authority, session)
	return from_base(base, authority.get("sessions", {}).size() + 1, selected) if not base.is_empty() else {}

static func from_base(base: Dictionary, run: int, selected: String) -> Dictionary:
	if selected not in PROFILES or not Save.Owned.version_in(base.get("version"), [91, 92]) \
		or not base.get("checkpoint") is Dictionary or not Profile.whole(run, 1, ClubCareer.MAX_RUNS): return {}
	var checked: Dictionary = Carried.qualify(base, Carried.header(base)) if base.version == 92 \
		else Alternate.qualify_bound(base, base.session, base.grant, base.home_property)
	if checked.is_empty() or not load("res://src/gameplay/season/dynasty_league_home_save.gd").prephysical(checked.season): return {}
	var probe: SeasonState = checked.season
	probe._npc_replay_run = run
	var value: Dictionary = {"version": CARRIED if base.version == 92 else ALTERNATE, "family": FAMILY,
		"session": base.session.duplicate(true), "base_header": Carried.header(base), "time_run": run,
		"source_reference": Save.snapshot_reference(base), "starting_profile": selected,
		"owned_surface_night": _policy(probe, _paid(base), selected), "checkpoint": base.checkpoint.duplicate(true)}
	if not header_valid(header(value)): return {}
	var raw: Dictionary = _unbound(value)
	var closed: Dictionary = _closed(raw)
	if closed.is_empty(): return {}
	closed["shared_time_home"] = key(value)
	value.checkpoint = _bind(raw, value.session, value.version)
	return value if not qualify(value, header(value)).is_empty() else {}

static func _unbound(value: Dictionary) -> Dictionary:
	if value.version == ALTERNATE: return Alternate.unbound(value.checkpoint, value.session).duplicate(true)
	var bound: Dictionary = value.checkpoint
	if not Profile.keys(bound, ["version", "session", "checkpoint"]) \
		or not Profile.whole(bound.version, Save.TIER_VERSION if int(value.session.tier) > 0 else Save.VERSION,
			Save.TIER_VERSION if int(value.session.tier) > 0 else Save.VERSION) \
		or not ClubCareer.same(bound.session, value.session) or not bound.checkpoint is Dictionary: return {}
	return bound.checkpoint.duplicate(true)

static func _closed(raw: Dictionary) -> Dictionary:
	var unpacked: Dictionary = Save.Owned.unpack(raw) if raw.get("version") == Save.Owned.VERSION else {}
	var payload: Dictionary = unpacked.get("checkpoint", raw)
	return payload.get("checkpoint", {}) if payload.get("checkpoint") is Dictionary else {}

static func _bind(raw: Dictionary, session: Dictionary, format: int) -> Dictionary:
	return Alternate.bind_raw(raw, session) if format == ALTERNATE else {
		"version": Save.TIER_VERSION if int(session.tier) > 0 else Save.VERSION,
		"session": session.duplicate(true), "checkpoint": raw}

static func original(value: Dictionary) -> Dictionary:
	# Admission only: strip the new marker only after proving no physical work.
	var checked: Dictionary = qualify(value, header(value))
	if checked.is_empty() or not checked.season.results.is_empty() \
		or not checked.season.player_results.is_empty() or checked.season.physical.cursor != 0 \
		or not checked.season.physical.reports.is_empty() or not checked.season.physical.pending.is_empty(): return {}
	var base: Dictionary = value.base_header.duplicate(true)
	base["checkpoint"] = _bind(checked.inner.duplicate(true), value.session, value.version)
	return base if ClubCareer.same(Save.snapshot_reference(base), value.source_reference) else {}

static func qualify(value: Variant, expected: Dictionary) -> Dictionary:
	if not Profile.keys(value, FIELDS) or not header_valid(expected) \
		or not ClubCareer.same(header(value), expected) or not value.checkpoint is Dictionary \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024: return {}
	var raw: Dictionary = _unbound(value)
	var closed: Dictionary = _closed(raw)
	if closed.is_empty() or closed.get("shared_time_home") != key(value): return {}
	closed.erase("shared_time_home")
	var core: Dictionary = Save.core(raw)
	if core.is_empty(): return {}
	var owned: Dictionary = Save.Owned.unpack(raw) if value.version == ALTERNATE else {}
	var payload: Dictionary = owned.get("checkpoint", raw)
	var fields: Array = ["version", "access", "inventory_rules", "checkpoint"]
	if value.version == CARRIED: fields.append("dynasty_start")
	if not Profile.keys(payload, fields) or not Profile.whole(payload.version,
		Save.RAW_TIER_VERSION if int(value.session.tier) > 0 else 80,
		Save.RAW_TIER_VERSION if int(value.session.tier) > 0 else 80) \
		or not payload.inventory_rules is Dictionary \
		or (not payload.inventory_rules.is_empty() and not SeasonInventoryRules.valid(payload.inventory_rules)): return {}
	var rules: Dictionary = LeagueRules.capture_tier("dynasty", int(value.session.tier)) if value.version == CARRIED \
		else Alternate.rules_for(value.session)
	var closed_version: int = Save.TIER_CHECKPOINT_VERSION if int(value.session.tier) > 0 \
		else (77 if LeagueRules.doubleheader(rules) else 76)
	if not Profile.whole(closed.get("version"), closed_version, closed_version): return {}
	var access: Dictionary = value.base_header.lineage.start_profile.access if value.version == CARRIED \
		else value.base_header.grant.access
	if not ClubCareer.same(payload.access, access) or not ClubCareer.same(closed.league_rules, rules) \
		or (value.version == ALTERNATE and (owned.is_empty() or not ClubCareer.same(owned.players, value.base_header.grant.player_access))) \
		or (value.version == CARRIED and (not ClubCareer.same(payload.dynasty_start, value.base_header.lineage.start_profile)
			or not SeasonInventoryRules.valid(payload.inventory_rules))): return {}
	# JSON versions are floats. Normalize only this already-validated local route
	# discriminator; the full saved header, policy and exact references stay intact.
	var context: Dictionary = {"format": int(value.version), "header": expected.duplicate(true)}
	var season: SeasonState = SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		core, value.owned_surface_night, false, rules, true, payload.inventory_rules,
		Profile.normalize(payload.dynasty_start) if value.version == CARRIED else null,
		ClosedContentAccess.normalize(access), null, owned.get("players", []), {}, context)
	if season == null: return {}
	return {"session": value.session.duplicate(true), "time_home": expected.duplicate(true),
		"season": season, "inner": raw, "reference": Save.snapshot_reference(value),
		"raw_reference": Save.snapshot_reference(raw)}

static func install_replay(season: SeasonState, context: Dictionary) -> bool:
	if season == null or not Profile.keys(context, ["format", "header"]) \
		or not version(context.format) or not header_valid(context.header) \
		or context.format != context.header.version or season.career != null or season.league_career: return false
	var value: Dictionary = context.header
	var base: Dictionary = value.base_header
	var access: Dictionary = base.lineage.start_profile.access if value.version == CARRIED else base.grant.access
	if season.season_seed != value.session.seed or not ClubCareer.same(season._closed_access, access) \
		or (value.version == CARRIED and not ClubCareer.same(season._dynasty_start, base.lineage.start_profile)) \
		or (value.version == ALTERNATE and not ClubCareer.same(season.player_access, base.grant.player_access)): return false
	season.home_property = base.home_property.duplicate(true)
	season.owned_surface_night = value.owned_surface_night.duplicate(true)
	season._npc_replay_run = int(value.time_run)
	season._pool_replay_ledger = _paid(base)
	season._dynasty_career_session = value.session.duplicate(true)
	season._league_home_context = context.duplicate(true)
	return StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, season._pool_replay_ledger)

static func detached(season: SeasonState) -> SeasonState:
	var result: SeasonState = Alternate.detached_state(season)
	result.owned_surface_night = {}
	result._npc_replay_run = -1
	return result

static func matches(season: SeasonState) -> bool:
	if season == null or not Profile.keys(season._league_home_context, ["format", "header"]) \
		or not version(season._league_home_context.format) or not header_valid(season._league_home_context.header) \
		or season.career != null or season.league_career or not season.npc_venues.is_empty() \
		or not season.final_venue.is_empty() or not season._standard_live_context.is_empty(): return false
	var value: Dictionary = season._league_home_context.header
	if season._league_home_context.format != value.version or not Save._matches(season, value.session) \
		or not ClubCareer.same(season._dynasty_career_session, value.session) \
		or not ClubCareer.same(season.home_property, value.base_header.home_property) \
		or not ClubCareer.same(season.owned_surface_night, value.owned_surface_night) \
		or season._npc_replay_run != value.time_run or season._pool_replay_ledger == null \
		or not ClubCareer.same(season._pool_replay_ledger.to_data(), _paid(value.base_header).to_data()): return false
	if value.version == ALTERNATE and (not ClubCareer.same(season.player_access, value.base_header.grant.player_access)
		or not ClubPlayerDraft.frozen_matches(season)): return false
	if value.version == CARRIED and not ClubCareer.same(season._dynasty_start, value.base_header.lineage.start_profile): return false
	return StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, season._pool_replay_ledger) \
		and detached(season).league_context_consistent()

static func capture(season: SeasonState) -> Dictionary:
	if not matches(season): return {}
	var raw: Dictionary = SeasonSave.snapshot(detached(season))
	var closed: Dictionary = _closed(raw)
	if closed.is_empty(): return {}
	var value: Dictionary = season._league_home_context.header.duplicate(true)
	closed["shared_time_home"] = key(value)
	value["checkpoint"] = _bind(raw, value.session, value.version)
	return value if not qualify(value, header(value)).is_empty() else {}

static func decode_current(value: Dictionary) -> SeasonState:
	if not SeasonSave.dynasty_owner_bound(): return null
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	var slot: String = "dynasty" if value.get("version") == CARRIED else "other"
	if found.get("status") not in ["ready", "recoverable"] or owner.get("selected") != slot: return null
	var entry: Dictionary = owner.get("career", {}).get("sessions", {}).get(owner.get(slot, {}).get("session_id", ""), {})
	return qualify(value, entry.get("time_home", {})).get("season")

static func slot(checked: Dictionary) -> Dictionary:
	var replay = load("res://src/gameplay/season/dynasty_career_owner_replay.gd")
	var result: Dictionary = replay.slot(checked.session.session_id, checked.reference, checked.inner, checked.season)
	result.frontier.header_hash = Save.snapshot_reference({"base": result.frontier.header_hash, "time": checked.time_home}).sha256
	return result

static func extends_checkpoint(before: Dictionary, after: Dictionary, frontier: Dictionary) -> bool:
	if not before.has("time_home") or not after.has("time_home") \
		or not ClubCareer.same(before.time_home, after.time_home) \
		or not ClubCareer.same(slot(before).frontier, frontier): return false
	var replay = load("res://src/gameplay/season/dynasty_career_owner_replay.gd")
	return replay.Ops._extends(Save.core, replay.Legacy._prefix, replay.Lineage,
		_pending_extends, before.inner, after.inner, frontier)

static func _pending_extends(before: Dictionary, after: Dictionary) -> bool:
	var replay = load("res://src/gameplay/season/dynasty_career_owner_replay.gd")
	return replay.Ops._pending_extends(replay.Legacy.Profile, replay.Legacy._prefix, _human_matches, before, after)

static func _human_matches(human: Array, result: Dictionary) -> bool:
	return load("res://src/gameplay/season/league_home_night_result.gd").human_matches(human, result) \
		if result.has("night_evidence") else Alternate._human_matches(human, result)

static func preference(season: SeasonState) -> String:
	if season == null or season.owned_surface_night.is_empty(): return ""
	var policy: Dictionary = season.owned_surface_night
	if policy.get("version") == 1: return "fixed_night"
	return str(policy.get("mode", "")) if policy.get("version") == 2 else "unsupported"
