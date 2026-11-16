extends "res://src/tests/dynasty_career_authority_test.gd"
## Actual fresh replay checks plus explicitly synthetic ladder/receipt operands.
## No played physical season or naturally earned Dynasty championship is claimed.


func _ready() -> void:
	var source: SeasonState = _origin()
	if source == null:
		_finish_tiers()
		return
	var origin: Dictionary = SeasonSave.snapshot(source)
	var authority: Dictionary = Authority.create(origin, "tier-owner")
	var start: Dictionary = Profile.capture_access_season(origin, "tier-lineage", "tier-owner")
	check(not authority.is_empty() and not start.is_empty(), "source-qualified initial origin")
	if authority.is_empty() or start.is_empty():
		_finish_tiers()
		return
	var staging: SeasonState = SeasonState.create_closed_league(13004,
		LeagueRules.capture("dugout"), false, Authority.access(authority))
	var old_raw: Dictionary = SeasonSave.snapshot(staging)
	check(old_raw.get("version") == 80 and old_raw.checkpoint.version == 75
		and SeasonSave._decode(old_raw) != null and not Save.core(old_raw).is_empty(),
		"retained non-live raw80 profile75 core extraction stays supported")
	for tier in range(5):
		_raw_tier(start, authority, tier)
	for league: String in ["dugout", "sponsorship", "academy", "doubleheader",
		"equipment", "earnings", "scramble"]:
		_alternate_tier(authority, league)
	_ladder(authority, source, start)
	_finish_tiers()


func _origin() -> SeasonState:
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = ClubCareer.new()
	if not source.career.start(source):
		return null
	for pick in range(4):
		if not source.choose_player(source.offers()[0]):
			return null
	return source


func _raw_tier(start: Dictionary, authority: Dictionary, tier: int) -> void:
	var before: Dictionary = start.duplicate(true)
	var season: SeasonState = Bridge.create(start, true, tier)
	check(season != null, "fresh carried roster at tier " + str(tier))
	if season == null:
		return
	check(ClubCareer.same(start, before) and season.picks == start.roster
		and ClubCareer.same(season._dynasty_start, start),
		"tier selection never decays or redrafts human")
	check(season.league_rules.version == (1 if tier == 0 else 4)
		and season.league_rules.tier == tier, "distinct immutable Dynasty rule version")
	check((tier > 0) == season.build.d1_pricing_valid()
		and (tier == 3) == season.build.d3_sponsors_valid()
		and (tier == 4) == season.build.d4_sponsors_valid(), "existing cumulative economics")
	check(season.opponents.clubs.size() == 5, "all five opponent builds initialized")
	for club: Dictionary in season.opponents.clubs.values():
		check(club.build._league_rules == season.league_rules
			and (tier == 0 or club.build._bank._term_seed == club.build._seed),
			"same tier, own opponent sponsor seed")
	if tier >= 2:
		var remaining: Array[String] = []
		for id: String in season.draft_pool:
			if id not in start.roster:
				remaining.append(id)
		var expected: Dictionary = SeasonOpponentDraft.allocate_d2(season.season_seed, remaining)
		check(season.opponents.draft_rule == SeasonOpponentDraft.D2_RULE
			and season.opponents.draft_order == expected.order, "d2 fresh AI allocator selected")
		for team in range(1, 6):
			check(season.teams[team].roster == expected.rosters[team], "exact d2 roster")
	var raw: Dictionary = SeasonSave.snapshot(season)
	check(raw.get("version") == (80 if tier == 0 else 84), "additive raw save version")
	var context: Dictionary = Save.binding_for(season, "tier-owner", "tier-lineage",
		0, 1, "tier-lineage:1")
	var wrapped: Dictionary = Save.wrap_checkpoint(raw, context)
	check(wrapped.get("version") == (83 if tier == 0 else 85), "exact outer session version")
	var restored: SeasonState = SeasonSave._decode(wrapped)
	check(restored != null, "fresh composed Dynasty cold decode")
	if restored == null:
		return
	check(ClubCareer.same(SeasonSave.snapshot(restored), wrapped), "byte-equivalent snapshot replay")
	check(not SeasonRoundSettlement._physical_payload(wrapped).is_empty(),
		"actual new physical envelope is discoverable")
	check((not Authority.open_session(authority, wrapped).is_empty()) == (tier == 0),
		"fresh owner admits Base only, never skips a championship")
	if tier == 0:
		return
	var bad: Dictionary = wrapped.duplicate(true)
	bad.version = 83
	check(SeasonSave._decode(bad) == null, "old83 cannot carry tiered session")
	bad = raw.duplicate(true)
	bad.version = 80
	check(SeasonSave._decode(bad) == null, "old80 cannot carry tiered raw profile")
	bad = raw.duplicate(true)
	bad.checkpoint.version = 82
	check(SeasonSave._decode(bad) == null, "Career27 profile82 cannot substitute for86")
	bad = wrapped.duplicate(true)
	bad.session.tier = 0
	check(SeasonSave._decode(bad) == null, "session tier must match exact captured rules")
	bad = raw.duplicate(true)
	bad.checkpoint.league_rules.version = 3
	check(SeasonSave._decode(bad) == null, "old Rules3 never admits Dynasty")


func _alternate_tier(authority: Dictionary, league: String) -> void:
	var rules: Dictionary = LeagueRules.capture_tier(
		league, 4, 13003 if league == "scramble" else null)
	var season: SeasonState = SeasonState.create_closed_league(13003, rules, true,
		Authority.access(authority))
	check(season != null, "fresh tiered owner alternate " + league)
	if season == null:
		return
	var raw: Dictionary = SeasonSave.snapshot(season)
	check(raw.get("version") == 84 and SeasonSave._decode(raw) != null,
		"alternate raw84 draft-zero accepts empty inventory prefix")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "owner alternate real fourth pick")
	check(SeasonInventoryRules.enable(season), "owner alternate inventory enable")
	var context: Dictionary = Save.binding_for(season, "tier-owner", "tier-lineage",
		0, 1, "other-tier:1")
	var wrapped: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(season), context)
	var restored: SeasonState = SeasonSave._decode(wrapped)
	check(restored != null, "tiered owner alternate snapshot decodes " + league)
	if restored != null:
		check(ClubCareer.same(SeasonSave.snapshot(restored), wrapped), "exact alternate85 replay")


func _ladder(authority: Dictionary, source: SeasonState, start: Dictionary) -> void:
	# Legacy score-only result API supplies semantic operands, NOT a Dynasty save.
	for game in range(12):
		if source.phase == SeasonState.Phase.COMPLETE:
			break
		var fixture: Dictionary = source.pending_fixture()
		check(source.record_player_result(fixture.id,
			0 if fixture.home == 0 else 1, 1 if fixture.home == 0 else 0),
			"synthetic legacy score-only result")
	check(source.phase == SeasonState.Phase.COMPLETE and source.career.sync(source),
		"synthetic complete compact score operands")
	if source.phase != SeasonState.Phase.COMPLETE:
		return
	var row: Dictionary = source.career.runs[-1]
	var candidate: Dictionary = authority.duplicate(true)
	for tier in range(5):
		check(tier in Authority.available_tiers(candidate, "dynasty"), "own previous title unlocks next")
		candidate = _synthetic_title(candidate, row, tier)
		check(not candidate.is_empty(), "synthetic tier settlement semantics " + str(tier))
		if candidate.is_empty():
			return
		check(Authority.available_tiers(candidate, "dugout") == [0], "other League remains Base")
		if tier < 4:
			_open_unlocked(candidate, start, tier + 1)
	check(Authority.available_tiers(candidate, "dynasty") == [0, 1, 2, 3, 4],
		"lower tiers remain replayable")
	var bad: Dictionary = candidate.duplicate(true)
	bad.version = 28
	check(Authority.normalize(bad).is_empty(), "old Authority28 rejects higher tiers")
	bad = candidate.duplicate(true)
	bad.sessions["synthetic-tier-2:1"].admission_frontier.clear()
	check(Authority.normalize(bad).is_empty(), "title must precede immutable session admission")
	bad = candidate.duplicate(true)
	bad.sessions["synthetic-tier-3:1"].session.tier = 2
	check(Authority.normalize(bad).is_empty(), "settled session tier binds proof tier")


func _open_unlocked(authority: Dictionary, start: Dictionary, tier: int) -> void:
	# Real fresh save API, but its preceding titles above are synthetic semantic operands.
	var prepared: Dictionary = start.duplicate(true)
	prepared.access = Authority.access(authority)
	var season: SeasonState = Bridge.create(prepared, true, tier)
	check(season != null, "fresh next tier after synthetic prerequisite")
	if season == null:
		return
	var context: Dictionary = Save.binding_for(season, "tier-owner", "tier-lineage",
		0, 1, "tier-lineage:1")
	var snapshot: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(season), context)
	var opened: Dictionary = Authority.open_session(authority, snapshot)
	check(not opened.is_empty() and opened.version == 29, "new tier session uses Authority29")
	if opened.is_empty():
		return
	check(Authority.validate_snapshot(opened, context.session_id, snapshot) != null,
		"new selected tier remains source-qualified against synthetic prerequisite fixture")
	check(ClubCareer.same(Authority.checkpoint_session(opened, context.session_id, snapshot), opened),
		"same tier checkpoint never duplicates contribution or balance")


func _synthetic_title(authority: Dictionary, row: Dictionary, tier: int) -> Dictionary:
	var candidate: Dictionary = authority.duplicate(true)
	var id: String = "synthetic-tier-%d:1" % tier
	var delta: Dictionary = {"version": 1 if tier == 0 else 2}
	for field: String in Progress.FIELDS:
		if field != "version":
			delta[field] = row[field]
	for flag: String in Progress.FLAGS:
		delta[flag + "_earned"] = row[flag + "_earned"]
	delta = delta.duplicate(true)
	delta.proof["version"] = ClubSeasonRecord.LEAGUE_VERSION
	delta.proof["league_rules"] = LeagueRules.capture_tier("dynasty", tier)
	var baseline: Dictionary = Authority.access(authority)
	var context: Dictionary = Save.binding({"owner_id": "tier-owner",
		"lineage_id": "synthetic-tier-%d" % tier, "generation": 0, "ordinal": 1,
		"session_id": id, "seed": 13002, "tier": tier, "league": "dynasty",
		"access_sha256": ClosedContentAccess.digest(baseline)})
	var frontier: Dictionary = {}
	for prior: String in candidate.sessions:
		frontier[prior] = candidate.sessions[prior].reference.duplicate(true)
	var era: Dictionary = StadiumClubIdentity.current()
	candidate.sessions[id] = {"session": context, "baseline": baseline,
		"reference": Save.snapshot_reference({"synthetic_only": id}), "contribution": delta,
		"settled": tier + 1, "era": era, "admission_frontier": frontier}
	candidate.settlements.append({"session_id": id, "reason": "complete",
		"receipt": ClubSeasonRecord.receipt(delta.proof, true, tier)})
	candidate.pennants.eras[str(candidate.origin.career.runs.size() + tier + 1)] = era
	candidate.version = 29 if tier > 0 else 28
	return Authority.normalize(candidate)


func _finish_tiers() -> void:
	print("Dynasty tier checks: %d, failures: %d, synthetic_history=true, physical_games=0"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
