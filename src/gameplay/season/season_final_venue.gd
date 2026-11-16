class_name SeasonFinalVenue
extends RefCounted
## Frozen neutral final: Standard/Base new seasons and retained explicit qualification records.
## Saved before the draft; normal final entry additionally requires the settled real-history prefix.
# gdlint: disable=max-returns

const VERSION: int = 1
const LEAGUE: String = "doubleheader"
const SELECTION: String = "explicit-qualification"
const STANDARD_BASE_SELECTION: String = "standard-base-season"
const STANDARD_D1_SELECTION: String = "standard-d1-season"
const STANDARD_D2_SELECTION: String = "standard-d2-season"
const STANDARD_D3_SELECTION: String = "standard-d3-season"
const STANDARD_D4_SELECTION: String = "standard-d4-season"
const OWNER: String = "finals-venue:long-yard:v2"
const AUTHORITY: String = "neutral-final-v1"
const HILLSIDE_VERSION: int = 6
const HILLSIDE_OWNER: String = "finals-venue:hillside:v1"
const HILLSIDE_AUTHORITY: String = "neutral-final-hillside-v1"
const POOL_PARTY_VERSION: int = 5
const POOL_PARTY_OWNER: String = "finals-venue:pool-party:v1"
const POOL_PARTY_AUTHORITY: String = "neutral-final-pool-party-v1"
const GRAND_III_VERSION: int = 4
const GRAND_III_OWNER: String = "finals-venue:grand-iii:v1"
const GRAND_III_AUTHORITY: String = "neutral-final-grand-iii-v1"
const GRAND_II_VERSION: int = 3
const GRAND_II_OWNER: String = "finals-venue:grand-ii:v1"
const GRAND_II_AUTHORITY: String = "neutral-final-grand-ii-v1"
const GRAND_VERSION: int = 2
const GRAND_LEAGUE: String = "standard"
const GRAND_OWNER: String = "finals-venue:grand-i:v1"
const GRAND_AUTHORITY: String = "neutral-final-grand-i-v1"


static func capture(seed: int, career_run: int, league: String) -> Dictionary:
	# A caller must explicitly name the planned pairing. Never infer it from Standard or AI level.
	if (
		league != LEAGUE
		or seed < 0
		or seed > 2147483647
		or career_run < 1
		or career_run > ClubCareer.MAX_RUNS
	):
		return {}
	var manifest: Dictionary = StadiumLongYardDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": league,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumLongYardEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


static func normalized(value: Variant, seed: int = -1, career_run: int = -1) -> Dictionary:
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), HILLSIDE_VERSION, HILLSIDE_VERSION)
	):
		return _normalized_hillside(value, seed, career_run)
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), POOL_PARTY_VERSION, POOL_PARTY_VERSION)
	):
		return _normalized_pool_party(value, seed, career_run)
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), GRAND_III_VERSION, GRAND_III_VERSION)
	):
		return _normalized_grand_iii(value, seed, career_run)
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), GRAND_II_VERSION, GRAND_II_VERSION)
	):
		return _normalized_grand_ii(value, seed, career_run)
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), GRAND_VERSION, GRAND_VERSION)
	):
		return _normalized_grand(value, seed, career_run)
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != LEAGUE
		or value.selection != SELECTION
		or value.venue_owner != OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumLongYardEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumLongYardDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	return {
		"version": VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": LEAGUE,
		"selection": SELECTION,
		"fixture": 32,
		"venue_owner": OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumLongYardEnvironmentV1.capture(_seed(int(value.seed)))
	}


static func key(value: Variant) -> String:
	var data: Dictionary = normalized(value)
	return "" if data.is_empty() else JSON.stringify(data, "", true, true).sha256_text()


static func matches_season(season: SeasonState) -> bool:
	if season == null or SeasonVenues.run_for(season) <= 0:
		return false
	var record: Dictionary = normalized(
		season.final_venue, season.season_seed, SeasonVenues.run_for(season)
	)
	if record.is_empty():
		return false
	if record.selection == STANDARD_BASE_SELECTION:
		return standard_base_context(season)
	if record.selection == STANDARD_D1_SELECTION:
		return standard_d1_context(season)
	if record.selection == STANDARD_D2_SELECTION:
		return standard_d2_context(season)
	if record.selection == STANDARD_D3_SELECTION:
		return standard_d3_context(season)
	if record.selection == STANDARD_D4_SELECTION:
		return standard_d4_context(season)
	return true


static func for_fixture(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if (
		not matches_season(season)
		or not StadiumNpcSnapshot._keys(fixture, ["id", "round", "home", "away", "neutral"])
		or not SeasonOwnership._whole(fixture.id, 32, 32)
		or not SeasonOwnership._whole(fixture.round, 11, 11)
		or not SeasonOwnership._whole(fixture.home, 0, 5)
		or not SeasonOwnership._whole(fixture.away, 0, 5)
		or fixture.away == fixture.home
		or not fixture.neutral is bool
		or not fixture.neutral
		or not ClubCareer.same(fixture, SeasonVenues.fixture_for_id(season, 32))
	):
		return {}
	var data: Dictionary = normalized(
		season.final_venue, season.season_seed, SeasonVenues.run_for(season)
	)
	if (
		(
			data.selection
			in [
				STANDARD_BASE_SELECTION,
				STANDARD_D1_SELECTION,
				STANDARD_D2_SELECTION,
				STANDARD_D3_SELECTION,
				STANDARD_D4_SELECTION
			]
		)
		and not standard_base_final_ready(season, fixture)
	):
		return {}
	var grand: bool = data.version == GRAND_VERSION
	var hillside: bool = data.version == HILLSIDE_VERSION
	var pool_party: bool = data.version == POOL_PARTY_VERSION
	var grand_iii: bool = data.version == GRAND_III_VERSION
	var grand_ii: bool = data.version == GRAND_II_VERSION
	return StadiumNpcSnapshot.normalized(
		{
			"version":
			(
				StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
				if hillside
				else (
					StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
					if pool_party
					else (
						StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
						if grand_iii
						else (
							StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
							if grand_ii
							else (
								StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
								if grand
								else StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
							)
						)
					)
				)
			),
			"authority":
			(
				HILLSIDE_AUTHORITY
				if hillside
				else (
					POOL_PARTY_AUTHORITY
					if pool_party
					else (
						GRAND_III_AUTHORITY
						if grand_iii
						else (
							GRAND_II_AUTHORITY
							if grand_ii
							else (GRAND_AUTHORITY if grand else AUTHORITY)
						)
					)
				)
			),
			"manifest": data.manifest,
			"manifest_key": data.manifest_key,
			"binding":
			{
				"season_seed": season.season_seed,
				"career_run": SeasonVenues.run_for(season),
				"assignment_key": key(data),
				"league": data.league,
				"selection": data.selection,
				"venue_owner": data.venue_owner,
				"venue_id": data.manifest.id,
				"venue_revision": 1,
				"fixture": 32,
				"away": int(fixture.away),
				"batting_home": int(fixture.home),
				"neutral": true,
				"match_seed": SeasonPhysicalFixtures.seed_for(season, fixture),
				"field": StadiumNpcSnapshot.FIELD
			},
			"environment": data.environment
		}
	)


# The ordinary final is earned from the settled prefinal prefix, never from the
# qualification helper's in-memory final_fixture alone. Existing replay has already
# validated each consumed report; do not recursively decode saves or demand a final report.
static func standard_base_final_ready(season: SeasonState, fixture: Dictionary) -> bool:
	if (
		season == null
		or season.physical == null
		or season.round_index != 10
		or season.phase not in [SeasonState.Phase.FINAL, SeasonState.Phase.COMPLETE]
		or season.results.size() not in [32, 33]
		or season.physical.cursor < 21
		or season.physical.cursor > season.physical.reports.size()
	):
		return false
	var proof: Dictionary = ClubSeasonRecord.capture(season)
	if proof.scores.size() == 33:
		proof.scores.pop_back()
	if ClubSeasonRecord.analyze(proof).is_empty():
		return false
	var seeds: Array = season.standings().slice(0, 4).map(
		func(row: Dictionary) -> int: return row.team
	)
	if not ClubCareer.same(seeds, season.playoff_seeds):
		return false
	var human: Dictionary = {}
	for row: Dictionary in season.player_results:
		if row.id < 32:
			if human.has(int(row.id)):
				return false
			human[int(row.id)] = row
	var consumed: Dictionary = {}
	for index: int in range(season.physical.cursor):
		var row: Dictionary = season.physical.reports[index]
		if row.fixture < 32:
			if consumed.has(int(row.fixture)):
				return false
			consumed[int(row.fixture)] = row.report
	var winners: Array[int] = []
	var human_regular: int = 0
	for row: Dictionary in season.results:
		if row.id >= 32:
			continue
		if row.home == 0 or row.away == 0:
			if not human.has(int(row.id)):
				return false
			var played: Dictionary = human[int(row.id)]
			if not ClubCareer.same(
				[row.id, row.away, row.home, row.away_runs, row.home_runs],
				[played.id, played.away, played.home, played.away_runs, played.home_runs]
			):
				return false
			human_regular += 1 if row.id < 30 else 0
		elif (
			not consumed.has(int(row.id))
			or consumed[int(row.id)].away_runs != row.away_runs
			or consumed[int(row.id)].home_runs != row.home_runs
		):
			return false
		if row.id in [30, 31]:
			winners.append(SeasonState._winner(row))
	winners.sort_custom(func(a: int, b: int) -> bool: return seeds.find(a) < seeds.find(b))
	return (
		human_regular == 10
		and human.size() + consumed.size() == 32
		and winners.size() == 2
		and ClubCareer.same(
			fixture,
			{"id": 32, "round": 11, "home": winners[0], "away": winners[1], "neutral": true}
		)
	)


static func _seed(seed: int) -> int:
	return (seed + 32 * 104729) & 0x7fffffff


# Retained explicit qualification API; normal Standard/Base entry uses capture_standard_base.
# The legacy three-argument capture keeps refusing Standard; no inference or migration.
static func capture_explicit(
	seed: int, career_run: int, league: String, venue_id: String
) -> Dictionary:
	if venue_id == "LONG-YARD":
		return capture(seed, career_run, league)
	if venue_id == "HILLSIDE" and league == GRAND_LEAGUE:
		return capture_hillside(seed, career_run)
	if venue_id == "POOL-PARTY" and league == GRAND_LEAGUE:
		return capture_pool_party(seed, career_run)
	if venue_id == "GRAND-III" and league == GRAND_LEAGUE:
		return capture_grand_iii(seed, career_run)
	if venue_id == "GRAND-II" and league == GRAND_LEAGUE:
		return capture_grand_ii(seed, career_run)
	if venue_id != "GRAND-I" or league != GRAND_LEAGUE:
		return {}
	return capture_grand_i(seed, career_run)


# New selection is made only before the first draft choice. This is a venue assignment,
# never proof of reaching the final; SeasonState derives participants from real results.
static func capture_standard_base(season: SeasonState) -> Dictionary:
	return _capture_standard(season, 0)


static func capture_standard_d1(season: SeasonState) -> Dictionary:
	return _capture_standard(season, 1)


static func capture_standard_d2(season: SeasonState) -> Dictionary:
	return _capture_standard(season, 2)


static func capture_standard_d3(season: SeasonState) -> Dictionary:
	return _capture_standard(season, 3)


static func capture_standard_d4(season: SeasonState) -> Dictionary:
	return _capture_standard(season, 4)


# New profile selection retains all ordinary D4 pre-draft gates and final eligibility.
static func capture_standard_d4_time(season: SeasonState, mode: String = "day") -> Dictionary:
	var record: Dictionary = capture_standard_d4(season)
	if record.is_empty():
		return {}
	var environment: Dictionary = StadiumGrandIIIEnvironmentV1.capture_time(
		_seed(season.season_seed), mode
	)
	if environment.is_empty():
		return {}
	record.environment = environment
	return normalized(record, season.season_seed, season.career.current)


static func _capture_standard(season: SeasonState, tier: int) -> Dictionary:
	if tier not in [0, 1, 2, 3, 4]:
		return {}
	var context: bool = (
		standard_d4_context(season)
		if tier == 4
		else (
			standard_d3_context(season)
			if tier == 3
			else (
				standard_d2_context(season)
				if tier == 2
				else (standard_d1_context(season) if tier == 1 else standard_base_context(season))
			)
		)
	)
	if (
		not context
		or season.career == null
		or season.career.runs[-1].status != "active"
		or season.phase != SeasonState.Phase.DRAFT
		or not season.picks.is_empty()
		or not season.results.is_empty()
		or not season.player_results.is_empty()
		or not season.playoff_seeds.is_empty()
		or not season.semifinals.is_empty()
		or not season.final_fixture.is_empty()
		or not season.final_venue.is_empty()
		or season.physical == null
		or not season.physical.reports.is_empty()
		or not season.physical.pending.is_empty()
		or season.build == null
		or season.opponents == null
		or season.opponents._format != 13
		or season.player_access.is_empty()
		or season.home_property.is_empty()
	):
		return {}
	var record: Dictionary = (
		capture_grand_iii(season.season_seed, season.career.current)
		if tier == 4
		else (
			capture_grand_ii(season.season_seed, season.career.current)
			if tier >= 2
			else capture_grand_i(season.season_seed, season.career.current)
		)
	)
	if record.is_empty():
		return {}
	record.selection = (
		STANDARD_D4_SELECTION
		if tier == 4
		else (
			STANDARD_D3_SELECTION
			if tier == 3
			else (
				STANDARD_D2_SELECTION
				if tier == 2
				else (STANDARD_D1_SELECTION if tier == 1 else STANDARD_BASE_SELECTION)
			)
		)
	)
	return normalized(record, season.season_seed, season.career.current)


static func standard_base_context(season: SeasonState, saved_career: ClubCareer = null) -> bool:
	if (
		season == null
		or not SeasonVenues.matches_season(season)
		or season.npc_venues.get("version") != SeasonVenues.FIVE_VERSION
		or season.npc_venues.get("venue_ordinal") != 0
		or (season.opponents != null and not season.opponents.draft_rule.is_empty())
	):
		return false
	var club: ClubCareer = saved_career if saved_career != null else season.career
	# During replay the saved career is validated before the first result, then attached later.
	if club == null:
		return season._npc_replay_run > 0
	return (
		club.current > 0
		and club.current == club.runs.size()
		and club.runs[-1].id == club.current
		and club.runs[-1].seed == season.season_seed
		and club.runs[-1].league == GRAND_LEAGUE
		and club.runs[-1].tier == 0
	)


static func standard_d1_context(season: SeasonState, saved_career: ClubCareer = null) -> bool:
	return _standard_paid_context(season, saved_career, 1)


static func standard_d2_context(season: SeasonState, saved_career: ClubCareer = null) -> bool:
	return _standard_paid_context(season, saved_career, 2)


static func standard_d3_context(season: SeasonState, saved_career: ClubCareer = null) -> bool:
	return _standard_paid_context(season, saved_career, 3)


static func standard_d4_context(season: SeasonState, saved_career: ClubCareer = null) -> bool:
	return _standard_paid_context(season, saved_career, 4)


static func _standard_paid_context(
	season: SeasonState, saved_career: ClubCareer, tier: int
) -> bool:
	if (
		season == null
		or not SeasonVenues.matches_season(season)
		or season.npc_venues.get("version") != SeasonVenues.FIVE_VERSION
		or season.npc_venues.get("venue_ordinal") != tier
		or season.build == null
		or season.build._market != 0
		or not season.build.d1_pricing_valid()
		or (tier == 3) != season.build.d3_sponsors_valid()
		or (tier == 4) != season.build.d4_sponsors_valid()
		or season.opponents == null
		or season.opponents._format != 13
		or season.opponents.draft_rule != (SeasonOpponentDraft.D2_RULE if tier >= 2 else "")
	):
		return false
	if season.picks.size() < 4:
		if not season.opponents.clubs.is_empty():
			return false
	else:
		if not SeasonOwnership._keys(season.opponents.clubs, ["1", "2", "3", "4", "5"]):
			return false
		for opponent: Variant in season.opponents.clubs.values():
			if (
				not opponent is Dictionary
				or not opponent.get("build") is SeasonBuild
				or opponent.build._market != 12
				or not opponent.build.d1_pricing_valid()
				or (tier == 3) != opponent.build.d3_sponsors_valid()
				or (tier == 4) != opponent.build.d4_sponsors_valid()
			):
				return false
	var club: ClubCareer = saved_career if saved_career != null else season.career
	# The explicit save envelope validates career, price and draft headers before replay.
	if club == null:
		return season._npc_replay_run > 0
	return (
		club.current > 0
		and club.current == club.runs.size()
		and club.runs[-1].id == club.current
		and club.runs[-1].seed == season.season_seed
		and club.runs[-1].league == GRAND_LEAGUE
		and club.runs[-1].tier == tier
	)


static func capture_grand_i(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var manifest: Dictionary = StadiumGrandIDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": GRAND_VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": GRAND_LEAGUE,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": GRAND_OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumGrandIEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


static func _normalized_grand(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, GRAND_VERSION, GRAND_VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != GRAND_LEAGUE
		or value.selection not in [SELECTION, STANDARD_BASE_SELECTION, STANDARD_D1_SELECTION]
		or value.venue_owner != GRAND_OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumGrandIEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumGrandIDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	return {
		"version": GRAND_VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": GRAND_LEAGUE,
		"selection": value.selection,
		"fixture": 32,
		"venue_owner": GRAND_OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumGrandIEnvironmentV1.capture(_seed(int(value.seed)))
	}


static func capture_grand_ii(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var manifest: Dictionary = StadiumGrandIIDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": GRAND_II_VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": GRAND_LEAGUE,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": GRAND_II_OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumGrandIIEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


static func _normalized_grand_ii(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, GRAND_II_VERSION, GRAND_II_VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != GRAND_LEAGUE
		or value.selection not in [SELECTION, STANDARD_D2_SELECTION, STANDARD_D3_SELECTION]
		or value.venue_owner != GRAND_II_OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumGrandIIEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumGrandIIDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	return {
		"version": GRAND_II_VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": GRAND_LEAGUE,
		"selection": value.selection,
		"fixture": 32,
		"venue_owner": GRAND_II_OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumGrandIIEnvironmentV1.capture(_seed(int(value.seed)))
	}


static func capture_grand_iii(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var manifest: Dictionary = StadiumGrandIIIDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": GRAND_III_VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": GRAND_LEAGUE,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": GRAND_III_OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumGrandIIIEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


# Explicit construction remains qualification-only; it never grants earned final access.
static func capture_grand_iii_time(seed: int, career_run: int, mode: String = "day") -> Dictionary:
	var record: Dictionary = capture_grand_iii(seed, career_run)
	if record.is_empty():
		return {}
	var environment: Dictionary = StadiumGrandIIIEnvironmentV1.capture_time(_seed(seed), mode)
	if environment.is_empty():
		return {}
	record.environment = environment
	return normalized(record, seed, career_run)


static func _normalized_grand_iii(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, GRAND_III_VERSION, GRAND_III_VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != GRAND_LEAGUE
		or value.selection not in [SELECTION, STANDARD_D4_SELECTION]
		or value.venue_owner != GRAND_III_OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumGrandIIIEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumGrandIIIDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	if value.environment.version == StadiumGrandIIIEnvironmentV1.TIME_ENVIRONMENT_VERSION:
		return {
			"version": GRAND_III_VERSION,
			"seed": int(value.seed),
			"career_run": int(value.career_run),
			"league": GRAND_LEAGUE,
			"selection": value.selection,
			"fixture": 32,
			"venue_owner": GRAND_III_OWNER,
			"manifest": manifest,
			"manifest_key": value.manifest_key,
			"environment":
			StadiumGrandIIIEnvironmentV1.capture_time(
				_seed(int(value.seed)), value.environment.mode
			)
		}
	return {
		"version": GRAND_III_VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": GRAND_LEAGUE,
		"selection": value.selection,
		"fixture": 32,
		"venue_owner": GRAND_III_OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumGrandIIIEnvironmentV1.capture(_seed(int(value.seed)))
	}


static func capture_pool_party(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var manifest: Dictionary = StadiumPoolPartyDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": POOL_PARTY_VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": GRAND_LEAGUE,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": POOL_PARTY_OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumPoolPartyEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


static func _normalized_pool_party(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, POOL_PARTY_VERSION, POOL_PARTY_VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != GRAND_LEAGUE
		or value.selection != SELECTION
		or value.venue_owner != POOL_PARTY_OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumPoolPartyEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumPoolPartyDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	return {
		"version": POOL_PARTY_VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": GRAND_LEAGUE,
		"selection": SELECTION,
		"fixture": 32,
		"venue_owner": POOL_PARTY_OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumPoolPartyEnvironmentV1.capture(_seed(int(value.seed)))
	}


static func capture_hillside(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var manifest: Dictionary = StadiumHillsideDefinitionV1.canonical()
	if manifest.is_empty():
		return {}
	return normalized(
		{
			"version": HILLSIDE_VERSION,
			"seed": seed,
			"career_run": career_run,
			"league": GRAND_LEAGUE,
			"selection": SELECTION,
			"fixture": 32,
			"venue_owner": HILLSIDE_OWNER,
			"manifest": manifest,
			"manifest_key": JSON.stringify(manifest, "", true, true).sha256_text(),
			"environment": StadiumHillsideEnvironmentV1.capture(_seed(seed))
		},
		seed,
		career_run
	)


static func _normalized_hillside(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if (
		not StadiumNpcSnapshot._keys(
			value,
			[
				"version",
				"seed",
				"career_run",
				"league",
				"selection",
				"fixture",
				"venue_owner",
				"manifest",
				"manifest_key",
				"environment"
			]
		)
		or not SeasonOwnership._whole(value.version, HILLSIDE_VERSION, HILLSIDE_VERSION)
		or not SeasonOwnership._whole(value.seed, 0, 2147483647)
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS)
		or (seed >= 0 and value.seed != seed)
		or (career_run >= 0 and value.career_run != career_run)
		or not value.league is String
		or not value.selection is String
		or not value.venue_owner is String
		or value.league != GRAND_LEAGUE
		or value.selection != SELECTION
		or value.venue_owner != HILLSIDE_OWNER
		or not SeasonOwnership._whole(value.fixture, 32, 32)
		or not StadiumNpcManifest._hash(value.manifest_key)
		or not StadiumHillsideEnvironmentV1.valid(value.environment)
		or value.environment.seed != _seed(int(value.seed))
		or not StadiumNpcSnapshot._json_types(value)
	):
		return {}
	var manifest: Dictionary = StadiumNpcManifest.canonical_shape(value.manifest)
	var expected: Dictionary = StadiumHillsideDefinitionV1.canonical()
	if (
		manifest.is_empty()
		or expected.is_empty()
		or not ClubCareer.same(manifest, expected)
		or JSON.stringify(manifest, "", true, true).sha256_text() != value.manifest_key
	):
		return {}
	return {
		"version": HILLSIDE_VERSION,
		"seed": int(value.seed),
		"career_run": int(value.career_run),
		"league": GRAND_LEAGUE,
		"selection": SELECTION,
		"fixture": 32,
		"venue_owner": HILLSIDE_OWNER,
		"manifest": manifest,
		"manifest_key": value.manifest_key,
		"environment": StadiumHillsideEnvironmentV1.capture(_seed(int(value.seed)))
	}
