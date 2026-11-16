extends Node
## Source-authored envelope tests only: no fabricated completed game or earned history.
## Participant authoring is confined to the separate bounded installation helper.

const FIXTURE = preload("res://src/tests/hillside_public_fixture.gd")
const LEGACY: Array = [
	preload("res://src/tests/long_yard_public_fixture.gd"),
	preload("res://src/tests/grand_i_public_fixture.gd"),
	preload("res://src/tests/grand_ii_public_fixture.gd"),
	preload("res://src/tests/grand_iii_public_fixture.gd"),
	preload("res://src/tests/pool_party_public_fixture.gd")
]
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_routing()
	_profile()
	_legacy()
	_model_capacity()
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "Hillside record before four genuine draft choices")
	if season != null:
		_record(season.final_venue)
		_save(season)
		_binding(season)
	print("HILLSIDE_PUBLIC_DATA checks=%d failures=%d completed_games=0" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _routing() -> void:
	for version: int in range(16, 27):
		var value: Dictionary = {"version": version}
		var expected: bool = version >= 19 and version <= 25
		_check(
			(
				StadiumNpcSnapshot.is_fixture(value) == expected
				and StadiumNpcSnapshot.is_fixture(_json(value)) == expected
			),
			"routing discriminates19 through25; route alone grants no valid payload"
		)
	for wrong: Variant in [25.5, "25", true, null, [], {}]:
		_check(not StadiumNpcSnapshot.is_fixture({"version": wrong}), "raw discriminator refuses")
	_check(
		(
			not StadiumNpcSnapshot.supports("HILLSIDE", 1)
			and StadiumNpcSnapshot.capture("HILLSIDE", 1).is_empty()
			and not SeasonVenues.PUBLIC_LAYOUTS.has("HILLSIDE")
			and not StadiumNpcPublicReport.supports_definition("HILLSIDE", 1)
		),
		"away/raw/selection fallback stays closed"
	)
	_check(
		(
			SeasonFinalVenue.capture(6, 1, "standard").is_empty()
			and SeasonFinalVenue.capture_explicit(6, 1, "doubleheader", "HILLSIDE").is_empty()
			and SeasonFinalVenue.capture_explicit(6, 1, "standard", "unknown").is_empty()
		),
		"explicit-only existing league contract"
	)


func _profile() -> void:
	for seed: int in [0, 6, 2147483647]:
		var value: Dictionary = StadiumHillsideEnvironmentV1.capture(seed)
		_check(
			(
				StadiumHillsideEnvironmentV1.valid(value)
				and StadiumHillsideEnvironmentV1.valid(_json(value))
				and value.version == 7
				and value.render_profile == 1
				and value.profile == "HILLSIDE-1310-CLEAR-HUD-v1"
				and value.time == "13:10"
				and value.weather == "clear"
				and value.lighting.active_lights.is_empty()
			),
			"exact13:10 clear HUD profile7, retained renderer1"
		)
	var environment: Dictionary = StadiumHillsideEnvironmentV1.capture(6)
	for other: Dictionary in [
		StadiumLongYardEnvironmentV1.capture(6),
		StadiumGrandIEnvironmentV1.capture(6),
		StadiumGrandIIEnvironmentV1.capture(6),
		StadiumGrandIIIEnvironmentV1.capture(6),
		StadiumPoolPartyEnvironmentV1.capture(6)
	]:
		_check(not StadiumHillsideEnvironmentV1.valid(other), "other venue profile refuses")
	for field: String in ["version", "seed", "fixture", "render_profile"]:
		for wrong: Variant in [true, "7", 7.5, null]:
			var changed: Dictionary = environment.duplicate(true)
			changed[field] = wrong
			_check(
				not StadiumHillsideEnvironmentV1.valid(changed), "profile raw numeric type refuses"
			)
	for edit: int in range(5):
		var changed: Dictionary = environment.duplicate(true)
		match edit:
			0:
				changed["extra"] = false
			1:
				changed.profile = &"HILLSIDE-1310-CLEAR-HUD-v1"
			2:
				changed.lighting.sun_energy = "1.0"
			3:
				changed.lighting.sun_energy += 0.000000000000001
			4:
				changed.lighting.active_lights = ["foreign"]
		_check(
			not StadiumHillsideEnvironmentV1.valid(changed),
			"exact profile type/shape/value refuses"
		)
	_check(
		(
			StadiumHillsideEnvironmentV1.capture(-1).is_empty()
			and StadiumHillsideEnvironmentV1.capture(2147483648).is_empty()
		),
		"profile seed bounds"
	)


func _record(record: Dictionary) -> void:
	_check(
		(
			record.version == 6
			and record.manifest.id == "HILLSIDE"
			and record.manifest.tier == "expanded"
			and record.manifest.shape == "deeper_center"
			and record.manifest.instances.size() == 8
			and record.manifest.live_units == 0
			and record.manifest.graph.id == StadiumHillsidePublicContacts.GRAPH
			and record.manifest.presentation.profile == record.environment.profile
		),
		"record6 binds exact eight-copy terrain/graph/HUD identity"
	)
	_check(
		ClubCareer.same(
			record,
			SeasonFinalVenue.capture_explicit(
				record.seed, record.career_run, "standard", "HILLSIDE"
			)
		),
		"only named explicit route captures"
	)
	for version: int in range(1, 6):
		var changed: Dictionary = record.duplicate(true)
		changed.version = version
		_check(
			SeasonFinalVenue.normalized(changed).is_empty(),
			"old record cannot be relabelled Hillside"
		)
	for field: String in ["version", "seed", "career_run", "fixture"]:
		for wrong: Variant in [true, "6", 6.5, null]:
			var changed: Dictionary = record.duplicate(true)
			changed[field] = wrong
			_check(
				SeasonFinalVenue.normalized(changed).is_empty(), "record raw numeric type refuses"
			)
	for edit: int in range(7):
		var changed: Dictionary = record.duplicate(true)
		match edit:
			0:
				changed["extra"] = false
			1:
				changed.selection = SeasonFinalVenue.STANDARD_BASE_SELECTION
			2:
				changed.venue_owner = SeasonFinalVenue.POOL_PARTY_OWNER
			3:
				changed.manifest.id = "POOL-PARTY"
			4:
				changed.manifest.instances.pop_back()
			5:
				changed.league = &"standard"
			6:
				changed.environment.seed += 1
		_check(
			SeasonFinalVenue.normalized(changed).is_empty(),
			"identity/selection/type/shape mutation refuses"
		)


func _save(season: SeasonState) -> void:
	# This is the actual post-draft pre-season state; never serialize authored final participants.
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(
		saved.get("version") == 67 and saved.get("final_venue", {}).get("version") == 6,
		"save67 advertises final record6"
	)
	for value: Dictionary in [saved, _json(saved)]:
		var restored: SeasonState = SeasonSave._decode(value)
		_check(
			restored != null and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
			"native and engine-JSON save67 roundtrip"
		)
	for version: int in range(61, 67):
		var changed: Dictionary = saved.duplicate(true)
		changed.version = version
		_check(SeasonSave._decode(changed) == null, "old save wrapper cannot borrow record6")
	for edit: int in range(3):
		var changed: Dictionary = saved.duplicate(true)
		match edit:
			0:
				changed.erase("final_venue")
			1:
				changed["extra"] = true
			2:
				changed.version = "67"
		_check(SeasonSave._decode(changed) == null, "save type/shape refuses")


func _binding(season: SeasonState) -> void:
	for player_home: bool in [false, true]:
		var fixture: Dictionary = FIXTURE.fixture(season, player_home)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		_check(not snapshot.is_empty(), "explicit neutral participant orientation binds")
		if snapshot.is_empty():
			continue
		_check(
			(
				snapshot.version == 25
				and snapshot.authority == "neutral-final-hillside-v1"
				and snapshot.binding.venue_owner == "finals-venue:hillside:v1"
				and snapshot.binding.venue_id == "HILLSIDE"
				and snapshot.binding.fixture == 32
				and snapshot.binding.neutral
				and not snapshot.binding.has("owner_club")
				and snapshot.binding.batting_home == fixture.home
				and snapshot.binding.away == fixture.away
				and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture)
			),
			"snapshot25 neutral owner distinct from batting-home"
		)
		_check(
			ClubCareer.same(snapshot, StadiumNpcSnapshot.normalized(_json(snapshot))),
			"full-precision canonical snapshot roundtrip"
		)
		_check(
			(
				PhysicalStadiumReport.npc_resolver(snapshot) == StadiumHillsidePublicReport.RESOLVER
				and StadiumHillsidePublicReport.VERSION == 23
				and PhysicalStadiumReport.HILLSIDE_FINAL_VERSION == 23
				and StadiumFixtureEnvironment.label(season, fixture) == "13:10 • Clear"
			),
			"report23 resolver and exact environment label"
		)
		var human: Dictionary = {"version": 7, "fixture": 32, "property": snapshot}
		_check(
			(
				StadiumNpcYardTwoHumanEvidence._envelope(human)
				and not StadiumNpcYardTwoHumanEvidence.valid(human)
			),
			"human7 envelope grants no outcome"
		)
		for version: int in range(1, 7):
			human.version = version
			_check(
				not StadiumNpcYardTwoHumanEvidence._envelope(human),
				"old human envelope cannot borrow25"
			)
		for version: int in [16, 17, 18, 19, 20, 21, 22, 23, 24, 26]:
			var changed: Dictionary = snapshot.duplicate(true)
			changed.version = version
			_check(
				(
					not StadiumNpcSnapshot.valid(changed)
					and PhysicalStadiumReport.npc_resolver(changed).is_empty()
				),
				"cross-envelope relabel refuses"
			)
		for edit: int in range(6):
			var changed: Dictionary = snapshot.duplicate(true)
			match edit:
				0:
					changed["extra"] = false
				1:
					changed.binding["owner_club"] = 1
				2:
					changed.binding.venue_id = &"HILLSIDE"
				3:
					changed.binding.fixture = 31
				4:
					changed.binding.neutral = 1
				5:
					changed.authority = SeasonFinalVenue.POOL_PARTY_AUTHORITY
			_check(not StadiumNpcSnapshot.valid(changed), "raw snapshot binding and shape refuses")
		var fake: Dictionary = {
			"version": 23, "resolver": StadiumHillsidePublicReport.RESOLVER, "property": snapshot
		}
		_check(
			(
				not StadiumHillsidePublicReport.valid(fake)
				and not PhysicalMatchReport.valid(fake)
				and not PhysicalStadiumReport.valid(fake)
			),
			"dictionary envelope cannot fabricate a game"
		)
		_check(
			(
				StadiumNpcPublicContacts._reference(snapshot).is_empty()
				and not StadiumHillsidePublicContacts._reference(snapshot).is_empty()
			),
			"cold contact dispatch uses actual hillside members, never flat fallback"
		)


func _legacy() -> void:
	for index in range(LEGACY.size()):
		var season: SeasonState = LEGACY[index].season()
		_check(season != null, "legacy neutral fixture constructs unchanged")
		if season == null:
			continue
		var saved: Dictionary = SeasonSave.snapshot(season)
		var restored: SeasonState = SeasonSave._decode(_json(saved))
		_check(
			(
				saved.get("version") == 62 + index
				and restored != null
				and ClubCareer.same(saved, SeasonSave.snapshot(restored))
			),
			"old saves62 through66 roundtrip"
		)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, LEGACY[index].fixture(season))
		_check(
			(
				snapshot.get("version") == 20 + index
				and not StadiumHillsidePublicContacts.matches(snapshot)
			),
			"legacy snapshots20 through24 remain disjoint"
		)
		var changed: Dictionary = saved.duplicate(true)
		changed.version = 67
		_check(SeasonSave._decode(changed) == null, "legacy record cannot borrow save67")
		season.final_venue = {}
		var ordinary: Dictionary = SeasonSave.snapshot(season)
		_check(
			ordinary.get("version") == 61 and not ordinary.has("final_venue"),
			"ordinary save61 never infers Hillside"
		)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("HILLSIDE_PUBLIC_DATA " + label)


func _model_capacity() -> void:
	var value: Dictionary = StadiumHillsideDefinitionV1.payload()
	var changed: Dictionary = value.duplicate(true)
	changed.models["capacity-extra"] = {"version": 1, "sha256": "0".repeat(64)}
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"exact Hillside family refuses45 model pins"
	)
	changed = value.duplicate(true)
	changed.revision = 2
	for instance: Dictionary in changed.instances:
		instance.instance = "npc:HILLSIDE:r2:" + instance.site
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"other Hillside revision retains32 cap"
	)
	changed = value.duplicate(true)
	changed.assembly.id = "HILLSIDE-other-assembly"
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"other Hillside assembly retains32 cap"
	)
	changed = value.duplicate(true)
	changed.id = "CAPACITY-CONTROL"
	changed.assembly.id = "CAPACITY-CONTROL-v1"
	for instance: Dictionary in changed.instances:
		instance.instance = "npc:CAPACITY-CONTROL:r1:" + instance.site
	var names: Array = changed.models.keys()
	names.sort()
	for index in range(32, names.size()):
		changed.models.erase(names[index])
	_check(
		not StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"other structurally valid family retains32 capacity"
	)
	changed.models["capacity-extra"] = {"version": 1, "sha256": "0".repeat(64)}
	_check(
		StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"other family still refuses33 model pins"
	)
