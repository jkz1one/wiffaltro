extends "res://src/tests/current_pitch_venue_boundaries_test.gd"
## Synthetic in-memory geometry/stock + retained balanced baseball operands.
## No earned career, selected owner, saved settlement, physical game or disk mutation.


func _ready() -> void:
	var catalog: String = WorkingPitchCatalog.signature()
	var context: Dictionary = {"pitch_catalog": catalog, "league_rules": {}, "ownership": []}
	var pool: Dictionary = _pool_venue(context)
	if not pool.is_empty():
		_check_wrapper(pool, context, "synthetic ownedPool14")
		_archive(pool, context)
		check(not CurrentPhysicalStadiumEvidence.core(pool, context).has("pool"),
			"ownedPool canonical core removes only component-specific evidence")
		_pool_negatives(pool, context)
		_human_pool(pool, context)
	var terrain: Dictionary = _terrain_venue(context)
	if not terrain.is_empty():
		_check_wrapper(terrain, context, "synthetic terrain26")
		_archive(terrain, context)
		for key: String in ["terrain", "inventory", "surface_access", "boundary", "geometry"]:
			var bad: Dictionary = terrain.duplicate(true)
			bad.property.erase(key)
			check(not CurrentPhysicalStadiumEvidence.valid(bad, context),
				"terrain component requires " + key)
		var changed: Dictionary = terrain.property.duplicate(true)
		changed.environment.seed += 1
		check(not CurrentPhysicalStadiumEvidence.matches(terrain, changed, context),
			"terrain expected fixture cannot change")
	print("Current owned/terrain checks: %d, failures: %d physical_games=0 synthetic=true" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _base_fixture(context: Dictionary) -> Dictionary:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://src/tests/fixtures/ac02-retained-first-ai-report17.json"))
	var body: Dictionary = StadiumNpcYardTwoReport._core(old)
	body["current_pitch_bound"] = context.pitch_catalog
	for team: Dictionary in body.teams:
		for id: String in team.roster:
			team.recipes[id].append(WorkingPitchCatalog.new_ids()[0])
	body["surfaces"] = []
	for index in range(body.plays.size()):
		check(body.plays[index].result not in ["triple", "home_run"],
			"balanced operand does not require a terminal contact")
		body.surfaces.append({"play": index, "reason": "synthetic_no_terminal", "events": []})
	return body


func _pool_venue(context: Dictionary) -> Dictionary:
	# Same bounded stock fixture as league_flat_home_exclusions_test. Funds and
	# progress are declared test inputs, never a claim of a played/earned career.
	var ledger: ClubAssetLedger = ClubAssetLedger.new(79,
		[10000, 10000, 10000, 10000, 10000, 10000],
		[{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3},
		{"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}, {"seasons": 1, "wins": 3}])
	for item: String in ["ST-079", "ST-006"]:
		var catalog: Dictionary = ClubConstruction.copy_catalog(item)
		var command: Dictionary = {"id": item, "rev": ledger.revision(), "op": "stadium_buy",
			"item": item, "quantity": 1, "price_version": catalog.price_version, "through": 6}
		if catalog.progress:
			command.progress_through = 6
		var purchased: Dictionary = ledger.commit(command)
		check(purchased.ok, "synthetic funding buys required stock " + item)
		if not purchased.ok:
			return {}
	var flat: Dictionary = StadiumSurfaceLayout.upgrade(ledger.view().stadium_active, ledger.surface_owned())
	flat.receiver = "purchase:ST-079:0"
	ledger._stadium_active = StadiumPoolOwnedLayout.upgrade(flat, ledger.construction(),
		ledger.surface_owned(), "backyard", "purchase:ST-006:0")
	var venue: Dictionary = _base_fixture(context)
	var snapshot: Dictionary = StadiumPoolOwnedSnapshot.fixture(
		StadiumPoolOwnedSnapshot.capture(ledger), int(venue.seed), 0)
	check(not snapshot.is_empty(), "complete synthetic ownedPool17 fixture")
	if snapshot.is_empty():
		return {}
	venue.version = StadiumPoolOwnedReport.VERSION
	venue.resolver = StadiumPoolOwnedReport.RESOLVER
	venue["property"] = snapshot
	venue["pool"] = {"version": StadiumPoolOwnedReport.EVIDENCE_VERSION,
		"copy": snapshot.layout.pool.copy,
		"pose": StadiumPoolMatchReport._pose(StadiumPoolOwnedLayout.pose(snapshot.layout)),
		"geometry": StadiumPoolOwnedLayout.signature(),
		"source_sha256": StadiumPoolPartyAssetIntegrity.source_sha256(),
		"water_commits": 0, "water_outcomes": []}
	return venue


func _terrain_venue(context: Dictionary) -> Dictionary:
	var ledger: ClubAssetLedger = ClubAssetLedger.new()
	var flat: Dictionary = StadiumSurfaceLayout.upgrade(ledger.view().stadium_active,
		ledger.surface_owned(), false)
	ledger._stadium_active = StadiumSurfaceLayout.terrain_upgrade(flat, ledger.surface_owned())
	var venue: Dictionary = _base_fixture(context)
	var snapshot: Dictionary = StadiumLayoutSnapshot.terrain_fixture(
		StadiumLayoutSnapshot.terrain_capture(ledger), int(venue.seed), 0)
	check(not snapshot.is_empty(), "complete synthetic terrain fixture")
	if snapshot.is_empty():
		return {}
	venue.version = PhysicalStadiumReport.TERRAIN_VERSION
	venue.resolver = PhysicalStadiumReport.TERRAIN_RESOLVER
	venue["property"] = snapshot
	return venue


func _pool_negatives(venue: Dictionary, context: Dictionary) -> void:
	for key: String in ["copy", "pose", "geometry", "source_sha256", "water_commits", "water_outcomes"]:
		var bad: Dictionary = venue.duplicate(true)
		bad.pool.erase(key)
		check(not CurrentPhysicalStadiumEvidence.valid(bad, context), "Pool requires " + key)
	var bad: Dictionary = venue.duplicate(true)
	bad.pool.copy = "foreign"
	check(not CurrentPhysicalStadiumEvidence.valid(bad, context), "Pool copy remains bound")
	bad = venue.duplicate(true)
	bad.pool.water_commits = 1
	check(not CurrentPhysicalStadiumEvidence.valid(bad, context), "water evidence cannot be invented")
	bad = venue.duplicate(true)
	bad.surfaces.clear()
	check(not CurrentPhysicalStadiumEvidence.valid(bad, context), "Pool surface chronology retained")
	check(not CurrentPhysicalStadiumEvidence.valid(venue, {}), "no catalog authority fails closed")
	var wrong: Dictionary = context.duplicate(true)
	wrong.pitch_catalog = "wrong"
	check(not CurrentPhysicalStadiumEvidence.valid(venue, wrong), "wrong catalog fails closed")


func _human_pool(venue: Dictionary, context: Dictionary) -> void:
	# Reconstruct count/PA chronology only from balanced retained operands. Every
	# recipe is deliberately synthetic/current. This validates the complete envelope
	# consumed at settled-Pool replay, not replay of an authorized paid owner itself.
	var human: Dictionary = {"version": StadiumPoolOwnedHumanEvidence.VERSION, "fixture": 0,
		"request": "a".repeat(64), "property": venue.property.duplicate(true),
		"away_runs": venue.away_runs, "home_runs": venue.home_runs,
		"performance": venue.performance.duplicate(true),
		"teams": [venue.teams[0].roster.duplicate(), venue.teams[1].roster.duplicate()],
		"plays": [], "base": venue.tactics.base.duplicate(true),
		"surfaces": venue.surfaces.duplicate(true), "pool": venue.pool.duplicate(true)}
	var balls: int = 0
	var strikes: int = 0
	var completed: int = 0
	for index in range(venue.plays.size()):
		if completed >= human.base.results.size():
			check(false, "base frontier available for every retained play")
			return
		var old: Dictionary = venue.plays[index]
		var ready: Dictionary = human.base.ready[completed]
		var row: Dictionary = {"play": index, "half": old.half, "batter": old.batter,
			"pitcher": old.pitcher, "recipe": WorkingPitchCatalog.new_ids()[0],
			"contact": old.contact, "exit_speed": old.exit_speed, "result": old.result,
			"balls": balls, "strikes": strikes, "outs": ready.outs, "runs": 0}
		var step: Dictionary = StadiumPoolOwnedHumanEvidence._step(row)
		check(not step.is_empty(), "retained result has a determinate count transition")
		if step.is_empty():
			return
		if not step.outcome.is_empty():
			row.runs = 0 if step.outcome == "walk" else int(human.base.results[completed].rbi)
			completed += 1
		balls = int(step.balls)
		strikes = int(step.strikes)
		human.plays.append(row)
	check(StadiumPoolOwnedHumanEvidence.valid(human, context.pitch_catalog),
		"complete new-recipe Pool human envelope validates with current context")
	check(StadiumPoolOwnedHumanEvidence.valid(JSON.parse_string(JSON.stringify(human, "", true, true)),
		context.pitch_catalog), "complete new-recipe Pool envelope cold JSON")
	check(not StadiumPoolOwnedHumanEvidence.valid(human), "historical Pool cannot accept current recipes")
	check(not StadiumPoolOwnedHumanEvidence.valid(human, "wrong"), "wrong current Pool context")
	var bad: Dictionary = human.duplicate(true)
	bad.plays[0].outs = (int(bad.plays[0].outs) + 1) % MatchState.OUTS_PER_HALF
	check(not StadiumPoolOwnedHumanEvidence.valid(bad, context.pitch_catalog), "Pool count chronology enforced")
	bad = human.duplicate(true)
	bad.pool.source_sha256 = "0".repeat(64)
	check(not StadiumPoolOwnedHumanEvidence.valid(bad, context.pitch_catalog), "Pool current source preserved")


func _archive(venue: Dictionary, context: Dictionary) -> void:
	var core: Dictionary = CurrentPhysicalStadiumEvidence.core(venue, context)
	if core.is_empty():
		return
	var report: Dictionary = {"version": 29, "resolver": CurrentPhysicalMatchReport.RESOLVER,
		"pitch_catalog": context.pitch_catalog, "league_rules": {}, "ownership": [{}, {}],
		"dynasty_start": [{}, {}], "pair": [{}, {}], "workload": [{}, {}], "uses": [],
		"physical": core, "venue": venue}
	for index in range(2):
		report.uses.append(core.tactics.teams[index].get("consumed", []))
	var archive: Dictionary = {"version": 1, "reports": [
		{"fixture": 0, "request": "a".repeat(64), "report": report}], "pending": {}}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(archive, "", true, true))
	var restored: SeasonPhysicalFixtures = SeasonPhysicalFixtures.from_data(parsed, context.pitch_catalog)
	check(restored != null and ClubCareer.same(restored.to_data(), parsed),
		"cold current archive preserves full component evidence")
	check(SeasonPhysicalFixtures.from_data(parsed) == null,
		"cold archive cannot infer authority from self-reported catalog")
	check(SeasonPhysicalFixtures.from_data(parsed, "wrong") == null,
		"cold archive rejects wrong expected catalog")
