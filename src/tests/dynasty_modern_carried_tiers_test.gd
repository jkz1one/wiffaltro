extends "res://src/tests/dynasty_career_tier_test.gd"
## Four real fresh carried replay profiles with explicitly synthetic prerequisite titles.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Home = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_carried_home_proposal.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const CareerLineage = preload("res://src/gameplay/season/dynasty_career_lineage.gd")
func _ready() -> void:
	_run_modern()
	print("MODERN_CARRIED_TIERS %d checks, %d failures; synthetic_titles=true; physical_games=0" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run_modern() -> void:
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = Fixture.nonphysical_dynasty_source()
	var prior: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(prior._seed, prior._credits, prior._progress, prior._championships).to_data()
	check(source.career.start(source), "genuine constructor source starts")
	for pick in range(4): source.choose_player(source.offers()[0])
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "tier-lineage", "tier-owner")
	var base: SeasonState = Bridge.create(profile)
	var base_session: Dictionary = Save.binding_for(base, "tier-owner", "tier-lineage", 0, 1, "tier-lineage:1")
	var base_save: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(base), base_session)
	var created: Dictionary = Owner.project({}, {"op": "create", "request_id": "modern-tier-origin", "expected_revision": 0,
		"payload": {"lineage": Lineage.create(profile), "snapshot": base_save, "session_id": base_session.session_id, "origin": origin}})
	check(not created.is_empty(), "source-qualified owner skeleton")
	if created.is_empty(): return
	var authority: Dictionary = Authority.create(origin, "tier-owner")
	for game in range(12):
		if source.phase == SeasonState.Phase.COMPLETE: break
		var fixture: Dictionary = source.pending_fixture()
		source.record_player_result(fixture.id, 0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0)
	if source.phase != SeasonState.Phase.COMPLETE or not source.career.sync(source):
		check(false, "synthetic champion operands")
		return
	var row: Dictionary = source.career.runs[-1]
	for tier in range(1, 5):
		check(tier not in Authority.available_tiers(authority, "dynasty"), "own title required before tier " + str(tier))
		authority = _synthetic_title(authority, row, tier - 1)
		check(not authority.is_empty(), "qualified synthetic preceding Dynasty title")
		if authority.is_empty(): return
		check(tier in Authority.available_tiers(authority, "dynasty") and Authority.available_tiers(authority, "dugout") == [0],
			"only Dynasty ladder unlocks tier " + str(tier))
		var lineage: Dictionary = CareerLineage.rebase(Lineage.create(profile), Authority.access(authority))
		check(not lineage.is_empty(), "exact source access rebase")
		if lineage.is_empty(): return
		var season: SeasonState = Bridge.create(lineage.start_profile, true, tier)
		var session: Dictionary = Save.binding_for(season, "tier-owner", "tier-lineage", 0, 1, "tier-lineage:1")
		var snapshot: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(season), session)
		var owner: Dictionary = created.owner.duplicate(true)
		owner.lineage = lineage
		owner.career = Authority.open_session(authority, snapshot)
		var installed: Dictionary = Owner._install(owner, "dynasty", snapshot) if not owner.career.is_empty() else {}
		check(not installed.is_empty(), "tier85 owner session opens")
		if installed.is_empty(): return
		owner.lineage = Owner._capture(lineage, installed)
		owner = Owner.normalize(owner)
		check(not owner.is_empty(), "synthetic owner metadata remains coherent")
		if owner.is_empty(): return
		var envelope: Dictionary = Proposal.prepare(owner, snapshot)
		var header: Dictionary = Home.header(envelope)
		var checked: Dictionary = Home.qualify(envelope, header)
		check(not checked.is_empty(), "modern carried tier replay " + str(tier))
		if checked.is_empty(): return
		check(envelope.checkpoint.version == 85 and envelope.checkpoint.checkpoint.version == 84
			and envelope.checkpoint.checkpoint.checkpoint.version == 86, "exact85/84/86 grammar")
		check(checked.season.picks == season.picks and ClubCareer.same(checked.season.build.to_data(), season.build.to_data())
			and ClubCareer.same(checked.season._dynasty_start, lineage.start_profile), "exact carried roster build start")
		check(not Home.qualify(JSON.parse_string(JSON.stringify(envelope, "", true, true)), header).is_empty(), "cold tier replay")
		for field: String in ["session", "lineage", "grant", "home_property"]:
			var bad: Dictionary = envelope.duplicate(true)
			bad[field] = {}
			check(Home.qualify(bad, Home.header(bad)).is_empty(), "changed " + field + " refused")
		var bad: Dictionary = envelope.duplicate(true)
		bad.checkpoint.checkpoint.dynasty_start.roster.reverse()
		check(Home.qualify(bad, header).is_empty(), "changed carried start refused")
		bad = envelope.duplicate(true)
		bad.checkpoint.checkpoint.checkpoint.version = 76
		check(Home.qualify(bad, header).is_empty(), "Base grammar downgrade refused")
