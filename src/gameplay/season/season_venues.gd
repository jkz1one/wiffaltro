class_name SeasonVenues
extends RefCounted
## Frozen opponent parks. Legacy AY02/AY03 assignments retain their exact v1/v2 behavior.
## V3 selects five complete public snapshots under an explicit venue quota ordinal.
## The independent namespace never consumes draft, opponent or physical-match RNG draws.
# gdlint: disable=max-returns

const VERSION: int = 2
const NAMESPACE: String = "ay02-away-v1:"
const AY03_NAMESPACE: String = "ay03-away-v1:"
const FIVE_VERSION: int = 3
const FIVE_NAMESPACE: String = "ordinary-venues-v3:"
const BUCKETS: Array[String] = ["backyard", "expanded", "club", "mogul"]
const OWNERS: Array[String] = ["1", "2", "3", "4", "5"]
# Explicit reference-format venue ordinals, never SeasonState.difficulty (AI tactics).
const QUOTAS: Array = [[2, 2, 1, 0], [2, 1, 2, 0], [1, 1, 2, 1],
	[1, 0, 2, 2], [1, 0, 2, 2]]
# New-season allowlist only. Restore uses the saved full snapshots, not this pool.
const PUBLIC_LAYOUTS: Dictionary = {"AY-01": 2, "AY-02": 1, "AY-03": 1,
	"AE-01": 2, "AE-02": 1, "AC-01": 2, "AC-02": 1, "AM-01": 1, "AM-02": 1}


static func capture(seed: int, career_run: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var entry: Dictionary = StadiumNpcSnapshot.capture("AY-02", 1)
	var next: Dictionary = StadiumNpcSnapshot.capture("AY-03", 1)
	if entry.is_empty() or next.is_empty():
		return {}
	return {"version": VERSION, "seed": seed, "career_run": career_run,
		"assignments": {str(owner_for(seed)): entry, str(ay03_owner_for(seed)): next}}


static func owner_for(seed: int) -> int:
	return 1 + (NAMESPACE + str(seed)).sha256_text().left(8).hex_to_int() % 5


static func ay03_owner_for(seed: int) -> int:
	var owner: int = owner_for(seed)
	var others: Array[int] = []
	for club: int in range(1, 6):
		if club != owner:
			others.append(club)
	return others[(AY03_NAMESPACE + str(seed)).sha256_text().left(8).hex_to_int() % 4]


static func normalized(value: Variant, seed: int = -1, career_run: int = -1) -> Dictionary:
	if _is_five(value):
		return _normalized_five(value, seed, career_run)
	if not StadiumNpcSnapshot._keys(value, ["version", "seed", "career_run", "assignments"]) \
		or not SeasonOwnership._whole(value.version, 1, VERSION) \
		or not SeasonOwnership._whole(value.seed, 0, 2147483647) \
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS) \
		or (seed >= 0 and value.seed != seed) \
		or (career_run >= 0 and value.career_run != career_run):
		return {}
	# Validate persisted assignments in place; version1 is never expanded or regenerated.
	var expected: Dictionary = {str(owner_for(int(value.seed))): "AY-02"}
	if value.version == VERSION:
		expected[str(ay03_owner_for(int(value.seed)))] = "AY-03"
	if not StadiumNpcSnapshot._keys(value.assignments, expected.keys()):
		return {}
	var assignments: Dictionary = {}
	for owner: String in expected:
		var entry: Dictionary = StadiumNpcSnapshot.normalized(value.assignments[owner])
		if entry.is_empty() or entry.version != StadiumNpcSnapshot.PUBLIC_VERSION \
			or entry.manifest.id != expected[owner] or entry.manifest.revision != 1:
			return {}
		assignments[owner] = entry
	return {"version": int(value.version), "seed": int(value.seed),
		"career_run": int(value.career_run), "assignments": assignments}


static func key(value: Variant) -> String:
	var data: Dictionary = normalized(value)
	return "" if data.is_empty() else JSON.stringify(data, "", true, true).sha256_text()


static func run_for(season: SeasonState) -> int:
	if season == null:
		return -1
	return season.career.current if season.career != null else season._npc_replay_run


static func matches_season(season: SeasonState) -> bool:
	return season != null and run_for(season) > 0 \
		and not normalized(season.npc_venues, season.season_seed, run_for(season)).is_empty()


static func fixture_for_id(season: SeasonState, id: int) -> Dictionary:
	if season == null or id < 0 or id > 32:
		return {}
	if id < 30:
		for row: Dictionary in season.schedule:
			if row.id == id:
				return row.duplicate(true)
	elif id < 32:
		for row: Dictionary in season.semifinals:
			if row.id == id:
				return row.duplicate(true)
	elif season.final_fixture.get("id", -1) == id:
		return season.final_fixture.duplicate(true)
	return {}


static func for_fixture(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if season != null and not season.final_venue.is_empty() and fixture.get("id") == 32:
		return SeasonFinalVenue.for_fixture(season, fixture)
	if season != null and _is_five(season.npc_venues):
		return _five_for_fixture(season, fixture)
	if not matches_season(season) or not SeasonOwnership._whole(fixture.get("id"), 0, 31):
		return {}
	var scheduled: Dictionary = fixture_for_id(season, int(fixture.id))
	if scheduled.is_empty() or not ClubCareer.same(fixture, scheduled) \
		or fixture.get("neutral", false) or fixture.get("home", -1) == 0:
		return {}
	var data: Dictionary = normalized(season.npc_venues, season.season_seed, run_for(season))
	var owner: String = str(int(fixture.home))
	if not data.assignments.has(owner):
		return {}
	var entry: Dictionary = data.assignments[owner]
	var seed: int = SeasonPhysicalFixtures.seed_for(season, fixture)
	return StadiumNpcSnapshot.fixture(entry, {
		"season_seed": season.season_seed, "career_run": run_for(season),
		"assignment_key": key(data), "owner_club": int(fixture.home),
		"venue_id": entry.manifest.id, "venue_revision": int(entry.manifest.revision),
		"fixture": int(fixture.id), "away": int(fixture.away),
		"batting_home": int(fixture.home), "neutral": false, "match_seed": seed,
		"field": StadiumNpcSnapshot.FIELD}, {
		"version": StadiumFixtureEnvironment.VERSION, "seed": seed,
		"fixture": int(fixture.id), "mode": "day", "profile": ""})


static func field_for_fixture(season: SeasonState, fixture: Dictionary) -> FieldDefinition:
	if season != null and not season.final_venue.is_empty():
		if not SeasonFinalVenue.matches_season(season):
			return null
		if fixture.get("id") == 32:
			return ContentDB.get_field(StringName(StadiumNpcSnapshot.FIELD)) if (
				not SeasonFinalVenue.for_fixture(season, fixture).is_empty()) else null
	if season == null or season.npc_venues.is_empty():
		return SeasonState.field_for_fixture(fixture)
	if not matches_season(season) or not SeasonOwnership._whole(fixture.get("id"), 0, 32) \
		or not ClubCareer.same(fixture_for_id(season, int(fixture.id)), fixture):
		return null
	var snapshot: Dictionary = for_fixture(season, fixture)
	if not snapshot.is_empty():
		return ContentDB.get_field(StringName(StadiumNpcSnapshot.FIELD))
	return SeasonState.field_for_fixture(fixture)


static func capture_five(seed: int, career_run: int, venue_ordinal: int) -> Dictionary:
	if seed < 0 or seed > 2147483647 or career_run < 1 or career_run > ClubCareer.MAX_RUNS:
		return {}
	var ready: Dictionary = readiness(venue_ordinal)
	if not ready.ok:
		return {}
	var streams: Dictionary = _stream_seeds(seed, career_run, venue_ordinal)
	var layout_state: Dictionary = {"seed": streams.layout, "draw": 0}
	var owner_state: Dictionary = {"seed": streams.owner, "draw": 0}
	var environment_state: Dictionary = {"seed": streams.environment, "draw": 0}
	var selected: Array = []
	var quota: Dictionary = _quota(venue_ordinal)
	for bucket: String in BUCKETS:
		var pool: Dictionary = ready.pools[bucket]
		var ids: Array = pool.keys()
		ids.sort()
		var remaining: int = quota[bucket]
		while remaining > 0:
			# Start another shuffled cycle only after exhausting every distinct eligible ID.
			for id: String in _shuffled(ids, layout_state):
				selected.append(pool[id].duplicate(true))
				remaining -= 1
				if remaining == 0:
					break
	selected = _shuffled(selected, owner_state)
	var assignments: Dictionary = {}
	for index in range(OWNERS.size()):
		assignments[OWNERS[index]] = selected[index].duplicate(true)
	var environments: Dictionary = {}
	for fixture in range(32):
		environments[str(fixture)] = {"version": StadiumFixtureEnvironment.VERSION,
			"seed": _draw_below(environment_state, 2147483648), "fixture": fixture,
			"mode": "day", "profile": ""}
	return normalized({"version": FIVE_VERSION, "seed": seed, "career_run": career_run,
		"venue_ordinal": venue_ordinal, "quota": quota, "streams": streams,
		"assignments": assignments, "environments": environments}, seed, career_run)


static func readiness(venue_ordinal: int) -> Dictionary:
	var quota: Dictionary = _quota(venue_ordinal)
	if quota.is_empty():
		return {"ok": false, "error": "This venue quota ordinal is not supported."}
	var pools: Dictionary = {}
	for bucket: String in BUCKETS:
		pools[bucket] = {}
	var ids: Array = PUBLIC_LAYOUTS.keys()
	ids.sort()
	for id: String in ids:
		var revision: int = PUBLIC_LAYOUTS[id]
		# Concrete public snapshot/runtime/report contracts, never availability flags.
		if not StadiumNpcSnapshot.supports(id, revision):
			continue
		var entry: Dictionary = StadiumNpcSnapshot.capture(id, revision)
		if entry.is_empty() or entry.version != StadiumNpcSnapshot.PUBLIC_VERSION \
			or entry.manifest.id != id or entry.manifest.revision != revision \
			or not BUCKETS.has(entry.manifest.tier) or not _supports_day(entry):
			continue
		pools[entry.manifest.tier][id] = entry
	for bucket: String in BUCKETS:
		if quota[bucket] == 0:
			continue
		if pools[bucket].is_empty():
			return {"ok": false, "error": "No supported daylight %s venue is ready." % bucket}
		var empty_option: bool = false
		for entry: Dictionary in pools[bucket].values():
			if entry.manifest.live_units == 0:
				empty_option = true
		if not empty_option:
			return {"ok": false, "error": "No supported empty-obstacle %s venue is ready." % bucket}
	return {"ok": true, "error": "", "pools": pools}


static func five_ready(venue_ordinal: int) -> bool:
	return readiness(venue_ordinal).ok


static func _is_five(value: Variant) -> bool:
	return value is Dictionary and SeasonOwnership._whole(value.get("version"),
		FIVE_VERSION, FIVE_VERSION)


static func _quota(venue_ordinal: int) -> Dictionary:
	if venue_ordinal < 0 or venue_ordinal >= QUOTAS.size():
		return {}
	var result: Dictionary = {}
	for index in range(BUCKETS.size()):
		result[BUCKETS[index]] = QUOTAS[venue_ordinal][index]
	return result


static func _stream_seeds(seed: int, career_run: int, venue_ordinal: int) -> Dictionary:
	var result: Dictionary = {}
	for stream: String in ["layout", "owner", "environment"]:
		var identity: String = "%s%s:%d:%d:%d" % [FIVE_NAMESPACE, stream,
			seed, career_run, venue_ordinal]
		result[stream] = identity.sha256_text().left(8).hex_to_int() & 0x7fffffff
	return result


static func _shuffled(values: Array, state: Dictionary) -> Array:
	var result: Array = values.duplicate(true)
	# Deterministic Fisher-Yates; independent local stream, no global RNG consumption.
	for index in range(result.size() - 1, 0, -1):
		var other: int = _draw_below(state, index + 1)
		var held: Variant = result[index]
		result[index] = result[other]
		result[other] = held
	return result


static func _draw_below(state: Dictionary, bound: int) -> int:
	# Rejection removes modulo bias. 32-bit draws remain within Godot's signed int64.
	var limit: int = 4294967296 - (4294967296 % bound)
	while true:
		var identity: String = "%sshuffle:%d:%d" % [FIVE_NAMESPACE, state.seed, state.draw]
		var draw: int = identity.sha256_text().left(8).hex_to_int()
		state.draw += 1
		if draw < limit:
			return draw % bound
	return 0


static func _supports_day(entry: Dictionary) -> bool:
	# These immutable r1 public contracts predate environment certificates.
	if entry.manifest.id in ["AY-02", "AY-03", "AM-01", "AM-02", "AE-02", "AC-02"] \
		and entry.manifest.revision == 1:
		return true
	for certificate: Dictionary in entry.manifest.environment_certificates:
		if certificate.mode == "day" and certificate.profile.is_empty():
			return true
	return false


static func _normalized_five(value: Dictionary, seed: int, career_run: int) -> Dictionary:
	if not StadiumNpcSnapshot._keys(value, ["version", "seed", "career_run", "venue_ordinal",
		"quota", "streams", "assignments", "environments"]) \
		or not SeasonOwnership._whole(value.seed, 0, 2147483647) \
		or not SeasonOwnership._whole(value.career_run, 1, ClubCareer.MAX_RUNS) \
		or not SeasonOwnership._whole(value.venue_ordinal, 0, QUOTAS.size() - 1) \
		or (seed >= 0 and value.seed != seed) \
		or (career_run >= 0 and value.career_run != career_run):
		return {}
	var quota: Dictionary = _quota(int(value.venue_ordinal))
	if not StadiumNpcSnapshot._keys(value.quota, BUCKETS) \
		or not StadiumNpcSnapshot._keys(value.assignments, OWNERS) \
		or not StadiumNpcSnapshot._keys(value.streams, ["layout", "owner", "environment"]):
		return {}
	for bucket: String in BUCKETS:
		if not SeasonOwnership._whole(value.quota[bucket], 0, 5) \
			or value.quota[bucket] != quota[bucket]:
			return {}
	var streams: Dictionary = _stream_seeds(int(value.seed), int(value.career_run),
		int(value.venue_ordinal))
	for stream: String in streams:
		if not SeasonOwnership._whole(value.streams[stream], 0, 2147483647) \
			or value.streams[stream] != streams[stream]:
			return {}
	# Only saved, immutable definitions are validated. No readiness/pool/shuffle calls here.
	var assignments: Dictionary = {}
	var counts: Dictionary = {"backyard": 0, "expanded": 0, "club": 0, "mogul": 0}
	for owner: String in OWNERS:
		var entry: Dictionary = StadiumNpcSnapshot.normalized(value.assignments[owner])
		if entry.is_empty() or entry.version != StadiumNpcSnapshot.PUBLIC_VERSION \
			or not BUCKETS.has(entry.manifest.tier) or not _supports_day(entry):
			return {}
		counts[entry.manifest.tier] += 1
		assignments[owner] = entry
	if not ClubCareer.same(counts, quota):
		return {}
	var environments: Dictionary = _normalized_environments(value.environments)
	if environments.is_empty():
		return {}
	return {"version": FIVE_VERSION, "seed": int(value.seed), "career_run": int(value.career_run),
		"venue_ordinal": int(value.venue_ordinal), "quota": quota, "streams": streams,
		"assignments": assignments, "environments": environments}


static func _normalized_environments(value: Variant) -> Dictionary:
	var ids: Array[String] = []
	for fixture in range(32):
		ids.append(str(fixture))
	if not StadiumNpcSnapshot._keys(value, ids):
		return {}
	var result: Dictionary = {}
	for fixture: String in ids:
		var row: Variant = value[fixture]
		if not StadiumNpcSnapshot._keys(row, StadiumNpcSnapshot.ENVIRONMENT_KEYS) \
			or not SeasonOwnership._whole(row.version, StadiumFixtureEnvironment.VERSION,
				StadiumFixtureEnvironment.VERSION) \
			or not SeasonOwnership._whole(row.seed, 0, 2147483647) \
			or not SeasonOwnership._whole(row.fixture, 0, 31) or row.fixture != int(fixture) \
			or not row.mode is String or row.mode != "day" \
			or not row.profile is String or not row.profile.is_empty():
			return {}
		result[fixture] = {"version": int(row.version), "seed": int(row.seed),
			"fixture": int(row.fixture), "mode": "day", "profile": ""}
	return result


static func _five_for_fixture(season: SeasonState, fixture: Dictionary) -> Dictionary:
	var owned: Variant = _owned_five_fixture(season, fixture)
	if owned != null:
		return owned
	return _five_for_fixture_cold(season, fixture)


static func _five_for_fixture_cold(season: SeasonState, fixture: Dictionary) -> Dictionary:
	if not matches_season(season) or not SeasonOwnership._whole(fixture.get("id"), 0, 31):
		return {}
	var scheduled: Dictionary = fixture_for_id(season, int(fixture.id))
	if scheduled.is_empty() or not ClubCareer.same(fixture, scheduled) \
		or fixture.get("neutral", false) or fixture.get("home", -1) == 0:
		return {}
	var data: Dictionary = normalized(season.npc_venues, season.season_seed, run_for(season))
	var owner: String = str(int(fixture.home))
	if not data.assignments.has(owner):
		return {}
	var entry: Dictionary = data.assignments[owner]
	var environment: Dictionary = data.environments[str(int(fixture.id))].duplicate(true)
	return StadiumNpcSnapshot.fixture(entry, {
		"season_seed": season.season_seed, "career_run": run_for(season),
		"assignment_key": key(data), "assignment_version": FIVE_VERSION,
		"environment_seed": int(environment.seed), "owner_club": int(fixture.home),
		"venue_id": entry.manifest.id, "venue_revision": int(entry.manifest.revision),
		"fixture": int(fixture.id), "away": int(fixture.away),
		"batting_home": int(fixture.home), "neutral": false,
		"match_seed": SeasonPhysicalFixtures.seed_for(season, fixture),
		"field": StadiumNpcSnapshot.FIELD}, environment)


static func _owned_five_fixture(season: SeasonState,
	fixture: Dictionary) -> Variant:
	# A private, synchronous raw-input entry, not a reusable canonical-data/proof API.
	# The entire eligibility walk is callback-free. Any unknown shape takes the exact
	# historical _five_for_fixture body, including its original error boundaries.
	if not _five_canonical_inputs(season, fixture):
		return null
	# Preserve matches_season's positive-run guard and its second run_for read, then
	# validate every saved assignment before the original fixture-id check.
	if run_for(season) <= 0:
		return {}
	var data: Dictionary = normalized(season.npc_venues, season.season_seed, run_for(season))
	if data.is_empty() or not SeasonOwnership._whole(fixture.get("id"), 0, 31):
		return {}
	var scheduled: Dictionary = fixture_for_id(season, int(fixture.id))
	if scheduled.is_empty() or not ClubCareer.same(fixture, scheduled) \
		or fixture.get("neutral", false) or fixture.get("home", -1) == 0:
		return {}
	# Keep the former second-normalized argument reads at their original position.
	# Exact owners/plain containers cannot mutate the privately owned canonical data.
	@warning_ignore("unused_variable")
	var unused_venues_again: Dictionary = season.npc_venues
	@warning_ignore("unused_variable")
	var unused_seed_again: int = season.season_seed
	@warning_ignore("unused_variable")
	var unused_run_again: int = run_for(season)
	var owner: String = str(int(fixture.home))
	if not data.assignments.has(owner):
		return {}
	var entry: Dictionary = data.assignments[owner]
	var environment: Dictionary = data.environments[str(int(fixture.id))].duplicate(true)
	# Do not change data.assignments before hashing the complete canonical assignment.
	# This replaces fixture's first normalization of an already canonical owned entry;
	# its final full snapshot normalization remains below.
	var result: Dictionary = entry.duplicate(true)
	result.version = StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION
	result["binding"] = {
		"season_seed": season.season_seed, "career_run": run_for(season),
		"assignment_key": JSON.stringify(data, "", true, true).sha256_text(),
		"assignment_version": FIVE_VERSION,
		"environment_seed": int(environment.seed), "owner_club": int(fixture.home),
		"venue_id": entry.manifest.id, "venue_revision": int(entry.manifest.revision),
		"fixture": int(fixture.id), "away": int(fixture.away),
		"batting_home": int(fixture.home), "neutral": false,
		"match_seed": SeasonPhysicalFixtures.seed_for(season, fixture),
		"field": StadiumNpcSnapshot.FIELD}
	result["environment"] = environment
	return StadiumNpcSnapshot.normalized(result)


static func _five_canonical_inputs(season: SeasonState, fixture: Dictionary) -> bool:
	# Exact owners and a bounded callback-free walk are eligibility, never authority.
	# Unknown inputs execute the untouched cold body, including its error boundaries.
	if not is_instance_valid(season) or season.get_script() != SeasonState:
		return false
	if season.career != null and season.career.get_script() != ClubCareer:
		return false
	if not _is_five(season.npc_venues) or not fixture.has_all(["id", "home", "away"]) \
		or not SeasonOwnership._whole(fixture.id, 0, 31) \
		or not SeasonOwnership._whole(fixture.home, 1, 5) \
		or not SeasonOwnership._whole(fixture.away, 0, 5):
		return false
	var budget: Array[int] = [32768]
	for value: Variant in [fixture, season.npc_venues, season.schedule,
		season.semifinals, season.final_fixture]:
		if not _canonical_plain_json(value, budget):
			return false
	for rows: Array[Dictionary] in [season.schedule, season.semifinals]:
		for row: Dictionary in rows:
			if not SeasonOwnership._whole(row.get("id"), 0, 32):
				return false
	return true


static func _owned_ac02_fixture(actual: Variant, season: SeasonState,
	fixture: Dictionary) -> Variant:
	# A private, synchronous raw-input entry, not a reusable canonical-data/proof API.
	# The entire eligibility walk is callback-free. Any unknown shape takes the exact
	# historical route in matches_fixture, including its original error boundaries.
	if not _ac02_canonical_inputs(actual, season, fixture):
		return null
	# Preserve matches_season's positive-run guard and its second run_for read, then
	# validate every saved assignment before the original fixture-id check.
	if run_for(season) <= 0:
		return {}
	var data: Dictionary = normalized(season.npc_venues, season.season_seed, run_for(season))
	if data.is_empty() or not SeasonOwnership._whole(fixture.get("id"), 0, 31):
		return {}
	var scheduled: Dictionary = fixture_for_id(season, int(fixture.id))
	if scheduled.is_empty() or not ClubCareer.same(fixture, scheduled) \
		or fixture.get("neutral", false) or fixture.get("home", -1) == 0:
		return {}
	# Keep the former second-normalized argument reads at their original position.
	# Exact owners/plain containers cannot mutate the privately owned canonical data.
	@warning_ignore("unused_variable")
	var unused_venues_again: Dictionary = season.npc_venues
	@warning_ignore("unused_variable")
	var unused_seed_again: int = season.season_seed
	@warning_ignore("unused_variable")
	var unused_run_again: int = run_for(season)
	var owner: String = str(int(fixture.home))
	if not data.assignments.has(owner):
		return {}
	var entry: Dictionary = data.assignments[owner]
	var environment: Dictionary = data.environments[str(int(fixture.id))].duplicate(true)
	# Do not change data.assignments before hashing the complete canonical assignment.
	# This replaces fixture's first normalization of an already canonical owned entry;
	# its final full snapshot normalization remains below.
	var result: Dictionary = entry.duplicate(true)
	result.version = StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION
	result["binding"] = {
		"season_seed": season.season_seed, "career_run": run_for(season),
		"assignment_key": JSON.stringify(data, "", true, true).sha256_text(),
		"assignment_version": FIVE_VERSION,
		"environment_seed": int(environment.seed), "owner_club": int(fixture.home),
		"venue_id": entry.manifest.id, "venue_revision": int(entry.manifest.revision),
		"fixture": int(fixture.id), "away": int(fixture.away),
		"batting_home": int(fixture.home), "neutral": false,
		"match_seed": SeasonPhysicalFixtures.seed_for(season, fixture),
		"field": StadiumNpcSnapshot.FIELD}
	result["environment"] = environment
	return StadiumNpcSnapshot.normalized(result)


static func _ac02_canonical_inputs(actual: Variant, season: SeasonState,
	fixture: Dictionary) -> bool:
	# Check Script identity before any scripted field read. Empty-path subclasses are
	# still scripts, and an eligibility miss must never become a validation rejection.
	if not is_instance_valid(season) or season.get_script() != SeasonState:
		return false
	if season.career != null and season.career.get_script() != ClubCareer:
		return false
	if not actual is Dictionary or actual.get("version") != StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION \
		or not actual.get("manifest") is Dictionary \
		or typeof(actual.manifest.get("id")) != TYPE_STRING or actual.manifest.id != "AC-02" \
		or actual.manifest.get("revision") != 1 or not season.final_venue.is_empty() \
		or not _is_five(season.npc_venues) or not fixture.has_all(["id", "home", "away"]) \
		or not SeasonOwnership._whole(fixture.id, 0, 31) \
		or not SeasonOwnership._whole(fixture.home, 1, 5) \
		or not SeasonOwnership._whole(fixture.away, 0, 5):
		return false
	var budget: Array[int] = [32768]
	for value: Variant in [actual, fixture, season.npc_venues, season.schedule,
		season.semifinals, season.final_fixture]:
		if not _canonical_plain_json(value, budget):
			return false
	# fixture_for_id dereferences row.id. Malformed rows must reach its original body,
	# not acquire an earlier error from the new path or a different stopping point.
	for rows: Array[Dictionary] in [season.schedule, season.semifinals]:
		for row: Dictionary in rows:
			if not SeasonOwnership._whole(row.get("id"), 0, 32):
				return false
	return true


static func _canonical_plain_json(value: Variant, budget: Array[int], depth: int = 0) -> bool:
	# No reflection, conversion, duplicate, serialization or callback. Depth/node
	# limits are admission limits only; larger/recursive/opaque inputs fall back.
	budget[0] -= 1
	if depth > 16 or budget[0] < 0:
		return false
	if value is Dictionary:
		for key: Variant in value:
			budget[0] -= 1
			if budget[0] < 0 or not key is String \
				or not _canonical_plain_json(value[key], budget, depth + 1):
				return false
		return true
	if value is Array:
		for child: Variant in value:
			if not _canonical_plain_json(child, budget, depth + 1):
				return false
		return true
	return value is String or value is bool or value is int \
		or (value is float and is_finite(value))
