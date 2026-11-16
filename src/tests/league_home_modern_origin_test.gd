extends "res://src/tests/dynasty_league_home_live_owner_test.gd"
## Synthetic eligibility and isolated owner protocol, never physical play evidence.
const Runtime = preload("res://src/gameplay/season/dynasty_league_home_runtime.gd")


func check(ok: bool, label: String) -> void:
	print("MODERN_ORIGIN_CHECK ", checks + 1, " ", ok, " ", label)
	super.check(ok, label)


func _source() -> SeasonState:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = Fixture.prefix([
		{"league": "standard", "tier": 0}, {"league": "sponsorship", "tier": 0},
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3},
		{"league": "equipment", "tier": 0}])
	var prior: ClubAssetLedger = ClubPlayers.assets(source.career)
	# Same production new_club constructor and exact synthetic earned prefix.
	source.career._assets = ClubAssetLedger.new_club(prior._seed, prior._credits,
		prior._progress, prior._championships).to_data()
	check(ClubCareer.from_data(source.career.to_data()) != null, "modern origin validates")
	return source


func _step(op: String, operands: Dictionary) -> Dictionary:
	if op == "close":
		_modern_controls()
	return super._step(op, operands)


func _modern_controls() -> void:
	var owner: Dictionary = Store.inspect(path).owner
	var before: Dictionary = _files(path.get_base_dir())
	var season: SeasonState = SeasonSave.restore()
	check(season != null and Bound.modern_origin(season.home_property), "cold modern origin retained")
	if season == null:
		return
	var paid: ClubAssetLedger = Runtime.paid_ledger(season)
	check(paid != null and paid.view().surface_origin == StadiumSurfaceProgression.ROUGH_ORIGIN,
		"saved selected owner grants exact rough-dirt paid ledger")
	if paid == null:
		return
	check(paid.construction().copies.has(StadiumStock.SALVAGE_COPY)
		and season.home_property.layout.salvage_cars == [{"copy": StadiumStock.SALVAGE_COPY,
			"site": StadiumSalvageCarItems.SITE}], "exact salvage copy remains installed and owned")
	check(ClubCareer.same(season.home_property, StadiumLayoutSnapshot.capture(paid, true)),
		"full geometry inventory surface boundary revision retained")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var canonical: String = JSON.stringify(saved, "", true, true)
	var cold: Dictionary = JSON.parse_string(canonical)
	check(not _qualified(cold, owner).is_empty(), "modern full JSON owner replay")
	check(SeasonSave._decode(cold) != null, "selected owner public decode exact modern snapshot")
	var home_fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool:
		return row.home == 0)[0]
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, home_fixture)
	check(state != null and state.stadium.get("version") == 9,
		"natural scheduled home constructs fixture9 without changing schedule")
	if state != null:
		check(StadiumLayoutSnapshot.valid(state.stadium)
			and StadiumLayoutSnapshot.matches(state.stadium, paid)
			and state.stadium.environment.mode == "day" and state.stadium.environment.profile == "",
			"existing complete surface fixture contract and day environment")
		check(not SeasonPhysicalFixtures.request_key(season, home_fixture).is_empty(),
			"surface resolver request binds exact league and owned field")
		_configure_controls(state, paid)
	var original_binding: Dictionary = season._dynasty_owner_binding.duplicate(true)
	season._dynasty_owner_binding = {}
	check(Runtime.paid_ledger(season) == null, "transient qualified grant cannot authorize paid runtime")
	season._dynasty_owner_binding = original_binding.duplicate(true)
	season._dynasty_owner_binding.revision += 1
	check(Runtime.paid_ledger(season) == null, "stale revision cannot authorize paid runtime")
	season._dynasty_owner_binding = original_binding.duplicate(true)
	var changed: SeasonState = _qualified(saved, owner).season
	changed._dynasty_owner_binding = original_binding.duplicate(true)
	changed._pool_replay_ledger = ClubAssetLedger.new()
	check(Runtime.paid_ledger(changed) == null, "legacy replacement ledger refuses modern field")
	changed = _qualified(saved, owner).season
	changed.owned_surface_night = {"version": 1}
	check(not Bound.matches(changed) and Bound.capture(changed).is_empty(), "night policy remains refused")
	_negative_envelopes(saved, owner)
	_transport_controls(season, saved)
	_all_profiles(owner, saved.home_property)
	check(JSON.stringify(saved, "", true, true) == canonical, "controls never rewrite frozen checkpoint")
	check(ClubCareer.same(before, _files(path.get_base_dir())), "read-only controls leave owner bytes exact")
	check(ClubCareer.same(owner, Store.inspect(path).owner), "no duplicate grant debit settlement or revision")
	print("MODERN_ORIGIN_CONTROLS complete; physical_games=0")


func _qualified(value: Dictionary, owner: Dictionary) -> Dictionary:
	# A committed session replays its frozen admission grant, not a fresh grant
	# from the subsequently advanced authority revision.
	var entry: Dictionary = owner.career.sessions[owner.other.session_id]
	return Bound.qualify_bound(value, entry.session, entry.league_home_grant, entry.home_property)


func _configure_controls(state: MatchState, paid: ClubAssetLedger) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = state
	lab._stadium_ledger = paid
	check(not StadiumSurfaceTerrainRuntime.configure(lab, paid),
		"flat modern dirt cannot impersonate explicit physical terrain")
	check(not StadiumPropertyRuntime.install_bound(lab),
		"off-tree match setup is not installed-world qualification")
	check(PhysicalMatchReport.capture(lab).is_empty(),
		"match setup alone cannot manufacture a physical report")
	lab.free()


func _negative_envelopes(saved: Dictionary, owner: Dictionary) -> void:
	for field: String in ["inventory", "surface_access", "layout", "boundary", "geometry", "revision"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.home_property.erase(field)
		check(_qualified(bad, owner).is_empty(), "missing frozen " + field + " refused")
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.layout.surface.condition = "leveled"
	check(_qualified(bad, owner).is_empty(), "changed surface state refused")
	for version: int in [3, 9, 28, 29, 41, 46, 47]:
		bad = saved.duplicate(true)
		bad.home_property.version = version
		check(_qualified(bad, owner).is_empty(), "wrong entry family %d refused" % version)
	for version: int in [39, 41, 42, 46, 47]:
		bad = saved.duplicate(true)
		bad.home_property.layout.version = version
		check(_qualified(bad, owner).is_empty(), "later or other layout %d refused" % version)
	bad = saved.duplicate(true)
	bad.home_property.inventory.copies.erase(StadiumStock.SALVAGE_COPY)
	check(_qualified(bad, owner).is_empty(), "missing owned salvage identity refused")
	bad = saved.duplicate(true)
	bad.home_property.layout.salvage_cars = []
	check(_qualified(bad, owner).is_empty(), "stripped starter salvage refuses")
	bad = saved.duplicate(true)
	bad.home_property["environment"] = {"mode": "night"}
	check(_qualified(bad, owner).is_empty(), "entry cannot smuggle night environment")
	bad = saved.duplicate(true)
	bad.session.tier = 1
	check(_qualified(bad, owner).is_empty(), "changed tier cannot replace the frozen session")
	var raw: Dictionary = Bound.unbound(saved.checkpoint.duplicate(true), saved.session)
	check(Closed.Owned.decode_setup(raw) != null, "unplayed historical core remains its closed setup grammar")
	var core: Dictionary = Closed.core(raw)
	core["home_property"] = saved.home_property.duplicate(true)
	check(Closed.Owned.decode_setup(raw) == null, "old closed decoder never accepts modern home")
	bad = saved.duplicate(true)
	var report: Dictionary = {"version": PhysicalStadiumReport.TERRAIN_VERSION,
		"resolver": PhysicalStadiumReport.TERRAIN_RESOLVER, "property": saved.home_property.duplicate(true)}
	Closed.core(Bound.unbound(bad.checkpoint, bad.session)).physical.reports.append({"fixture": 1, "request": "", "report": report})
	check(_qualified(bad, owner).is_empty(), "unplayed terrain report cannot pass new replay")
	check(SeasonSave._decode(report) == null, "terrain report is never a season checkpoint")


func _transport_controls(season: SeasonState, saved: Dictionary) -> void:
	var request: Dictionary = PhysicalRoundProcess.request_for(season, "modern-token", "key", 0)
	check(request.get("version") == 3, "existing request3 carries modern selected owner")
	if request.is_empty():
		return
	var decoded: SeasonState = PhysicalRoundProcess.decode_request(
		JSON.parse_string(JSON.stringify(request, "", true, true)), "modern-token")
	check(decoded != null and ClubCareer.same(SeasonSave.snapshot(decoded), saved)
		and Runtime.paid_ledger(decoded) != null, "process cold decode retains full paid modern field")
	for version: int in [1, 2]:
		var bad: Dictionary = request.duplicate(true)
		bad.version = version
		if version == 1:
			bad.erase("owner")
		check(PhysicalRoundProcess.decode_request(bad, "modern-token") == null,
			"historical process request%d stays closed" % version)
	var bad: Dictionary = request.duplicate(true)
	bad.owner.revision += 1
	check(PhysicalRoundProcess.decode_request(bad, "modern-token") == null, "transport refuses stale owner")
	bad = request.duplicate(true)
	bad.season.home_property.layout.surface.condition = "leveled"
	check(PhysicalRoundProcess.decode_request(bad, "modern-token") == null, "transport refuses changed surface")


func _all_profiles(owner: Dictionary, home: Dictionary) -> void:
	var grant: Dictionary = Grant.capture(owner.career)
	for league: String in Bound.BASE_LEAGUES:
		var session: Dictionary = Closed.binding({"owner_id": owner.owner_id,
			"lineage_id": owner.lineage.id, "generation": 0, "ordinal": 1,
			"session_id": "modern-" + league, "seed": 38201, "tier": 0, "league": league,
			"access_sha256": ClosedContentAccess.digest(grant.access)})
		var prepared: Dictionary = Bound.prepare(owner.career, session)
		check(not prepared.is_empty(), league + " exact Base modern proposal")
		if prepared.is_empty():
			continue
		var live: SeasonState = Bound.qualify(prepared, owner.career).get("season")
		check(live != null and ClubCareer.same(live.home_property, home)
			and ClubCareer.same(live.player_access, grant.player_access), league + " frozen field and draft")
		if live == null:
			continue
		for pick in range(4):
			check(live.choose_player(live.offers()[0]), league + " ordinary owned draft")
		check(SeasonInventoryRules.enable(live), league + " exact inventory rules")
		var checkpoint: Dictionary = Bound.capture(live)
		var restored: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(checkpoint, "", true, true)), owner.career)
		check(not checkpoint.is_empty() and not restored.is_empty(), league + " JSON draft inventory replay")
		check(Runtime.paid_ledger(live) == null, league + " unadmitted proposal has no runtime authority")
		var fixture: Dictionary = live.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
		var home_fixture: Dictionary = StadiumLayoutSnapshot.for_fixture(live, fixture)
		check(home_fixture.get("version") == 9 and StadiumLayoutSnapshot.valid(home_fixture),
			league + " scheduled home retains existing fixture9")
		check(SeasonPhysicalFixtures.match_for(live, live.pending_fixture()) != null,
			league + " actual next match reconstructs")
		if league == "doubleheader":
			check(SeasonPhysicalFixtures.match_for(live, fixture) == null,
				"future Doubleheader home refuses missing genuine first-leg workload")


func _files(root: String) -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at(root):
		result[file] = FileAccess.get_sha256(root.path_join(file))
	for folder: String in DirAccess.get_directories_at(root):
		result[folder] = _files(root.path_join(folder))
	return result
