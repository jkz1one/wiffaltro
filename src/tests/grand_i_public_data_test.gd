extends Node
## Source-authored native test, not a claim of execution or a played final.
## Explicit Grand qualification remains separate from public Standard selection.

const FIXTURE = preload("res://src/tests/grand_i_public_fixture.gd")
const LONG_FIXTURE = preload("res://src/tests/long_yard_public_fixture.gd")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_fixture_routing()
	_profile()
	_held_selection()
	_legacy()
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "Grand explicit record captured before four real draft choices")
	if season != null:
		_save(season)
		_binding(season)
	print("GRAND_I_PUBLIC_DATA checks=%d failures=%d completed_games=0" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture_routing() -> void:
	# Routing only: schema validation still rejects these deliberately incomplete envelopes.
	for version: int in [17, 18, 19, 20, 21, 22, 23, 24, 25]:
		var value: Dictionary = {"version": version}
		var expected: bool = version == 19 or version == 20 or version == 21 \
			or version == 22 or version == 23 or version == 24
		_check(StadiumNpcSnapshot.is_fixture(value) == expected
			and StadiumNpcSnapshot.is_fixture(JSON.parse_string(_json(value))) == expected,
			"native and JSON fixture version route exactly19/20/21/22/23/24: %d" % version)
	for version: Variant in [19.5, "19", true, null]:
		var value: Dictionary = {"version": version}
		_check(not StadiumNpcSnapshot.is_fixture(value)
			and not StadiumNpcSnapshot.is_fixture(JSON.parse_string(_json(value))),
			"fractional/string/bool/null fixture versions refuse")


func _profile() -> void:
	_check(StadiumGrandIEnvironmentV1.capture(-1).is_empty()
		and StadiumGrandIEnvironmentV1.capture(2147483648).is_empty(), "environment seed bounds")
	for seed: int in [0, 6, 2147483647]:
		var environment: Dictionary = StadiumGrandIEnvironmentV1.capture(seed)
		var decoded: Variant = JSON.parse_string(_json(environment))
		_check(StadiumGrandIEnvironmentV1.valid(decoded) and ClubCareer.same(environment, decoded),
			"full-precision seeded artistic environment JSON roundtrip")
		_check(environment.version == 3 and environment.seed == seed and environment.fixture == 32
			and environment.mode == "night" and environment.profile == "GRAND-I-1910-CLEAR-v1"
			and environment.time == "19:10" and environment.weather == "clear"
			and environment.render_profile == 2, "exact artistic slot independent of sunset or RNG")
		var lights: Dictionary = environment.lighting.active_lights
		_check(lights.version == 2 and lights.visible_heads == 24 and lights.dynamic_emitters == 6
			and lights.shadow_casters == 4 and lights.emitters.size() == 6
			and lights.glow.count == 24 and environment.lighting.ambient_energy == 0.65
			and lights.qualification == "native-readability-and-shadow-tuning-pending",
			"six emitters preserve 24 heads and four-slot initial shadow budget")
		var shadows: int = 0
		for row: Dictionary in lights.emitters:
			shadows += 1 if row.shadows else 0
			_check(row.represented_heads == 4 and row.energy == 3.0 and row.range == 80.0
				and row.angle == 68.0 and row.origin.size() == 3 and row.direction.size() == 3,
				"one versioned selected authored head ray per tower")
		_check(shadows == 4 and ClubCareer.same(lights.atlas.quadrant_slots, [1, 1, 1, 1]),
			"four casting tower lights fit the declared atlas slots")
		for edit: int in range(9):
			var changed: Dictionary = environment.duplicate(true)
			match edit:
				0: changed.time = "19:11"
				1: changed.weather = "overcast"
				2: changed.profile = "LONG-YARD-1610-CLEAR-v1"
				3: changed.lighting.active_lights.emitters[0].energy += 0.01
				4: changed.lighting.active_lights.emitters[0].head = "HEAD-99"
				5: changed.lighting.active_lights.emitters[0].origin[0] += 0.01
				6: changed.lighting.active_lights.emitters[0].shadows = false
				7: changed.lighting.active_lights.shadow_casters = 6
				8: changed["night_qualified"] = true
			_check(not StadiumGrandIEnvironmentV1.valid(changed), "corrupt artistic profile%d" % edit)


func _held_selection() -> void:
	_check(SeasonFinalVenue.capture(6, 1, "standard").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "doubleheader", "GRAND-I").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "standard", "LONG-YARD").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "standard", "unknown").is_empty(),
		"no old Standard inference or cross-pairing fallback")
	_check(not StadiumNpcSnapshot.supports("GRAND-I", 1)
		and StadiumNpcSnapshot.capture("GRAND-I", 1).is_empty()
		and not SeasonVenues.PUBLIC_LAYOUTS.has("GRAND-I")
		and not StadiumNpcPublicReport.supports_definition("GRAND-I", 1),
		"Grand excluded from ordinary entry snapshot18/report17 and venue quotas")
	var record: Dictionary = SeasonFinalVenue.capture_explicit(6, 1, "standard", "GRAND-I")
	_check(not record.is_empty() and ClubCareer.same(record, SeasonFinalVenue.capture_grand_i(6, 1)),
		"only separate explicit Grand qualification creates record2")
	if record.is_empty():
		return
	_check(record.version == 2 and record.league == "standard"
		and record.selection == "explicit-qualification" and record.fixture == 32
		and record.venue_owner == "finals-venue:grand-i:v1" and record.manifest.id == "GRAND-I"
		and record.manifest.revision == 1
		and record.manifest.environment_certificates.is_empty(),
		"planned pairing tag with neutral owner and no inherited night certificate")


func _save(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var parsed: Variant = JSON.parse_string(_json(saved))
	_check(typeof(saved.get("version")) == TYPE_INT and parsed is Dictionary
		and typeof(parsed.get("version")) == TYPE_FLOAT and parsed.version == 63,
		"save63 native integer and JSON float version representations")
	var native_restored: SeasonState = SeasonSave._decode(saved.duplicate(true))
	_check(native_restored != null and ClubCareer.same(saved, SeasonSave.snapshot(native_restored)),
		"save63 native dictionary roundtrip remains exact")
	var fractional: Dictionary = saved.duplicate(true)
	fractional.version = 63.5
	_check(SeasonSave._decode(fractional) == null, "save63 fractional version refuses")
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 63 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"Grand full-precision save63 roundtrip")
	if restored == null:
		return
	for edit: int in range(5):
		var changed: Dictionary = saved.duplicate(true)
		match edit:
			0: changed.version = 62
			1: changed.erase("final_venue")
			2: changed.final_venue.environment.seed += 1
			3: changed.final_venue.venue_owner = "npc-owner:1"
			4: changed.final_venue.environment.lighting.active_lights.emitters[0].head = "HEAD-99"
		_check(SeasonSave._decode(changed) == null, "save envelope/seed/owner/head corruption%d" % edit)


func _binding(season: SeasonState) -> void:
	var original: Dictionary = season.final_venue.duplicate(true)
	for home: bool in [false, true]:
		var fixture: Dictionary = FIXTURE.fixture(season, home)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		_check(not snapshot.is_empty(), "Grand binding available for both batting orders")
		if snapshot.is_empty():
			continue
		_check(snapshot.version == 21 and snapshot.authority == "neutral-final-grand-i-v1"
			and snapshot.binding.fixture == 32 and snapshot.binding.neutral
			and snapshot.binding.batting_home == fixture.home and snapshot.binding.away == fixture.away
			and snapshot.binding.venue_owner == "finals-venue:grand-i:v1"
			and not snapshot.binding.has("owner_club")
			and snapshot.binding.assignment_key == SeasonFinalVenue.key(original)
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
			"snapshot21 binds neutral venue owner separately from batting-home")
		_check(PhysicalStadiumReport.npc_resolver(snapshot) == StadiumGrandIPublicReport.RESOLVER
			and StadiumGrandIPublicReport.VERSION == 19 and PhysicalStadiumReport.GRAND_FINAL_VERSION == 19
			and StadiumGrandIPublicReport.supports_definition("GRAND-I", 1)
			and not StadiumLongYardPublicReport.supports_definition("GRAND-I", 1)
			and SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
			and StadiumFixtureEnvironment.label(season, fixture) == "19:10 • Clear",
			"new explicit report19 resolver/field/profile label")
		var human: Dictionary = {"version": 3, "fixture": 32, "property": snapshot}
		_check(StadiumNpcYardTwoHumanEvidence._envelope(human)
			and not StadiumNpcYardTwoHumanEvidence.valid(human),
			"human3 shape alone never fabricates completed evidence")
		human.version = 2
		_check(not StadiumNpcYardTwoHumanEvidence._envelope(human), "Grand cannot borrow human2")
		for edit: int in range(7):
			var changed: Dictionary = snapshot.duplicate(true)
			match edit:
				0: changed.version = 20
				1: changed.binding.venue_owner = SeasonFinalVenue.OWNER
				2: changed.binding.match_seed += 1
				3: changed.binding.league = "doubleheader"
				4: changed.binding.neutral = false
				5: changed.environment.time = "16:10"
				6: changed.environment.lighting.active_lights.emitters[0].direction[1] += 0.01
			_check(not StadiumNpcSnapshot.valid(changed)
				and PhysicalStadiumReport.npc_resolver(changed).is_empty(),
				"corrupt Grand snapshot%d" % edit)
		var fake: Dictionary = {"version": 19, "resolver": StadiumGrandIPublicReport.RESOLVER,
			"property": snapshot}
		_check(not PhysicalMatchReport.valid(fake) and not PhysicalStadiumReport.valid(fake)
			and not StadiumGrandIPublicReport.valid(fake), "binding is insufficient report19 baseball proof")
	_check(ClubCareer.same(original, season.final_venue),
		"participant binding never rerolls saved record")


func _legacy() -> void:
	var season: SeasonState = LONG_FIXTURE.season()
	_check(season != null, "legacy explicit Long Yard construction unchanged")
	if season == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	var parsed: Variant = JSON.parse_string(_json(saved))
	_check(typeof(saved.get("version")) == TYPE_INT and parsed is Dictionary
		and typeof(parsed.get("version")) == TYPE_FLOAT and parsed.version == 62,
		"save62 native integer and JSON float version representations")
	var native_restored: SeasonState = SeasonSave._decode(saved.duplicate(true))
	_check(native_restored != null and ClubCareer.same(saved, SeasonSave.snapshot(native_restored)),
		"save62 native dictionary roundtrip remains exact")
	var fractional: Dictionary = saved.duplicate(true)
	fractional.version = 62.5
	_check(SeasonSave._decode(fractional) == null, "save62 fractional version refuses")
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 62 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "Long Yard remains exact save62")
	var upgraded: Dictionary = saved.duplicate(true)
	upgraded.version = 63
	_check(SeasonSave._decode(upgraded) == null, "old final1 cannot borrow new save63")
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, LONG_FIXTURE.fixture(season, true))
	_check(snapshot.get("version") == 20 and snapshot.environment.profile == "LONG-YARD-1610-CLEAR-v1"
		and snapshot.binding.venue_owner == "finals-venue:long-yard:v2"
		and snapshot.binding.league == "doubleheader"
		and PhysicalStadiumReport.npc_resolver(snapshot) == StadiumLongYardPublicReport.RESOLVER
		and StadiumLongYardPublicReport.VERSION == 18, "old snapshot20/report18 retain exact dispatch")
	season.final_venue = {}
	var legacy: Dictionary = SeasonSave.snapshot(season)
	_check(legacy.get("version") == 61 and not legacy.has("final_venue"),
		"ordinary save61 still has no implicit final assignment")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GRAND_I_PUBLIC_DATA " + label)
