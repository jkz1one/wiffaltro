extends RefCounted
## Save91: explicit alternate owned-home replay. Each environment contract is named.
## Caller must supply a replay-qualified owner grant; claims never authorize runtime.
const VERSION: int = 91
const BASE_LEAGUES: Array[String] = ["dugout", "sponsorship", "academy", "equipment",
	"earnings", "doubleheader", "scramble"]
# Explicit matrix: adding a future League does not inherit modern-home admission.
const MODERN_TIERS: Dictionary = {
	"dugout": [0, 1, 2, 3, 4], "sponsorship": [0, 1, 2, 3, 4],
	"academy": [0, 1, 2, 3, 4], "equipment": [0, 1, 2, 3, 4],
	"earnings": [0, 1, 2, 3, 4], "doubleheader": [0, 1, 2, 3, 4],
	"scramble": [0, 1, 2, 3, 4]
}
# Existing complete flat snapshot8 contracts only. Named identities, not a range.
# Other complete home formats keep their separate replay/runtime/report adapters.
const FLAT_FAMILIES: Dictionary = {
	StadiumSurfaceLayout.VERSION: StadiumSurfaceLayout.FAMILY,
	StadiumFlagItems.LAYOUT_VERSION: StadiumFlagItems.FAMILY,
	StadiumGroundPropsItems.LAYOUT_VERSION: StadiumGroundPropsItems.FAMILY,
	StadiumStraightItems.LAYOUT_VERSION: StadiumStraightItems.FAMILY,
	StadiumRoofItems.LAYOUT_VERSION: StadiumRoofItems.FAMILY,
	StadiumFacilityItems.LAYOUT_VERSION: StadiumFacilityItems.FAMILY,
	StadiumBoundaryItems.LAYOUT_VERSION: StadiumBoundaryItems.FAMILY,
	StadiumReceiverOwnedItems.LAYOUT_VERSION: StadiumReceiverOwnedItems.FAMILY,
	StadiumFloodlightOwnedItems.LAYOUT_VERSION: StadiumFloodlightOwnedItems.FAMILY,
	StadiumLandscapeOwnedItems.LAYOUT_VERSION: StadiumLandscapeOwnedItems.FAMILY,
	StadiumLiveFurnishingItems.LAYOUT_VERSION: StadiumLiveFurnishingItems.FAMILY,
	StadiumSmallYardSceneryItems.LAYOUT_VERSION: StadiumSmallYardSceneryItems.FAMILY,
	StadiumMoldedSeatItems.LAYOUT_VERSION: StadiumMoldedSeatItems.FAMILY,
	StadiumGroundBoxItems.LAYOUT_VERSION: StadiumGroundBoxItems.FAMILY,
	StadiumPracticeFacilityItems.LAYOUT_VERSION: StadiumPracticeFacilityItems.FAMILY,
	StadiumTreehouseItems.LAYOUT_VERSION: StadiumTreehouseItems.FAMILY,
	StadiumLandmarkItems.LAYOUT_VERSION: StadiumLandmarkItems.FAMILY,
	StadiumOutfieldBleacherItems.LAYOUT_VERSION: StadiumOutfieldBleacherItems.FAMILY,
	StadiumRisingAppleItems.LAYOUT_VERSION: StadiumRisingAppleItems.FAMILY,
	StadiumWallTopTerraceItems.LAYOUT_VERSION: StadiumWallTopTerraceItems.FAMILY,
	StadiumPlayerTunnelItems.LAYOUT_VERSION: StadiumPlayerTunnelItems.FAMILY,
	StadiumMountedDisplayItems.LAYOUT_VERSION: StadiumMountedDisplayItems.FAMILY,
	StadiumStringLightItems.LAYOUT_VERSION: StadiumStringLightItems.FAMILY,
	StadiumSalvageCarItems.LAYOUT_VERSION: StadiumSalvageCarItems.FAMILY,
	StadiumMasteryBannerItems.LAYOUT_VERSION: StadiumMasteryBannerItems.FAMILY,
	StadiumWaterfallItems.LAYOUT_VERSION: StadiumWaterfallItems.FAMILY,
	StadiumLightingKitItems.LAYOUT_VERSION: StadiumLightingKitItems.FAMILY,
	StadiumOutfieldPlazaItems.LAYOUT_VERSION: StadiumOutfieldPlazaItems.FAMILY,
	StadiumWaterfallLiveItems.LAYOUT_VERSION: StadiumWaterfallLiveItems.FAMILY
}
# Historical complete contracts retain their own grammar; no version-range grant.
const LEGACY_FAMILIES: Dictionary = {
	1: "reference-starter-v1",
	2: "reference-seating-v2",
	3: "reference-styles-v3",
	4: "reference-club-displays-v4",
	5: "reference-ground-v5",
	6: "reference-bleachers-v6",
	7: "reference-target-v7",
	8: "reference-paired-receiver-v8",
	StadiumLightItems.LAYOUT_VERSION: "reference-yard-lights-v9",
	StadiumInfieldStyles.LAYOUT_VERSION: "reference-infield-v10",
	StadiumWallItems.LAYOUT_VERSION: "reference-wall-recipes-v11"
}
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Home = preload("res://src/gameplay/season/dynasty_league_home_save.gd")


static func supported(home: Dictionary, session: Dictionary) -> bool:
	if session.get("league") not in BASE_LEAGUES or not Profile.whole(session.get("tier"), 0, 4):
		return false
	# Named complete contracts reuse the existing League composition.
	# Earned League/tier and paid authority are checked on every admission.
	if flat_shared_home(home) or separate_shared_home(home) or legacy_shared_home(home) \
		or legacy_night_shared_home(home):
		return int(session.tier) in MODERN_TIERS.get(session.league, [])
	return SeasonOwnership._whole(home.get("version"), 3, 3) \
		and home.get("layout") is Dictionary and home.layout.get("version") == 1 \
		and StadiumLayoutSnapshot.valid(home)


static func flat_shared_home(home: Dictionary) -> bool:
	if not SeasonOwnership._whole(home.get("version"), 8, 8) \
		or not home.get("layout") is Dictionary:
		return false
	var layout: Dictionary = home.layout
	if not SeasonOwnership._whole(layout.get("version"), 1, 2147483647):
		return false
	var version: int = int(layout.version)
	if not FLAT_FAMILIES.has(version) \
		or layout.get("family") != FLAT_FAMILIES[version] \
		or not Assets.layout_adapted(layout):
		return false
	if layout.version != StadiumSurfaceLayout.VERSION \
		and not SeasonOwnership._whole(layout.get("base_version"), StadiumSurfaceLayout.VERSION, StadiumSurfaceLayout.VERSION):
		return false
	# Includes exact land geometry, complete boundary, original owned-stock and
	# host/earned-copy validators and surface access. Shape is never payment proof;
	# install_replay matches the entire home to the frozen paid journal capture.
	return StadiumLayoutSnapshot.valid(home)


static func separate_shared_home(home: Dictionary) -> bool:
	# Entry and layout discriminators are paired explicitly. None of these
	# complete contracts is snapshot8, and no fixture may masquerade as an entry.
	if not home.get("layout") is Dictionary \
		or not (Assets.layout_adapted(home.layout) or Assets.Pool.supported(home.layout)):
		return false
	var layout: Dictionary = home.layout
	if not SeasonOwnership._whole(layout.get("version"), 1, 2147483647):
		return false
	match int(layout.version):
		StadiumScoreboardLayout.VERSION:
			if home.get("version") != StadiumScoreboardSnapshot.VERSION \
				or layout.get("family") != StadiumScoreboardLayout.FAMILY:
				return false
		StadiumMountedScoreboardLayout.VERSION:
			if home.get("version") != StadiumMountedScoreboardSnapshot.VERSION \
				or layout.get("family") != StadiumMountedScoreboardLayout.FAMILY:
				return false
		StadiumPoolOwnedLayout.VERSION:
			if home.get("version") != StadiumPoolOwnedSnapshot.VERSION \
				or layout.get("family") != StadiumPoolOwnedLayout.FAMILY:
				return false
		StadiumSurfaceLayout.TERRAIN_VERSION:
			if home.get("version") != StadiumLayoutSnapshot.TERRAIN_VERSION \
				or layout.get("family") != StadiumSurfaceLayout.TERRAIN_FAMILY:
				return false
		StadiumWaterfallAnimationLayout.VERSION:
			if home.get("version") != StadiumWaterfallAnimationSnapshot.VERSION \
				or layout.get("family") != StadiumWaterfallAnimationLayout.FAMILY \
				or not SeasonOwnership._whole(layout.get("animation_base"), 45, 45):
				return false
		_:
			# Closed13/46, wrapped terrain and every Night contract stay outside.
			return false
	# Original full-stock, land, host/access, terrain and motion validators run
	# unchanged. install_replay additionally requires the entire paid grant capture.
	return StadiumLayoutSnapshot.valid(home)


static func legacy_shared_home(home: Dictionary) -> bool:
	var checked: Dictionary = _legacy_home_validation(home)
	# Daytime remains a distinct contract. A complete qualified legacy light
	# recipe is admitted only by legacy_night_shared_home, including its Day seeds.
	return checked.get("ok", false) and not checked.get("night_qualified", false)


static func legacy_night_shared_home(home: Dictionary) -> bool:
	# This is the original four-pole Yard environment, never SurfaceNight or a
	# kit/time wrapper. Its public validator checks exact owned light identities,
	# supported land, installed contents and (for Wall11) template-only walls.
	if not home.get("layout") is Dictionary \
		or not SeasonOwnership._whole(home.layout.get("version"), 1, 2147483647):
		return false
	match int(home.layout.version):
		StadiumLightItems.LAYOUT_VERSION, StadiumInfieldStyles.LAYOUT_VERSION, StadiumWallItems.LAYOUT_VERSION:
			var checked: Dictionary = _legacy_home_validation(home)
			return checked.get("ok", false) and checked.get("night_qualified", false)
	return false


static func _legacy_home_validation(home: Dictionary) -> Dictionary:
	# Exact complete historical entry3/4 or wall entry6, never a fixture or
	# an incomplete inventory-free snapshot. The public validator owns geometry,
	# stock, wall, land and family rules; frozen-grant equality owns payment.
	if not home.get("layout") is Dictionary or not Assets.layout_adapted(home.layout):
		return {}
	var layout: Dictionary = home.layout
	if not SeasonOwnership._whole(layout.get("version"), 1, 2147483647):
		return {}
	var version: int = int(layout.version)
	if not LEGACY_FAMILIES.has(version) or layout.get("family") != LEGACY_FAMILIES[version]:
		return {}
	var entry_version: int = 6 if version == StadiumWallItems.LAYOUT_VERSION else (
		3 if home.get("tier") == "backyard" else 4)
	if not SeasonOwnership._whole(home.get("version"), entry_version, entry_version) \
		or not StadiumLayoutSnapshot.valid(home):
		return {}
	# StadiumFixtureEnvironment.for_fixture retains the original fixture5/7
	# seed, profile and mode. Its complete key flows through LeagueHomeResult,
	# pending replay and owner continuation; no extra modern Night tail is used.
	return StadiumHomeLayout.validate(layout, StadiumLayoutSnapshot.ownership(home), home.tier)


static func modern_origin(home: Dictionary) -> bool:
	if not SeasonOwnership._whole(home.get("version"), 8, 8) or home.get("tier") != "backyard" \
		or not StadiumSalvageCarItems.is_family(home.get("layout")) \
		or not StadiumLayoutSnapshot.valid(home):
		return false
	# Keep the complete constructor layout, including the fixed owned salvage
	# copy and rough dirt. Stored purchases are retained by the frozen grant;
	# changed active layouts require their own explicit composition qualification.
	var origin: ClubAssetLedger = ClubAssetLedger.new_club()
	return ClubCareer.same(home.layout, origin.view().stadium_active)


static func modern_cleared(home: Dictionary) -> bool:
	# Structural scope only. Paid clearance is verified from the frozen journal
	# in install_replay; a valid empty placement alone never grants admission.
	if not SeasonOwnership._whole(home.get("version"), 8, 8) or home.get("tier") != "backyard" \
		or not StadiumSalvageCarItems.is_family(home.get("layout")) \
		or not StadiumLayoutSnapshot.valid(home):
		return false
	var origin: ClubAssetLedger = ClubAssetLedger.new_club()
	var cleared: Dictionary = origin.view().stadium_active.duplicate(true)
	cleared.salvage_cars = []
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(home)
	return ClubCareer.same(home.layout, cleared) and stock != null \
		and ClubCareer.same(stock.copies.get(StadiumStock.SALVAGE_COPY),
			origin.construction().copies[StadiumStock.SALVAGE_COPY])


static func paid_modern_clearance(paid: ClubAssetLedger) -> bool:
	if paid == null:
		return false
	var view: Dictionary = paid.view()
	return ClubAssetLedger.valid_salvage_origin(view.get("salvage_origin")) \
		and view.get("salvage_cleared") == true \
		and ClubCareer.same(paid.construction().copies.get(StadiumStock.SALVAGE_COPY),
			ClubAssetLedger.new_club().construction().copies[StadiumStock.SALVAGE_COPY])


static func prepare(authority: Dictionary, session: Dictionary) -> Dictionary:
	var staged: Dictionary = Home.prepare(authority, session)
	if staged.is_empty() or not supported(staged.home_property, staged.session):
		return {}
	var checked: Dictionary = Save.qualify(staged.checkpoint)
	if checked.is_empty():
		return {}
	var value: Dictionary = {"version": VERSION, "session": staged.session,
		"grant": staged.grant, "home_property": staged.home_property, "checkpoint": staged.checkpoint}
	return value if not qualify(value, authority).is_empty() else {}


static func qualify(value: Variant, authority: Dictionary) -> Dictionary:
	if not value is Dictionary or not value.get("home_property") is Dictionary:
		return {}
	var grant: Dictionary = Grant.qualify(value.get("grant"), authority)
	var session: Dictionary = Save.binding(value.get("session"))
	return {} if grant.is_empty() or session.is_empty() else qualify_bound(value, session, grant, value.home_property)


static func qualify_bound(value: Variant, session: Dictionary, grant: Dictionary, home: Dictionary) -> Dictionary:
	if not Profile.keys(value, ["version", "session", "grant", "home_property", "checkpoint"]) \
		or not Profile.whole(value.version, VERSION, VERSION) or not value.checkpoint is Dictionary \
		or not ClubCareer.same(value.session, session) or not ClubCareer.same(value.grant, grant) \
		or not ClubCareer.same(value.home_property, home) or not supported(home, session) \
		or Save.snapshot_reference(value).bytes > 8 * 1024 * 1024:
		return {}
	var inner: Dictionary = unbound(value.checkpoint, session)
	if inner.is_empty():
		return {}
	var season: SeasonState = decode_raw(inner, session, grant, home)
	if season == null:
		return {}
	season._dynasty_career_session = session.duplicate(true)
	return {"session": session, "home_grant": grant, "home_property": home,
		"season": season, "inner": inner,
		"reference": Save.snapshot_reference(value), "raw_reference": Save.snapshot_reference(inner)}


static func decode_raw(raw: Dictionary, session: Dictionary, grant: Dictionary, home: Dictionary) -> SeasonState:
	var owned: Dictionary = Save.Owned.unpack(raw)
	if owned.is_empty() or not ClubCareer.same(owned.players, grant.get("player_access")):
		return null
	var payload: Dictionary = owned.checkpoint
	var tiered: bool = int(session.tier) > 0
	var raw_version: int = Save.RAW_TIER_VERSION if tiered else 80
	var core: Dictionary = Save.core(raw)
	if not Profile.keys(payload, ["version", "access", "inventory_rules", "checkpoint"]) \
		or not Profile.whole(payload.version, raw_version, raw_version) or core.is_empty() \
		or not ClubCareer.same(payload.access, grant.get("access")) \
		or not payload.inventory_rules is Dictionary \
		or (not payload.inventory_rules.is_empty() and not SeasonInventoryRules.valid(payload.inventory_rules)):
		return null
	var rules: Dictionary = rules_for(session)
	var closed_version: int = Save.TIER_CHECKPOINT_VERSION if tiered else (77 if LeagueRules.doubleheader(rules) else 76)
	if not Profile.whole(payload.checkpoint.get("version"), closed_version, closed_version) \
		or not ClubCareer.same(payload.checkpoint.league_rules, rules):
		return null
	var context: Dictionary = {"format": VERSION, "session": session, "grant": grant, "home_property": home}
	return SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		core, {}, false, rules, true, payload.inventory_rules, null, payload.access, null, owned.players, {}, context)


static func install_replay(season: SeasonState, context: Dictionary) -> bool:
	if season == null or not Profile.keys(context, ["format", "session", "grant", "home_property"]) \
		or context.format != VERSION or not context.home_property is Dictionary:
		return false
	var grant: Dictionary = Grant._claim(context.grant)
	var session: Dictionary = Save.binding(context.session)
	if grant.is_empty() or session.is_empty() or not supported(context.home_property, session) \
		or session.owner_id != grant.owner_id or session.seed != season.season_seed \
		or session.access_sha256 != ClosedContentAccess.digest(grant.access) \
		or not ClubCareer.same(season._closed_access, grant.access):
		return false
	var paid: ClubAssetLedger = ClubPlayers.assets(preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history))
	if paid == null or not ClubCareer.same(context.home_property, StadiumLayoutSnapshot.capture(paid, true)) \
		or (modern_cleared(context.home_property) and not paid_modern_clearance(paid)):
		return false
	season.home_property = context.home_property.duplicate(true)
	season._league_home_context = context.duplicate(true)
	season._dynasty_career_session = session.duplicate(true)
	season._pool_replay_ledger = paid
	return true


static func matches(season: SeasonState) -> bool:
	if season != null and season._league_home_context.get("format") in [95, 96]:
		return load("res://src/gameplay/season/dynasty_shared_time.gd").matches(season)
	if season != null and season._league_home_context.get("format") == 94:
		return load("res://src/gameplay/season/normal_league_time_candidate.gd").matches(season)
	if season != null and season._league_home_context.get("format") == 93:
		return load("res://src/gameplay/season/normal_league_home.gd").matches(season)
	if season != null and season._league_home_context.get("format") == 92:
		return load("res://src/gameplay/season/dynasty_carried_home_live.gd").matches(season)
	if season == null or season._league_home_context.get("format") != VERSION \
		or season.career != null or not season.npc_venues.is_empty() \
		or not season.final_venue.is_empty() or not season.owned_surface_night.is_empty():
		return false
	var context: Dictionary = season._league_home_context
	if not Profile.keys(context, ["format", "session", "grant", "home_property"]) \
		or not context.session is Dictionary or not context.grant is Dictionary \
		or not context.home_property is Dictionary \
		or not ClubCareer.same(season._dynasty_career_session, context.session) \
		or not ClubCareer.same(season.league_rules, rules_for(context.session)) \
		or not ClubCareer.same(season.home_property, context.home_property) \
		or not supported(season.home_property, context.session) \
		or season.season_seed != context.session.seed \
		or not ClubCareer.same(season.player_access, context.grant.player_access) \
		or not ClubCareer.same(season._closed_access, context.grant.access):
		return false
	var detached: SeasonState = detached_state(season)
	return detached.league_context_consistent()


static func detached_state(season: SeasonState) -> SeasonState:
	var detached: SeasonState = SeasonState.new()
	for property: Dictionary in season.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			detached.set(property.name, season.get(property.name))
	detached.home_property = {}
	detached._league_home_context = {}
	detached._dynasty_career_session = {}
	detached._dynasty_owner_binding = {}
	detached._pool_replay_ledger = null
	return detached


static func capture(season: SeasonState) -> Dictionary:
	if not matches(season):
		return {}
	var context: Dictionary = season._league_home_context
	var raw: Dictionary = SeasonSave.snapshot(detached_state(season))
	var value: Dictionary = {"version": VERSION, "session": context.session.duplicate(true),
		"grant": context.grant.duplicate(true), "home_property": context.home_property.duplicate(true),
		"checkpoint": bind_raw(raw, context.session)}
	return value if not qualify_bound(value, context.session, context.grant, context.home_property).is_empty() else {}


static func bind_raw(raw: Dictionary, session: Dictionary) -> Dictionary:
	var owned: Dictionary = Save.Owned.unpack(raw)
	if owned.is_empty():
		return {}
	return Save.Owned.envelope({"version": Save.TIER_VERSION if int(session.tier) > 0 else Save.VERSION, "session": session.duplicate(true),
		"checkpoint": owned.checkpoint}, owned.players)


static func unbound(bound: Dictionary, session: Dictionary) -> Dictionary:
	var owned: Dictionary = Save.Owned.unpack(bound)
	var expected: int = Save.TIER_VERSION if int(session.tier) > 0 else Save.VERSION
	if owned.is_empty() or not Profile.keys(owned.checkpoint, ["version", "session", "checkpoint"]) \
		or not Profile.whole(owned.checkpoint.version, expected, expected) \
		or not ClubCareer.same(owned.checkpoint.session, session) \
		or not owned.checkpoint.checkpoint is Dictionary:
		return {}
	return Save.Owned.envelope(owned.checkpoint.checkpoint, owned.players)


static func rules_for(session: Dictionary) -> Dictionary:
	if session.get("league") not in BASE_LEAGUES or not Profile.whole(session.get("tier"), 0, 4):
		return {}
	return LeagueRules.capture_tier(session.league, int(session.tier),
		session.seed if session.league == "scramble" else null)

static func extends_checkpoint(before: Dictionary, after: Dictionary, frontier: Dictionary) -> bool:
	var replay = load("res://src/gameplay/season/dynasty_career_owner_replay.gd")
	return replay.Ops._extends(Save.core, replay.Legacy._prefix, replay.Lineage,
		_pending_extends, before, after, frontier)


static func _pending_extends(before: Dictionary, after: Dictionary) -> bool:
	var replay = load("res://src/gameplay/season/dynasty_career_owner_replay.gd")
	return replay.Ops._pending_extends(replay.Legacy.Profile, replay.Legacy._prefix,
		_human_matches, before, after)


static func _human_matches(human: Array, result: Dictionary) -> bool:
	# Both full snapshots are already qualified. Preserve exact pending identity
	# while keeping the new reserved venue tail out of the old league grammar.
	var doubleheader: bool = result.has("doubleheader_evidence")
	var owned_pool: bool = result.has("pool_evidence")
	var tail_size: int = 3 if owned_pool else 2
	if not LeagueHomeResult.shape(human, [], doubleheader, owned_pool) \
		or result.get("id") != human[0] or result.get("property") != human[-2 if owned_pool else -1] \
		or (owned_pool and not ClubCareer.same(result.pool_evidence, human[-1])):
		return false
	var base_size: int = 14 if doubleheader else 13
	var inventory: bool = human.size() == base_size + tail_size + 1
	if result.has("inventory_final") != inventory:
		return false
	for key: String in ["yard_evidence", "night_evidence"]:
		if result.has(key):
			return false
	return load("res://src/gameplay/season/dynasty_owner.gd")._human_matches(
		human.slice(0, human.size() - tail_size), result)

