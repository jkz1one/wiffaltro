extends Node
## Focused Base five-host contracts. No game is run and no result evidence is fabricated.

const V1_SAVE: String = "res://src/tests/fixtures/ay03_control_ay02_save61.json"
const V2_SAVE: String = "res://src/tests/fixtures/base_control_ay03_save61_v2.json"
const V1_SHA: String = "aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067"
const V2_SHA: String = "86cbcd4827d265647b2f9eba6f58079d0347edb19d9658e80cb6fe345c96ae1d"
const IDS: Dictionary = {"AY-01": 2, "AY-02": 1, "AY-03": 1, "AE-01": 2, "AE-02": 1,
	"AC-01": 2, "AC-02": 1, "AM-01": 1, "AM-02": 1}
const BASE_QUOTA: Dictionary = {"backyard": 2, "expanded": 2, "club": 1, "mogul": 0}
# Independently reconstructed SHA256/rejection/Fisher-Yates draws for current pools.
const GOLDEN: Dictionary = {
	0: ["AY-03", "AE-01", "AC-02", "AE-02", "AY-01"],
	1: ["AC-02", "AE-02", "AY-02", "AE-01", "AY-03"],
	10: ["AE-02", "AE-01", "AC-02", "AY-03", "AY-01"],
	47: ["AC-01", "AE-01", "AY-03", "AY-02", "AE-02"],
	443: ["AE-01", "AE-02", "AY-01", "AC-02", "AY-02"],
	2147483647: ["AY-02", "AE-02", "AC-02", "AE-01", "AY-03"]}
var _checks: int = 0
var _failures: int = 0
var _golden_maps: int = 0
var _routed_hosts: int = 0


func _ready() -> void:
	_public_ids()
	_allocations()
	_contact_contracts()
	_legacy_save(V1_SAVE, V1_SHA, 1)
	_legacy_save(V2_SAVE, V2_SHA, 2)
	var season: SeasonState = _season(true)
	if season.npc_venues.is_empty():
		_check(false, "new Base map required before route/save probes")
		_finish()
		return
	var legacy: SeasonState = _season(false)
	_draft_stability(season, legacy)
	_saved_map(season)
	_fixture_routes(season)
	_repeated_saved_geometry(season)
	_report_schema(season)
	_finish()


func _public_ids() -> void:
	for id: String in IDS:
		var entry: Dictionary = StadiumNpcSnapshot.capture(id, IDS[id])
		_check(StadiumNpcSnapshot.supports(id, IDS[id]) and not entry.is_empty()
			and entry.version == 18 and entry.manifest.id == id
			and entry.manifest.revision == IDS[id], "exact public entry " + id)
		_check(not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club())
			and StadiumLayoutSnapshot.ownership(entry) == null, "no human ownership " + id)
		if IDS[id] == 2:
			var raw: Dictionary = StadiumNpcSnapshot.raw_entry(id, 2)
			_check(StadiumNpcSnapshot.raw_envelope_valid(raw)
				and not StadiumNpcSnapshot.valid(raw), "retained raw16 remains quarantined " + id)
		_check(StadiumNpcSnapshot.capture(id, IDS[id] + 1).is_empty(),
			"adjacent revision cannot borrow public admission " + id)
	for id: String in ["AY-04", "AE-03", "AC-03", "AM-03", "UNKNOWN"]:
		_check(not StadiumNpcSnapshot.supports(id, 1)
			and StadiumNpcSnapshot.capture(id, 1).is_empty(), "unpublished identity rejected " + id)
	var ready: Dictionary = SeasonVenues.readiness(0)
	_check(ready.ok and ready.pools.backyard.keys() == ["AY-01", "AY-02", "AY-03"]
		and ready.pools.expanded.keys() == ["AE-01", "AE-02"]
		and ready.pools.club.keys() == ["AC-01", "AC-02"]
		and ready.pools.mogul.keys() == ["AM-01", "AM-02"],
		"Base readiness uses exact current concrete public families")
	var quotas: Array = [[2, 2, 1, 0], [2, 1, 2, 0], [1, 1, 2, 1],
		[1, 0, 2, 2], [1, 0, 2, 2]]
	for ordinal: int in range(5):
		var available: Dictionary = SeasonVenues.readiness(ordinal)
		var allocated: Dictionary = SeasonVenues.capture_five(443, 1, ordinal)
		_check(available.ok and String(available.error).is_empty() and not allocated.is_empty(),
			"current public pools support venue ordinal %d" % ordinal)
		if allocated.is_empty():
			continue
		var counts: Array[int] = [0, 0, 0, 0]
		for entry: Dictionary in allocated.assignments.values():
			counts[["backyard", "expanded", "club", "mogul"].find(entry.manifest.tier)] += 1
		_check(counts == quotas[ordinal], "independent tier quota ordinal %d" % ordinal)
	for ordinal: int in [-1, 5]:
		_check(not SeasonVenues.five_ready(ordinal), "invalid venue ordinal rejected")


func _allocations() -> void:
	for seed_value: int in GOLDEN:
		var data: Dictionary = SeasonVenues.capture_five(seed_value, 1, 0)
		_check(not data.is_empty(), "five-host capture seed %d" % seed_value)
		if data.is_empty():
			continue
		_golden_maps += 1
		var actual: Array = []
		var yards: Array = []
		for owner in range(1, 6):
			var entry: Dictionary = data.assignments[str(owner)]
			actual.append(entry.manifest.id)
			if entry.manifest.tier == "backyard":
				yards.append(entry.manifest.id)
		_check(data.version == 3 and data.venue_ordinal == 0
			and ClubCareer.same(data.quota, BASE_QUOTA) and actual == GOLDEN[seed_value],
			"independent sorted-pool shuffle golden seed %d" % seed_value)
		_check(yards.size() == 2 and yards[0] != yards[1]
			and actual.count("AE-01") == 1 and actual.count("AE-02") == 1,
			"distinct Backyard and Expanded pools exhaust before repeats")
		_check(ClubCareer.same(data, SeasonVenues.capture_five(seed_value, 1, 0))
			and SeasonVenues.key(data) == SeasonVenues.key(JSON.parse_string(_json(data))),
			"stable full-precision five-host map roundtrip")
		for stream: String in ["layout", "owner", "environment"]:
			var identity: String = "ordinary-venues-v3:%s:%d:1:0" % [stream, seed_value]
			var expected: int = identity.sha256_text().left(8).hex_to_int() & 0x7fffffff
			_check(data.streams[stream] == expected, "independent namespace " + stream)
		_check(data.environments.size() == 32, "all scheduled and semifinal environments saved")
		for fixture in range(32):
			var environment: Dictionary = data.environments[str(fixture)]
			_check(environment.fixture == fixture and environment.mode == "day"
				and environment.profile.is_empty(), "saved daylight environment %d" % fixture)
	var fixed: Dictionary = SeasonVenues.capture_five(443, 1, 0)
	if not fixed.is_empty():
		_check(fixed.environments["0"].seed == 2386655
			and fixed.environments["1"].seed == 1737811887
			and fixed.environments["2"].seed == 1397012882,
			"independent environment stream golden draws")
	seed(901)
	var expected_draw: int = randi()
	seed(901)
	SeasonVenues.capture_five(443, 1, 0)
	_check(randi() == expected_draw, "venue allocation consumes no global RNG draw")
	_check(SeasonVenues.capture(443, 1).version == 2,
		"historical capture entry point retains assignment2")
	for bad: Array in [[-1, 1], [2147483648, 1], [443, 0], [443, ClubCareer.MAX_RUNS + 1]]:
		_check(SeasonVenues.capture_five(bad[0], bad[1], 0).is_empty(),
			"invalid season identity cannot allocate")


func _season(five: bool) -> SeasonState:
	var season: SeasonState = SeasonState.create(4, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture_five(4, season.career.current, 0) if five \
		else SeasonVenues.capture(4, season.career.current)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "actual draft choice %d" % pick)
	return season


func _draft_stability(season: SeasonState, legacy: SeasonState) -> void:
	var current_save: Dictionary = SeasonSave.snapshot(season)
	var legacy_save: Dictionary = SeasonSave.snapshot(legacy)
	_check(not current_save.is_empty() and not legacy_save.is_empty(), "both saves are valid")
	current_save.erase("npc_venues")
	legacy_save.erase("npc_venues")
	_check(ClubCareer.same(current_save, legacy_save) and season.difficulty == 1,
		"Base venue ordinal0 preserves draft, opponents, career and tactical difficulty1")
	for fixture: Dictionary in season.schedule:
		var current: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
		var before: MatchState = SeasonPhysicalFixtures.match_for(legacy, fixture)
		_check(current.ai_tactical_quality == before.ai_tactical_quality
			and SeasonPhysicalFixtures.seed_for(season, fixture)
			== SeasonPhysicalFixtures.seed_for(legacy, fixture),
			"fixture match seed and tactical quality unchanged %d" % fixture.id)


func _saved_map(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 61 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "new assignment3 save61 exact reload")
	var original: Dictionary = season.npc_venues.duplicate(true)
	for key: String in ["1", "5"]:
		var missing: Dictionary = original.duplicate(true)
		missing.assignments.erase(key)
		_check(SeasonVenues.normalized(missing).is_empty(), "missing saved owner " + key)
	var bad: Dictionary = original.duplicate(true)
	bad.assignments["0"] = bad.assignments["1"]
	_check(SeasonVenues.normalized(bad).is_empty(), "human owner never enters NPC map")
	bad = original.duplicate(true)
	bad.assignments["3"] = bad.assignments["4"]
	_check(SeasonVenues.normalized(bad).is_empty(), "saved map must meet exact Base quota")
	bad = original.duplicate(true)
	bad.environments.erase("31")
	_check(SeasonVenues.normalized(bad).is_empty(), "missing semifinal environment rejects")
	bad = original.duplicate(true)
	bad.environments["0"].mode = "night"
	_check(SeasonVenues.normalized(bad).is_empty(), "uncertified night rejects")
	# Saved records are authoritative; normalization must not call the current allocator.
	var retained: Dictionary = original.duplicate(true)
	var held: Dictionary = retained.assignments["3"]
	retained.assignments["3"] = retained.assignments["5"]
	retained.assignments["5"] = held
	retained.environments["0"].seed = 2147483646
	_check(ClubCareer.same(retained, SeasonVenues.normalized(retained)),
		"shape-valid saved owner/environment records remain frozen without reroll")
	_check(ClubCareer.same(original, season.npc_venues), "validation never mutates live saved map")


func _fixture_routes(season: SeasonState) -> void:
	var before: PackedByteArray = var_to_bytes(SeasonSave.snapshot(season))
	var owners: Dictionary = {}
	var expanded: Array[Dictionary] = []
	var away_fixture: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		var field: FieldDefinition = SeasonState.field_for_fixture(fixture, season)
		if fixture.home == 0:
			_check(snapshot.is_empty() and field != null and field.id == PitchBatLab.FIELD_ID,
				"human-owned home routing remains unchanged")
			continue
		owners[str(fixture.home)] = true
		_check(not snapshot.is_empty() and field != null and field.id == &"field.npc_venue",
			"every saved NPC owner routes its public park")
		if snapshot.is_empty():
			continue
		_check(snapshot.version == 19 and snapshot.binding.assignment_version == 3
			and snapshot.binding.owner_club == fixture.home
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and snapshot.binding.environment_seed == snapshot.environment.seed
			and ClubCareer.same(snapshot.environment, season.npc_venues.environments[str(fixture.id)]),
			"fixture19 binds saved owner and independent saved environment")
		_check(ClubCareer.same(snapshot.manifest,
			season.npc_venues.assignments[str(fixture.home)].manifest), "exact saved host manifest")
		if fixture.away == 0:
			away_fixture = fixture
			_binding(snapshot, season, fixture)
			if snapshot.manifest.tier == "expanded":
				expanded.append(snapshot)
	_routed_hosts = owners.size()
	_check(owners.size() == 5 and expanded.size() == 2, "all five hosts and both Expanded owners")
	if expanded.size() == 2:
		_check(expanded[0].manifest.id != expanded[1].manifest.id
			and expanded[0].binding.owner_club != expanded[1].binding.owner_club
			and StadiumNpcSnapshot.key(expanded[0]) != StadiumNpcSnapshot.key(expanded[1]),
			"distinct Expanded geometries have distinct club and fixture authority")
		var other: Dictionary = SeasonVenues.fixture_for_id(season, expanded[1].binding.fixture)
		_check(not StadiumNpcSnapshot.matches_fixture(expanded[0], season, other),
			"one Expanded club cannot borrow the other club binding")
	if not away_fixture.is_empty():
		var prior: Dictionary = SeasonVenues.for_fixture(season, away_fixture)
		_check(ClubCareer.same(prior, SeasonVenues.for_fixture(season, away_fixture)),
			"same-fixture rematch retains saved venue/environment/match identity")
	_playoff_routes(season)
	_check(before == var_to_bytes(SeasonSave.snapshot(season)),
		"routing leaves assignment, stock, rewards and result history untouched")


func _repeated_saved_geometry(season: SeasonState) -> void:
	# Synthetic saved-map compatibility control only, never an earned/played result.
	# Restore permits repeated retained geometry even when the current pool is larger.
	var original: Dictionary = SeasonSave.snapshot(season)
	var saved: Dictionary = original.duplicate(true)
	var repeated: Dictionary = StadiumNpcSnapshot.capture("AE-01", 2)
	for owner: String in saved.npc_venues.assignments:
		if saved.npc_venues.assignments[owner].manifest.tier == "expanded":
			saved.npc_venues.assignments[owner] = repeated.duplicate(true)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(restored != null, "synthetic frozen repeated-geometry map restores without reroll")
	if restored == null:
		return
	var fixtures: Array[Dictionary] = []
	var snapshots: Array[Dictionary] = []
	for fixture: Dictionary in restored.schedule:
		var snapshot: Dictionary = SeasonVenues.for_fixture(restored, fixture)
		if fixture.away == 0 and not snapshot.is_empty() and snapshot.manifest.id == "AE-01":
			fixtures.append(fixture)
			snapshots.append(snapshot)
	_check(snapshots.size() == 2, "two genuine bindings in synthetic repeated-geometry saved map")
	if snapshots.size() == 2:
		_check(ClubCareer.same(snapshots[0].manifest, snapshots[1].manifest)
			and snapshots[0].binding.owner_club != snapshots[1].binding.owner_club
			and StadiumNpcSnapshot.key(snapshots[0]) != StadiumNpcSnapshot.key(snapshots[1]),
			"same AE01 geometry preserves distinct saved owner and fixture authority")
		_check(not StadiumNpcSnapshot.matches_fixture(snapshots[0], restored, fixtures[1]),
			"same geometry cannot borrow the other saved owner binding")
	_check(ClubCareer.same(original, SeasonSave.snapshot(season)),
		"synthetic repeated-geometry probe leaves original season unchanged")


func _binding(snapshot: Dictionary, season: SeasonState, fixture: Dictionary) -> void:
	_check(StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture)
		and StadiumNpcSnapshot.key(snapshot) == StadiumNpcSnapshot.key(
			JSON.parse_string(_json(snapshot))), "full-precision v3 fixture roundtrip")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.environment.seed = bad.binding.match_seed
	_check(not StadiumNpcSnapshot.valid(bad), "match seed cannot replace independent environment")
	bad = snapshot.duplicate(true)
	var held: int = bad.binding.match_seed
	bad.binding.match_seed = bad.binding.environment_seed
	bad.binding.environment_seed = held
	bad.environment.seed = held
	_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
		"internally coherent seed swap cannot match actual saved fixture")
	bad = snapshot.duplicate(true)
	bad.binding.owner_club = 1 + int(bad.binding.owner_club) % 5
	bad.binding.batting_home = bad.binding.owner_club
	_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
		"cross-club binding fails saved assignment comparison")
	bad = snapshot.duplicate(true)
	bad.binding.erase("assignment_version")
	_check(not StadiumNpcSnapshot.valid(bad), "partial new binding cannot masquerade as legacy")


func _playoff_routes(season: SeasonState) -> void:
	# Routing-only fixtures. No playoff result, report, progression or settlement is created.
	var semifinals: Array[Dictionary] = season.semifinals.duplicate(true)
	var final_fixture: Dictionary = season.final_fixture.duplicate(true)
	season.semifinals = [{"id": 30, "round": 10, "away": 0, "home": 1},
		{"id": 31, "round": 10, "away": 2, "home": 0}]
	var hosted: Dictionary = SeasonVenues.for_fixture(season, season.semifinals[0])
	_check(not hosted.is_empty() and hosted.binding.owner_club == 1
		and ClubCareer.same(hosted.environment, season.npc_venues.environments["30"]),
		"hosted semifinal uses saved NPC owner and pre-saved environment30")
	_check(SeasonVenues.for_fixture(season, season.semifinals[1]).is_empty()
		and SeasonState.field_for_fixture(season.semifinals[1], season).id == PitchBatLab.FIELD_ID,
		"human-hosted semifinal remains owned home")
	season.final_fixture = {"id": 32, "round": 11, "away": 0, "home": 1, "neutral": true}
	_check(SeasonVenues.for_fixture(season, season.final_fixture).is_empty()
		and SeasonState.field_for_fixture(season.final_fixture, season).id == SeasonState.AWAY_FIELD_ID,
		"neutral final remains Commons despite saved home-club venue")
	season.semifinals = semifinals
	season.final_fixture = final_fixture


func _legacy_save(path: String, pin: String, version: int) -> void:
	_check(FileAccess.get_sha256(path) == pin, "byte-pinned actual assignment%d save61" % version)
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(value is Dictionary and value.get("version") == 61, "actual save61 input")
	if not value is Dictionary:
		return
	var season: SeasonState = SeasonSave._decode(value)
	_check(season != null, "historical completed save still decodes")
	if season == null:
		return
	_check(season.npc_venues.version == version
		and season.npc_venues.assignments.size() == version
		and ClubCareer.same(value, SeasonSave.snapshot(season)),
		"historical assignment/reports/rewards/evidence remain exact")
	var reread: SeasonState = SeasonSave._decode(JSON.parse_string(_json(SeasonSave.snapshot(season))))
	_check(reread != null and ClubCareer.same(value, SeasonSave.snapshot(reread)),
		"actual completed save full-precision reload replays retained evidence exactly")
	_check(StadiumNpcYardTwoPublicChecks.settled(season, 0).is_empty(),
		"existing settled-save helper rejects duplicate rewards and cleared-round replay")
	for fixture: Dictionary in season.schedule:
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if not snapshot.is_empty():
			_check(not snapshot.binding.has("assignment_version")
				and not snapshot.binding.has("environment_seed")
				and snapshot.environment.seed == snapshot.binding.match_seed,
				"historical fixture19 keeps old binding shape and seed equality")


func _contact_contracts() -> void:
	# Detached geometry/schema probes only. These rows are never recorded as match evidence.
	var graphs: Dictionary = {"AY-01": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
		"AE-01": "PERIM-BACKYARD-ANGLED-BX1-v1",
		"AC-01": "PROTOTYPE-CLUB-DUGOUT-OFFSET-GABLES-v2"}
	for id: String in graphs:
		var snapshot: Dictionary = StadiumNpcSnapshot.capture(id, 2)
		var reference: Dictionary = StadiumNpcPublicContacts._reference(snapshot)
		_check(not reference.is_empty() and reference.graph == graphs[id],
			"schema-only exact family contact graph " + id)
		if reference.is_empty():
			continue
		var rear: Dictionary = {}
		for segment: Dictionary in reference.segments.values():
			if segment.role == "REAR_PERIMETER_DEAD":
				rear = _segment_event(reference.graph, segment)
				break
		var rows: Array = [{"play": 0, "reason": "rear_perimeter", "events": [rear]}]
		var plays: Array = [{"contact": ContactResult.Outcome.CONTACT,
			"exit_speed": 20.0, "result": "foul"}]
		_check(not rear.is_empty() and StadiumNpcPublicContacts.valid(rows, plays, snapshot),
			"schema-only real rear boundary accepts " + id)
		var bad: Array = rows.duplicate(true)
		bad[0].events[0].id = "FOREIGN-GRAPH"
		_check(not StadiumNpcPublicContacts.valid(bad, plays, snapshot),
			"foreign family graph cannot supply contact " + id)
		bad = rows.duplicate(true)
		bad[0].events[0].position = [500.0, 500.0, 500.0]
		_check(not StadiumNpcPublicContacts.valid(bad, plays, snapshot),
			"correct surface name cannot authorize remote position " + id)
		_check(not reference.provenance.is_empty(), "actual provenance surfaces exist " + id)
		if reference.provenance.is_empty():
			continue
		var instance: String = reference.provenance.keys()[0]
		var provenance: Array = [{"instance": instance,
			"surface": reference.provenance[instance][0], "preterminal": true, "elapsed": 0.1}]
		_check(StadiumNpcPublicContacts.provenance(provenance, snapshot),
			"schema-only actual physical provenance surface " + id)
		provenance[0].instance = instance.replace(":r2:", ":r1:")
		_check(not StadiumNpcPublicContacts.provenance(provenance, snapshot),
			"old-revision source cannot supply new public provenance " + id)
		if id == "AE-01":
			_check(not reference.items.is_empty(), "actual Expanded receiver bodies exist")
			if reference.items.is_empty():
				continue
			var body: Dictionary = reference.items[0]
			var point: Vector3 = body.shapes[0].inverse.affine_inverse().origin
			var event: Dictionary = {"source": "item", "id": body.instance,
				"surface": body.surface, "role": body.role,
				"position": [point.x, point.y, point.z], "time": 0.1, "kind": "contact"}
			_check(StadiumNpcPublicContacts.valid([{"play": 0, "reason": "receiver_containment",
				"events": [event]}], plays, snapshot), "schema-only actual Expanded receiver")
		if id == "AC-01":
			_club_contacts(snapshot, reference)


func _segment_event(graph: String, segment: Dictionary) -> Dictionary:
	var point: Vector2 = (segment.a + segment.b) / 2
	return {"source": "boundary", "id": graph, "surface": segment.id, "role": segment.role,
		"position": [point.x, 0.5, point.y], "time": 0.1, "kind": "crossing"}


func _club_contacts(snapshot: Dictionary, reference: Dictionary) -> void:
	var opening: Dictionary = {}
	for segment: Dictionary in reference.segments.values():
		if segment.role == "DUGOUT_OPENING_DEAD":
			opening = _segment_event(reference.graph, segment)
			break
	var plays: Array = [{"contact": ContactResult.Outcome.CONTACT,
		"exit_speed": 20.0, "result": "single"}]
	_check(not opening.is_empty() and StadiumNpcPublicContacts.valid(
		[{"play": 0, "reason": "dugout_opening_dead", "events": [opening]}], plays, snapshot),
		"schema-only actual Club dugout opening role")
	var pole: Dictionary = {}
	for body: Dictionary in reference.bodies:
		if body.kind == "pole":
			var point: Vector3 = body.shapes[0].inverse.affine_inverse().origin
			point.y = body.split + 0.25
			pole = {"source": "boundary", "id": reference.graph, "surface": body.segment,
				"role": "FOUL_POLE_UPPER", "position": [point.x, point.y, point.z],
				"time": 0.1, "kind": "contact"}
			break
	plays[0].result = "home_run"
	_check(not pole.is_empty() and StadiumNpcPublicContacts.valid(
		[{"play": 0, "reason": "foul_pole_upper", "events": [pole]}], plays, snapshot),
		"schema-only actual Club upper pole and terminal role")


func _report_schema(season: SeasonState) -> void:
	# Synthetic envelope lift only: existing accepted AY02 baseball core/boundary rows.
	# This is not an AY01 game, is never persisted and never reaches season settlement.
	var path: String = "res://src/tests/fixtures/ay03_control_ay02_report15.json"
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(FileAccess.get_sha256(path)
		== "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564"
		and PhysicalMatchReport.valid(old), "byte-pinned accepted report15 schema input")
	var snapshots: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if not snapshot.is_empty():
			snapshots[snapshot.manifest.id] = snapshot
	_check(snapshots.has("AY-01") and snapshots.has("AE-01") and snapshots.has("AC-01"),
		"three real saved fixture bindings for schema-only dispatch")
	if not snapshots.has("AY-01") or not snapshots.has("AE-01") or not snapshots.has("AC-01"):
		return
	var schema: Dictionary = old.duplicate(true)
	schema.version = 17
	schema.resolver = "physical-ai-npc-public-v1"
	schema.property = snapshots["AY-01"]
	schema.seed = schema.property.binding.match_seed
	_check(PhysicalMatchReport.valid(schema)
		and StadiumNpcPublicReport.matches(schema, snapshots["AY-01"])
		and PhysicalMatchReport.valid(StadiumNpcPublicReport.core(schema)),
		"schema-only report17 dispatch with unchanged accepted baseball core")
	for id: String in ["AE-01", "AC-01"]:
		var wrong: Dictionary = schema.duplicate(true)
		wrong.property = snapshots[id]
		wrong.seed = wrong.property.binding.match_seed
		_check(not PhysicalMatchReport.valid(wrong),
			"Yard contact graph cannot masquerade as report17 " + id)
	var wrong: Dictionary = schema.duplicate(true)
	wrong.seed += 1
	_check(not PhysicalMatchReport.valid(wrong), "report17 rejects swapped match seed")
	wrong = schema.duplicate(true)
	wrong.property = old.property
	wrong.seed = old.seed
	_check(not PhysicalMatchReport.valid(wrong), "report17 rejects legacy AY02 property")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BASE_PUBLIC_DATA " + label)


func _finish() -> void:
	print("BASE_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	print("BASE_PUBLIC_COVERAGE_DATA golden_maps=%d routed_hosts=%d" % [_golden_maps, _routed_hosts])
	get_tree().quit(0 if _failures == 0 else 1)
