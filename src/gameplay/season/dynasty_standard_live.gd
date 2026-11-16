extends RefCounted
## Grant-aware Standard replay context. No fake career rows or second wallet.
## The sequential projection validates venues/tiers only; live grants are separate.
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")


static func prepare(expected_grant: Dictionary, session: Dictionary) -> Dictionary:
	var grant: Dictionary = Grant._claim(expected_grant)
	var binding: Dictionary = Bound.binding(session)
	if grant.is_empty() or binding.is_empty() or binding.owner_id != grant.owner_id \
		or binding.grant_sha256 != Save.snapshot_reference(grant).sha256:
		return {}
	var club: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history)
	if binding.tier not in club.available_tiers():
		return {}
	var season: SeasonState = SeasonState.create(binding.seed, false, true, true)
	season.difficulty = 1
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)):
		return {}
	var started: bool = club.start_owner_projection(season, binding.tier) \
		if grant.version == Grant.OWNER_HISTORY_VERSION else club.start(season, binding.tier)
	if not started:
		return {}
	season.career = club
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	if season.home_property.is_empty() or not SeasonVenues.readiness(binding.tier).get("ok", false):
		return {}
	season.npc_venues = SeasonVenues.capture_five(binding.seed, club.current, binding.tier)
	match int(binding.tier):
		0: season.final_venue = SeasonFinalVenue.capture_standard_base(season)
		1: season.final_venue = SeasonFinalVenue.capture_standard_d1(season)
		2: season.final_venue = SeasonFinalVenue.capture_standard_d2(season)
		3: season.final_venue = SeasonFinalVenue.capture_standard_d3(season)
		4: season.final_venue = SeasonFinalVenue.capture_standard_d4(season)
	if season.npc_venues.is_empty() or season.final_venue.is_empty():
		return {}
	var starting: String = binding.get("starting_profile", "")
	if not starting.is_empty():
		var paid: ClubAssetLedger = ClubPlayers.assets(club)
		var kit: bool = StadiumLightingKitNightCandidate.is_candidate_layout(season.home_property.get("layout"))
		season.owned_surface_night = StadiumSurfaceNightSnapshot.capture_policy(season, paid) \
			if starting == "night" and kit else StadiumSurfaceNightSnapshot.capture_time_policy(season, paid, starting)
		if season.owned_surface_night.is_empty() and starting != "day":
			return {}
		if not season.owned_surface_night.is_empty() and kit \
			and not StadiumLightingKitNightCandidate.renderer_supported(season.home_property):
			return {}
	var template: Dictionary = SeasonSave.snapshot(season)
	if template.is_empty():
		return {}
	# Mixed-history envelope is unpacked only here into the explicit validation
	# projection; public Save81 and all old snapshots remain unchanged.
	if template.get("version") == 81:
		var history: Dictionary = template.career
		template = template.checkpoint.duplicate(true)
		template["career"] = history
	if grant.version == Grant.OWNER_HISTORY_VERSION:
		# Explicit transient Standard projection. Never label owner rows Career27.
		template.career.version = 29
		if not club.sync(season):
			return {}
	return {"grant": grant, "session": binding, "career": club,
		"template": template, "season": season}


static func install(build: SeasonBuild, grant: Dictionary) -> bool:
	if build == null or not build._league_rules.is_empty() or build._market != 0 \
		or build.revision() != 0 or build._bank.revision() != 0 \
		or not build._requests.is_empty() or int(build._visit.number) != 0:
		return false
	var access: Dictionary = ClosedContentAccess.normalize(grant.get("access"))
	if access.is_empty():
		return false
	build._gear_progress.enabled = true
	build._gear_progress.start = access.progress.gear_start.duplicate(true)
	build._sponsor_progress.enabled = true
	build._sponsor_progress.start = access.progress.sponsor_start.duplicate(true)
	for field: String in ClosedContentAccess.FIELDS:
		if field in ["gear_start", "sponsor_start"]:
			continue
		var value: Variant = access.progress[field]
		if field == "major_start":
			build._major.start = value
		elif field == "ability_start":
			build._abilities.start = value
		elif field == "copy_start":
			build._copy.start = value
		else:
			build.set("_" + field, value.duplicate(true) if value is Array or value is Dictionary else value)
	return ClosedContentAccess.matches(build, access)


static func create(expected_grant: Dictionary, session: Dictionary) -> SeasonState:
	var prepared: Dictionary = prepare(expected_grant, session)
	if prepared.is_empty():
		return null
	var season: SeasonState = prepared.season
	season.career = null
	season._npc_replay_run = prepared.career.current
	season._pool_replay_ledger = ClubPlayers.assets(prepared.career)
	if not ClubPlayerDraft.apply(season, prepared.grant.player_access) \
		or not install(season.build, prepared.grant):
		return null
	season._standard_live_context = {"grant": prepared.grant, "session": prepared.session,
		"template": prepared.template}
	return season if matches(season) else null


static func matches(season: SeasonState) -> bool:
	if season == null or season.career != null or season.league_career \
		or not season.league_rules.is_empty() or not season._closed_access.is_empty():
		return false
	var context: Dictionary = season._standard_live_context
	if not context.get("template") is Dictionary or not context.get("grant") is Dictionary:
		return false
	var binding: Dictionary = Bound.binding(context.get("session"))
	var grant: Dictionary = Grant._claim(context.grant)
	if binding.is_empty() or grant.is_empty() or binding.owner_id != grant.owner_id \
		or binding.seed != season.season_seed \
		or binding.grant_sha256 != Save.snapshot_reference(grant).sha256 \
		or not ClosedContentAccess.matches(season.build, grant.access) \
		or not ClubCareer.same(season.player_access, grant.player_access) \
		or not ClubPlayerDraft.frozen_matches(season):
		return false
	var template: Dictionary = context.template
	if not template.get("career") is Dictionary or season._npc_replay_run != template.career.current:
		return false
	for field: String in ["home_property", "npc_venues", "final_venue"]:
		if not ClubCareer.same(season.get(field), template.get(field)):
			return false
	if not ClubCareer.same(season.owned_surface_night, template.get("owned_surface_night", {})):
		return false
	return true


static func capture_raw(season: SeasonState) -> Dictionary:
	if not matches(season):
		return {}
	var raw: Dictionary = season._standard_live_context.template.duplicate(true)
	raw.picks = season.picks.duplicate()
	raw.results = season.player_results.duplicate(true)
	raw.lineup = season.teams[0].roster.duplicate()
	raw.starter = season.starter_index
	raw.fielder = season.fielder_index
	raw.pool = season.draft_pool.duplicate()
	raw.difficulty = season.difficulty
	raw.draws = season.teams.map(func(team: Dictionary) -> float: return team.draw)
	raw.strengths = season.teams.map(func(team: Dictionary) -> float: return team.get("strength", -1.0))
	raw.build = season.build.to_data()
	raw.opponents = season.opponents.to_data()
	raw.physical = season.physical.to_data()
	raw.player_access = season.player_access.duplicate()
	return raw


static func decode(raw: Dictionary, expected_grant: Dictionary, session: Dictionary) -> SeasonState:
	var prepared: Dictionary = prepare(expected_grant, session)
	if prepared.is_empty():
		return null
	var mutable: Array[String] = ["picks", "results", "lineup", "starter", "fielder", "pool",
		"difficulty", "draws", "strengths", "build", "opponents", "physical", "player_access"]
	if not SeasonOwnership._keys(raw, prepared.template.keys()):
		return null
	for field: String in prepared.template:
		if field not in mutable and not ClubCareer.same(raw[field], prepared.template[field]):
			return null
	if not ClubCareer.same(raw.player_access, prepared.grant.player_access) \
		or not raw.get("physical") is Dictionary or not raw.physical.get("pending") is Dictionary:
		return null
	var data: Dictionary = raw.duplicate(true)
	var terrain: bool = data.version == 74
	if terrain:
		if not SeasonOwnership._whole(data.get("terrain_save_version"), 59, 73):
			return null
		data.version = int(data.terrain_save_version)
		data.erase("terrain_save_version")
	var policy: Dictionary = {}
	if SeasonOwnership._whole(data.version, 72, 73):
		var policy_version: int = 1 if data.version == 72 else 2
		if not SeasonOwnership._whole(data.get("legacy_save_version"), 59, 71) \
			or not data.get("owned_surface_night") is Dictionary \
			or not SeasonOwnership._whole(data.owned_surface_night.get("version"), policy_version, policy_version) \
			or not StadiumSurfaceNightSnapshot.policy_shape(data.owned_surface_night) \
			or StadiumLayoutSnapshot.is_terrain(data.get("home_property")) or data.has("ownership"):
			return null
		policy = data.owned_surface_night.duplicate(true)
		data.version = int(data.legacy_save_version)
		data.erase("legacy_save_version")
		data.erase("owned_surface_night")
	var context: Dictionary = {"grant": prepared.grant, "session": prepared.session,
		"template": prepared.template}
	return SeasonSave.Operations1._ac02_passive_15_private_decode_payload_terrain(
		data, policy, terrain, {}, false, {}, null, {}, null, [], context, {},
		prepared.career if prepared.grant.version == Grant.OWNER_HISTORY_VERSION else null)


static func projection_matches(career: ClubCareer, context: Dictionary, data: Dictionary) -> bool:
	if career == null or not context.get("template") is Dictionary \
		or not context.get("grant") is Dictionary or context.grant.get("version") != Grant.OWNER_HISTORY_VERSION:
		return false
	var grant: Dictionary = Grant._claim(context.grant)
	var session: Dictionary = Bound.binding(context.get("session"))
	if grant.is_empty() or session.is_empty() or session.owner_id != grant.owner_id \
		or session.grant_sha256 != Save.snapshot_reference(grant).sha256:
		return false
	var prefix: ClubCareer = Grant.history_club(grant.history)
	if prefix == null or career.current != career.runs.size() or career.current != prefix.runs.size() + 1 \
		or not ClubCareer.same(career.runs.slice(0, -1), prefix.runs) \
		or career.runs[-1].league != "standard" or career.runs[-1].seed != session.seed \
		or career.runs[-1].tier != session.tier or career.runs[-1].status != "active":
		return false
	var projection: Dictionary = career.to_data()
	projection.version = 29
	return ClubCareer.same(projection, context.template.get("career")) \
		and ClubCareer.same(projection, data.get("career"))
