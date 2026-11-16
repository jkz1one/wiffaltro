extends Node
## Source-authored native test, not a claim of execution or a played final.
## Explicit Grand qualification remains separate from public Standard selection.

const FIXTURE = preload("res://src/tests/grand_iii_public_fixture.gd")
const GRAND_I_FIXTURE = preload("res://src/tests/grand_i_public_fixture.gd")
const GRAND_II_FIXTURE = preload("res://src/tests/grand_ii_public_fixture.gd")
const LONG_FIXTURE = preload("res://src/tests/long_yard_public_fixture.gd")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_fixture_routing()
	_profile()
	_definition()
	_held_selection()
	_legacy()
	_grand_i_unchanged()
	_grand_ii_unchanged()
	_strict_types()
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "Grand explicit record captured before four real draft choices")
	if season != null:
		_save(season)
		_binding(season)
	print("GRAND_III_PUBLIC_DATA checks=%d failures=%d completed_games=0" % [_checks, _failures])
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
	_check(StadiumGrandIIIEnvironmentV1.capture(-1).is_empty()
		and StadiumGrandIIIEnvironmentV1.capture(2147483648).is_empty(), "environment seed bounds")
	for seed: int in [0, 6, 2147483647]:
		var environment: Dictionary = StadiumGrandIIIEnvironmentV1.capture(seed)
		var decoded: Variant = JSON.parse_string(_json(environment))
		_check(StadiumGrandIIIEnvironmentV1.valid(decoded) and ClubCareer.same(environment, decoded),
			"full-precision seeded artistic environment JSON roundtrip")
		_check(environment.version == 5 and environment.seed == seed and environment.fixture == 32
			and environment.mode == "night" and environment.profile == "GRAND-III-1910-CLEAR-v1"
			and environment.time == "19:10" and environment.weather == "clear"
			and environment.render_profile == 2, "exact artistic slot independent of sunset or RNG")
		_check(not StadiumGrandIEnvironmentV1.valid(environment)
			and not StadiumGrandIIIEnvironmentV1.valid(StadiumGrandIEnvironmentV1.capture(seed)),
			"Grand I and III environment validity never cross-admit artistic profiles")
		var lights: Dictionary = environment.lighting.active_lights
		_check(lights.version == 1 and lights.visible_heads == 32 and lights.dynamic_emitters == 4
			and lights.shadow_casters == 4 and lights.emitters.size() == 4
			and lights.glow.count == 32 and environment.lighting.ambient_energy == 0.65
			and lights.profile == "GRAND-III-FOUR-PREMIUM-TOWER-LIGHTING-v1"
			and lights.qualification == "grand-iii-nine-canopy-video-waterfall-native-readability-pending",
			"four premium emitters preserve 32 heads and four-slot initial shadow budget")
		var shadows: int = 0
		for row: Dictionary in lights.emitters:
			shadows += 1 if row.shadows else 0
			_check(row.represented_heads == 8 and row.energy == 4.5 and row.range == 90.0
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
			_check(not StadiumGrandIIIEnvironmentV1.valid(changed), "corrupt artistic profile%d" % edit)


func _definition() -> void:
	var value: Dictionary = StadiumGrandIIIDefinitionV1.canonical()
	_check(not value.is_empty(), "III authored manifest normalizes")
	if value.is_empty():
		return
	_check(value.instances.size() == 107 and value.models.size() == 52,
		"III exact107-copy authored inventory and frozen52 model sources")
	_check(value.environment_certificates.is_empty() and value.shape == "straight"
		and value.field == StadiumNpcSnapshot.FIELD and value.revision == 1
		and value.assembly.id == "GRAND-III-public-straight-v1",
		"Grand III distinct public r1 straight family carries no night approval")
	var counts: Dictionary = {}
	for row: Dictionary in value.instances:
		_check(row.instance.begins_with("npc:GRAND-III:r1:"), "every issued identity names Grand III")
		counts[row.item] = counts.get(row.item, 0) + 1
	_check(counts.get("ST-076", 0) == 4 and counts.get("ST-038", 0) == 0,
		"III four premium towers replace six large towers")
	_check(counts.get("ST-040", 0) == 1 and counts.get("ST-046", 0) == 1
		and counts.get("ST-039", 0) == 0, "one video board and waterfall; no manual board")
	var layout: Dictionary = StadiumGrandIIIDefinitionV1.source_layout()
	_check(layout.layout_revision.status == "Working-owner-acceptance-pending"
		and layout.owner_acceptance_required and layout.progression_held
		and layout.board.site == "BOARD-LARGE-v2" and layout.board.art_version == 2
		and layout.structural_layers.roofs == 9
		and layout.structural_layers.transition_concourses == 2 and layout.crowd.total == 560,
		"owner acceptance, board placement review and held progression remain explicit")
	var changed: Dictionary = value.duplicate(true)
	changed.id = "GRAND-II"
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"frozen52 model allowance cannot widen Grand II32 cap")
	changed = value.duplicate(true)
	changed.revision = 2
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"frozen52 model allowance cannot migrate revision2")
	changed = value.duplicate(true)
	changed.assembly.id = "GRAND-II-public-straight-v1"
	_check(StadiumNpcManifest.canonical_shape(changed).is_empty(),
		"frozen52 model allowance requires exact III assembly")


func _held_selection() -> void:
	_check(SeasonFinalVenue.capture(6, 1, "standard").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "doubleheader", "GRAND-III").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "standard", "LONG-YARD").is_empty()
		and SeasonFinalVenue.capture_explicit(6, 1, "standard", "unknown").is_empty(),
		"no old Standard inference or cross-pairing fallback")
	_check(not StadiumNpcSnapshot.supports("GRAND-III", 1)
		and StadiumNpcSnapshot.capture("GRAND-III", 1).is_empty()
		and not SeasonVenues.PUBLIC_LAYOUTS.has("GRAND-III")
		and not StadiumNpcPublicReport.supports_definition("GRAND-III", 1),
		"Grand excluded from ordinary entry snapshot18/report17 and venue quotas")
	var record: Dictionary = SeasonFinalVenue.capture_explicit(6, 1, "standard", "GRAND-III")
	_check(not record.is_empty() and ClubCareer.same(record, SeasonFinalVenue.capture_grand_iii(6, 1)),
		"only separate explicit Grand qualification creates record4")
	if record.is_empty():
		return
	_check(record.version == 4 and record.league == "standard"
		and record.selection == "explicit-qualification" and record.fixture == 32
		and record.venue_owner == "finals-venue:grand-iii:v1" and record.manifest.id == "GRAND-III"
		and record.manifest.revision == 1
		and record.manifest.environment_certificates.is_empty(),
		"planned pairing tag with neutral owner and no inherited night certificate")


func _save(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var parsed: Variant = JSON.parse_string(_json(saved))
	_check(typeof(saved.get("version")) == TYPE_INT and parsed is Dictionary
		and typeof(parsed.get("version")) == TYPE_FLOAT and parsed.version == 65,
		"save65 native integer and JSON float version representations")
	var native_restored: SeasonState = SeasonSave._decode(saved.duplicate(true))
	_check(native_restored != null and ClubCareer.same(saved, SeasonSave.snapshot(native_restored)),
		"save65 native dictionary roundtrip remains exact")
	var fractional: Dictionary = saved.duplicate(true)
	fractional.version = 65.5
	_check(SeasonSave._decode(fractional) == null, "save65 fractional version refuses")
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 65 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"Grand full-precision save65 roundtrip")
	if restored == null:
		return
	for wrong: Variant in [true, "65", null, [], {}]:
		var changed: Dictionary = saved.duplicate(true)
		changed.version = wrong
		_check(SeasonSave._decode(changed) == null, "save65 raw version type rejects")
	for edit: int in range(7):
		var changed: Dictionary = saved.duplicate(true)
		match edit:
			0: changed.version = 62
			1: changed.erase("final_venue")
			2: changed.final_venue.environment.seed += 1
			3: changed.final_venue.venue_owner = "npc-owner:1"
			4: changed.final_venue.environment.lighting.active_lights.emitters[0].head = "HEAD-99"
			5: changed.version = 63
			6: changed.version = 64
		_check(SeasonSave._decode(changed) == null, "save envelope/seed/owner/head corruption%d" % edit)


func _binding(season: SeasonState) -> void:
	var original: Dictionary = season.final_venue.duplicate(true)
	for home: bool in [false, true]:
		var fixture: Dictionary = FIXTURE.fixture(season, home)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		_check(not snapshot.is_empty(), "Grand binding available for both batting orders")
		if snapshot.is_empty():
			continue
		_check(snapshot.version == 23 and snapshot.authority == "neutral-final-grand-iii-v1"
			and snapshot.binding.fixture == 32 and snapshot.binding.neutral
			and snapshot.binding.batting_home == fixture.home and snapshot.binding.away == fixture.away
			and snapshot.binding.venue_owner == "finals-venue:grand-iii:v1"
			and not snapshot.binding.has("owner_club")
			and snapshot.binding.assignment_key == SeasonFinalVenue.key(original)
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
			"snapshot23 binds neutral venue owner separately from batting-home")
		_check(PhysicalStadiumReport.npc_resolver(snapshot) == StadiumGrandIIIPublicReport.RESOLVER
			and StadiumGrandIIIPublicReport.VERSION == 21
			and PhysicalStadiumReport.GRAND_III_FINAL_VERSION == 21
			and StadiumGrandIIIPublicReport.supports_definition("GRAND-III", 1)
			and not StadiumLongYardPublicReport.supports_definition("GRAND-III", 1)
			and SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
			and StadiumFixtureEnvironment.label(season, fixture) == "19:10 • Clear",
			"new explicit report21 resolver/field/profile label")
		var human: Dictionary = {"version": 5, "fixture": 32, "property": snapshot}
		_check(StadiumNpcYardTwoHumanEvidence._envelope(human)
			and not StadiumNpcYardTwoHumanEvidence.valid(human),
			"human5 shape alone never fabricates completed evidence")
		human.version = 4
		_check(not StadiumNpcYardTwoHumanEvidence._envelope(human), "Grand cannot borrow human4")
		for edit: int in range(11):
			var changed: Dictionary = snapshot.duplicate(true)
			match edit:
				0: changed.version = 20
				1: changed.binding.venue_owner = SeasonFinalVenue.OWNER
				2: changed.binding.match_seed += 1
				3: changed.binding.league = "doubleheader"
				4: changed.binding.neutral = false
				5: changed.environment.time = "16:10"
				6: changed.environment.lighting.active_lights.emitters[0].direction[1] += 0.01
				7: changed.version = 21
				8: changed.binding.venue_id = "GRAND-I"
				9: changed.version = 22
				10: changed.binding.venue_id = "GRAND-II"
			_check(not StadiumNpcSnapshot.valid(changed)
				and PhysicalStadiumReport.npc_resolver(changed).is_empty(),
				"corrupt Grand snapshot%d" % edit)
		for field: String in ["league", "selection", "venue_owner", "venue_id", "field"]:
			for wrong: Variant in [true, 23, null, [], {}, &"GRAND-III"]:
				var changed: Dictionary = snapshot.duplicate(true)
				changed.binding[field] = wrong
				_check(not StadiumNpcSnapshot.valid(changed),
					"snapshot binding string guards precede equality: " + field)
		for field: String in ["season_seed", "career_run", "venue_revision", "fixture",
			"away", "batting_home", "match_seed"]:
			for wrong: Variant in [true, "23", 23.5, null, [], {}]:
				var changed: Dictionary = snapshot.duplicate(true)
				changed.binding[field] = wrong
				_check(not StadiumNpcSnapshot.valid(changed),
					"snapshot binding raw integral type refuses: " + field)
		var fake: Dictionary = {"version": 21, "resolver": StadiumGrandIIIPublicReport.RESOLVER,
			"property": snapshot}
		_check(not PhysicalMatchReport.valid(fake) and not PhysicalStadiumReport.valid(fake)
			and not StadiumGrandIIIPublicReport.valid(fake),
			"binding is insufficient report21 baseball proof")
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


func _grand_i_unchanged() -> void:
	var season: SeasonState = GRAND_I_FIXTURE.season()
	_check(season != null, "Grand I fixture remains available")
	if season == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 63 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "Grand I stays exact save63")
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, GRAND_I_FIXTURE.fixture(season))
	_check(snapshot.get("version") == 21 and snapshot.manifest.id == "GRAND-I"
		and snapshot.environment.profile == "GRAND-I-1910-CLEAR-v1"
		and PhysicalStadiumReport.npc_resolver(snapshot) == StadiumGrandIPublicReport.RESOLVER,
		"Grand I snapshot21/report19/profile dispatch unchanged")
	var relabelled: Dictionary = saved.duplicate(true)
	relabelled.version = 65
	_check(SeasonSave._decode(relabelled) == null, "Grand I record2 cannot borrow III save65")
	_check(not StadiumGrandIIIPublicReport.supports_definition("GRAND-I", 1)
		and not StadiumGrandIPublicReport.supports_definition("GRAND-III", 1),
		"Grand I and III reports never cross-admit venue identities")


func _grand_ii_unchanged() -> void:
	var season: SeasonState = GRAND_II_FIXTURE.season()
	_check(season != null, "Grand II fixture remains available")
	if season == null:
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 64 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "Grand II stays exact save64")
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, GRAND_II_FIXTURE.fixture(season))
	_check(snapshot.get("version") == 22 and snapshot.manifest.id == "GRAND-II"
		and snapshot.environment.profile == "GRAND-II-1910-CLEAR-v1"
		and PhysicalStadiumReport.npc_resolver(snapshot) == StadiumGrandIIPublicReport.RESOLVER,
		"Grand II snapshot22/report20/profile dispatch unchanged")
	var relabelled: Dictionary = saved.duplicate(true)
	relabelled.version = 65
	_check(SeasonSave._decode(relabelled) == null, "Grand II record3 cannot borrow III save65")
	_check(not StadiumGrandIIIPublicReport.supports_definition("GRAND-II", 1)
		and not StadiumGrandIIPublicReport.supports_definition("GRAND-III", 1),
		"Grand II and III reports never cross-admit venue identities")


func _strict_types() -> void:
	var record: Dictionary = SeasonFinalVenue.capture_grand_iii(6, 1)
	_check(not record.is_empty(), "strict-type test record4 exists")
	if record.is_empty():
		return
	for field: String in ["version", "seed", "career_run", "fixture"]:
		for wrong: Variant in [true, "4", 4.5, null, [], {}]:
			var changed: Dictionary = record.duplicate(true)
			changed[field] = wrong
			_check(SeasonFinalVenue.normalized(changed).is_empty(),
				"record numeric type/range mutation refuses before conversion: " + field)
	for field: String in ["league", "selection", "venue_owner"]:
		for wrong: Variant in [true, 4, null, [], {}, &"standard"]:
			var changed: Dictionary = record.duplicate(true)
			changed[field] = wrong
			_check(SeasonFinalVenue.normalized(changed).is_empty(),
				"record string guard refuses before equality: " + field)
	var environment: Dictionary = record.environment
	for field: String in ["version", "seed", "fixture", "render_profile"]:
		for wrong: Variant in [true, "5", 5.5, null, [], {}]:
			var changed: Dictionary = environment.duplicate(true)
			changed[field] = wrong
			_check(not StadiumGrandIIIEnvironmentV1.valid(changed),
				"environment raw numeric type/range mutation: " + field)
	for wrong: Variant in [true, "4.5", null, [], {}]:
		var changed: Dictionary = environment.duplicate(true)
		changed.lighting.active_lights.emitters[0].energy = wrong
		_check(not StadiumGrandIIIEnvironmentV1.valid(changed), "emitter numeric type rejected")
	for other: Dictionary in [StadiumGrandIEnvironmentV1.capture(environment.seed),
		StadiumGrandIIEnvironmentV1.capture(environment.seed)]:
		_check(not StadiumGrandIIIEnvironmentV1.valid(other)
			and not StadiumGrandIEnvironmentV1.valid(environment)
			and not StadiumGrandIIEnvironmentV1.valid(environment),
			"I II III environment types and authorities are disjoint")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("GRAND_III_PUBLIC_DATA " + label)
