extends Node
## Source fixture only; no awarded results, fake career credit, owner mutation or disk save.
var failures: int = 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _ready() -> void:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	var career: ClubCareer = ClubCareer.new()
	check(WorkingPitchCareerProgress.admit(season, career), "fresh normal career catalog admission")
	check(ClubPlayerDraft.apply(season, ClubPlayers.owned(career)), "unchanged owned-player draft")
	check(career.start(season), "current career starts without granted rewards")
	season.career = career
	for _pick in range(4):
		check(season.choose_player(season.offers()[0]), "current normal draft")
	var data: Dictionary = SeasonSave.snapshot(season)
	check(WorkingPitchProgression.is_version(data.get("version"), 98), "normal Save98 envelope")
	if data.is_empty():
		get_tree().quit(1)
		return
	check(SeasonSave._decode(cold(data)) != null, "normal Save98 JSON cold replay")
	check(SeasonSave._decode(cold(data.checkpoint)) == null, "stripped98 rejects old decoder")
	check(SeasonSave._decode_payload(cold(data.checkpoint)) == null, "stripped98 rejects old leaf")
	var record: Dictionary = cold(data.checkpoint.career)
	check(ClubCareer.from_data(record) != null, "Career32 JSON")
	check(WorkingPitchCareerProgress.valid(record.runs[-1].player_progress,
		record.runs[-1].proof.scores), "Progress4 JSON")
	var old: Dictionary = record.duplicate(true)
	old.version = old.base_version
	old.erase("base_version")
	old.erase("pitch_catalog")
	check(ClubCareer.from_data(old) == null, "old career rejects Progress4")
	old = record.duplicate(true)
	old.version = 29
	check(ClubCareer.from_data(old) == null, "private historical29 is not a public current career")
	var fixture: Dictionary = season.pending_fixture()
	var request: Dictionary = PhysicalRoundProcess.request_for(season, "career-catalog",
		SeasonPhysicalFixtures.request_key(season, fixture), fixture.id)
	check(WorkingPitchProgression.is_version(request.get("version"), 8), "normal worker8")
	check(PhysicalRoundProcess.decode_request(cold(request), "career-catalog") != null,
		"worker8 actual JSON restore")
	for invalid: Variant in ["98", true, null, 98.5]:
		var bad: Dictionary = cold(data)
		bad.version = invalid
		check(SeasonSave._decode(bad) == null, "malformed98 rejects")
		bad = cold(data)
		bad.checkpoint.career.version = invalid
		check(SeasonSave._decode(bad) == null, "malformed32 rejects")
		bad = cold(record)
		bad.runs[-1].player_progress.version = invalid
		check(ClubCareer.from_data(bad) == null, "malformed Progress4 rejects")
		bad = cold(request)
		bad.version = invalid
		check(PhysicalRoundProcess.decode_request(bad, "career-catalog") == null,
			"malformed worker8 rejects")
	var wrong: Dictionary = cold(data)
	wrong.pitch_catalog = "wrong"
	check(SeasonSave._decode(wrong) == null, "cross-catalog98 rejects")
	request.version = 1
	request.erase("pitch_catalog")
	check(PhysicalRoundProcess.decode_request(request, "career-catalog") == null,
		"worker1 cannot downgrade98")
	var historical: SeasonState = SeasonState.create(444, false, true, true)
	var historical_career: ClubCareer = ClubCareer.new()
	check(historical_career.start(historical), "historical career start unchanged")
	historical.career = historical_career
	check(ClubCareer.from_data(cold(historical_career.to_data())) != null,
		"historical Career22 cold replay unchanged")
	check(not WorkingPitchCareerProgress.admit(historical, historical_career),
		"existing career cannot silently upgrade")
	print("Working normal pitch career failures: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
