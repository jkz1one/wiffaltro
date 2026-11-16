extends Node
## Authored data tests only. No invented completed games, earned finals, or public selection.

const FIXTURE = preload("res://src/tests/pool_party_public_fixture.gd")
const LEGACY: Array = [preload("res://src/tests/long_yard_public_fixture.gd"),
	preload("res://src/tests/grand_i_public_fixture.gd"),
	preload("res://src/tests/grand_ii_public_fixture.gd"),
	preload("res://src/tests/grand_iii_public_fixture.gd")]
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_routing()
	_profile()
	_definition()
	_held()
	_legacy()
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "Pool Party fixed record captured before four real draft choices")
	if season != null:
		_save(season)
		_binding(season)
		_types(season.final_venue)
	_pool_shapes()
	print("POOL_PARTY_PUBLIC_DATA checks=%d failures=%d completed_games=0" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _routing() -> void:
	for version: int in range(16, 26):
		var value: Dictionary = {"version": version}
		var expected: bool = version >= 19 and version <= 24
		_check(StadiumNpcSnapshot.is_fixture(value) == expected
			and StadiumNpcSnapshot.is_fixture(JSON.parse_string(_json(value))) == expected,
			"native and JSON route only fixture19 through24")
	for wrong: Variant in [24.5, "24", true, null, [], {}]:
		_check(not StadiumNpcSnapshot.is_fixture({"version": wrong}), "raw fixture version refuses")


func _profile() -> void:
	for seed: int in [0, 6, 2147483647]:
		var value: Dictionary = StadiumPoolPartyEnvironmentV1.capture(seed)
		_check(StadiumPoolPartyEnvironmentV1.valid(JSON.parse_string(_json(value)))
			and value.version == 6 and value.mode == "day" and value.time == "13:10"
			and value.profile == "POOL-PARTY-1310-CLEAR-v1" and value.weather == "clear"
			and value.render_profile == 1 and value.lighting.active_lights.is_empty(),
			"exact daytime clear environment6 has no artificial emitters")
		for other: Dictionary in [StadiumLongYardEnvironmentV1.capture(seed),
			StadiumGrandIEnvironmentV1.capture(seed), StadiumGrandIIEnvironmentV1.capture(seed),
			StadiumGrandIIIEnvironmentV1.capture(seed)]:
			_check(not StadiumPoolPartyEnvironmentV1.valid(other), "other neutral environment refuses")
		_check(not StadiumLongYardEnvironmentV1.valid(value)
			and not StadiumGrandIEnvironmentV1.valid(value)
			and not StadiumGrandIIEnvironmentV1.valid(value)
			and not StadiumGrandIIIEnvironmentV1.valid(value), "daytime cannot borrow old authority")
		for field: String in ["version", "seed", "fixture", "render_profile"]:
			for wrong: Variant in [true, "6", 6.5, null, [], {}]:
				var changed: Dictionary = value.duplicate(true)
				changed[field] = wrong
				_check(not StadiumPoolPartyEnvironmentV1.valid(changed), "profile numeric type refuses")
		for field: String in ["profile", "time", "weather", "mode"]:
			for wrong: Variant in [true, 6, null, [], {}, &"clear", "changed"]:
				var changed: Dictionary = value.duplicate(true)
				changed[field] = wrong
				_check(not StadiumPoolPartyEnvironmentV1.valid(changed), "profile string type refuses")
		var changed: Dictionary = value.duplicate(true)
		changed.lighting.sun_energy += 0.01
		_check(not StadiumPoolPartyEnvironmentV1.valid(changed), "daytime light mutation refuses")
	_check(StadiumPoolPartyEnvironmentV1.capture(-1).is_empty()
		and StadiumPoolPartyEnvironmentV1.capture(2147483648).is_empty(), "seed bounds refuse")


func _definition() -> void:
	var value: Dictionary = StadiumPoolPartyDefinitionV1.canonical()
	_check(not value.is_empty(), "authored Pool Party manifest normalizes")
	if value.is_empty():
		return
	_check(value.id == "POOL-PARTY" and value.revision == 1
		and value.instances.size() == 65 and value.field == StadiumNpcSnapshot.FIELD
		and value.shape == "straight" and value.tier == "expanded"
		and value.assembly.id == "POOL-PARTY-public-straight-v1"
		and value.environment_certificates.is_empty(), "exact Expanded straight65 neutral identity")
	var pool_count: int = 0
	for row: Dictionary in value.instances:
		_check(row.instance.begins_with("npc:POOL-PARTY:r1:"), "frozen distinct neutral identities")
		if row.item == "ST-006":
			pool_count += 1
			_check(row.instance == StadiumPoolPartyPublicContacts.COPY,
				"one neutral pool OL-R copy has no paid owner")
	_check(pool_count == 1, "exactly one genuine authored live pool")


func _held() -> void:
	_check(SeasonFinalVenue.capture(6, 1, "standard").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "doubleheader", "POOL-PARTY").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "standard", "unknown").is_empty(),
		"legacy Standard inference and unknown pairing refuse")
	_check(not StadiumNpcSnapshot.supports("POOL-PARTY", 1)
		and StadiumNpcSnapshot.capture("POOL-PARTY", 1).is_empty()
		and not SeasonVenues.PUBLIC_LAYOUTS.has("POOL-PARTY")
		and not StadiumNpcPublicReport.supports_definition("POOL-PARTY", 1),
		"ordinary public selection and quotas stay held")
	_check(ClubCareer.same(SeasonFinalVenue.capture_explicit(6, 1, "standard", "POOL-PARTY"),
		SeasonFinalVenue.capture_pool_party(6, 1)), "explicit-only planned pairing")


func _save(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var decoded: Variant = JSON.parse_string(_json(saved))
	_check(saved.get("version") == 66 and typeof(saved.version) == TYPE_INT
		and decoded is Dictionary and typeof(decoded.version) == TYPE_FLOAT,
		"save66 native and JSON representations")
	for value: Dictionary in [saved.duplicate(true), decoded]:
		var restored: SeasonState = SeasonSave._decode(value)
		_check(restored != null and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
			"exact save66 full-precision roundtrip")
	for wrong: Variant in [61, 62, 63, 64, 65, 66.5, true, "66", null, [], {}]:
		var changed: Dictionary = saved.duplicate(true)
		changed.version = wrong
		_check(SeasonSave._decode(changed) == null, "save66 wrapper cannot relabel record5")
	for edit: int in range(4):
		var changed: Dictionary = saved.duplicate(true)
		match edit:
			0: changed.erase("final_venue")
			1: changed.final_venue.environment.seed += 1
			2: changed.final_venue.venue_owner = "npc-owner:1"
			3: changed.final_venue.environment.lighting.sun_rotation[0] += 0.01
		_check(SeasonSave._decode(changed) == null, "save binding mutation refuses")


func _binding(season: SeasonState) -> void:
	var original: Dictionary = season.final_venue.duplicate(true)
	for player_home: bool in [true, false]:
		var fixture: Dictionary = FIXTURE.fixture(season, player_home)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		_check(not snapshot.is_empty(), "both neutral participant orientations bind")
		if snapshot.is_empty():
			continue
		_check(snapshot.version == 24 and snapshot.authority == "neutral-final-pool-party-v1"
			and snapshot.binding.venue_owner == "finals-venue:pool-party:v1"
			and snapshot.binding.batting_home == fixture.home and snapshot.binding.away == fixture.away
			and snapshot.binding.neutral and not snapshot.binding.has("owner_club")
			and snapshot.binding.assignment_key == SeasonFinalVenue.key(original)
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
			"neutral venue owner remains separate from higher-seed batting-home")
		_check(PhysicalStadiumReport.npc_resolver(snapshot) == StadiumPoolPartyPublicReport.RESOLVER
			and StadiumPoolPartyPublicReport.VERSION == 22
			and PhysicalStadiumReport.POOL_PARTY_FINAL_VERSION == 22
			and SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
			and StadiumFixtureEnvironment.label(season, fixture) == "13:10 • Clear",
			"report22 field and daytime label routes")
		var human: Dictionary = {"version": 6, "fixture": 32, "property": snapshot}
		_check(StadiumNpcYardTwoHumanEvidence._envelope(human)
			and not StadiumNpcYardTwoHumanEvidence.valid(human), "human6 shape is not completed proof")
		for version: int in [1, 2, 3, 4, 5]:
			human.version = version
			_check(not StadiumNpcYardTwoHumanEvidence._envelope(human), "old human cannot borrow24")
		for version: int in [16, 17, 18, 19, 20, 21, 22, 23, 25]:
			var changed: Dictionary = snapshot.duplicate(true)
			changed.version = version
			_check(not StadiumNpcSnapshot.valid(changed)
				and PhysicalStadiumReport.npc_resolver(changed).is_empty(), "cross-venue snapshot refuses")
		for field: String in ["league", "selection", "venue_owner", "venue_id", "field"]:
			for wrong: Variant in [true, 24, null, [], {}, &"POOL-PARTY", "foreign"]:
				var changed: Dictionary = snapshot.duplicate(true)
				changed.binding[field] = wrong
				_check(not StadiumNpcSnapshot.valid(changed), "raw binding string rejects before equality")
		var fake: Dictionary = {"version": 22, "resolver": StadiumPoolPartyPublicReport.RESOLVER,
			"property": snapshot}
		_check(not StadiumPoolPartyPublicReport.valid(fake) and not PhysicalMatchReport.valid(fake)
			and not PhysicalStadiumReport.valid(fake), "report22 needs genuine report7 and pool proof")
	_check(ClubCareer.same(original, season.final_venue), "participants never reroll fixed record")


func _legacy() -> void:
	for index in range(LEGACY.size()):
		var season: SeasonState = LEGACY[index].season()
		_check(season != null, "old neutral fixture still constructs")
		if season == null:
			continue
		var saved: Dictionary = SeasonSave.snapshot(season)
		var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
		_check(saved.get("version") == 62 + index and restored != null
			and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "old save62 through65 unchanged")
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, LEGACY[index].fixture(season))
		_check(snapshot.get("version") == 20 + index
			and not StadiumPoolPartyPublicContacts.matches(snapshot), "old snapshots remain disjoint")
		var changed: Dictionary = saved.duplicate(true)
		changed.version = 66
		_check(SeasonSave._decode(changed) == null, "old final cannot borrow save66")
		season.final_venue = {}
		var ordinary: Dictionary = SeasonSave.snapshot(season)
		_check(ordinary.get("version") == 61 and not ordinary.has("final_venue"),
			"ordinary save61 never infers final")


func _types(record: Dictionary) -> void:
	for field: String in ["version", "seed", "career_run", "fixture"]:
		for wrong: Variant in [true, "5", 5.5, null, [], {}]:
			var changed: Dictionary = record.duplicate(true)
			changed[field] = wrong
			_check(SeasonFinalVenue.normalized(changed).is_empty(), "raw record numeric refuses")
	for field: String in ["league", "selection", "venue_owner"]:
		for wrong: Variant in [true, 5, null, [], {}, &"standard"]:
			var changed: Dictionary = record.duplicate(true)
			changed[field] = wrong
			_check(SeasonFinalVenue.normalized(changed).is_empty(), "raw record string refuses")


func _pool_shapes() -> void:
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var empty: Dictionary = {"version": 1, "copy": StadiumPoolPartyPublicContacts.COPY,
		"pose": [12, 0, 18, 0], "geometry": StadiumPoolPartyPublicContacts.geometry(source),
		"source_sha256": source, "water_commits": [], "water_outcomes": []}
	_check(StadiumPoolPartyPublicContacts._pool(empty, []), "empty pool proof only validates shape")
	_commit_shapes(empty)
	for edit: int in range(7):
		var changed: Dictionary = empty.duplicate(true)
		match edit:
			0: changed.copy = "owned:ST-006:1"
			1: changed.pose[0] += 1
			2: changed.geometry.physics_qualified = true
			3: changed.source_sha256 = "0".repeat(64)
			4: changed.version = true
			5: changed.water_commits = 0
			6: changed.water_outcomes = {}
		_check(not StadiumPoolPartyPublicContacts._pool(changed, []), "pool evidence mutation refuses")


func _commit_shapes(empty: Dictionary) -> void:
	# Synthetic validator operands only; never a completed report or a captured trajectory.
	var plays: Array = [{"result": "double", "contact": ContactResult.Outcome.CONTACT,
		"exit_speed": 20.0}]
	var valid_shape: Dictionary = empty.duplicate(true)
	valid_shape.water_commits = [{"generation": 1, "position": [12.0, 1.1, 18.0],
		"foul": false, "entry_fraction": 0.5, "play_sequence": 0}]
	valid_shape.water_outcomes = [{"play": 0,
		"reason": StadiumPoolPartyPublicContacts.WATER_DOUBLE,
		"resolution_position": [12.0, 1.1, 18.0], "result_floor": BallPlayState.ResultFloor.DOUBLE,
		"last_defender_touch": "", "has_first_ground": false, "result": "double"}]
	_check(StadiumPoolPartyPublicContacts._pool(valid_shape, plays),
		"well-shaped water receipt/outcome pair only, no completed-game claim")
	for edit: int in range(12):
		var changed: Dictionary = valid_shape.duplicate(true)
		match edit:
			0: changed.water_commits[0].generation = true
			1: changed.water_commits[0].play_sequence = 1
			2: changed.water_commits[0].entry_fraction = 1.1
			3: changed.water_commits[0].foul = 0
			4: changed.water_commits[0].position[0] = 12.1
			5: changed.water_outcomes[0].play = 1
			6: changed.water_outcomes[0].reason = "owned_pool_controller_water_double"
			7: changed.water_outcomes[0].has_first_ground = true
			8: changed.water_outcomes[0].last_defender_touch = "fielder"
			9: changed.water_outcomes[0].result_floor = BallPlayState.ResultFloor.HOME_RUN
			10: changed.water_outcomes[0].result = "home_run"
			11: changed.water_outcomes = []
		_check(not StadiumPoolPartyPublicContacts._pool(changed, plays),
			"receipt/outcome index, type, reason, position and ground-rule mismatch refuses")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("POOL_PARTY_PUBLIC_DATA " + label)
