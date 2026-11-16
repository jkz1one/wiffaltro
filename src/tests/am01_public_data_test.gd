extends Node
## Bounded exact AM01/r1 data and schema checks; no game, result or settlement is generated.

const FIXTURE = preload("res://src/tests/am01_public_fixture.gd")
const EXPECTED_SHA: String = "91109581ee67835d39ac63527e66407b86824a68f6dab93e4778a5d53f9f6beb"
const COUNTS: Dictionary = {"ST-021": 2, "ST-022": 16, "ST-023": 16, "ST-026": 1,
	"ST-029": 2, "ST-038": 6, "ST-039": 1, "ST-065": 22, "ST-073": 1,
	"ST-074": 2, "ST-081": 3}
const LEGACY: Array = [
	["res://src/tests/fixtures/ay03_control_ay02_save61.json",
		"aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067", 1],
	["res://src/tests/fixtures/base_control_ay03_save61_v2.json",
		"86cbcd4827d265647b2f9eba6f58079d0347edb19d9658e80cb6fe345c96ae1d", 2]]
var _checks: int = 0
var _failures: int = 0
var _copies: int = 0
var _legacy_saves: int = 0


func _ready() -> void:
	_definition()
	_base_unchanged()
	for row: Array in LEGACY:
		_legacy_save(row)
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "real explicit ordinal2 assignment and actual draft")
	if season != null:
		_binding(season)
	_contacts()
	print("AM01_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	print("AM01_PUBLIC_DATA_COVERAGE copies=%d legacy_saves=%d completed_games=0" %
		[_copies, _legacy_saves])
	get_tree().quit(0 if _failures == 0 and _copies == 72 and _legacy_saves == 2 else 1)


func _definition() -> void:
	var definition: Dictionary = StadiumNpcVenues.definition("AM-01", 1)
	var entry: Dictionary = StadiumNpcSnapshot.capture("AM-01", 1)
	_check(not definition.is_empty() and not entry.is_empty(), "exact AM01/r1 public entry")
	if definition.is_empty() or entry.is_empty():
		return
	_check(_json(definition).sha256_text() == EXPECTED_SHA
		and ClubCareer.same(definition, StadiumNpcMogulOneCandidateV1.payload()),
		"public definition is the immutable existing 72-copy payload")
	_check(entry.version == 18 and entry.authority == "npc-authored-v1"
		and entry.manifest_key == EXPECTED_SHA and definition.id == "AM-01"
		and definition.revision == 1 and definition.field == "field.npc_venue"
		and definition.tier == "mogul" and definition.shape == "deeper_center"
		and definition.graph.id == "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1"
		and definition.live_units == 0, "exact public identity and zero live obstacle units")
	var copies: Dictionary = {}
	var ids: Dictionary = {}
	for row: Dictionary in definition.instances:
		_check(String(row.instance) == "npc:AM-01:r1:" + row.site
			and not ids.has(row.instance) and row.transform.size() == 12,
			"unique immutable r1 copy " + row.instance)
		ids[row.instance] = true
		copies[row.item] = int(copies.get(row.item, 0)) + 1
	_copies = ids.size()
	_check(_copies == 72 and ClubCareer.same(copies, COUNTS), "exact per-item copy totals")
	_check(StadiumNpcSnapshot.key(entry) == StadiumNpcSnapshot.key(JSON.parse_string(_json(entry)))
		and not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club())
		and StadiumLayoutSnapshot.ownership(entry) == null, "roundtrip has no human ownership")
	for pair: Array in [["AM-01", 2], ["AM-02", 1], ["AE-02", 1], ["AC-02", 1]]:
		_check(not StadiumNpcSnapshot.supports(pair[0], pair[1])
			and StadiumNpcSnapshot.capture(pair[0], pair[1]).is_empty(), "adjacent family stays held")
	var bad: Dictionary = entry.duplicate(true)
	bad.manifest.instances[0].instance = "npc:AC-01:r2:" + bad.manifest.instances[0].site
	bad.manifest_key = _json(bad.manifest).sha256_text()
	_check(not StadiumNpcSnapshot.valid(bad), "rehashed cross-venue copy cannot gain authority")
	bad = entry.duplicate(true)
	bad.manifest.instances[0].transform[9] += 0.01
	bad.manifest_key = _json(bad.manifest).sha256_text()
	_check(not StadiumNpcSnapshot.valid(bad), "rehashed moved copy cannot replace exact authored pose")


func _base_unchanged() -> void:
	var data: Dictionary = SeasonVenues.capture_five(10, 1, 0)
	_check(not data.is_empty(), "Base assignment still available")
	if data.is_empty():
		return
	var ids: Array = []
	for owner in range(1, 6):
		ids.append(data.assignments[str(owner)].manifest.id)
	_check(ids == ["AE-01", "AE-01", "AC-01", "AY-03", "AY-01"]
		and data.venue_ordinal == 0 and data.quota.mogul == 0,
		"Base seed10 exact host order and quota remain unchanged")


func _binding(season: SeasonState) -> void:
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty(), "genuine scheduled AM01 human-away fixture")
	if fixture.is_empty():
		return
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
	_check(not snapshot.is_empty() and snapshot.version == 19
		and snapshot.binding.assignment_version == 3
		and snapshot.binding.venue_id == "AM-01" and snapshot.binding.venue_revision == 1
		and snapshot.binding.owner_club == fixture.home
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
		and snapshot.binding.environment_seed == snapshot.environment.seed
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
		"fixture19 binds actual saved AM01 owner, match and independent day environment")
	_check(SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
		and StadiumNpcPublicReport.VERSION == 17
		and StadiumNpcPublicReport.RESOLVER == "physical-ai-npc-public-v1"
		and StadiumNpcPublicReport.supports_definition("AM-01", 1),
		"ordinary public sport field and unchanged report17 dispatch")
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.binding[key] += 1
		_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
			"changed saved fixture authority refuses " + key)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumNpcSnapshot.valid(bad), "dormant towers confer no night authority")
	bad = snapshot.duplicate(true)
	bad.binding.neutral = true
	_check(not StadiumNpcSnapshot.valid(bad), "neutral final cannot borrow ordinary AM01 fixture")
	bad = snapshot.duplicate(true)
	bad.manifest = StadiumNpcVenues.definition("AC-01", 2)
	bad.manifest_key = StadiumNpcVenues.key(bad.manifest)
	_check(not StadiumNpcSnapshot.valid(bad), "Club manifest cannot borrow AM01 binding")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.get("version") == 61 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"explicit test assignment roundtrips save61 without a schema change")


func _contacts() -> void:
	# One frozen construction reference, reused by schema-only probes. No match evidence is saved.
	var snapshot: Dictionary = StadiumNpcSnapshot.capture("AM-01", 1)
	var reference: Dictionary = StadiumNpcPublicContacts._reference(snapshot)
	_check(not reference.is_empty() and reference.graph == "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1",
		"contact reference uses the actual deeper-center family")
	if reference.is_empty():
		return
	var opening: Dictionary = {}
	for segment: Dictionary in reference.segments.values():
		if segment.role == "DUGOUT_OPENING_DEAD":
			var point: Vector2 = (segment.a + segment.b) / 2
			opening = {"source": "boundary", "id": reference.graph, "surface": segment.id,
				"role": segment.role, "position": [point.x, 0.5, point.y],
				"time": 0.1, "kind": "crossing"}
			break
	var rows: Array = [{"play": 0, "reason": "dugout_opening_dead", "events": [opening]}]
	var plays: Array = [{"contact": ContactResult.Outcome.CONTACT,
		"exit_speed": 20.0, "result": "single"}]
	_check(not opening.is_empty() and StadiumNpcPublicContacts._rows(rows, plays, reference),
		"schema-only exact AM01 dugout crossing accepts unchanged Club role")
	var pole: Dictionary = {}
	var receiver: Dictionary = {}
	for body: Dictionary in reference.bodies:
		if body.kind == "pole" and pole.is_empty():
			var point: Vector3 = body.shapes[0].inverse.affine_inverse().origin
			point.y = body.split + 0.25
			pole = {"source": "boundary", "id": reference.graph, "surface": body.segment,
				"role": "FOUL_POLE_UPPER", "position": [point.x, point.y, point.z],
				"time": 0.1, "kind": "contact"}
		elif body.role == "RECEIVER_CONTAINMENT_FOUL" and receiver.is_empty():
			var point: Vector3 = body.shapes[0].inverse.affine_inverse().origin
			receiver = {"source": "boundary", "id": reference.graph, "surface": body.segment,
				"role": body.role, "position": [point.x, point.y, point.z],
				"time": 0.1, "kind": "contact"}
	plays[0].result = "home_run"
	_check(not pole.is_empty() and StadiumNpcPublicContacts._rows(
		[{"play": 0, "reason": "foul_pole_upper", "events": [pole]}], plays, reference),
		"schema-only actual AM01 upper pole accepts unchanged terminal role")
	plays[0].result = "foul"
	_check(not receiver.is_empty() and StadiumNpcPublicContacts._rows(
		[{"play": 0, "reason": "stadium_receiver", "events": [receiver]}], plays, reference),
		"schema-only actual AM01 paired receiver accepts unchanged containment role")
	plays[0].result = "single"
	var wrong: Array = rows.duplicate(true)
	wrong[0].events[0].id = "PROTOTYPE-CLUB-DUGOUT-OFFSET-GABLES-v2"
	_check(not StadiumNpcPublicContacts._rows(wrong, plays, reference),
		"Club boundary cannot masquerade as AM01 report contact")
	wrong = rows.duplicate(true)
	wrong[0].events[0].position = [500.0, 500.0, 500.0]
	_check(not StadiumNpcPublicContacts._rows(wrong, plays, reference),
		"correct AM01 surface name cannot authorize remote contact")
	_check(not reference.provenance.is_empty(), "actual AM01 physical provenance surfaces exist")
	if reference.provenance.is_empty():
		return
	var copy: String = reference.provenance.keys()[0]
	var provenance: Array = [{"instance": copy, "surface": reference.provenance[copy][0],
		"preterminal": true, "elapsed": 0.1}]
	_check(copy.begins_with("npc:AM-01:r1:")
		and StadiumNpcPublicContacts._provenance(provenance, reference),
		"actual r1 copy identity accepts schema-only provenance")
	for prefix: String in ["npc:AC-01:r2:", "npc:AM-01:r2:"]:
		provenance[0].instance = copy.replace("npc:AM-01:r1:", prefix)
		_check(not StadiumNpcPublicContacts._provenance(provenance, reference),
			"foreign family or revision cannot supply AM01 provenance")
	var path: String = "res://src/tests/fixtures/ay03_control_ay02_report15.json"
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(FileAccess.get_sha256(path)
		== "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564"
		and PhysicalMatchReport.valid(old), "unchanged byte-pinned historical report15 accepts")
	# Refusal-only detached schema lift; never a completed AM01 game or persisted result.
	var season: SeasonState = FIXTURE.season()
	if season == null:
		_check(false, "AM01 binding needed for cross-venue report refusal")
		return
	old.version = 17
	old.resolver = StadiumNpcPublicReport.RESOLVER
	old.property = SeasonVenues.for_fixture(season, FIXTURE.fixture(season))
	old.seed = old.property.binding.match_seed
	_check(not PhysicalMatchReport.valid(old), "retained Yard report cannot claim an AM01 game")


func _legacy_save(row: Array) -> void:
	_check(FileAccess.get_sha256(row[0]) == row[1], "byte-pinned historical save61")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(row[0]))
	var season: SeasonState = SeasonSave._decode(value)
	_check(season != null, "existing completed save decodes")
	if season == null:
		return
	var valid: bool = value.version == 61 and season.npc_venues.version == row[2] \
		and ClubCareer.same(value, SeasonSave.snapshot(season))
	_check(valid, "historical assignment, reports, rewards and evidence remain exact")
	if valid:
		_legacy_saves += 1


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AM01_PUBLIC_DATA " + label)
