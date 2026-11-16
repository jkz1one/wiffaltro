extends Node
## Focused AY03 data contracts. Report mutation tests are schema tests, never new match evidence.

const SAVE: String = "res://src/tests/fixtures/ay03_control_ay02_save61.json"
const POOL_SAVE: String = "res://src/tests/fixtures/ay02_public_pool60_accepted.json"
const REPORT: String = "res://src/tests/fixtures/ay03_control_ay02_report15.json"
const SAVE_SHA: String = "aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067"
const REPORT_SHA: String = "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564"
const CHECKS_SHA: String = "7adda9013489a154db9debbf90403d5cb9ef8fee5443bfa179947772bb4b0582"
const PAYLOAD_SHA: String = "4ce7a2b451994bd64a0173c80bb30dc001f4229b6f6d1e5383b253012415e652"
const SURFACES: Dictionary = {
	"ST-080": ["SpectatorSeat", "SpectatorBack", "SpectatorLeg-1_-1", "SpectatorLeg-1_1",
		"SpectatorLeg1_-1", "SpectatorLeg1_1"],
	"ST-037": ["Footing", "BasePlate", "Pole", "Arm", "LampHousing"]}
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	var entry: Dictionary = StadiumNpcSnapshot.capture("AY-03", 1)
	_check(not entry.is_empty(), "public AY03/r1 exists")
	if entry.is_empty():
		_finish()
		return
	_payload(entry)
	_assignments()
	_retained_save()
	_pool_legacy_control()
	var season: SeasonState = _season()
	_legacy_saves(season)
	_home_final_routes(season)
	var expected: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if fixture.home in [3, 4]:
			var id: String = "AY-03" if fixture.home == 3 else "AY-02"
			_check(not snapshot.is_empty() and snapshot.version == 19
				and snapshot.manifest.id == id and snapshot.binding.venue_id == id
				and snapshot.binding.venue_revision == snapshot.manifest.revision
				and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
				and snapshot.environment.mode == "day", "saved fixture binds exact " + id)
			if id == "AY-03" and fixture.away == 0:
				expected = snapshot
		else:
			_check(snapshot.is_empty(), "other hosts have no authored away assignment")
	_check(not expected.is_empty(), "scheduled human-away AY03 fixture")
	if not expected.is_empty():
		_binding(expected)
		_provenance(expected)
		_reports(expected)
	_finish()


func _payload(entry: Dictionary) -> void:
	_check(entry.version == 18 and entry.manifest_key == PAYLOAD_SHA
		and _json(entry.manifest).sha256_text() == PAYLOAD_SHA
		and ClubCareer.same(entry.manifest, StadiumNpcYardThreeCandidateV1.definition()),
		"public18 preserves the exact immutable AY03/r1 payload")
	var chairs: int = 0
	var lights: int = 0
	for row: Dictionary in entry.manifest.instances:
		chairs += int(row.item == "ST-080")
		lights += int(row.item == "ST-037")
	_check(entry.manifest.instances.size() == 8 and chairs == 4 and lights == 4
		and entry.manifest.live_units == 0 and entry.manifest.environment_certificates.is_empty(),
		"four chairs and four dormant lights; no live units or night certificate")
	var record: Dictionary = StadiumNpcAvailability.record("AY-03", 1)
	_check(record.get("production_runtime", false) and record.get("selectable", false),
		"exact AY03 registry admission")
	_check(StadiumNpcSnapshot.capture("AY-03", 2).is_empty()
		and StadiumNpcSnapshot.capture("AY-01", 2).is_empty(), "no adjacent public promotion")
	var raw: Dictionary = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	_check(StadiumNpcSnapshot.raw_envelope_valid(raw) and not StadiumNpcSnapshot.valid(raw)
		and not StadiumNpcSnapshot.valid(entry.manifest)
		and StadiumNpcSnapshot.raw_entry("AY-03", 1).is_empty(),
		"raw and private payloads cannot become public snapshots")
	_check(not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club())
		and StadiumLayoutSnapshot.ownership(entry) == null, "public NPC grants no human stock")
	var changed: Dictionary = entry.duplicate(true)
	changed.manifest.instances[0].transform[9] += 1.0
	changed.manifest_key = _json(changed.manifest).sha256_text()
	_check(not StadiumNpcSnapshot.valid(changed), "rehashing changed geometry grants no authority")
	_check(StadiumNpcSnapshot.key(entry) == StadiumNpcSnapshot.key(JSON.parse_string(_json(entry))),
		"public18 exact JSON roundtrip")


func _assignments() -> void:
	for seed: int in [0, 1, 47, 443, 2147483647]:
		var owner: int = 1 + ("ay02-away-v1:" + str(seed)).sha256_text().left(8).hex_to_int() % 5
		var others: Array[int] = []
		for club in range(1, 6):
			if club != owner:
				others.append(club)
		var next: int = others[("ay03-away-v1:" + str(seed)).sha256_text().left(8).hex_to_int() % 4]
		var legacy: Dictionary = {"version": 1, "seed": seed, "career_run": 1,
			"assignments": {str(owner): StadiumNpcSnapshot.capture("AY-02", 1)}}
		_check(ClubCareer.same(legacy, SeasonVenues.normalized(legacy)),
			"assignment1 remains exactly one existing AY02 owner")
		var current: Dictionary = SeasonVenues.capture(seed, 1)
		_check(current.get("version") == 2 and current.get("assignments", {}).size() == 2
			and ClubCareer.same(current.assignments.get(str(owner), {}), legacy.assignments[str(owner)])
			and ClubCareer.same(current.assignments.get(str(next), {}),
				StadiumNpcSnapshot.capture("AY-03", 1)), "assignment2 independent ascending-other host")
		_check(ClubCareer.same(current, SeasonVenues.capture(seed, 1))
			and SeasonVenues.key(current) == SeasonVenues.key(JSON.parse_string(_json(current))),
			"assignment2 deterministic and exact JSON roundtrip")
		if seed == 443:
			_check(owner == 4 and next == 3, "seed443 retains AY02 owner4 and adds AY03 owner3")
		var bad: Dictionary = legacy.duplicate(true)
		bad.assignments[str(owner)] = StadiumNpcSnapshot.capture("AY-03", 1)
		_check(SeasonVenues.normalized(bad).is_empty(), "assignment1 cannot replace AY02 with AY03")
		bad = current.duplicate(true)
		bad.assignments[str(next)] = StadiumNpcSnapshot.capture("AY-02", 1)
		_check(SeasonVenues.normalized(bad).is_empty(), "assignment2 rejects duplicated venue")
		bad = current.duplicate(true)
		bad.assignments[str(owner)] = current.assignments[str(next)]
		bad.assignments[str(next)] = current.assignments[str(owner)]
		_check(SeasonVenues.normalized(bad).is_empty(), "assignment2 rejects swapped owners")
		bad = current.duplicate(true)
		bad.version = 1
		_check(SeasonVenues.normalized(bad).is_empty(), "assignment1 rejects a second owner")


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual working career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture(season.season_seed, season.career.current)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 61 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "new assignment2 save61 roundtrip")
	return season


func _pool_legacy_control() -> void:
	# Exact accepted six-game save; no new funding or gameplay history.
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOL_SAVE))
	_check(value is Dictionary and value.get("version") == 60, "frozen accepted Pool60 input")
	if not value is Dictionary:
		return
	var restored: SeasonState = SeasonSave._decode(value)
	_check(restored != null and restored.npc_venues.is_empty(),
		"accepted Pool60 stays unassigned after AY03 admission")
	if restored != null:
		_check(ClubCareer.same(value, SeasonSave.snapshot(restored)),
			"accepted Pool60 reports, human evidence and paid field remain exact")


func _legacy_saves(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	if saved.is_empty():
		return  # _season already records the invalid new-save assertion.
	var old: Dictionary = saved.duplicate(true)
	old.erase("npc_venues")
	old.version = 59
	var restored59: SeasonState = SeasonSave._decode(old)
	_check(restored59 != null and restored59.npc_venues.is_empty()
		and ClubCareer.same(old, SeasonSave.snapshot(restored59)), "save59 stays unassigned and exact")
	old.erase("home_property")
	old.version = 58
	var restored58: SeasonState = SeasonSave._decode(old)
	_check(restored58 != null and restored58.npc_venues.is_empty()
		and ClubCareer.same(old, SeasonSave.snapshot(restored58)), "save58 stays unassigned and exact")


func _home_final_routes(season: SeasonState) -> void:
	var before: PackedByteArray = var_to_bytes(SeasonSave.snapshot(season))
	var home: Dictionary = {}
	var commons: Dictionary = {}
	for fixture: Dictionary in season.schedule:
		if home.is_empty() and fixture.home == 0:
			home = fixture
		if commons.is_empty() and fixture.home not in [0, 3, 4]:
			commons = fixture
	var home_field: FieldDefinition = SeasonState.field_for_fixture(home, season)
	var away_field: FieldDefinition = SeasonState.field_for_fixture(commons, season)
	_check(not home.is_empty() and home_field != null and home_field.id == PitchBatLab.FIELD_ID,
		"human home field remains the actual owned home")
	_check(not commons.is_empty() and away_field != null
		and away_field.id == SeasonState.AWAY_FIELD_ID,
		"unassigned opponent remains Commons")
	# Schema-only scheduled final routing; no game or settlement is fabricated.
	var previous: Dictionary = season.final_fixture.duplicate(true)
	season.final_fixture = {"id": 32, "round": 11, "away": 0, "home": 3, "neutral": true}
	var final_field: FieldDefinition = SeasonState.field_for_fixture(season.final_fixture, season)
	_check(SeasonVenues.for_fixture(season, season.final_fixture).is_empty()
		and final_field != null and final_field.id == SeasonState.AWAY_FIELD_ID,
		"neutral final remains Commons even if AY03 owner bats last")
	season.final_fixture = previous
	_check(before == var_to_bytes(SeasonSave.snapshot(season)),
		"routing controls preserve saved assignment, home field and career")


func _retained_save() -> void:
	_check(FileAccess.get_sha256(SAVE) == SAVE_SHA, "byte-pinned actual historical save61")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	_check(value is Dictionary and value.get("version") == 61, "historical save61 input")
	if not value is Dictionary:
		return
	var restored: SeasonState = SeasonSave._decode(value)
	_check(restored != null, "actual assignment1 completed save still decodes")
	if restored == null:
		return
	_check(restored.npc_venues.version == 1 and restored.npc_venues.assignments.size() == 1
		and ClubCareer.same(value, SeasonSave.snapshot(restored)),
		"old61 keeps its assignment, reports, human evidence and rewards exact")
	var reread: SeasonState = SeasonSave._decode(
		JSON.parse_string(_json(SeasonSave.snapshot(restored))))
	_check(reread != null and ClubCareer.same(value, SeasonSave.snapshot(reread)),
		"old61 full-precision JSON roundtrip remains exact")
	_check(FileAccess.get_sha256("res://src/tests/stadium_npc_yard_two_public_checks.gd")
		== CHECKS_SHA, "joined R13 helper retains accepted full-precision correction")
	_check(StadiumNpcYardTwoPublicChecks.settled(restored, 0).is_empty(),
		"existing R13 settled-save helper refuses duplicate rewards and replay")


func _binding(snapshot: Dictionary) -> void:
	_check(StadiumNpcSnapshot.key(snapshot) == StadiumNpcSnapshot.key(
		JSON.parse_string(_json(snapshot))), "public19 exact JSON roundtrip")
	for id: String in ["AY-02", "AY-01"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.binding.venue_id = id
		_check(not StadiumNpcSnapshot.valid(bad), "binding must match manifest ID: " + id)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.binding.venue_revision = 2
	_check(not StadiumNpcSnapshot.valid(bad), "binding revision must match immutable r1")
	bad = snapshot.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumNpcSnapshot.valid(bad), "dormant lights do not qualify night")
	for version: int in [16, 17, 18]:
		bad = snapshot.duplicate(true)
		bad.version = version
		_check(not StadiumNpcSnapshot.valid(bad), "public fixture cannot use non19 envelope")


func _provenance(snapshot: Dictionary) -> void:
	_check(StadiumNpcYardThreeContacts._surfaces("ST-080") == SURFACES["ST-080"]
		and StadiumNpcYardThreeContacts._surfaces("ST-037") == SURFACES["ST-037"],
		"exact six chair and five light collision surface names")
	for item: Dictionary in snapshot.manifest.instances:
		for surface: String in SURFACES[item.item]:
			var rows: Array = [{"instance": item.instance, "surface": surface,
				"preterminal": true, "elapsed": 1.0}]
			_check(StadiumNpcYardThreeContacts.provenance(rows, snapshot),
				"physical provenance " + item.site + ":" + surface)
		for fake: String in ["BackRib0", "LampLens", "Glow", "CONE_BODY"]:
			_check(not StadiumNpcYardThreeContacts.provenance([{"instance": item.instance,
				"surface": fake, "preterminal": true, "elapsed": 1.0}], snapshot),
				"visual or foreign surface refused " + item.site + ":" + fake)
	var event: Dictionary = {"source": "item", "id": snapshot.manifest.instances[0].instance,
		"surface": "SpectatorSeat", "role": "LIVE_RICOCHET", "position": [0.0, 0.0, 0.0],
		"time": 1.0, "kind": "contact"}
	_check(not StadiumNpcYardThreeContacts.valid([{"play": 0, "reason": "", "events": [event]}],
		[{"contact": 1, "exit_speed": 20.0, "result": "single"}], snapshot),
		"decorative provenance cannot become a live item outcome")


func _reports(snapshot: Dictionary) -> void:
	_check(FileAccess.get_sha256(REPORT) == REPORT_SHA, "byte-pinned actual AY02 report15")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	_check(PhysicalMatchReport.valid(old) and StadiumNpcYardTwoReport.valid(old)
		and not StadiumNpcYardThreeReport.valid(old), "historical report15 stays exactly AY02")
	var boundary_only: bool = old.yard.is_empty()
	for row: Dictionary in old.surfaces:
		for event: Dictionary in row.events:
			boundary_only = boundary_only and event.source == "boundary"
	_check(boundary_only, "retained report has no AY02 item events or decorative provenance")
	if not boundary_only:
		return
	# This envelope exercises schema dispatch only. No game is run, recorded, or settled.
	var schema: Dictionary = old.duplicate(true)
	schema.version = 16
	schema.resolver = "physical-ai-ay03-away-v1"
	schema.property = snapshot.duplicate(true)
	schema.seed = snapshot.binding.match_seed
	_check(PhysicalMatchReport.valid(schema) and StadiumNpcYardThreeReport.matches(schema, snapshot)
		and not StadiumNpcYardTwoReport.valid(schema), "schema-only report16 routes exactly AY03")
	var wrong: Dictionary = schema.duplicate(true)
	wrong.property = old.property.duplicate(true)
	wrong.seed = old.seed
	_check(not PhysicalMatchReport.valid(wrong) and not StadiumNpcYardThreeReport.valid(wrong),
		"report16 cannot wrap valid AY02 property")
	wrong = schema.duplicate(true)
	wrong.version = 15
	wrong.resolver = "physical-ai-ay02-away-v1"
	_check(not PhysicalMatchReport.valid(wrong) and not StadiumNpcYardTwoReport.valid(wrong),
		"report15 cannot wrap valid AY03 property")
	wrong = schema.duplicate(true)
	wrong.property.binding.venue_id = "AY-02"
	_check(not PhysicalMatchReport.valid(wrong), "report16 rejects mismatched binding ID")
	wrong = schema.duplicate(true)
	wrong.seed += 1
	_check(not PhysicalMatchReport.valid(wrong), "report16 rejects wrong match seed")
	_check(PhysicalMatchReport.valid(StadiumNpcYardThreeReport.core(schema)),
		"report16 retains unchanged baseball-core validation")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AY03_PUBLIC_DATA " + label)


func _finish() -> void:
	print("AY03_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
