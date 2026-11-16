extends Node
## Exact immutable AE02 data, saved-fixture binding and report17/save61 compatibility.

const FIXTURE = preload("res://src/tests/ae02_public_fixture.gd")
const EXPECTED_SHA: String = "19854bdcd5128341f4de7ec610b6a34e3256bb63efc3bd0df75f21d8a7b8fd27"
const COUNTS: Dictionary = {"ST-001": 2, "ST-024": 22, "ST-025": 1, "ST-026": 1,
	"ST-028": 2, "ST-037": 4, "ST-039": 1}
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
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "real fixed Base assignment and actual draft")
	if season != null:
		_binding(season)
	_report_reference()
	print("AE02_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	print("AE02_PUBLIC_DATA_COVERAGE copies=%d legacy_saves=%d completed_games=0" %
		[_copies, _legacy_saves])
	get_tree().quit(0 if _failures == 0 and _copies == 33 and _legacy_saves == 4 else 1)


func _definition() -> void:
	var definition: Dictionary = StadiumNpcVenues.definition("AE-02", 1)
	var entry: Dictionary = StadiumNpcSnapshot.capture("AE-02", 1)
	_check(not definition.is_empty() and not entry.is_empty(), "exact AE02/r1 public entry")
	if definition.is_empty() or entry.is_empty():
		return
	_check(_json(definition).sha256_text() == EXPECTED_SHA
		and ClubCareer.same(definition, StadiumNpcExpandedTwoDefinitionV1.payload()),
		"public immutable payload has literal frozen identity")
	_check(entry.version == 18 and entry.authority == "npc-authored-v1"
		and entry.manifest_key == EXPECTED_SHA and definition.id == "AE-02"
		and definition.revision == 1 and definition.field == "field.npc_venue"
		and definition.tier == "expanded" and definition.shape == "deeper_center"
		and definition.live_units == 2 and definition.blueprints.size() == 7
		and definition.valuation.total == 4170, "exact 33-copy two-live-unit daylight identity")
	var counts: Dictionary = {}
	var identities: Dictionary = {}
	for row: Dictionary in definition.instances:
		_check(row.instance == "npc:AE-02:r1:" + row.site and not identities.has(row.instance)
			and row.transform.size() == 12, "unique complete copy " + row.instance)
		identities[row.instance] = row
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	_copies = identities.size()
	_check(_copies == 33 and ClubCareer.same(counts, COUNTS), "exact seven item copy totals")
	for side: Array in [["O-L1", -8.0], ["O-R1", 8.0]]:
		var row: Dictionary = identities["npc:AE-02:r1:" + side[0]]
		_check(row.item == "ST-001" and ClubCareer.same(row.transform.slice(9), [side[1], 0, 14]),
			"exact authored cone pose " + side[0])
	_check(StadiumNpcSnapshot.key(entry) == StadiumNpcSnapshot.key(JSON.parse_string(_json(entry)))
		and not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club())
		and StadiumLayoutSnapshot.ownership(entry) == null, "saved snapshot gives no human stock")
	for pair: Array in [["AE-02", 2], ["AC-02", 1], ["AM-03", 1]]:
		_check(not StadiumNpcSnapshot.supports(pair[0], pair[1])
			and StadiumNpcSnapshot.capture(pair[0], pair[1]).is_empty(), "unissued revision stays closed")
	var altered: Dictionary = definition.duplicate(true)
	altered.instances[0].transform[9] += 0.01
	_check(ClubCareer.same(StadiumNpcVenues.definition("AE-02", 1), definition),
		"caller mutation cannot rewrite immutable definition")
	var bad: Dictionary = entry.duplicate(true)
	bad.manifest = altered
	bad.manifest_key = _json(altered).sha256_text()
	_check(not StadiumNpcSnapshot.valid(bad), "rehashed moved copy cannot gain authority")
	bad = entry.duplicate(true)
	bad.manifest.instances[0].instance = "npc:AE-01:r2:" + bad.manifest.instances[0].site
	bad.manifest_key = _json(bad.manifest).sha256_text()
	_check(not StadiumNpcSnapshot.valid(bad), "rehashed foreign identity cannot gain authority")


func _binding(season: SeasonState) -> void:
	var ids: Array = []
	for owner in range(1, 6):
		ids.append(season.npc_venues.assignments[str(owner)].manifest.id)
	_check(season.season_seed == FIXTURE.SEED and season.npc_venues.venue_ordinal == 0
		and season.npc_venues.streams == FIXTURE.STREAMS and ids == FIXTURE.HOSTS,
		"source-derived seed3 actual Base map and independent streams")
	for index in range(32):
		_check(season.npc_venues.environments[str(index)].seed == FIXTURE.ENVIRONMENT_SEEDS[index],
			"independent daylight environment golden " + str(index))
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty() and fixture.id == 0 and fixture.home == 5 and fixture.away == 0,
		"actual opening AE02 home-owner5 fixture")
	if fixture.is_empty():
		return
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
	_check(snapshot.version == 19 and snapshot.binding.assignment_version == 3
		and snapshot.binding.venue_id == "AE-02" and snapshot.binding.venue_revision == 1
		and snapshot.binding.owner_club == fixture.home
		and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture)
		and snapshot.binding.environment_seed == snapshot.environment.seed
		and snapshot.environment.mode == "day" and snapshot.environment.profile.is_empty()
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
		"fixture19 binds actual saved owner, game seed and independent daylight")
	_check(SeasonState.field_for_fixture(fixture, season).id == &"field.npc_venue"
		and StadiumNpcPublicReport.VERSION == 17
		and StadiumNpcPublicReport.RESOLVER == "physical-ai-npc-public-v1"
		and StadiumNpcPublicReport.supports_definition("AE-02", 1),
		"unchanged ordinary field and report17 dispatch")
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.binding[key] += 1
		_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
			"changed saved binding refuses " + key)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumNpcSnapshot.valid(bad), "dormant yard lights confer no night authority")
	bad = snapshot.duplicate(true)
	bad.binding.neutral = true
	_check(not StadiumNpcSnapshot.valid(bad), "neutral final cannot borrow ordinary fixture")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(saved.version == 61 and restored != null
		and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"actual AE02 assignment roundtrips full-precision save61 unchanged")


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
			and not ClubCareer.same(saved.npc_venues, SeasonVenues.capture_five(
				int(saved.seed), int(saved.npc_venues.career_run), int(saved.npc_venues.venue_ordinal))),
			"current expanded pool never rerolls an older saved Base or Mogul map")
		for report: Dictionary in restored.physical.reports:
			_check(report.report.version == 17 and PhysicalMatchReport.valid(report.report),
				"genuine old report17 keeps its original property and contacts")
	if valid:
		_legacy_saves += 1


func _report_reference() -> void:
	var reference: Dictionary = StadiumNpcPublicContacts._reference(
		StadiumNpcSnapshot.capture("AE-02", 1))
	_check(not reference.is_empty(), "one immutable exact physical report reference")
	if reference.is_empty():
		return
	var cones: int = 0
	var receivers: int = 0
	for body: Dictionary in reference.items:
		if body.role == "LIVE_RICOCHET":
			cones += 1
			_check(body.instance in ["npc:AE-02:r1:O-L1", "npc:AE-02:r1:O-R1"]
				and body.surface in ["CONE_BASE", "CONE_BODY"], "only authentic cone item surfaces")
			if body.surface == "CONE_BODY":
				var shape: ConvexPolygonShape3D = body.shapes[0].shape
				_check(shape != null and shape.points.size() == 24
					and StadiumNpcPublicContacts._cone_contains(shape.points, Vector3(0.11, 0.23, 0))
					and not StadiumNpcPublicContacts._cone_contains(
						shape.points, Vector3(0.14, 0.23, 0)), "tapered hull never relaxes to cylinder")
				var wrong: PackedVector3Array = shape.points.duplicate()
				wrong[0].x += 0.001
				_check(not StadiumNpcPublicContacts._cone_contains(wrong, Vector3.ZERO),
					"changed cone hull cannot borrow exact shape handling")
		elif body.role == "RECEIVER_CONTAINMENT_FOUL":
			receivers += 1
	_check(cones == 4 and receivers > 0, "two actual body/base pairs plus existing receiver")
	var path: String = "res://src/tests/fixtures/base-public-retained-human-report17.json"
	_check(FileAccess.get_sha256(path)
		== "23bb116dbf9a88cf3b7d713562f1447ece5cc55f07f332834802637bfc4db6ad"
		and PhysicalMatchReport.valid(JSON.parse_string(FileAccess.get_file_as_string(path))),
		"unchanged saved Base report17 remains valid")


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AE02_PUBLIC_DATA " + label)
