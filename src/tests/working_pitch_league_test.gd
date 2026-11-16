extends Node
## Finite domain fixtures only. No physical games, fake rewards, owner writes or
## existing save mutation. Native execution is required separately.
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")
var failures: int = 0


func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)


static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _ready() -> void:
	for version: Variant in [93, 93.0, 94, 94.0]:
		check(WorkingPitchLeagueSave.Owned.version_in(version, [93, 94]),
			"ordinary home accepts exact warm and cold numeric discriminator")
	for version: Variant in [null, true, false, "93", 93.5, 92, 95, {}, []]:
		check(not WorkingPitchLeagueSave.Owned.version_in(version, [93, 94]),
			"ordinary home discriminator rejects malformed type before equality")
	_return_to_standard()
	for home: bool in [false, true]:
		_current(home)
	for league: String in ["dugout", "sponsorship", "academy", "equipment", "earnings", "doubleheader", "scramble"]:
		_historical(league)
	print("Current alternate League domain failures=%d physical_games=0" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _current(home: bool) -> void:
	var season: SeasonState = SeasonState.create_closed_league(9901, LeagueRules.capture("dugout"), true)
	var career: ClubCareer = ClubCareer.new()
	check(WorkingPitchCareerProgress.admit(season, career), "new alternate catalog admission")
	check(ClubPlayerDraft.apply(season, ClubPlayers.owned(career)), "owned draft retained")
	check(career.start_league(season), "fresh Dugout starts with no rewards")
	career._assets = ClubAssetLedger.new_club(9901, ClubPlayers.income(career),
		StadiumCareerProgress.capture(career)).to_data()
	if home:
		check(Normal.prepare(season), "ordinary paid home context")
	var before: Dictionary = SeasonSave.snapshot(season)
	check(before.get("version") == WorkingPitchLeagueSave.VERSION, "explicit99")
	if before.is_empty():
		return
	check(WorkingPitchLeagueSave.authority_key(before) == WorkingPitchLeagueSave.authority_key(cold(before)),
		"authority hash stable across actual JSON number representation")
	var label: String = "home93" if home else "no-home"
	var cold_before: Dictionary = cold(before)
	var cold_parts: Dictionary = WorkingPitchLeagueSave.parts(cold_before)
	check(not cold_parts.is_empty(), "pristine99 cold authority parts " + label)
	if not cold_parts.is_empty():
		check(ClubCareer.same(cold_parts.home_context, before.home_context),
			"runtime home context preserves exact saved authority " + label)
		if home:
			check(cold_parts.home_context.format is int and cold_parts.home_context.format == Normal.VERSION,
				"cold ordinary context restores historical integer discriminator")
			check(cold_before.home_context.format is float,
				"runtime normalization does not mutate cold saved payload")
	var restored: SeasonState = SeasonSave._decode(cold_before)
	check(restored != null, "pristine99 JSON restore " + label)
	if restored == null:
		return
	check(ClubCareer.same(SeasonSave.snapshot(restored), before), "exact current roundtrip")
	check(restored.career.balance() == 0, "no new money")
	for pick in range(4):
		check(restored.choose_player(restored.offers()[0]), "current alternate draft")
	check(SeasonInventoryRules.enable(restored), "six-club inventory admission")
	var data: Dictionary = SeasonSave.snapshot(restored)
	check(not data.is_empty(), "drafted inventory capture")
	if data.is_empty():
		return
	check(WorkingPitchLeagueSave.authority_key(data) == WorkingPitchLeagueSave.authority_key(cold(data)),
		"drafted inventory authority hash stable across JSON")
	var replay: SeasonState = SeasonSave._decode(cold(data))
	check(replay != null, "drafted inventory99 cold restore")
	if replay != null:
		check(ClubCareer.same(replay.build.to_data(), restored.build.to_data()), "actual journal retained")
		check(ClubCareer.same(replay._league_home_context, restored._league_home_context), "home retained")
	_negatives(data, before)
	var fixture: Dictionary = restored.pending_fixture()
	var request: Dictionary = PhysicalRoundProcess.request_for(restored, "current-league",
		SeasonPhysicalFixtures.request_key(restored, fixture), fixture.id)
	check(request.get("version") == WorkingPitchLeagueSave.WORKER_VERSION, "worker9 explicit")
	check(PhysicalRoundProcess.decode_request(cold(request), "current-league") != null, "worker9 JSON")
	var downgrade: Dictionary = cold(request)
	downgrade.version = 1
	downgrade.erase("pitch_catalog")
	check(PhysicalRoundProcess.decode_request(downgrade, "current-league") == null, "worker downgrade")
	for version: Variant in [null, true, "9", 9.5, 8]:
		downgrade = cold(request)
		downgrade.version = version
		check(PhysicalRoundProcess.decode_request(downgrade, "current-league") == null, "worker malformed")


func _negatives(data: Dictionary, before: Dictionary) -> void:
	check(SeasonSave._decode(cold(data.checkpoint)) == null, "stripped99 closed rejects")
	check(SeasonSave._decode_payload(cold(data.checkpoint.checkpoint)) == null, "stripped99 leaf rejects")
	for field: String in WorkingPitchLeagueSave.FIELDS:
		var stripped: Dictionary = cold(data)
		stripped.erase(field)
		check(SeasonSave._decode(stripped) == null, "missing99 " + field)
	for version: Variant in [null, true, "99", 99.5, 81, 87, 93, 94, 97, 98]:
		var malformed: Dictionary = cold(data)
		malformed.version = version
		check(SeasonSave._decode(malformed) == null, "malformed99")
	var bad: Dictionary = cold(data)
	bad.career = before.career
	check(SeasonSave._decode(bad) == null, "borrowed stale career rejects")
	for field: String in ["pitch_catalog", "home_context", "inventory_rules", "player_access"]:
		bad = cold(data)
		bad[field] = "bad"
		check(SeasonSave._decode(bad) == null, "wrong99 type " + field)
	bad = cold(data)
	bad.inventory_rules = {}
	bad.checkpoint.checkpoint.current_league_authority = WorkingPitchLeagueSave.authority_key(bad)
	check(SeasonSave._decode(bad) == null, "stripped inventory cannot hide actual journal")
	bad = cold(data)
	bad.home_context = {"format": 92}
	bad.checkpoint.checkpoint.current_league_authority = WorkingPitchLeagueSave.authority_key(bad)
	check(SeasonSave._decode(bad) == null, "cannot borrow Dynasty home authority")
	if not data.home_context.is_empty():
		for format: Variant in [null, true, false, "93", 93.5, 92, 95, 96, 99]:
			bad = cold(data)
			bad.home_context.format = format
			# Rebind the untrusted header to ensure the strict context discriminator,
			# rather than only a stale authority hash, rejects each malformed value.
			bad.checkpoint.checkpoint.current_league_authority = WorkingPitchLeagueSave.authority_key(bad)
			check(WorkingPitchLeagueSave.parts(bad).is_empty(), "malformed ordinary home discriminator")
			check(SeasonSave._decode(bad) == null, "malformed ordinary home cannot replay")
	bad = cold(data)
	bad.checkpoint.checkpoint.build.pitch_catalog = "foreign"
	check(SeasonSave._decode(bad) == null, "cross-catalog Build rejects")
	bad = cold(data)
	bad.checkpoint.checkpoint.erase("current_league_authority")
	check(SeasonSave._decode(bad) == null, "missing authority binding rejects")


func _historical(league: String) -> void:
	var career: ClubCareer = UnlockFixture.for_league(league)
	var season: SeasonState = SeasonState.create_closed_league(8107,
		LeagueRules.capture(league, 0, 8107 if league == "scramble" else null), true)
	check(career != null and career.start_league(season), "historical start " + league)
	if season.career == null:
		return
	var data: Dictionary = SeasonSave.snapshot(season)
	check(data.get("version") == 81, "historical81 preserved " + league)
	var restored: SeasonState = SeasonSave._decode(cold(data))
	check(restored != null, "historical JSON " + league)
	if restored != null:
		check(ClubCareer.same(data, SeasonSave.snapshot(restored)), "historical exact " + league)
	check(not WorkingPitchCareerProgress.admit(season, career), "no midseason widening " + league)
	check(WorkingPitchLeagueSave.capture(season).is_empty(), "historical cannot enter99 " + league)


func _return_to_standard() -> void:
	var alternate: SeasonState = SeasonState.create_closed_league(9911, LeagueRules.capture("dugout"), true)
	var career: ClubCareer = ClubCareer.new()
	check(WorkingPitchCareerProgress.admit(alternate, career), "mixed current catalog")
	check(ClubPlayerDraft.apply(alternate, ClubPlayers.owned(career)), "mixed owned draft")
	check(career.start_league(alternate), "mixed Dugout begins")
	check(not WorkingPitchCareerSave.ordinary_base_valid(career.to_data()),
		"active alternate base27 cannot enter98")
	check(WorkingPitchCareerSave.capture(alternate).is_empty(), "active alternate cannot strip to98")
	check(career.close(alternate), "close unfinished alternate without rewards")
	var standard: SeasonState = SeasonState.create(9912, false, true, true)
	standard.physical = SeasonPhysicalFixtures.new()
	standard.opponents._format = 13
	check(WorkingPitchCareerProgress.admit(standard, career), "same current club retains catalog")
	check(ClubPlayerDraft.apply(standard, ClubPlayers.owned(career)), "return Standard owned draft")
	check(career.start(standard), "same club starts Standard")
	standard.career = career
	var data: Dictionary = SeasonSave.snapshot(standard)
	check(data.get("version") == WorkingPitchCareerSave.VERSION, "mixed Standard uses98")
	if data.is_empty():
		return
	check(data.checkpoint.career.base_version == 27, "mixed history retained as27")
	var restored: SeasonState = SeasonSave._decode(cold(data))
	check(restored != null, "alternate to Standard same-club JSON cold restore")
	if restored != null:
		check(restored.career.runs.size() == 2 and restored.career.runs[0].league == "dugout" \
			and restored.career.runs[1].league == "standard", "both run histories retained")
		check(ClubCareer.same(data, SeasonSave.snapshot(restored)), "mixed98 exact roundtrip")
	var bad: Dictionary = cold(data)
	bad.checkpoint.career.runs[-1].league = "dugout"
	check(SeasonSave._decode(bad) == null, "active alternate relabel cannot enter98")
