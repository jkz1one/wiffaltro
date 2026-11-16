extends Node
## Focused public AY02 data/save routing. No gameplay outcomes or rewards are fabricated.
# gdlint: disable=max-returns

const POOL_SAVE: String = "res://src/tests/fixtures/ay02_public_pool60_accepted.json"
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_check(StadiumNpcSnapshot.PUBLIC_VERSION == 18 \
		and StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION == 19 \
		and StadiumPoolOwnedSnapshot.VERSION == 16 \
		and StadiumPoolOwnedSnapshot.FIXTURE_VERSION == 17, "disjoint public snapshot versions")
	var entry: Dictionary = StadiumNpcSnapshot.capture("AY-02", 1)
	_check(not entry.is_empty() and entry.version == 18 \
		and entry.manifest_key == StadiumNpcYardTwoCandidateV1.SHA256, "exact public AY02 data")
	_check(StadiumNpcAvailability.record("AY-02", 1).production_runtime \
		and StadiumNpcAvailability.record("AY-02", 1).selectable, "explicit AY02 registry admission")
	_check(StadiumNpcSnapshot.capture("AY-02", 2).is_empty() \
		and not StadiumNpcSnapshot.capture("AY-03", 1).is_empty(),
		"AY02 revision2 absent while independently admitted AY03 revision1 exists")
	var raw: Dictionary = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	_check(not raw.is_empty() and StadiumNpcSnapshot.raw_envelope_valid(raw) \
		and not StadiumNpcSnapshot.valid(raw), "raw16 remains qualification only")
	_check(not StadiumLayoutSnapshot.valid(entry, StadiumStock.new_club()) \
		and StadiumLayoutSnapshot.ownership(entry) == null, "NPC data grants no human stock")
	_check(ContentDB.get_field(&"field.npc_venue") != null, "actual NPC field registered")
	_check(SeasonVenues.owner_for(443) == 4, "independent namespace443 selects Comets")
	_pool_legacy_control()
	for seed: int in [0, 1, 47, 443, 2147483647]:
		var data: Dictionary = _legacy_assignment(seed, 1)
		_check(data.assignments.size() == 1
			and ClubCareer.same(data, SeasonVenues.normalized(data)),
			"explicit assignment1 retains exactly one independently selected AY02 host")
		_current_assignment(seed, data)
		_check(SeasonVenues.key(data) == SeasonVenues.key(JSON.parse_string(_json(data))),
			"exact map JSON roundtrip")
	var season: SeasonState = _season()
	if season == null or _failures > 0:
		_finish()
		return
	_save_controls(season)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "real draft choice")
	_route_controls(season)
	_mutation_controls(season)
	_check(SeasonSave._decode(SeasonSave.snapshot(season)) != null,
		"drafted public season roundtrips without a played result")
	_finish()


func _legacy_assignment(seed: int, career_run: int) -> Dictionary:
	# Synthetic v1 schema control, not an authentic historical save or played result.
	# Persisted v1 still has one owner; later v2 capture must not manufacture v1.
	var owner: int = 1 + ("ay02-away-v1:" + str(seed)).sha256_text().left(8).hex_to_int() % 5
	return {"version": 1, "seed": seed, "career_run": career_run,
		"assignments": {str(owner): StadiumNpcSnapshot.capture("AY-02", 1)}}


func _current_assignment(seed: int, legacy: Dictionary) -> void:
	var owner: int = int(legacy.assignments.keys()[0])
	var others: Array[int] = []
	for club: int in range(1, 6):
		if club != owner:
			others.append(club)
	var next: int = others[("ay03-away-v1:" + str(seed)).sha256_text().left(8).hex_to_int() % 4]
	var expected: Dictionary = {"version": 2, "seed": seed, "career_run": 1,
		"assignments": {str(owner): StadiumNpcSnapshot.capture("AY-02", 1),
			str(next): StadiumNpcSnapshot.capture("AY-03", 1)}}
	var current: Dictionary = SeasonVenues.capture(seed, 1)
	_check(ClubCareer.same(current, expected), "v2 capture matches independent two-owner map")
	_check(ClubCareer.same(current, SeasonVenues.capture(seed, 1))
		and ClubCareer.same(current, SeasonVenues.normalized(JSON.parse_string(_json(current)))),
		"v2 capture deterministic and exact cold roundtrip")
	var promoted: Dictionary = legacy.duplicate(true)
	promoted.assignments[str(next)] = expected.assignments[str(next)]
	_check(SeasonVenues.normalized(promoted).is_empty(), "v1 rejects unversioned second owner")
	var swapped: Dictionary = expected.duplicate(true)
	swapped.assignments[str(owner)] = expected.assignments[str(next)]
	swapped.assignments[str(next)] = expected.assignments[str(owner)]
	_check(SeasonVenues.normalized(swapped).is_empty(), "v2 rejects swapped venue owners")
	var duplicated: Dictionary = expected.duplicate(true)
	duplicated.assignments[str(next)] = expected.assignments[str(owner)]
	_check(SeasonVenues.normalized(duplicated).is_empty(), "v2 rejects duplicated AY02 venue")


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual career run starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = _legacy_assignment(season.season_seed, season.career.current)
	_check(not season.home_property.is_empty() and SeasonVenues.matches_season(season),
		"real home field and independent saved away map")
	return season


func _pool_legacy_control() -> void:
	# Exact accepted six-game save, never a newly simulated funding or gameplay history.
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(POOL_SAVE))
	_check(value is Dictionary and value.get("version") == 60, "frozen accepted Pool60 input")
	if not value is Dictionary:
		return
	var restored: SeasonState = SeasonSave._decode(value)
	_check(restored != null and restored.npc_venues.is_empty(),
		"accepted Pool60 history decodes without receiving an AY02 assignment")
	if restored != null:
		_check(ClubCareer.same(value, SeasonSave.snapshot(restored)),
			"accepted Pool60 reports, human evidence and paid field remain exact")


func _save_controls(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(not saved.is_empty() and saved.version == 61, "public Working save61")
	var restored: SeasonState = SeasonSave._decode(JSON.parse_string(_json(saved)))
	_check(restored != null and restored._npc_replay_run == -1 \
		and SeasonVenues.key(restored.npc_venues) == SeasonVenues.key(season.npc_venues),
		"saved run and assignment restore without regeneration")
	var old: Dictionary = saved.duplicate(true)
	old.erase("npc_venues")
	old.version = 59
	var old_season: SeasonState = SeasonSave._decode(old)
	_check(old_season != null and old_season.npc_venues.is_empty() \
		and ClubCareer.same(old, SeasonSave.snapshot(old_season)), "save59 stays unassigned and exact")
	var old58: Dictionary = old.duplicate(true)
	old58.erase("home_property")
	old58.version = 58
	var restored58: SeasonState = SeasonSave._decode(old58)
	_check(restored58 != null and restored58.npc_venues.is_empty() \
		and ClubCareer.same(old58, SeasonSave.snapshot(restored58)), "save58 stays unassigned and exact")
	var bad: Dictionary = saved.duplicate(true)
	bad.npc_venues.career_run += 1
	_check(SeasonSave._decode(bad) == null, "different saved career run rejected")
	bad = saved.duplicate(true)
	bad.version = 60
	_check(SeasonSave._decode(bad) == null, "new map cannot enter historical Pool60")
	bad = saved.duplicate(true)
	bad.home_property = StadiumNpcSnapshot.capture("AY-02", 1)
	_check(SeasonSave._decode(bad) == null, "NPC entry cannot become the human owned home")
	var previous_path: String = SeasonSave.path
	var path: String = "user://ay02-public-data-%d.json" % OS.get_process_id()
	_check(not FileAccess.file_exists(path), "fresh isolated save path")
	if FileAccess.file_exists(path):
		return
	SeasonSave.path = path
	_check(SeasonSave.save(season), "public data saves through normal atomic writer")
	var bytes: String = FileAccess.get_file_as_string(path)
	SeasonSave.path = path + "/unavailable/season.json"
	_check(not SeasonSave.save(season) and FileAccess.get_file_as_string(path) == bytes,
		"failed save cannot replace preceding valid checkpoint")
	SeasonSave.path = path
	_check(SeasonSave.restore() != null, "normal disk restore accepts exact saved assignment")
	SeasonSave.path = previous_path
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _route_controls(season: SeasonState) -> void:
	var venues: String = SeasonVenues.key(season.npc_venues)
	var ledger: String = _json(ClubPlayers.assets(season.career).to_data())
	var selected: int = 0
	for fixture: Dictionary in season.schedule:
		var field: FieldDefinition = SeasonState.field_for_fixture(fixture, season)
		var snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		if fixture.home == 4:
			selected += 1
			_check(field != null and field.id == &"field.npc_venue" \
				and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
				"actual selected host uses exact scheduled public fixture")
			_check(snapshot.binding.career_run == season.career.current \
				and snapshot.binding.match_seed == SeasonPhysicalFixtures.seed_for(season, fixture) \
				and snapshot.environment.mode == "day", "real run/seed and day-only fixture")
		else:
			_check(field != null and field.id == (PitchBatLab.FIELD_ID if fixture.home == 0 \
				else SeasonState.AWAY_FIELD_ID), "home and other Commons routes preserved")
	_check(selected == 5, "one opponent hosts its existing five regular fixtures")
	var prior: Array[Dictionary] = season.semifinals.duplicate(true)
	season.semifinals = [{"id": 30, "round": 10, "away": 0, "home": 4}]
	_check(not SeasonVenues.for_fixture(season, season.semifinals[0]).is_empty(),
		"saved assignment serves a scheduled hosted semifinal")
	season.semifinals = prior
	var prior_final: Dictionary = season.final_fixture.duplicate(true)
	season.final_fixture = {"id": 32, "round": 11, "away": 0, "home": 4, "neutral": true}
	_check(SeasonVenues.for_fixture(season, season.final_fixture).is_empty() \
		and SeasonState.field_for_fixture(season.final_fixture, season).id == SeasonState.AWAY_FIELD_ID,
		"neutral final remains Commons even if selected host bats last")
	season.final_fixture = prior_final
	_check(SeasonVenues.key(season.npc_venues) == venues \
		and _json(ClubPlayers.assets(season.career).to_data()) == ledger,
		"routing and schema-only semifinal controls leave map and human ledger unchanged")


func _mutation_controls(season: SeasonState) -> void:
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.home == 4:
			fixture = row
			break
	var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
	for field: String in ["season_seed", "career_run", "fixture", "match_seed"]:
		var bad: Dictionary = snapshot.duplicate(true)
		bad.binding[field] += 1
		_check(not StadiumNpcSnapshot.matches_fixture(bad, season, fixture),
			"actual saved fixture rejects changed " + field)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.environment.mode = "night"
	_check(not StadiumNpcSnapshot.valid(bad), "no night authority")
	bad = snapshot.duplicate(true)
	bad.manifest.instances[0].transform[9] += 1.0
	bad.manifest_key = StadiumNpcManifest.payload_key(bad.manifest)
	_check(not StadiumNpcSnapshot.valid(bad), "rehashing changed physical data grants no authority")
	var map: Dictionary = season.npc_venues.duplicate(true)
	map.assignments["3"] = map.assignments["4"]
	map.assignments.erase("4")
	_check(SeasonVenues.normalized(map).is_empty(), "wrong host cannot replace saved selection")
	var before: Dictionary = season.npc_venues
	season.npc_venues = map
	_check(SeasonState.field_for_fixture(fixture, season) == null,
		"invalid assignment cannot silently fall back to Commons")
	season.npc_venues = before


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AY02_PUBLIC_DATA " + description)


func _json(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


func _finish() -> void:
	print("AY02_PUBLIC_DATA checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
