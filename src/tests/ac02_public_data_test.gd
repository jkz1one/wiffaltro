extends Node
## Bounded immutable AC02/r1, old saved-map and report17 schema checks. No game is generated.

const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
const PREFIX: String = "npc:AC-02:r1:"
const EXPECTED_SHA: String = "81bf357269937420a99b7711ea4e96e0ead70982f20c6d963be710693ed95ceb"
const COUNTS: Dictionary = {"ST-065": 19, "ST-065-L": 7, "ST-022": 16, "ST-023": 16,
	"ST-074": 2, "ST-021": 2, "ST-026": 1, "ST-073": 1,
	"ST-029": 4, "ST-053": 2, "ST-039": 1, "ST-038": 4}
const LEGACY: Array = [
	["res://src/tests/fixtures/ay03_control_ay02_save61.json",
		"aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067", 1],
	["res://src/tests/fixtures/base_control_ay03_save61_v2.json",
		"86cbcd4827d265647b2f9eba6f58079d0347edb19d9658e80cb6fe345c96ae1d", 2],
	["res://src/tests/fixtures/base-public-completed-pending.json",
		"688611ea88162690c6da224ba2f7fbfc01f7b3c69fc0b3adb4104536fd3ee9b4", 3],
	["res://src/tests/fixtures/am02_managed_seed36_save61.json",
		"63eba7bb3f880c02dbff1110b07a3c3124793ec3c78ec4a59f079c29741cd427", 3]]
var _checks: int = 0
var _failures: int = 0
var _copies: int = 0
var _legacy_saves: int = 0


func _ready() -> void:
	_definition()
	for row: Array in LEGACY:
		_legacy_save(row)
	_check(FIXTURE.ready(), "exact joined allocator seed/map pins have been supplied")
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "actual source-pinned AC02 saved fixture exists")
	if season != null:
		_binding(season)
	_contacts()
	print("AC02_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	print("AC02_PUBLIC_DATA_COVERAGE copies=%d legacy_saves=%d completed_games=0" %
		[_copies, _legacy_saves])
	get_tree().quit(0 if _failures == 0 and _copies == 75 and _legacy_saves == LEGACY.size() else 1)


func _definition() -> void:
	var definition: Dictionary = StadiumNpcVenues.definition("AC-02", 1)
	var entry: Dictionary = StadiumNpcSnapshot.capture("AC-02", 1)
	_check(not definition.is_empty() and not entry.is_empty(), "exact public AC02/r1 registry entry")
	if definition.is_empty() or entry.is_empty():
		return
	_check(_json(definition).sha256_text() == EXPECTED_SHA
		and StadiumNpcClubTwoDefinitionV1.SHA256 == EXPECTED_SHA
		and ClubCareer.same(definition, StadiumNpcClubTwoDefinitionV1.payload()),
		"immutable full-precision literal public definition")
	_check(entry.version == 18 and entry.authority == "npc-authored-v1"
		and entry.manifest_key == EXPECTED_SHA
		and definition.id == "AC-02" and definition.revision == 1
		and definition.field == "field.npc_venue" and definition.tier == "club"
		and definition.shape == "right_shelf" and definition.live_units == 0
		and definition.blueprints.size() == 12,
		"75-copy existing-asset RightShelf with no obstacle units")
	var counts: Dictionary = {}
	var identities: Dictionary = {}
	for row: Dictionary in definition.instances:
		_check(row.instance == PREFIX + row.site and not identities.has(row.instance)
			and row.transform.size() == 12, "unique complete authored copy " + row.instance)
		identities[row.instance] = row
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	_copies = identities.size()
	_check(_copies == 75 and ClubCareer.same(counts, COUNTS), "exact twelve item copy totals")
	var board: Dictionary = identities.get(PREFIX + "SCORE-SMALL", {})
	_check(not board.is_empty() and board.item == "ST-039"
		and ClubCareer.same(board.transform.slice(9), [-20.0, 0.0, 30.0]),
		"original SCORE-SMALL world position remains distinct from AC01")
	for side: Array in [["CLIGHT-HL", -30.0, -16.0], ["CLIGHT-HR", 30.0, -16.0],
		["CLIGHT-OL", -32.0, 38.0], ["CLIGHT-OR", 32.0, 38.0]]:
		var tower: Dictionary = identities.get(PREFIX + side[0], {})
		_check(not tower.is_empty() and tower.item == "ST-038"
			and ClubCareer.same(tower.transform.slice(9), [side[1], 0.0, side[2]]),
			"exact dormant four-head tower pose " + side[0])
	_check(StadiumNpcSnapshot.key(entry) == StadiumNpcSnapshot.key(JSON.parse_string(_json(entry)))
		and not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club())
		and StadiumLayoutSnapshot.ownership(entry) == null, "snapshot18 gives no human ownership")
	for pair: Array in [["AC-02", 2], ["AC-03", 1], ["AM-03", 1]]:
		_check(not StadiumNpcSnapshot.supports(pair[0], pair[1])
			and StadiumNpcSnapshot.capture(pair[0], pair[1]).is_empty(), "unissued revision stays closed")
	for prefix: String in ["npc:AC-01:r2:", "npc:AM-02:r1:",
		"npc-candidate:AC-02:right-shelf-v1:"]:
		var bad: Dictionary = entry.duplicate(true)
		bad.manifest.instances[0].instance = prefix + bad.manifest.instances[0].site
		bad.manifest_key = _json(bad.manifest).sha256_text()
		_check(not StadiumNpcSnapshot.valid(bad), "rehashed foreign/private copy identity refuses")
	var bad: Dictionary = entry.duplicate(true)
	bad.manifest.instances[0].transform[9] += 0.01
	bad.manifest_key = _json(bad.manifest).sha256_text()
	_check(not StadiumNpcSnapshot.valid(bad)
		and ClubCareer.same(StadiumNpcVenues.definition("AC-02", 1), definition),
		"moved caller copy cannot gain authority or mutate frozen definition")


func _binding(season: SeasonState) -> void:
	var ids: Array = []
	for owner in range(1, 6):
		ids.append(season.npc_venues.assignments[str(owner)].manifest.id)
	_check(season.season_seed == FIXTURE.SEED
		and season.npc_venues.venue_ordinal == FIXTURE.ORDINAL
		and ClubCareer.same(season.npc_venues.streams, FIXTURE.STREAMS)
		and ids == FIXTURE.HOSTS, "exact source-derived allocator map and independent streams")
	_check(ClubCareer.same(season.npc_venues.quota,
		{"backyard": 2, "expanded": 2, "club": 1, "mogul": 0}),
		"unchanged Base quota has exactly five saved host owners")
	for index in range(32):
		_check(season.npc_venues.environments[str(index)].seed == FIXTURE.ENVIRONMENT_SEEDS[index],
			"independent day environment golden " + str(index))
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty() and fixture.id == 0 and fixture.home == 5 and fixture.away == 0,
		"natural opening AC02 human-away fixture0 owner5")
	if fixture.is_empty():
		return
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
	_check(snapshot.version == 19 and snapshot.binding.assignment_version == 3
		and snapshot.binding.venue_id == "AC-02" and snapshot.binding.venue_revision == 1
		and snapshot.binding.owner_club == fixture.home
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
		and snapshot.binding.environment_seed == snapshot.environment.seed
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
		"fixture19 binds actual saved owner, match seed and independent daylight")
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, season)
	_check(field.id == &"field.npc_venue" and typeof(field.id) == TYPE_STRING_NAME
		and StadiumNpcPublicReport.VERSION == 17
		and StadiumNpcPublicReport.RESOLVER == "physical-ai-npc-public-v1"
		and StadiumNpcPublicReport.supports_definition("AC-02", 1),
		"public NPC StringName selector and unchanged report17 envelope")
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.binding[key] += 1
		_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
			"changed saved binding refuses " + key)
	for marker: String in ["night", "rain"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.environment.mode = marker
		_check(not StadiumNpcSnapshot.valid(bad), "dormant towers confer no weather/night authority")
	var bad: Dictionary = snapshot.duplicate(true)
	bad.binding.neutral = true
	_check(not StadiumNpcSnapshot.valid(bad), "neutral final cannot borrow AC02 fixture")
	bad = snapshot.duplicate(true)
	bad.manifest = StadiumNpcVenues.definition("AC-01", 2)
	bad.manifest_key = StadiumNpcVenues.key(bad.manifest)
	_check(not StadiumNpcSnapshot.valid(bad), "AC01 manifest cannot borrow AC02 fixture binding")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.version == 61 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"actual AC02 assignment roundtrips full-precision save61 unchanged")


func _contacts() -> void:
	# One frozen construction reference, reused by schema-only probes. No match evidence is saved.
	var snapshot: Dictionary = StadiumNpcSnapshot.capture("AC-02", 1)
	var reference: Dictionary = StadiumNpcPublicContacts._reference(snapshot)
	_check(not reference.is_empty() and reference.graph == "PROTOTYPE-CLUB-DUGOUT-RIGHT-SHELF-v1",
		"contact reference uses the actual right-shelf family")
	if reference.is_empty():
		return
	_graph_contract(reference)
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
		"schema-only exact AC02 dugout crossing accepts unchanged Club role")
	for segment: Dictionary in reference.segments.values():
		if segment.role != "DUGOUT_FACE_LIVE":
			continue
		var center: Vector2 = (segment.a + segment.b) / 2
		var live: Dictionary = {"source": "boundary", "id": reference.graph,
			"surface": segment.id, "role": segment.role, "position": [center.x, 0.5, center.y],
			"time": 0.05, "kind": "crossing"}
		var ordered: Array = [{"play": 0, "reason": "dugout_opening_dead", "events": [live, opening]}]
		_check(StadiumNpcPublicContacts._rows(ordered, plays, reference),
			"schema-only live dugout event precedes terminal opening")
		ordered[0].events = [opening, live]
		_check(not StadiumNpcPublicContacts._rows(ordered, plays, reference),
			"live event after terminal cannot gain report17 credit")
		break
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
		"schema-only actual AC02 upper pole accepts unchanged terminal role")
	plays[0].result = "foul"
	_check(not receiver.is_empty() and StadiumNpcPublicContacts._rows(
		[{"play": 0, "reason": "stadium_receiver", "events": [receiver]}], plays, reference),
		"schema-only actual AC02 paired receiver accepts unchanged containment role")
	var item: Dictionary = receiver.duplicate(true)
	item.source = "item"
	item.id = "npc:AC-02:r1:RECEIVER-PRIMARY"
	_check(not StadiumNpcPublicContacts._event(item, reference),
		"AC02 receiver stays a Club boundary event, never an Expanded item event")
	plays[0].result = "single"
	var wrong: Array = rows.duplicate(true)
	wrong[0].events[0].id = "PROTOTYPE-CLUB-DUGOUT-LEFT-LOFT-v1"
	_check(not StadiumNpcPublicContacts._rows(wrong, plays, reference),
		"AM02 boundary cannot masquerade as AC02 report contact")
	wrong = rows.duplicate(true)
	wrong[0].events[0].position = [500.0, 500.0, 500.0]
	_check(not StadiumNpcPublicContacts._rows(wrong, plays, reference),
		"correct AC02 surface name cannot authorize remote contact")
	_check(not reference.provenance.is_empty(), "actual AC02 physical provenance surfaces exist")
	if reference.provenance.is_empty():
		return
	var copy: String = reference.provenance.keys()[0]
	var provenance: Array = [{"instance": copy, "surface": reference.provenance[copy][0],
		"preterminal": true, "elapsed": 0.1}]
	_check(copy.begins_with("npc:AC-02:r1:")
		and StadiumNpcPublicContacts._provenance(provenance, reference),
		"actual r1 copy identity accepts schema-only provenance")
	for prefix: String in ["npc:AC-01:r2:", "npc:AM-02:r1:", "npc:AE-02:r1:", "npc:AC-02:r2:",
		"npc-candidate:AC-02:right-shelf-v1:"]:
		provenance[0].instance = copy.replace("npc:AC-02:r1:", prefix)
		_check(not StadiumNpcPublicContacts._provenance(provenance, reference),
			"foreign family or revision cannot supply AC02 provenance")
	var path: String = "res://src/tests/fixtures/ay03_control_ay02_report15.json"
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(FileAccess.get_sha256(path)
		== "20bbc936bbb2a60775cfd0bc73233f746b6648e8b7b5b2a5667c1f7873377564"
		and PhysicalMatchReport.valid(old), "unchanged byte-pinned historical report15 accepts")
	# Refusal-only detached schema lift; never a completed AC02 game or persisted result.
	var season: SeasonState = FIXTURE.season()
	if season == null:
		_check(false, "AC02 binding needed for cross-venue report refusal")
		return
	old.version = 17
	old.resolver = StadiumNpcPublicReport.RESOLVER
	old.property = SeasonVenues.for_fixture(season, FIXTURE.fixture(season))
	old.seed = old.property.binding.match_seed
	_check(not PhysicalMatchReport.valid(old), "retained Yard report cannot claim an AC02 game")


func _graph_contract(reference: Dictionary) -> void:
	var graph: StadiumNpcAc02PublicGraph = StadiumNpcAc02PublicGraph.new()
	_check(reference.segments.size() == 18 and graph.identity() == reference.graph,
		"complete distinct eighteen-edge RightShelf boundary")
	for row: Dictionary in graph.segments():
		var actual: Dictionary = reference.segments.get(row.id, {})
		_check(not actual.is_empty() and actual.a == row.a and actual.b == row.b
			and actual.height == row.height and actual.role == row.role and actual.priority == row.priority,
			"exact original graph segment " + row.id)
	for side: Array in [["BACK-01", 1.625, "BACK_CLEAR"], ["BACK-02", 1.625, "BACK_CLEAR"],
		["BACK-03", 3.25, "BACK_WALL_TERMINAL"], ["BACK-04", 3.25, "BACK_WALL_TERMINAL"],
		["BACK-05", 3.25, "BACK_WALL_TERMINAL"]]:
		var row: Dictionary = reference.segments[side[0]]
		var center: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumRecipeBoundary.inward(row)
		var event: Dictionary = graph.crossing(
			Vector3(center.x + inward.x, 2, center.y + inward.y),
			Vector3(center.x - inward.x, 2, center.y - inward.y))
		_check(row.height == side[1] and event.get("role") == side[2],
			"two-meter crossing distinguishes actual low and standard back " + side[0])
	_check(reference.segments["BACK-02"].b == Vector2(10, 21)
		and reference.segments["BACK-03"].a == Vector2(10, 21),
		"real low-to-standard junction stays at10,21")
	var splits: Dictionary = {}
	for body: Dictionary in reference.bodies:
		if body.kind == "pole":
			splits[body.segment] = body.split
	_check(ClubCareer.same(splits, {"FOUL-POLE-L": 3.25, "FOUL-POLE-R": 1.625}),
		"left and right foul poles retain actual asymmetric wall cap")


func _legacy_save(row: Array) -> void:
	_check(FileAccess.get_sha256(row[0]) == row[1], "byte-pinned prior saved assignment")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row[0]))
	var restored: SeasonState = SeasonSave._decode(saved)
	_check(restored != null, "old completed or pending save still decodes")
	if restored == null:
		return
	var actual: Dictionary = SeasonSave.snapshot(restored)
	var valid: bool = saved.version == 61 and restored.npc_venues.version == row[2] \
		and ClubCareer.same(saved, actual)
	_check(valid, "old full saved map, results and pending/report evidence remain exact")
	if int(row[2]) == 3:
		_check(ClubCareer.same(saved.npc_venues, actual.npc_venues)
			and StadiumNpcSnapshot.valid(saved.npc_venues.assignments["1"]),
			"current expanded pool never rerolls an older saved Base or Mogul map")
		for report: Dictionary in restored.physical.reports:
			_check(report.report.version == 17 and PhysicalMatchReport.valid(report.report),
				"genuine old report17 keeps its original property and contacts")
	if valid:
		_legacy_saves += 1


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AC02_PUBLIC_DATA " + label)
