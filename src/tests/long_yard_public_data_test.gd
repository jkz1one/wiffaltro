extends Node
## Exact public Long Yard record, old-save compatibility and bounded schema-only negatives.
## Synthetic participants test neutral plumbing only; no played final or certification is claimed.

const FIXTURE = preload("res://src/tests/long_yard_public_fixture.gd")
const PREFIX: String = "npc:LONG-YARD:r1:"
const EXPECTED_SHA: String = "3e8acd3047f510f5128cf51e2f759a6ed04db8f7ee166e0f67c25099136fc01c"
const COUNTS: Dictionary = {"ST-065": 22, "ST-022": 16, "ST-023": 16, "ST-074": 2,
	"ST-021": 2, "ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-053": 2, "ST-039": 1}
const LEGACY: Array = [
	["res://src/tests/fixtures/ay03_control_ay02_save61.json",
		"aabce07259d737e7dbbeb8f00139a7963cbeb457b948c23af49336b956106067", 1],
	["res://src/tests/fixtures/base_control_ay03_save61_v2.json",
		"86cbcd4827d265647b2f9eba6f58079d0347edb19d9658e80cb6fe345c96ae1d", 2],
	["res://src/tests/fixtures/base-public-completed-pending.json",
		"688611ea88162690c6da224ba2f7fbfc01f7b3c69fc0b3adb4104536fd3ee9b4", 3],
	["res://src/tests/fixtures/am01_managed_seed2_save61.json",
		"cc350dc4efbf9dd985920b5ee6db53cb0f217f0374bb3b1055871da11a888770", 3],
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
	_check(FIXTURE.ready(), "explicit qualification record exists")
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "fixed record captured before real draft choices")
	if season != null:
		_saved_record(season)
		_binding(season)
		_geometry(season)
	print("LONG_YARD_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	print("LONG_YARD_PUBLIC_DATA_COVERAGE copies=%d legacy_saves=%d completed_games=0" %
		[_copies, _legacy_saves])
	get_tree().quit(0 if _failures == 0 and _copies == 67 and _legacy_saves == 5 else 1)


func _definition() -> void:
	var definition: Dictionary = StadiumLongYardDefinitionV1.canonical()
	_check(not definition.is_empty() and _json(definition).sha256_text() == EXPECTED_SHA
		and StadiumLongYardDefinitionV1.SHA256 == EXPECTED_SHA
		and ClubCareer.same(definition, StadiumLongYardDefinitionV1.payload()),
		"immutable full-precision exact authored v2/publicr1 definition")
	if definition.is_empty():
		return
	_check(definition.id == "LONG-YARD" and definition.revision == 1
		and definition.assembly.version == 2 and definition.field == "field.npc_venue"
		and definition.tier == "club" and definition.shape == "deeper_center"
		and definition.live_units == 0 and definition.blueprints.size() == 10
		and definition.environment_certificates.is_empty()
		and definition.presentation.profile == "LONG-YARD-1610-CLEAR-v1",
		"fixed original67-copy Deeper Center has no obstacle units or fabricated certificate")
	var counts: Dictionary = {}
	var identities: Dictionary = {}
	for row: Dictionary in definition.instances:
		_check(row.instance == PREFIX + row.site and not identities.has(row.instance)
			and row.transform.size() == 12, "unique complete authored copy " + row.instance)
		identities[row.instance] = row
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	_copies = identities.size()
	_check(_copies == 67 and ClubCareer.same(counts, COUNTS), "exact ten item copy totals")
	_check(ClubCareer.same(identities[PREFIX + "SCORE-SMALL"].transform.slice(9), [-20.0, 0.0, 30.0]),
		"original manual scoreboard world position stays exact")
	for site: String in ["BASE-L2", "BASE-R2"]:
		var roof: Dictionary = identities[PREFIX + "ROOF:" + site]
		_check(roof.item == "ST-053" and roof.host == PREFIX + site
			and ClubCareer.same(roof.transform, [1.0, 0.0, 0.0, 0.0, 1.0, 0.0,
				0.0, 0.0, 1.0, 0.0, 0.0, 0.0]),
			"exact two original roof hosts retain local identity " + site)
	_check(not StadiumNpcSnapshot.supports("LONG-YARD", 1)
		and StadiumNpcSnapshot.capture("LONG-YARD", 1).is_empty()
		and not StadiumNpcPublicReport.supports_definition("LONG-YARD", 1)
		and StadiumLongYardPublicReport.supports_definition("LONG-YARD", 1)
		and not StadiumLongYardPublicReport.supports_definition("LONG-YARD", 2)
		and not StadiumLongYardPublicReport.supports_definition("AC-01", 2),
		"Long Yard is final-only; no ordinary snapshot18/report17 or unsupported revision")


func _saved_record(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.version == 62 and saved.has("final_venue") and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"actual drafted explicit record roundtrips full-precision save62")
	_check(season.final_venue.selection == "explicit-qualification"
		and season.final_venue.league == "doubleheader"
		and season.final_venue.venue_owner == "finals-venue:long-yard:v2"
		and season.final_venue.fixture == 32,
		"qualification discriminator preserves Working pairing without public activation")
	for league: String in ["standard", "pressure_count", "sponsorship", ""]:
		_check(SeasonFinalVenue.capture(season.season_seed, season.career.current, league).is_empty(),
			"unapproved pairing does not infer Long Yard " + league)
	for edit: int in range(4):
		var changed: Dictionary = saved.duplicate(true)
		match edit:
			0:
				changed.final_venue.environment.lighting.sun_energy += 0.01
			1:
				changed.final_venue.selection = "public-selection"
			2:
				changed.final_venue.venue_owner = "npc-owner:1"
			3:
				changed.final_venue.manifest.instances[0].transform[9] += 0.01
				changed.final_venue.manifest_key = _json(changed.final_venue.manifest).sha256_text()
		_check(SeasonSave._decode(changed) == null,
			"saved final record rejects changed profile/selection/owner/rehashed manifest%d" % edit)
	var old: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	if old == null:
		return
	old.final_venue = {}
	var old_saved: Dictionary = SeasonSave.snapshot(old)
	var old_restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(old_saved)))
	_check(old_saved.version == 61 and not old_saved.has("final_venue") and old_restored != null
		and ClubCareer.same(old_saved, SeasonSave.snapshot(old_restored)),
		"ordinary opted-out season retains exact save61 envelope")
	var final_fixture: Dictionary = FIXTURE.fixture(old)
	_check(SeasonVenues.for_fixture(old, final_fixture).is_empty()
		and SeasonState.field_for_fixture(final_fixture, old).id == &"field.commons_park",
		"legacy Commons final plumbing is never silently substituted")
	var wrong: Dictionary = saved.duplicate(true)
	wrong.erase("final_venue")
	_check(SeasonSave._decode(wrong) == null, "save62 cannot strip its durable final record")
	wrong = saved.duplicate(true)
	wrong.version = 61
	_check(SeasonSave._decode(wrong) == null, "save61 cannot smuggle a new fixed final record")


func _binding(season: SeasonState) -> void:
	var original: Dictionary = season.final_venue.duplicate(true)
	for home: bool in [false, true]:
		var fixture: Dictionary = FIXTURE.fixture(season, home)
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		_check(not snapshot.is_empty(), "saved neutral-final binding exists for both batting orders")
		if snapshot.is_empty():
			continue
		_check(snapshot.version == 20 and snapshot.authority == "neutral-final-v1"
			and snapshot.manifest_key == EXPECTED_SHA and snapshot.binding.fixture == 32
			and snapshot.binding.neutral and snapshot.binding.batting_home == fixture.home
			and snapshot.binding.away == fixture.away and not snapshot.binding.has("owner_club")
			and snapshot.binding.venue_owner == "finals-venue:long-yard:v2"
			and snapshot.binding.assignment_key == SeasonFinalVenue.key(season.final_venue)
			and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
			and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
			"neutral venue owner is separate from higher-seed batting-home")
		var environment: Dictionary = snapshot.environment
		_check(environment.version == 2 and environment.fixture == 32
			and environment.mode == "day" and environment.profile == "LONG-YARD-1610-CLEAR-v1"
			and environment.time == "16:10" and environment.weather == "clear"
			and environment.render_profile == 1 and StadiumLongYardEnvironmentV1.valid(environment)
			and environment.lighting.active_lights.is_empty()
			and ClubCareer.same(environment.lighting.sun_rotation, [-32.0, -55.0, 0.0]),
			"fixed artistic16:10 clear has exact real lighting operands and no active lamps")
		_check(SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
			and typeof(SeasonState.field_for_fixture(fixture, season).id) == TYPE_STRING_NAME
			and PhysicalStadiumReport.npc_resolver(snapshot) == StadiumLongYardPublicReport.RESOLVER
			and StadiumLongYardPublicReport.VERSION == 18
			and not StadiumLayoutSnapshot.valid(snapshot, StadiumStock.new_club())
			and StadiumLayoutSnapshot.ownership(snapshot) == null,
			"exact final field/report18 selector gives no human stock ownership")
		for key: String in ["fixture", "match_seed", "career_run", "batting_home", "away"]:
			var bad: Dictionary = snapshot.duplicate(true)
			bad.binding[key] += 1
			_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
				"changed saved final binding refuses " + key)
		for key: String in ["venue_owner", "assignment_key", "selection", "league"]:
			var bad: Dictionary = snapshot.duplicate(true)
			bad.binding[key] = "foreign"
			_check(not StadiumNpcSnapshot.valid(bad), "changed exact final identity refuses " + key)
		_environment_negatives(snapshot)
		_manifest_negatives(snapshot)
		var human_shape: Dictionary = {"version": 2, "fixture": 32, "property": snapshot}
		_check(StadiumNpcYardTwoHumanEvidence._envelope(human_shape)
			and not StadiumNpcYardTwoHumanEvidence.valid(human_shape),
			"schema-only humanv2 envelope is never sufficient completed game evidence")
		for version: int in [0, 1, 3]:
			human_shape.version = version
			_check(not StadiumNpcYardTwoHumanEvidence._envelope(human_shape),
				"neutral snapshot20 cannot borrow another human evidence version")
	_check(ClubCareer.same(original, season.final_venue),
		"both participant bindings preserve one original pre-draft saved neutral record")


func _environment_negatives(snapshot: Dictionary) -> void:
	for pair: Array in [["version", 1], ["mode", "night"], ["profile", ""],
		["time", "13:10"], ["weather", "overcast"], ["render_profile", 2]]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.environment[pair[0]] = pair[1]
		_check(not StadiumNpcSnapshot.valid(bad), "changed fixed environment refuses " + pair[0])
	var bad: Dictionary = snapshot.duplicate(true)
	bad.environment.lighting.sun_energy += 0.01
	_check(not StadiumNpcSnapshot.valid(bad), "changed actual fixed rendering operand refuses")
	bad = snapshot.duplicate(true)
	bad.environment = {"version": 1, "seed": snapshot.environment.seed,
		"fixture": 32, "mode": "day", "profile": ""}
	_check(not StadiumNpcSnapshot.valid(bad), "generic day cannot stand in for fixed16:10 clear")


func _manifest_negatives(snapshot: Dictionary) -> void:
	for edit: int in range(5):
		var bad: Dictionary = snapshot.duplicate(true)
		match edit:
			0:
				bad.manifest.instances[0].transform[9] += 0.01
			1:
				bad.manifest.instances[0].instance = "finals-candidate:LONG-YARD:v2:BASE-L1"
			2:
				bad.manifest.revision = 2
			3:
				bad.manifest.field = "field.commons_park"
			4:
				bad.manifest = StadiumNpcVenues.definition("AM-01", 1)
		bad.manifest_key = _json(bad.manifest).sha256_text()
		_check(not StadiumNpcSnapshot.valid(bad), "rehashed changed final manifest refuses%d" % edit)


func _geometry(season: SeasonState) -> void:
	var snapshot: Dictionary = SeasonFinalVenue.for_fixture(season, FIXTURE.fixture(season))
	var reference: Dictionary = StadiumNpcPublicContacts._reference(snapshot)
	_check(not reference.is_empty(), "one detached exact reference supports geometry probes")
	if reference.is_empty():
		return
	var graph: StadiumDugoutBoundary = StadiumDugoutBoundary.candidate("deeper_center")
	_check(reference.graph == "PROTOTYPE-CLUB-DUGOUT-DEEPER-CENTER-v1"
		and graph.signature() == "329df908c5c38c496a73cb2c4265d5eed53f2d2da7bfbbb7ade04c808e0a6dcf"
		and reference.segments.size() == 16 and graph.polygon().size() == 16
		and reference.segments["BACK-02"].a == Vector2(10, 26)
		and reference.segments["BACK-02"].b == Vector2(-10, 26),
		"exact sixteen-edge Deeper Center has original twenty-meter deepest run")
	var slabs: int = 0
	var poles: int = 0
	for row: Dictionary in graph.segments():
		var actual: Dictionary = reference.segments[row.id]
		_check(actual.a == row.a and actual.b == row.b and actual.height == row.height
			and actual.role == row.role and actual.priority == row.priority,
			"exact original graph endpoint/height/role/priority " + row.id)
	for body: Dictionary in reference.bodies:
		if body.kind == "pole":
			poles += 1
			_check(body.split == 3.25, "exact original pole split")
		if body.kind != "boundary":
			continue
		slabs += 1
		var row: Dictionary = reference.segments[body.segment]
		var index: int = graph.segments().find(row)
		var points: PackedVector3Array = []
		var corners: Array[Vector2] = [row.a, row.b,
			graph.outer_vertex((index + 1) % 16), graph.outer_vertex(index)]
		for height: float in [0.0, float(row.height)]:
			for point: Vector2 in corners:
				points.append(Vector3(point.x, height, point.y))
		var shape: ConvexPolygonShape3D = body.shapes[0].shape as ConvexPolygonShape3D
		_check(shape != null and shape.points == points and shape.margin == 0,
			"same-origin exact eight-point zero-margin original slab " + body.segment)
	_check(slabs == 10 and poles == 2, "complete ten exact slabs and two original poles")


func _legacy_save(row: Array) -> void:
	_check(FileAccess.get_sha256(row[0]) == row[1], "byte-pinned prior saved assignment")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(row[0]))
	var restored: SeasonState = SeasonSave._decode(saved)
	_check(restored != null, "old completed or pending save still decodes")
	if restored == null:
		return
	var actual: Dictionary = SeasonSave.snapshot(restored)
	var valid: bool = saved.version == 61 and restored.npc_venues.version == row[2] \
		and restored.final_venue.is_empty() and ClubCareer.same(saved, actual)
	_check(valid, "old full saved map/results/pending evidence preserve exact save61")
	if valid:
		_legacy_saves += 1


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("LONG_YARD_PUBLIC_DATA " + label)
