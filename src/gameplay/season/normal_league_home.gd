extends RefCounted
## Save93: ordinary LeagueCareer with a frozen paid home, never a Dynasty owner.
const VERSION: int = 93
# Route-local implementation scope. Runtime qualification remains separate.
# A future shared adapter never enters this route just because Save 91 accepts it.
const FLAT_LAYOUTS: Array[int] = [12, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
	28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45]
# Historical entry3/4/6 keeps its grammar, including original Yard fixtures5/7.
const LEGACY_LAYOUTS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
# Exact independent entry12/14/16/28/34 contracts, never snapshot8 aliases.
const SEPARATE_LAYOUTS: Array[int] = [14, 15, 16, 17, 47]
const ClubLeagueCareer = preload("res://src/gameplay/season/club_league_career.gd")
const Alternate = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Owned = preload("res://src/gameplay/season/league_owned_draft_save.gd")

static func prepare(season: SeasonState) -> bool:
	if season == null or season.career == null or not season.league_career \
		or not season._league_home_context.is_empty() or not season.home_property.is_empty() \
		or not season.player_results.is_empty():
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true) if paid != null else {}
	if not _supported(home, season.league_rules): return false
	season.home_property = home.duplicate(true)
	season._league_home_context = {"format": VERSION, "home_property": home.duplicate(true)}
	return matches(season)

static func _supported(home: Dictionary, rules: Dictionary) -> bool:
	# Keep normal93's qualification matrix independent of future shared adapters.
	if rules.get("league") not in ["dugout", "sponsorship", "academy", "equipment", "earnings", "doubleheader", "scramble"] \
		or not SeasonOwnership._whole(rules.get("tier"), 0, 4): return false
	if not home.get("layout") is Dictionary: return false
	var version: Variant = home.layout.get("version")
	if version in FLAT_LAYOUTS: return Alternate.flat_shared_home(home)
	if version in SEPARATE_LAYOUTS: return Alternate.separate_shared_home(home)
	if version in LEGACY_LAYOUTS:
		return Alternate.legacy_shared_home(home) or Alternate.legacy_night_shared_home(home)
	# Closed13/46, wrapped terrain and modern owned_surface_night stay excluded.
	return false

static func detached(season: SeasonState) -> SeasonState:
	var result: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result.set(property.name, season.get(property.name))
	result.home_property = {}
	result._league_home_context = {}
	result._pool_replay_ledger = null
	return result

static func matches(season: SeasonState) -> bool:
	if season == null or not SeasonOwnership._keys(season._league_home_context, ["format", "home_property"]) \
		or season._league_home_context.format != VERSION \
		or not season._dynasty_career_session.is_empty() or not season._dynasty_owner_binding.is_empty() \
		or not season._closed_access.is_empty() or not season._dynasty_start.is_empty() \
		or not season._standard_live_context.is_empty() or not season.npc_venues.is_empty() \
		or not season.final_venue.is_empty() or not season.owned_surface_night.is_empty() \
		or not ClubCareer.same(season.home_property, season._league_home_context.home_property) \
		or not _supported(season.home_property, season.league_rules):
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career) if season.career != null else season._pool_replay_ledger
	if paid == null or not StadiumLayoutSnapshot.matches(season.home_property, paid): return false
	if season.career != null and (not season.league_career or not ClubLeagueCareer.context_matches(season, season.career)):
		return false
	return detached(season).league_context_consistent()

static func capture(season: SeasonState) -> Dictionary:
	if not matches(season) or season.career == null or not season.league_career: return {}
	var checkpoint: Dictionary = SeasonSave.snapshot(detached(season))
	if checkpoint.is_empty(): return {}
	var parts: Dictionary = Owned.unpack(checkpoint)
	var closed: Dictionary = Owned.closed(parts.get("checkpoint", {}))
	if closed.is_empty(): return {}
	closed["normal_home"] = StadiumLayoutSnapshot.key(season.home_property)
	return {"version": VERSION, "home_property": season.home_property.duplicate(true), "checkpoint": checkpoint}

static func decode(value: Variant) -> SeasonState:
	if not SeasonOwnership._keys(value, ["version", "home_property", "checkpoint"]) \
		or not SeasonOwnership._whole(value.version, VERSION, VERSION) or not value.home_property is Dictionary:
		return null
	var owned: Dictionary = Owned.unpack(value.checkpoint)
	if owned.is_empty(): return null
	var mixed: Dictionary = owned.checkpoint
	if not SeasonOwnership._keys(mixed, ["version", "career", "checkpoint"]) \
		or not SeasonOwnership._whole(mixed.version, 81, 81) or not mixed.checkpoint is Dictionary: return null
	var career: ClubCareer = ClubCareer.from_data(mixed.career)
	if career == null or career.current <= 0 or career.current != career.runs.size(): return null
	var paid: ClubAssetLedger = ClubPlayers.assets(career)
	var rules: Dictionary = career.runs[-1].get("league_rules", {})
	if not _supported(value.home_property, rules) or not StadiumLayoutSnapshot.matches(value.home_property, paid): return null
	var closed: Dictionary = mixed.checkpoint
	var inventory: Dictionary = {}
	if Owned.version_in(closed.get("version"), [78]):
		if not SeasonOwnership._keys(closed, ["version", "inventory_rules", "checkpoint"]) \
			or not SeasonInventoryRules.valid(closed.inventory_rules) or not closed.checkpoint is Dictionary: return null
		inventory = closed.inventory_rules
		closed = closed.checkpoint
	var expected: int = 82 if int(rules.tier) > 0 else (77 if LeagueRules.doubleheader(rules) else 76)
	if not Owned.version_in(closed.get("version"), [expected]) \
		or closed.get("normal_home") != StadiumLayoutSnapshot.key(value.home_property): return null
	closed = closed.duplicate(true)
	closed.erase("normal_home")
	return SeasonSave._decode_closed_league(closed, inventory, null, {}, career, owned.players,
		{"format": VERSION, "home_property": value.home_property.duplicate(true)})

static func install_replay(season: SeasonState, context: Dictionary, career: ClubCareer) -> bool:
	if career == null or season == null or not SeasonOwnership._keys(context, ["format", "home_property"]) \
		or context.format != VERSION or not context.home_property is Dictionary \
		or not _supported(context.home_property, season.league_rules): return false
	var paid: ClubAssetLedger = ClubPlayers.assets(career)
	if paid == null or not StadiumLayoutSnapshot.matches(context.home_property, paid): return false
	season.home_property = context.home_property.duplicate(true)
	season._league_home_context = context.duplicate(true)
	season._pool_replay_ledger = paid
	return true


static func recapture(season: SeasonState, home: Dictionary) -> bool:
	if season != null and season._league_home_context.get("format") == 94:
		return load("res://src/gameplay/season/normal_league_time_candidate.gd").recapture(season, home)
	# Ordinary first-pick lock: only a detached, editable pre-draft transaction
	# may replace BOTH admitted field and context before its durable publication.
	if season == null or season._league_home_context.get("format") != VERSION \
		or season.phase != SeasonState.Phase.DRAFT or not season.picks.is_empty() \
		or not season.player_results.is_empty() or season.physical == null \
		or not season.physical.pending.is_empty() or not season.physical.reports.is_empty() \
		or not ClubConstruction.editable(season) or not _supported(home, season.league_rules): return false
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	if paid == null or not ClubCareer.same(home, StadiumLayoutSnapshot.capture(paid, true)): return false
	season.home_property = home.duplicate(true)
	season._league_home_context = {"format": VERSION, "home_property": home.duplicate(true)}
	# Recapture runs on a disposable transaction candidate. Publish this exact
	# refreshed ledger with career/home/context only after the save succeeds.
	season._pool_replay_ledger = paid
	return matches(season)
