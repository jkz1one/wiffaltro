extends RefCounted
## Unqualified candidate94. Explicit ordinary time replay; public entry is disabled.
## No new owner authority, shared95/96 migration or source qualification is implied.
const VERSION: int = 94
const FAMILY: String = "ordinary-league-owned-time-v1"
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const FIELDS: Array[String] = [
	"version", "family", "home_property", "starting_profile", "owned_surface_night", "checkpoint"
]


static func prepare(season: SeasonState, profile: String) -> Dictionary:
	if season != null and season.build != null and season.build.pitch_catalog_current():
		return WorkingPitchLeagueSave.prepare_time(season, profile)
	# The existing ordinary route must first establish Career27, frozen players,
	# exact League/tier rules and paid home. Never create a second authority.
	if not _prephysical(season) or not Normal.matches(season) \
		or profile not in ["day", "sunset", "night", "fixed_night"]:
		return {}
	var original: Dictionary = Normal.capture(season)
	if original.is_empty():
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	if not supported_home(season.home_property) or paid == null:
		return {}
	var policy: Dictionary = _policy(season, paid, profile)
	if policy.is_empty():
		return {}  # No unlit fallback or implicit permission from purchased lights.
	var value: Dictionary = {
		"version": VERSION, "family": FAMILY,
		"home_property": season.home_property.duplicate(true),
		"starting_profile": profile, "owned_surface_night": policy,
		"checkpoint": original.checkpoint.duplicate(true)
	}
	var closed: Dictionary = _closed(value.checkpoint)
	if closed.is_empty():
		return {}
	closed.erase("normal_home")
	closed["normal_time_home"] = header_key(value)
	return value if not qualify_prephysical(value).is_empty() else {}


static func supported_home(home: Dictionary) -> bool:
	# Exact existing public SurfaceNight profiles, never kit candidate3,13,46,
	# standalone terrain17 or motion47. Preserve the original complete validator.
	if not SeasonOwnership._whole(home.get("version"), 8, 8) \
		or not home.get("layout") is Dictionary:
		return false
	var layout: Dictionary = home.layout
	var named: bool = (
		layout.get("version") == StadiumSurfaceLayout.VERSION
		and layout.get("family") == StadiumSurfaceLayout.FAMILY
	) or (
		layout.get("version") == StadiumFloodlightOwnedItems.LAYOUT_VERSION
		and layout.get("family") == StadiumFloodlightOwnedItems.FAMILY
	)
	return named and StadiumSurfaceNightSnapshot.PUBLIC_READY \
		and StadiumLayoutSnapshot.valid(home) and StadiumSurfaceNightSnapshot._composition(home)


static func header_key(value: Dictionary) -> String:
	var header: Dictionary = value.duplicate(true)
	header.erase("checkpoint")
	return Save.snapshot_reference(header).sha256


static func qualify_prephysical(value: Variant) -> Dictionary:
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchLeagueSave.VERSION):
		return WorkingPitchLeagueSave.qualify_time(value)
	if not SeasonOwnership._keys(value, FIELDS) \
		or not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or value.family != FAMILY or not value.home_property is Dictionary \
		or not supported_home(value.home_property) \
		or value.starting_profile not in ["day", "sunset", "night", "fixed_night"] \
		or not value.owned_surface_night is Dictionary or not value.checkpoint is Dictionary \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return {}
	var checkpoint: Dictionary = value.checkpoint.duplicate(true)
	var closed: Dictionary = _closed(checkpoint)
	if closed.is_empty() or closed.get("normal_time_home") != header_key(value) \
		or closed.has("normal_home") or not _pristine_checkpoint(closed):
		return {}
	# This bounded candidate can validate the unchanged historical chain only
	# because it proves NO played/pending evidence before changing the marker.
	# Full94 must instead install policy before replay; never strip played Night.
	closed.erase("normal_time_home")
	closed["normal_home"] = StadiumLayoutSnapshot.key(value.home_property)
	var season: SeasonState = Normal.decode({"version": Normal.VERSION,
		"home_property": value.home_property.duplicate(true), "checkpoint": checkpoint})
	if not _prephysical(season) or not Normal.matches(season) \
		or season._npc_replay_run != -1:
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	if paid == null or not ClubCareer.same(value.owned_surface_night,
		_policy(season, paid, value.starting_profile)):
		return {}
	return {"source": season, "policy": value.owned_surface_night.duplicate(true),
		"reference": Save.snapshot_reference(value), "header_key": header_key(value)}


static func current(season: SeasonState, value: Dictionary) -> bool:
	# Exact source checkpoint includes Career27, rules, players, home and journal.
	# A profile cannot migrate across a different ordinary run or refresh a draft.
	if qualify_prephysical(value).is_empty():
		return false
	return ClubCareer.same(prepare(season, value.home_context.header.starting_profile
		if WorkingPitchProgression.is_version(value.get("version"), WorkingPitchLeagueSave.VERSION)
		else value.starting_profile), value)


static func _policy(season: SeasonState, paid: ClubAssetLedger, profile: String) -> Dictionary:
	if season == null or season.career == null or season._npc_replay_run != -1 \
		or not season.owned_surface_night.is_empty() or not supported_home(season.home_property):
		return {}
	# run_id is Career27.current, never a fabricated owner-history ordinal.
	return StadiumSurfaceNightSnapshot.capture_policy(season, paid) if profile == "fixed_night" \
		else StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, profile)


static func _closed(checkpoint: Dictionary) -> Dictionary:
	var owned: Dictionary = Owned.unpack(checkpoint)
	return Owned.closed(owned.get("checkpoint", {}))


static func _pristine_checkpoint(closed: Dictionary) -> bool:
	var core: Variant = closed.get("checkpoint")
	return core is Dictionary and core.get("results") is Array and core.results.is_empty() \
		and core.get("picks") is Array and core.picks.is_empty() \
		and core.get("physical") is Dictionary \
		and core.physical.get("reports") is Array and core.physical.reports.is_empty() \
		and core.physical.get("pending") is Dictionary and core.physical.pending.is_empty()


static func _prephysical(season: SeasonState) -> bool:
	return season != null and season.career != null and season.league_career \
		and season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty() \
		and season.results.is_empty() and season.player_results.is_empty() \
		and season.physical != null and season.physical.cursor == 0 \
		and season.physical.reports.is_empty() and season.physical.pending.is_empty()


# Full candidate94 integration. The public chooser stays disabled until reviewed.
const ENTRY_ENABLED: bool = false


static func admit(season: SeasonState, profile: String) -> SeasonState:
	var value: Dictionary = prepare(season, profile)
	return null if value.is_empty() else decode(value)


static func _header(value: Dictionary) -> Dictionary:
	var header: Dictionary = value.duplicate(true)
	header.erase("checkpoint")
	return header


static func _header_valid(header: Variant) -> bool:
	var fields: Array = FIELDS.duplicate()
	fields.erase("checkpoint")
	if not SeasonOwnership._keys(header, fields) \
		or not SeasonOwnership._whole(header.version, VERSION, VERSION) \
		or header.family != FAMILY or not header.home_property is Dictionary \
		or not supported_home(header.home_property) \
		or header.starting_profile not in ["day", "sunset", "night", "fixed_night"] \
		or not StadiumSurfaceNightSnapshot.policy_shape(header.owned_surface_night):
		return false
	var policy: Dictionary = header.owned_surface_night
	return policy.version == (1 if header.starting_profile == "fixed_night" else 2) \
		and policy.mode == ("night" if header.starting_profile == "fixed_night" else header.starting_profile) \
		and ClubCareer.same(policy.candidate.entry, header.home_property)


static func detached(season: SeasonState) -> SeasonState:
	var result: SeasonState = Normal.detached(season)
	result.owned_surface_night = {}
	result._npc_replay_run = -1
	return result


static func matches(season: SeasonState) -> bool:
	if season == null or not SeasonOwnership._keys(season._league_home_context, ["format", "header"]) \
		or season._league_home_context.format != VERSION \
		or not _header_valid(season._league_home_context.header) \
		or not season._dynasty_career_session.is_empty() or not season._dynasty_owner_binding.is_empty() \
		or not season._closed_access.is_empty() or not season._dynasty_start.is_empty() \
		or not season._standard_live_context.is_empty() or not season.npc_venues.is_empty() \
		or not season.final_venue.is_empty():
		return false
	var header: Dictionary = season._league_home_context.header
	if not ClubCareer.same(season.home_property, header.home_property) \
		or not ClubCareer.same(season.owned_surface_night, header.owned_surface_night) \
		or not Normal._supported(season.home_property, season.league_rules) \
		or season._npc_replay_run != header.owned_surface_night.run_id:
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career) if season.career != null else season._pool_replay_ledger
	if paid == null or not StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, paid):
		return false
	if season.career != null and (not season.league_career \
		or season._npc_replay_run != season.career.current \
		or not Normal.ClubLeagueCareer.context_matches(season, season.career)):
		return false
	return detached(season).league_context_consistent()


static func capture(season: SeasonState) -> Dictionary:
	if season != null and season.build != null and season.build.pitch_catalog_current():
		return WorkingPitchLeagueSave.capture(season)
	if not matches(season) or season.career == null or not season.league_career:
		return {}
	var checkpoint: Dictionary = SeasonSave.snapshot(detached(season))
	var closed: Dictionary = _closed(checkpoint)
	if checkpoint.is_empty() or closed.is_empty():
		return {}
	var value: Dictionary = season._league_home_context.header.duplicate(true)
	closed["normal_time_home"] = header_key(value)
	value["checkpoint"] = checkpoint
	return value


static func decode(value: Variant) -> SeasonState:
	if value is Dictionary and WorkingPitchProgression.is_version(value.get("version"), WorkingPitchLeagueSave.VERSION):
		return WorkingPitchLeagueSave.restore(value)
	if not SeasonOwnership._keys(value, FIELDS) or not _header_valid(_header(value)) \
		or not value.checkpoint is Dictionary or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return null
	var owned: Dictionary = Owned.unpack(value.checkpoint)
	if owned.is_empty():
		return null
	var mixed: Dictionary = owned.checkpoint
	if not SeasonOwnership._keys(mixed, ["version", "career", "checkpoint"]) \
		or not SeasonOwnership._whole(mixed.version, 81, 81) or not mixed.checkpoint is Dictionary:
		return null
	var career: ClubCareer = ClubCareer.from_data(mixed.career)
	if career == null or career.current <= 0 or career.current != career.runs.size():
		return null
	var rules: Dictionary = career.runs[-1].get("league_rules", {})
	if not Normal._supported(value.home_property, rules) \
		or not StadiumLayoutSnapshot.matches(value.home_property, ClubPlayers.assets(career)):
		return null
	var closed: Dictionary = mixed.checkpoint
	var inventory: Dictionary = {}
	if Owned.version_in(closed.get("version"), [78]):
		if not SeasonOwnership._keys(closed, ["version", "inventory_rules", "checkpoint"]) \
			or not SeasonInventoryRules.valid(closed.inventory_rules) or not closed.checkpoint is Dictionary:
			return null
		inventory = closed.inventory_rules
		closed = closed.checkpoint
	var expected: int = 82 if int(rules.tier) > 0 else (77 if LeagueRules.doubleheader(rules) else 76)
	if not Owned.version_in(closed.get("version"), [expected]) \
		or closed.get("normal_time_home") != header_key(value) or closed.has("normal_home"):
		return null
	closed = closed.duplicate(true)
	closed.erase("normal_time_home")
	return SeasonSave._decode_closed_league(closed, inventory, null, {}, career, owned.players,
		{"format": VERSION, "header": _header(value)})


static func install_replay(season: SeasonState, context: Dictionary, career: ClubCareer) -> bool:
	if season == null or career == null or not SeasonOwnership._keys(context, ["format", "header"]) \
		or context.format != VERSION or not _header_valid(context.header) \
		or not Normal._supported(context.header.home_property, season.league_rules) \
		or context.header.owned_surface_night.run_id != career.current \
		or context.header.owned_surface_night.season_seed != season.season_seed:
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(career)
	if paid == null or not StadiumLayoutSnapshot.matches(context.header.home_property, paid):
		return false
	season.home_property = context.header.home_property.duplicate(true)
	season.owned_surface_night = context.header.owned_surface_night.duplicate(true)
	season._npc_replay_run = career.current
	season._pool_replay_ledger = paid
	season._league_home_context = context.duplicate(true)
	return StadiumSurfaceNightSnapshot.valid_policy(season.owned_surface_night, season, paid)


static func workshop_editable(season: SeasonState) -> bool:
	# Exception only to the ordinary94 Night freeze, never to physical/edit gates.
	# Validate the existing exact home/policy and owner BEFORE any paid command;
	# recapture then validates the proposed revision on a disposable candidate.
	return _prephysical(season) and ClubConstruction.editable(season) and matches(season)


static func recapture(season: SeasonState, home: Dictionary) -> bool:
	# Called only on the transaction's disposable candidate. Prepare everything
	# locally before replacing either pin; a failed policy never debits the source.
	if not _prephysical(season) or not ClubConstruction.editable(season) \
		or not SeasonOwnership._keys(season._league_home_context, ["format", "header"]) \
		or season._league_home_context.format != VERSION \
		or not _header_valid(season._league_home_context.header) or not supported_home(home):
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	if paid == null or not ClubCareer.same(home, StadiumLayoutSnapshot.capture(paid, true)):
		return false
	var probe: SeasonState = detached(season)
	probe.home_property = home.duplicate(true)
	var header: Dictionary = season._league_home_context.header.duplicate(true)
	var policy: Dictionary = _policy(probe, paid, header.starting_profile)
	if policy.is_empty():
		return false
	header.home_property = home.duplicate(true)
	header.owned_surface_night = policy
	probe.owned_surface_night = policy.duplicate(true)
	probe._npc_replay_run = season.career.current
	probe._pool_replay_ledger = paid
	probe._league_home_context = {"format": VERSION, "header": header}
	if not matches(probe):
		return false
	season.home_property = probe.home_property
	season.owned_surface_night = probe.owned_surface_night
	season._league_home_context = probe._league_home_context
	season._pool_replay_ledger = paid
	return true
