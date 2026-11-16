extends Node
## Synthetic domain fixtures only. These checks are not earned human play or balance approval.
const Fixture = preload("res://src/tests/working_exotic_access_test.gd")
const Registry = preload("res://src/gameplay/pitching/working_pitch_catalog_registry.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const ROSTER: Array[String] = Fixture.ROSTER
const NEW_IDS: Array[String] = ["pitch.submarine_two_seam", "pitch.submarine_curveball"]
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

static func cold(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func _ready() -> void:
	_catalog()
	_paid()
	_replacement_and_boundaries()
	_exotics()
	_transport()
	print("Expanded standalone season checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _catalog() -> void:
	check(WorkingPitchCatalog.signature() == ExpandedSeasonCatalog.Provider.LEGACY_SIGNATURE, "v5 signature unchanged")
	check(ExpandedSeasonCatalog.ids().size() == 43, "43 exact active recipes")
	var context: Dictionary = cold(ExpandedSeasonCatalog.descriptor())
	check(ExpandedSeasonCatalog.valid_descriptor(context), "persisted descriptor accepts integral JSON version")
	check(not Registry.valid_context(context), "persisted descriptor never admitted as preview")
	check(not ExpandedSeasonCatalog.valid_descriptor(Registry.context_for_use(6, Registry.PREVIEW)), "preview never admitted as persisted")
	for marker: Variant in ["6", true, null, 6.5, 5]:
		var bad: Dictionary = context.duplicate(true)
		bad.version = marker
		check(not ExpandedSeasonCatalog.valid_descriptor(bad), "descriptor rejects malformed or mixed version")
	var old: SeasonDevelopment = SeasonDevelopment.new("v5")
	check(old.enable_pitch_catalog(), "v5 activation")
	check(not old.enable_expanded_pitch_catalog(), "no v5-to-v6 migration")
	check(SeasonDevelopment.from_data(cold(old.to_data()), "v5") != null, "v5 development cold replay")
	for id: String in ExpandedSeasonCatalog.ids():
		var book: SeasonDevelopment = SeasonDevelopment.new("v6")
		check(book.enable_expanded_pitch_catalog(), "fresh v6 activation")
		check(not book.enable_pitch_catalog(), "no v6-to-v5 downgrade")
		if ExpandedSeasonCatalog.lesson_price(id) < 0:
			check(not book.lesson_supported(id), "unearned exotic unavailable")
			continue
		check(book.lesson_supported(id), "conventional lesson supported " + id)
		if book.player(ROSTER[0]).active.has(id):
			continue
		var command: Dictionary = {"id": "fixture:learn", "rev": 0, "player": ROSTER[0], "op": "learn", "target": id, "replace": ""}
		check(book.commit(command).ok, "exact recipe acquisition " + id)
		var authored: PlayerDefinition = ContentDB.get_player(StringName(ROSTER[0]))
		var player: PlayerDefinition = ProgressionMatchAdapter.player(book, ROSTER[0])
		check(player != null and player.starting_pitches[-1].id == StringName(id), "match adapter exact ID " + id)
		check(player != null and player.throws == authored.throws and player.natural_delivery == authored.natural_delivery, "authored hand/natural delivery preserved")
		check(SeasonDevelopment.from_data(cold(book.to_data()), "v6") != null, "exact recipe cold replay " + id)
	# Capacity/replacement and retained mastery use only the ordinary development ledger.
	var book: SeasonDevelopment = SeasonDevelopment.new("capacity")
	book.enable_expanded_pitch_catalog()
	for id: String in NEW_IDS:
		var command: Dictionary = {"id": id, "rev": book.revision(), "player": ROSTER[0], "op": "learn", "target": id, "replace": ""}
		if book.player(ROSTER[0]).active.size() == book.player(ROSTER[0]).capacity:
			check(not book.commit(command).ok, "full repertoire requires explicit replacement")
			command.replace = book.player(ROSTER[0]).active[0]
		check(book.commit(command).ok, "new recipe acquired with capacity respected")
		for level in range(2, 6):
			check(book.commit({"id": "%s:%d" % [id, level], "rev": book.revision(), "player": ROSTER[0], "op": "mastery", "target": id}).ok, "exact new recipe mastery ladder")
		check(ProgressionMatchAdapter.player(book, ROSTER[0]).starting_pitches.any(func(pitch: PitchDefinition) -> bool: return String(pitch.id) == id and pitch.mastery_level == 5), "new recipe mastery materialized")

func _paid() -> void:
	var found: Dictionary = {}
	for seed_value in range(128):
		var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
		build.enable_expanded_pitch_catalog()
		check(build.commit(Fixture.cmd(build, "reward", {"game": 0, "win": true})).ok, "synthetic settled game income")
		check(build.commit(Fixture.cmd(build, "open")).ok, "ordinary generated shop")
		for key: String in build._visit.offers:
			var item_id: String = build._visit.offers[key]
			var recipe: String = item_id.trim_prefix("lesson.")
			if not NEW_IDS.has(recipe) or found.has(recipe):
				continue
			var target: Dictionary = build.targets(item_id)[0]
			var buy: Dictionary = Fixture.cmd(build, "buy", {"offer": key, "mode": "use", "player": target.player, "pitch": target.pitch, "replace": target.replace})
			var cash: int = build.cash()
			check(build.preview(buy).ok and build.cash() == cash, "paid preview inert")
			check(build.commit(buy).ok and build.cash() == cash - 10, "new pitch costs exactly ten earned Cash")
			check(build.commit(buy).replayed and build.cash() == cash - 10, "retry does not charge twice")
			var restored: SeasonBuild = SeasonBuild.from_data(cold(build.to_data()), seed_value, ROSTER)
			check(restored != null and restored.player(target.player).active.has(recipe), "paid new recipe cold build replay")
			if restored != null:
				check(restored.cash() == build.cash() and ClubCareer.same(restored._book.to_data(), build._book.to_data()) and ClubCareer.same(restored.to_data(), build.to_data()), "cold paid cash, mastery and full journal equality")
				var settled: Dictionary = restored.to_data()
				check(restored.commit(cold(buy)).replayed and ClubCareer.same(settled, restored.to_data()), "cold retry is idempotent across wallet/mastery/journal")
			found[recipe] = true
			break
		if found.size() == 2:
			break
	check(found.size() == 2, "both new recipes appear in generated paid stock")

func _exotics() -> void:
	var build: SeasonBuild = SeasonBuild.new(611, ROSTER)
	build.enable_expanded_pitch_catalog()
	check(not build._book.install_exotic_start([]), "v5 inherited access API rejects v6")
	var reward: Dictionary = Fixture.fixture_reward()
	var staged: SeasonBuild = build.candidate(reward)
	check(staged != null, "ordinary reward accepts prospective proof")
	if staged == null:
		return
	var result: Dictionary = Fixture.fixture_result(reward)
	var bad: Dictionary = result.duplicate(true)
	bad.pitching_current.called_strikeouts = []
	check(ExpandedExoticAccess.finalized_candidate(staged, [], bad) == null, "mismatched reward/result cannot earn access")
	var admitted: SeasonBuild = ExpandedExoticAccess.finalized_candidate(staged, [], result)
	check(admitted != null, "settled matching proof derives access")
	if admitted == null:
		return
	check(admitted._book.lesson_supported("pitch.switchback") and not admitted._book.lesson_supported("pitch.sidearm_switchback"), "exact unique Switchback earned")
	check(admitted.cash() == 18 and not admitted.player(ROSTER[0]).active.has("pitch.switchback"), "access grants neither pitch nor extra cash")
	check(not admitted._book.lesson_supported("pitch.corkscrew") and not admitted._book.lesson_supported("pitch.trapdoor"), "unearned designs stay locked")
	var restored: SeasonBuild = SeasonBuild.from_data(cold(admitted.to_data()), 611, ROSTER)
	check(restored != null and restored._book.lesson_supported("pitch.switchback"), "earned access cold replay")
	var forged: Dictionary = cold(admitted.to_data())
	forged.events[-1].proof.catalog = WorkingPitchCatalog.signature()
	check(SeasonBuild.from_data(forged, 611, ROSTER) == null, "v5 proof cannot authorize v6")
	# Pure threshold fixture: no claim this synthetic proof was played or paid.
	var proof: Dictionary = admitted._book._exotic_current.duplicate(true)
	var rows: Array = proof.games[0].strikeouts
	for id: String in ["pitch.drop", "pitch.overhand_sinker", "pitch.riser", "pitch.drop", "pitch.drop"]:
		rows.append({"pa": rows.size() + 1, "half": 0, "pitcher": ROSTER[0], "finish": id, "sequence": [id], "called": true})
	var ledger: Dictionary = cold(build._book.to_data())
	ledger.exotic_current = proof
	ledger.exotic_current.season = build._book._season_key
	check(SeasonDevelopment.from_data(ledger, build._book._season_key) == null, "standalone development import cannot self-authorize exotic access")
	var eligible: Array[String] = ExpandedExoticEligibility.eligible_ids(proof)
	eligible.sort()
	check(eligible == ["pitch.corkscrew", "pitch.switchback", "pitch.trapdoor"], "thresholds expose exactly three unique exotic designs")
	var before: Dictionary = build.to_data()
	check(not build.commit(Fixture.cmd(build, "exotic_admit", {"proof": proof})).ok and ClubCareer.same(before, build.to_data()), "shape-valid synthetic proof without settled games cannot self-grant")

func _transport() -> void:
	var season: SeasonState = ExpandedSeasonProgression.create_season(318)
	check(season != null, "normal standalone season created")
	if season == null:
		return
	check(not ClubCareer.new().start(season), "career attachment explicitly blocked")
	for _pick in range(4):
		check(season.choose_player(season.offers()[0]), "authored draft preserves v6")
	check(Profile.capture_build(season.build, "test", "test").is_empty(), "dynasty carry explicitly blocked")
	var data: Dictionary = SeasonSave.snapshot(season)
	check(data.get("version") == 102, "explicit v6 envelope102")
	if data.is_empty():
		return
	check(SeasonSave._decode(cold(data)) != null, "drafted season cold restore")
	check(SeasonSave._decode(cold(data.checkpoint)) == null, "stripped outer envelope rejected")
	check(SeasonSave._decode_payload(cold(data.checkpoint)) == null, "legacy leaf rejects v6")
	var bad: Dictionary = cold(data)
	bad.version = 97
	bad.pitch_catalog = WorkingPitchCatalog.signature()
	check(SeasonSave._decode(bad) == null, "v5 envelope cannot carry v6 build")
	bad = cold(data)
	bad.checkpoint.build.catalog_context.purpose = "isolated_preview"
	check(SeasonSave._decode(bad) == null, "preview context cannot enter season save")
	var fixture: Dictionary = season.pending_fixture()
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	check(state != null and state.pitch_catalog == ExpandedSeasonCatalog.signature(), "normal match has exact v6 physical context")
	var key: String = SeasonPhysicalFixtures.request_key(season, fixture)
	var request: Dictionary = PhysicalRoundProcess.request_for(season, "expanded-test", key, fixture.id)
	check(request.get("version") == 11, "distinct worker11")
	check(PhysicalRoundProcess.decode_request(cold(request), "expanded-test") != null, "cold worker request restores")
	request.version = 7
	check(PhysicalRoundProcess.decode_request(request, "expanded-test") == null, "v5 worker rejects v6")
	for id: String in NEW_IDS:
		check(PhysicalPitchEvidence.recipe(id, ExpandedSeasonCatalog.signature()) != null, "v6 physical recipe admitted")
		check(PhysicalPitchEvidence.recipe(id, WorkingPitchCatalog.signature()) == null, "v5 physical context rejects new recipe")
	var legacy: SeasonState = WorkingPitchProgression.create_season(319)
	check(SeasonSave._decode(cold(SeasonSave.snapshot(legacy))) != null, "unchanged v5 season cold replay")

func _replacement_and_boundaries() -> void:
	var build: SeasonBuild = SeasonBuild.new(918, ROSTER)
	check(build.enable_expanded_pitch_catalog(), "fresh standalone boundary")
	var before: Dictionary = build.to_data()
	check(not build.enable_d1_pricing() and not build.enable_d3_sponsors() and not build.enable_d4_sponsors(), "v6 rejects unimplemented pricing/sponsor contexts")
	check(ClubCareer.same(before, build.to_data()), "rejected pricing contexts leave all state unchanged")
	var book: SeasonDevelopment = SeasonDevelopment.new("replacement:v6")
	book.enable_expanded_pitch_catalog()
	var original: String = NEW_IDS[0]
	check(book.commit({"id": "learn-original", "rev": 0, "op": "learn", "player": ROSTER[0], "target": original, "replace": ""}).ok, "replacement fixture learns exact new recipe")
	check(book.commit({"id": "master-original", "rev": 1, "op": "mastery", "player": ROSTER[0], "target": original}).ok, "original mastery raised")
	check(book.commit({"id": "replace-original", "rev": 2, "op": "learn", "player": ROSTER[0], "target": NEW_IDS[1], "replace": original}).ok, "replace active recipe without erasing personal mastery")
	check(book.player(ROSTER[0]).mastery[original] == 2 and not book.player(ROSTER[0]).active.has(original), "inactive mastery retained")
	var replay: SeasonDevelopment = SeasonDevelopment.from_data(cold(book.to_data()), book._season_key)
	check(replay != null and ClubCareer.same(replay.to_data(), book.to_data()), "removed recipe and mastery cold replay")
	if replay == null:
		return
	var learn: Dictionary = {"id": "reacquire", "rev": replay.revision(), "op": "learn", "player": ROSTER[0], "target": original, "replace": NEW_IDS[1]}
	check(replay.commit(learn).ok and replay.player(ROSTER[0]).mastery[original] == 2, "reacquisition restores exact personal mastery")
	var again: SeasonDevelopment = SeasonDevelopment.from_data(cold(replay.to_data()), replay._season_key)
	check(again != null and ClubCareer.same(again.to_data(), replay.to_data()), "reacquired mastery and journal survive cold restore")
	if again != null:
		var stable: Dictionary = again.to_data()
		check(again.commit(cold(learn)).replayed and ClubCareer.same(stable, again.to_data()), "reacquisition retry remains idempotent after restore")
