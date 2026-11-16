class_name WorkingPitchDynastySave
extends RefCounted
## Explicit current-book Dynasty admission. Raw100 is not durable owner authority.
## Bound101 preserves the exact raw bytes and independently validates its session.

const VERSION: int = 100
const BOUND_VERSION: int = 101
const WORKER_VERSION: int = 10
const Historical = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
const TIER_VERSION: int = BOUND_VERSION
const RAW_TIER_VERSION: int = VERSION
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")


static func leaf_valid(data: Variant, catalog: String) -> bool:
	return data is Dictionary and catalog == WorkingPitchCatalog.signature() \
		and WorkingPitchProgression.is_version(data.get("version"), 57) \
		and not data.has("career") and not data.has("ownership") \
		and data.get("build") is Dictionary \
		and not WorkingPitchProgression.unwrap_build(data.build).is_empty() \
		and LeagueRules.dynasty(data.build.get("league_rules", {}))


static func parts(value: Variant) -> Dictionary:
	if not value is Dictionary or Historical.snapshot_reference(value).bytes > 8 * 1024 * 1024 \
		or not Profile.keys(value, ["version", "pitch_catalog", "checkpoint"]) \
		or not WorkingPitchProgression.is_version(value.version, VERSION) \
		or value.pitch_catalog != WorkingPitchCatalog.signature() or not value.checkpoint is Dictionary:
		return {}
	var raw: Dictionary = value.checkpoint
	if not Profile.keys(raw, ["version", "access", "inventory_rules", "dynasty_start", "checkpoint"]) \
		or not Historical.Owned.version_in(raw.version, [80, Historical.RAW_TIER_VERSION]) \
		or ClosedContentAccess.normalize(raw.access).is_empty() \
		or not raw.inventory_rules is Dictionary \
		or (not raw.inventory_rules.is_empty() and not SeasonInventoryRules.valid(raw.inventory_rules)) \
		or not raw.dynasty_start is Dictionary:
		return {}
	var start: Dictionary = Profile.normalize(raw.dynasty_start)
	var data: Dictionary = Historical.core(raw)
	if start.is_empty() or start.get("pitch_catalog") != value.pitch_catalog \
		or not ClubCareer.same(start.get("access"), raw.access) \
		or not leaf_valid(data, value.pitch_catalog) \
		or not ClubCareer.same(raw.checkpoint.league_rules, data.build.league_rules):
		return {}
	return {"raw": raw, "data": data, "start": start}


static func supported(season: SeasonState) -> bool:
	return season != null and season.build != null and season.build.pitch_catalog_current() \
		and season.career == null and not season.league_career \
		and LeagueRules.dynasty(season.league_rules) and season.league_live \
		and not season._closed_access.is_empty() and not season._dynasty_start.is_empty() \
		and season.player_access.is_empty() and season.home_property.is_empty() \
		and season.npc_venues.is_empty() and season.final_venue.is_empty() \
		and season._standard_live_context.is_empty() and season._league_home_context.is_empty()


static func capture_raw(season: SeasonState) -> Dictionary:
	if not supported(season):
		return {}
	# Detached view retains all gameplay contexts and journals. Only owner routing
	# metadata is omitted from a raw checkpoint, as on the historical raw route.
	var raw: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			raw.set(property.name, season.get(property.name))
	raw._dynasty_career_session = {}
	raw._dynasty_owner_binding = {}
	var result: Dictionary = {"version": VERSION, "pitch_catalog": WorkingPitchCatalog.signature(),
		"checkpoint": SeasonSave._ac02_passive_15_snapshot(raw)}
	return result if not parts(result).is_empty() else {}


static func restore_raw(value: Dictionary) -> SeasonState:
	var unpacked: Dictionary = parts(value)
	if unpacked.is_empty():
		return null
	var raw: Dictionary = unpacked.raw
	var season: SeasonState = SeasonSave._decode_closed_league(raw.checkpoint,
		raw.inventory_rules, raw.dynasty_start, raw.access, null, [], {}, value.pitch_catalog, VERSION)
	return season if supported(season) else null


static func wrap_checkpoint(inner: Dictionary, context: Dictionary) -> Dictionary:
	var binding: Dictionary = Historical.binding(context)
	var season: SeasonState = restore_raw(inner)
	if binding.is_empty() or not Historical._matches(season, binding):
		return {}
	return {"version": BOUND_VERSION, "pitch_catalog": WorkingPitchCatalog.signature(),
		"session": binding, "checkpoint": inner.duplicate(true)}


static func qualify(value: Variant) -> Dictionary:
	if not value is Dictionary or Historical.snapshot_reference(value).bytes > 8 * 1024 * 1024 \
		or not Profile.keys(value, ["version", "pitch_catalog", "session", "checkpoint"]) \
		or not WorkingPitchProgression.is_version(value.version, BOUND_VERSION) \
		or value.pitch_catalog != WorkingPitchCatalog.signature() \
		or not value.checkpoint is Dictionary:
		return {}
	var context: Dictionary = Historical.binding(value.session)
	var season: SeasonState = restore_raw(value.checkpoint)
	if context.is_empty() or not Historical._matches(season, context):
		return {}
	season._dynasty_career_session = context.duplicate(true)
	return {"inner": value.checkpoint.duplicate(true), "season": season, "session": context,
		"raw_reference": Historical.snapshot_reference(value.checkpoint),
		"reference": Historical.snapshot_reference(value)}


static func capture(season: SeasonState) -> Dictionary:
	var raw: Dictionary = capture_raw(season)
	if raw.is_empty() or season._dynasty_career_session.is_empty():
		return raw
	return wrap_checkpoint(raw, season._dynasty_career_session)


static func restore(value: Dictionary) -> SeasonState:
	return restore_raw(value) if WorkingPitchProgression.is_version(value.get("version"), VERSION) \
		else qualify(value).get("season")


static func core(value: Dictionary) -> Dictionary:
	return parts(value).get("data", {})


static func binding(value: Variant) -> Dictionary:
	return Historical.binding(value)


static func binding_for(season: SeasonState, owner: String, lineage: String,
	generation: int, ordinal: int, id: String) -> Dictionary:
	return Historical.binding_for(season, owner, lineage, generation, ordinal, id)


static func snapshot_reference(value: Dictionary) -> Dictionary:
	return Historical.snapshot_reference(value)


static func worker_request(season: SeasonState, token: String, key: String, fixture: int) -> Dictionary:
	var snapshot: Dictionary = capture(season)
	if snapshot.get("version") != BOUND_VERSION:
		return {}
	var path: String = SeasonSave._dynasty_owner_path
	var binding: Dictionary = season._dynasty_owner_binding
	if path.is_empty() or binding.get("path") != path:
		return {}
	var absolute: String = SeasonSave.DYNASTY_OWNER_STORE._canonical(path)
	if FileAccess.file_exists(absolute + ".intent"):
		return {}
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(absolute)
	var owner: Dictionary = found.get("owner", {})
	var slot: Dictionary = owner.get("dynasty", {})
	if found.get("status") != "ready" or owner.get("version") != 3 \
		or owner.get("selected") != "dynasty" or binding.get("revision") != found.get("revision") \
		or binding.get("session_id") != slot.get("session_id") \
		or load("res://src/gameplay/season/dynasty_career_owner.gd").validate_selected(owner, snapshot) == null:
		return {}
	return {"version": WORKER_VERSION, "pitch_catalog": WorkingPitchCatalog.signature(),
		"token": token, "request": key, "fixture": fixture, "season": snapshot,
		"owner": {"path": absolute, "owner_id": owner.owner_id, "revision": found.revision,
			"session_id": slot.session_id, "reference": slot.reference.duplicate(true)}}


static func decode_worker(input: Dictionary, token: String) -> SeasonState:
	if not Profile.keys(input, ["version", "pitch_catalog", "token", "request", "fixture", "season", "owner"]) \
		or not WorkingPitchProgression.is_version(input.version, WORKER_VERSION) \
		or input.pitch_catalog != WorkingPitchCatalog.signature() or input.token != token \
		or not input.request is String or input.request.length() != 64 \
		or not Profile.whole(input.fixture, 0, 32) or not input.season is Dictionary \
		or not Profile.keys(input.owner, ["path", "owner_id", "revision", "session_id", "reference"]):
		return null
	var context: Dictionary = input.owner
	if not context.path is String or not context.path.is_absolute_path() \
		or context.path != SeasonSave.DYNASTY_OWNER_STORE._canonical(context.path) \
		or FileAccess.file_exists(context.path + ".intent"):
		return null
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(context.path)
	var owner: Dictionary = found.get("owner", {})
	var slot: Dictionary = owner.get("dynasty", {})
	if found.get("status") != "ready" or owner.get("version") != 3 \
		or owner.get("selected") != "dynasty" or owner.get("owner_id") != context.owner_id \
		or found.get("revision") != context.revision or slot.get("session_id") != context.session_id \
		or not ClubCareer.same(slot.get("reference"), context.reference):
		return null
	var season: SeasonState = load("res://src/gameplay/season/dynasty_career_owner.gd").validate_selected(owner, input.season)
	if season == null:
		return null
	SeasonSave._dynasty_owner_path = context.path
	SeasonSave._bind_owner_season(season, found)
	return season


static func requires_owner(season: SeasonState) -> bool:
	return season != null and season.build != null and season.build.pitch_catalog_current() \
		and (LeagueRules.dynasty(season.league_rules) or not season._dynasty_start.is_empty()
			or not season._dynasty_career_session.is_empty())


static func owner_context_valid(season: SeasonState) -> bool:
	# Public writes may contain new gameplay. Check the durable identity here;
	# the Store separately validates its exact checkpoint extension before commit.
	if not requires_owner(season):
		return true
	if not SeasonSave.dynasty_owner_bound() or SeasonSave._dynasty_owner_content_blocked \
		or season._dynasty_career_session.is_empty():
		return false
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	var slot: Dictionary = owner.get("dynasty", {})
	var binding: Dictionary = season._dynasty_owner_binding
	return found.get("status") == "ready" and owner.get("version") == 3 \
		and owner.get("selected") == "dynasty" and binding.get("path") == SeasonSave._dynasty_owner_path \
		and binding.get("revision") == found.get("revision") \
		and binding.get("session_id") == slot.get("session_id") \
		and season._dynasty_career_session.get("session_id") == slot.get("session_id")


static func public_playable(season: SeasonState) -> bool:
	if not requires_owner(season):
		return true
	if not owner_context_valid(season):
		return false
	var found: Dictionary = SeasonSave.DYNASTY_OWNER_STORE.inspect(SeasonSave._dynasty_owner_path)
	return load("res://src/gameplay/season/dynasty_career_owner.gd").validate_selected(
		found.get("owner", {}), capture(season)) != null
