extends "res://src/tests/stadium_scoreboard_physical_test.gd"
## Paid normal runner, report13 replay and installed-world QC integrity without worker admission.

var _mounted_checks: int = 0


func _ready() -> void:
	SeasonSave.path = "user://mounted-scoreboard-physical-%d.json" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	_begin(app)
	if _failures == 0:
		await _production(app)
	app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	for suffix: String in ["", ".tmp"]:
		DirAccess.remove_absolute(_export_path() + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard physical passed: report13 replay and paid QC integrity.")
	print("MOUNTED_PHYSICAL_RESULT ", JSON.stringify({"checks": _mounted_checks,
		"failures": _failures, "physical_reports": _reports.size()}))
	get_tree().quit(0 if _failures == 0 else 1)


func _begin(app: SeasonApp) -> void:
	super._begin(app)
	_check(StadiumMountedScoreboardLayout.RUNTIME_READY, "mounted production gate is open")
	if _failures > 0:
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	_owned_layout = StadiumMountedScoreboardLayout.upgrade(_owned_layout, ledger.construction(),
		ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards())
	_check(not _owned_layout.is_empty(), "exact paid complete14 upgrades without new ownership")
	if not _owned_layout.is_empty():
		_owned_layout.scoreboards[0].site = StadiumScoreboardMountCatalog.CENTER_SITE
		_owned_layout.scoreboards[0].mount_profile = StadiumScoreboardMountCatalog.CENTER_PROFILE


func _production(app: SeasonApp) -> void:
	var season: SeasonState = app.season
	var revision: int = ClubPlayers.assets(season.career).revision()
	var before_balance: int = season.career.balance()
	_check(ClubConstruction.save_draft(season, _layout(), revision).ok,
		"normal mounted Save Draft persists zero-cost proposal")
	_check(ClubConstruction.apply_draft(season, _layout(), revision + 1).ok,
		"normal mounted Apply freezes entry14 atomically")
	if _failures > 0:
		return
	_check(season.home_property.version == 14 and season.home_property.layout.version == 15,
		"normal construction captures exact new entry without test-side replacement")
	for pick in range(4):
		app.choose_player(season.offers()[0])
	var fixture: Dictionary = {}
	for game: Dictionary in season.schedule:
		if _select_fixture(season, game):
			fixture = game
			break
	_check(not fixture.is_empty(), "scheduled home fixture exists")
	if fixture.is_empty():
		return
	var source: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var seed: int = int(source.stadium.environment.seed)
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(func(report: Dictionary) -> void: _reports.append(report))
	runner.failed.connect(func(reason: String) -> void: _errors.append(reason))
	_check(not runner.start(source, seed), "mounted startup without paid ledger fails closed")
	_check(not runner.start(source, seed, SeasonState.AWAY_FIELD_ID, ledger),
		"mounted home cannot enter an ordinary away venue")
	_check(runner.start(source, seed, PitchBatLab.FIELD_ID, ledger),
		"normal typed-proof runner installs mounted fixture15")
	if runner._lab == null:
		runner.queue_free()
		return
	_check(StadiumBoundaryRuntime.installed(runner._lab, source.stadium),
		"public boundary dispatcher verifies mounted installed-world and paid prefix")
	var frozen: Dictionary = source.stadium.duplicate(true)
	source.stadium.layout.scoreboards.clear()
	_check(ClubCareer.same(runner._lab._match_state.stadium, frozen),
		"running mounted world owns a detached immutable match snapshot")
	source.stadium = frozen
	await _qualified_capture(runner)
	await _complete(1)
	_check(_reports.size() == 1 and _errors.is_empty(), "first mounted game produces real report13")
	if _reports.size() != 1:
		runner.cancel()
		runner.queue_free()
		return
	_tamper(_reports[0], source)
	_check(runner.start(source, seed, PitchBatLab.FIELD_ID, ledger),
		"same frozen fixture and paid proof restart deterministically")
	await _complete(2)
	_check(_reports.size() == 2 and _errors.is_empty(), "second real mounted game completes")
	if _reports.size() == 2:
		_check(ClubCareer.same(_reports[0], _reports[1]),
			"report13 replay preserves exact baseball, contact and property evidence")
	_check(FileAccess.get_file_as_string(SeasonSave.path) == original
		and SeasonSave.restore() != null and season.career.balance() == before_balance,
		"detached mounted qualification never changes paid ownership or awards money")
	runner.cancel()
	runner.queue_free()


func _qualified_capture(runner: PhysicalMatchRunner) -> void:
	runner.set_process(false)
	for frame in range(200000):
		if runner._lab._match_state.phase == MatchState.Phase.GAME_END:
			break
		await get_tree().process_frame
	_check(runner._lab._match_state.phase == MatchState.Phase.GAME_END,
		"real mounted game completes before report-integrity probes")
	if runner._lab._match_state.phase == MatchState.Phase.GAME_END:
		_capture_integrity(runner._lab)
	runner.set_process(true)


func _capture_integrity(lab: PitchBatLab) -> void:
	var original: Dictionary = PhysicalMatchReport.capture(lab)
	_check(PhysicalMatchReport.valid(original) and original.version == 13,
		"completed real game qualifies report13 before integrity mutation")
	if original.is_empty():
		return
	var proof: ClubAssetLedger = lab._stadium_ledger
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var model: Node3D = property.board_objects.values()[0]
	var transform: Transform3D = model.transform
	model.position.x += 1
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"real completed capture rejects moved center assembly despite valid baseball")
	model.transform = transform
	lab._stadium_ledger = null
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"real completed capture requires paid ledger on every call")
	lab._stadium_ledger = proof.prefix(proof.revision() - 1)
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"real completed capture rejects stale paid prefix despite unchanged world")
	lab._stadium_ledger = proof
	lab.set_meta("stadium_snapshot", false)
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"real completed capture safely rejects malformed frozen metadata")
	lab.set_meta("stadium_snapshot", original.property.duplicate(true))
	lab.set_meta("stadium_candidate_only", false)
	_check(PhysicalMatchReport.capture(lab).is_empty(),
		"candidate marker presence cannot authenticate completed production baseball")
	lab.remove_meta("stadium_candidate_only")
	_check(ClubCareer.same(PhysicalMatchReport.capture(lab), original),
		"restored installed world and paid proof reproduce exact completed report13")


func _tamper(report: Dictionary, source: MatchState) -> void:
	_check(report.version == PhysicalStadiumReport.MOUNTED_VERSION
		and report.resolver == PhysicalStadiumReport.MOUNTED_RESOLVER
		and report.property.version == 15 and report.property.layout.version == 15
		and report.property.layout.mount_catalog == 1
		and report.property.environment.mode == "day" and report.property.environment.profile == ""
		and PhysicalMatchReport.valid(report)
		and PhysicalChoiceEvidence.matches(report, source)
		and PhysicalTacticalEvidence.report_matches(report, source),
		"report13 binds exact fixture15/layout15/catalog1 with unchanged baseball authority")
	_check(PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))),
		"mounted report survives canonical JSON replay")
	var expected: Dictionary = report.duplicate(true)
	expected.erase("property")
	expected.erase("surfaces")
	expected.version = PhysicalMatchReport.BASE_VERSION
	expected.resolver = PhysicalMatchReport.BASE_RESOLVER
	_check(ClubCareer.same(PhysicalStadiumReport.core(report), expected)
		and PhysicalMatchReport.valid(expected), "mounted core remains exact report7 baseball evidence")
	_wrapper_edges(report)
	_inventory_edges(report)
	_contacts(report)
	_fixture_authority(report, source)
	_save_edges(source)
	_runner_edges(source)
	var metadata: Dictionary = PlayRecordExport.field_metadata(
		ContentDB.get_field(PitchBatLab.FIELD_ID), report.property)
	var graph: StadiumRecipeBoundary = StadiumOwnedLayout.graph_for(report.property.layout)
	_check(metadata.get("wall_m") == 27.5
		and metadata.get("wall_sections", []).size() == graph.segments().size()
		and metadata.get("property_key") == StadiumLayoutSnapshot.key(report.property),
		"mounted export uses real joined wall sections and exact frozen property key")


func _wrapper_edges(report: Dictionary) -> void:
	_seed_edges(report)
	var resolvers: Dictionary = {8: PhysicalStadiumReport.LEGACY_RESOLVER,
		9: PhysicalStadiumReport.RESOLVER, 10: PhysicalStadiumReport.RECIPE_RESOLVER,
		11: PhysicalStadiumReport.SURFACE_RESOLVER, 12: PhysicalStadiumReport.SCOREBOARD_RESOLVER}
	for version: int in resolvers:
		var bad: Dictionary = report.duplicate(true)
		bad.version = version
		bad.resolver = resolvers[version]
		if version == 8:
			bad.erase("surfaces")
		_reject_report(bad, report.property, "old report wrapper cannot impersonate mounted ownership")
	for version: Variant in [true, 13.5, 14, 15, 99]:
		var bad: Dictionary = report.duplicate(true)
		bad.version = version
		_reject_report(bad, report.property, "malformed and future report ceilings reject consistently")
	var entry: Dictionary = _season.home_property.duplicate(true)
	var bad: Dictionary = report.duplicate(true)
	bad.property = entry
	_check(StadiumLayoutSnapshot.valid(entry), "entry14 remains a valid ownership declaration")
	_reject_report(bad, report.property, "entry14 never impersonates playable fixture15")
	_check(PhysicalStadiumReport.wrap(PhysicalStadiumReport.core(report), entry,
		report.surfaces).is_empty(), "wrapping valid baseball does not promote entry14 into a fixture")
	for field: String in ["catalog", "catalog_type", "geometry", "boundary", "seed", "teams"]:
		bad = report.duplicate(true)
		match field:
			"catalog": bad.property.layout.mount_catalog = 2
			"catalog_type": bad.property.layout.mount_catalog = true
			"geometry": bad.property.geometry = "forged"
			"boundary": bad.property.boundary = "forged"
			"seed": bad.property.environment.seed += 1
			"teams": bad.teams = []
		_check(not PhysicalMatchReport.valid(bad) and not PhysicalStadiumReport.valid(bad),
			"report13 rejects changed mounted context or baseball evidence: " + field)
	bad = report.duplicate(true)
	bad.property.environment.fixture = (int(bad.property.environment.fixture) + 1) % 30
	_check(PhysicalMatchReport.valid(bad)
		and not PhysicalStadiumReport.matches(bad, report.property),
		"structurally valid foreign fixture cannot match the frozen expected fixture")


func _seed_edges(report: Dictionary) -> void:
	for seed: Variant in [null, true, false, [], {}, "x", str(report.seed), NAN, INF,
		-INF, -1, 2147483648, float(report.seed) + 0.5]:
		var bad: Dictionary = report.duplicate(true)
		bad.seed = seed
		_reject_report(bad, report.property,
			"malformed top-level seed rejects before unlike-type fixture comparison")
	var missing: Dictionary = report.duplicate(true)
	missing.erase("seed")
	_reject_report(missing, report.property, "missing top-level seed rejects safely")
	for seed: Variant in [int(report.seed), float(report.seed)]:
		var accepted: Dictionary = report.duplicate(true)
		accepted.seed = seed
		_check(PhysicalMatchReport.valid(accepted)
			and PhysicalMatchReport.valid(PhysicalStadiumReport.core(accepted))
			and PhysicalStadiumReport.matches(accepted, report.property),
			"integer and integral-float report seed representations remain accepted")


func _save_edges(source: MatchState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(_season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_season.career)
	_check(saved.version == 63 and saved.home_property.version == 14
		and StadiumLayoutSnapshot.matches(saved.home_property, ledger)
		and StadiumLayoutSnapshot.capture(ledger, false).is_empty(),
		"current save63 carries paid entry14 and refuses incomplete-boundary capture")
	var loaded: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true)))
	_check(loaded != null and StadiumLayoutSnapshot.key(loaded.home_property)
		== StadiumLayoutSnapshot.key(saved.home_property), "entry14 restores with identical ownership")
	# Retain the original save59 contract separately from modern NPC/final venues.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var legacy_loaded: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	_check(legacy_loaded != null and legacy_loaded.npc_venues.is_empty()
		and legacy_loaded.final_venue.is_empty()
		and StadiumLayoutSnapshot.key(legacy_loaded.home_property)
		== StadiumLayoutSnapshot.key(saved.home_property),
		"historical save59 restores exact paid entry14 without invented venue assignments")
	_check(loaded != null and ClubCareer.same(loaded.npc_venues, _season.npc_venues)
		and ClubCareer.same(loaded.final_venue, _season.final_venue),
		"full-precision save63 restores exact NPC and neutral-final assignments")
	var lossy: Dictionary = JSON.parse_string(JSON.stringify(saved))
	_check(not ClubCareer.same(lossy.npc_venues, saved.npc_venues)
		and SeasonSave._decode(lossy) == null,
		"lossy fixture serialization cannot silently rewrite signed venue geometry")
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property = source.stadium.duplicate(true)
	_check(SeasonSave._decode(bad) == null, "current home entry rejects playable fixture15")
	bad = saved.duplicate(true)
	bad.home_property.scoreboard_inventory.copies["scoreboard:invented:0"] = {
		"item": "ST-090", "paid": 160, "source": "purchase-scoreboard-v1"}
	_check(StadiumLayoutSnapshot.valid(bad.home_property) and SeasonSave._decode(bad) == null,
		"same-looking unused board without actual paid history never restores")


func _runner_edges(source: MatchState) -> void:
	var probe: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(probe)
	var ledger: ClubAssetLedger = ClubPlayers.assets(_season.career)
	var seed: int = int(source.stadium.environment.seed)
	_check(not probe.start(source, seed + 1, PitchBatLab.FIELD_ID, ledger),
		"mounted runner refuses wrong seed before world mutation")
	var entry: MatchState = PhysicalMatchRequest.capture(source)
	entry.stadium = _season.home_property.duplicate(true)
	_check(not probe.start(entry, seed, PitchBatLab.FIELD_ID, ledger),
		"mounted runner refuses entry14 before world mutation")
	_check(not probe.start(source, seed, PitchBatLab.FIELD_ID,
		ledger.prefix(ledger.revision() - 1)), "incomplete paid prefix cannot start mounted fixture")
	_check(probe.start(source, seed, PitchBatLab.FIELD_ID, ledger),
		"normal production adapter accepts exact full paid proof")
	if probe._lab != null:
		_export_checks(probe._lab, source.stadium)
	probe.cancel()
	probe.queue_free()


func _export_checks(lab: PitchBatLab, snapshot: Dictionary) -> void:
	var automation: MatchAutomation = lab._automation
	var proof: ClubAssetLedger = lab._stadium_ledger
	lab._automation = null
	lab._record_export.path = _export_path()
	_check(PitchBatLabFeelSupport._save_records(lab), "normal mounted QC writes exact installed field")
	var bytes: String = FileAccess.get_file_as_string(_export_path())
	var payload: Variant = JSON.parse_string(bytes)
	_check(payload is Dictionary and payload.schema_version == 2
		and payload.field.property_key == StadiumLayoutSnapshot.key(snapshot)
		and ClubCareer.same(payload.property, StadiumLayoutSnapshot.normalized(snapshot)),
		"mounted QC retains export2 with complete immutable property")
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var model: Node3D = property.board_objects.values()[0]
	var transform: Transform3D = model.transform
	model.position.x += 1.0
	_export_refused(lab, bytes, "displaced mounted board cannot label QC with frozen property")
	model.transform = transform
	lab._stadium_ledger = null
	_export_refused(lab, bytes, "missing typed proof cannot authenticate normal QC")
	lab._stadium_ledger = proof.prefix(proof.revision() - 1)
	_export_refused(lab, bytes, "stale paid prefix cannot authenticate normal QC")
	lab._stadium_ledger = proof
	lab.set_meta("stadium_candidate_only", false)
	_export_refused(lab, bytes, "candidate marker presence is never production QC authority")
	lab.remove_meta("stadium_candidate_only")
	lab.set_meta("stadium_snapshot", false)
	_export_refused(lab, bytes, "malformed installed snapshot fails safely")
	lab.set_meta("stadium_snapshot", snapshot.duplicate(true))
	_check(StadiumBoundaryRuntime.installed(lab, snapshot)
		and PitchBatLabFeelSupport._save_records(lab),
		"restoring actual world and paid proof permits QC retry")
	lab._automation = automation


func _export_refused(lab: PitchBatLab, bytes: String, message: String) -> void:
	_check(not PitchBatLabFeelSupport._save_records(lab)
		and FileAccess.get_file_as_string(_export_path()) == bytes, message)


func _export_path() -> String:
	return "user://mounted-scoreboard-qc-%d.json" % OS.get_process_id()


func _reject_report(value: Dictionary, expected: Dictionary, message: String) -> void:
	_check(not PhysicalMatchReport.valid(value) and PhysicalStadiumReport.core(value).is_empty()
		and not PhysicalStadiumReport.matches(value, expected), message)


func _check(ok: bool, message: String) -> void:
	_mounted_checks += 1
	super._check(ok, message)
