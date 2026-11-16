extends Node

var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	for id: String in LeagueRules.IDS:
		check(not LeagueRules.public_activation_enabled(id), "registry does not admit " + id)
	check(LeagueRules.capture("dugout", 1).is_empty(), "higher tiers unsupported")
	check(LeagueRules.capture("dynasty").is_empty(), "unimplemented profile unsupported")
	var rules: Dictionary = LeagueRules.capture("dugout")
	var bad: Dictionary = rules.duplicate()
	bad.held = 99
	check(LeagueRules.normalized(bad).is_empty(), "no caller-defined capacity")
	var catalog: Dictionary = OwnershipFixtures.catalog()
	catalog["fixture.major"] = {"kind": "sponsor", "price": 0, "sale": "half", "held_delta": -1}
	catalog["fixture.batch"] = {
		"kind": "sponsor", "price": 0, "sale": "half", "held_delta": 1, "sponsor_cap": 3
	}
	for league: String in ["standard", "dugout"]:
		var bank: SeasonOwnership = SeasonOwnership.new(catalog)
		check(bank.enable_league_rules(LeagueRules.capture(league)), "enable " + league)
		var capacity: int = 3 if league == "dugout" else 2
		check(bank.view().capacity == {"held": capacity, "sponsors": 5}, "base capacity")
		var offers: Dictionary = {"batch": "fixture.batch", "major": "fixture.major"}
		for i in range(5):
			offers[str(i)] = "fixture.card"
		check(bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})).ok, "stock")
		for i in range(capacity):
			check(bank.commit(OwnershipFixtures.buy(bank, str(i))).ok, "legal held acquisition")
		var before: Dictionary = bank.to_data()
		check(not bank.commit(OwnershipFixtures.buy(bank, str(capacity))).ok, "overflow refused")
		check(bank.to_data() == before, "overflow atomic")
		check(not bank.commit(OwnershipFixtures.buy(bank, "major")).ok, "capacity loss refused")
		check(bank.commit(OwnershipFixtures.buy(bank, "batch")).ok, "batch acquired")
		check(bank.view().capacity == {"held": capacity + 1, "sponsors": 3}, "hard cap preserved")
		check(bank.commit(OwnershipFixtures.buy(bank, "major")).ok, "combined modifiers")
		check(bank.view().capacity.held == capacity, "additive held modifiers")
		var restored: SeasonOwnership = SeasonOwnership.from_data(bank.to_data(), catalog)
		check(restored != null and restored.view() == bank.view(), "ownership replay")
		check(bank.fork().to_data() == bank.to_data(), "ownership fork")
		var forged: Dictionary = bank.to_data()
		forged.league_rules.profile = "future"
		check(SeasonOwnership.from_data(forged, catalog) == null, "unknown rule refused")
		check(not bank.enable_league_rules(rules), "no live rule toggle")
	_builds()
	_seasons()
	var legacy: SeasonOwnership = SeasonOwnership.new(catalog)
	check(
		legacy.to_data().keys().size() == 3 and legacy.to_data().version == 1, "legacy shape intact"
	)
	check(legacy.view().capacity == {"held": 2, "sponsors": 5}, "legacy capacity intact")
	print("League staging checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _builds() -> void:
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for market: int in [0, 12]:
		var build: SeasonBuild = SeasonBuild.new(701, roster)
		build._market = market
		check(build.enable_league_rules(LeagueRules.capture("dugout")), "build context enable")
		check(
			build.pricing_context_valid() and build._bank.view().capacity.held == 3, "build binding"
		)
		var data: Dictionary = build.to_data()
		var restored: SeasonBuild = SeasonBuild.from_data(data, 701, roster)
		check(restored != null and restored.to_data() == data, "build journal roundtrip")
		check(build._fork().to_data() == data, "build fork")
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": 0, "win": true}))
				. ok
			),
			"synthetic completed-game build reward"
		)
		check(build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "shop opens")
		var journal: Dictionary = build.to_data()
		var replay: SeasonBuild = SeasonBuild.from_data(journal, 701, roster)
		check(replay != null and replay.to_data() == journal, "nonempty human/AI journal replay")

		check(not build.enable_d1_pricing(), "no unqualified tier mixing")
		var divergent: SeasonBuild = build._fork()
		divergent._bank._league_rules = LeagueRules.capture("standard")
		check(
			not divergent.pricing_context_valid() and divergent.to_data().is_empty(),
			"context mismatch rejected"
		)
		var forged: Dictionary = data.duplicate(true)
		forged.league_rules.tier = 1
		check(
			SeasonBuild.from_data(forged, 701, roster) == null, "unsupported tier restore rejected"
		)


func _seasons() -> void:
	var season: SeasonState = SeasonState.create_closed_league(778, LeagueRules.capture("dugout"))
	check(season != null, "closed season constructor")
	check(not ClubCareer.new().start(season), "closed profile cannot enter Standard career")
	for count in range(5):
		var data: Dictionary = SeasonSave.snapshot(season)
		check(data.get("version") == 75, "explicit staging envelope")
		var restored: SeasonState = SeasonSave._decode(data)
		check(restored != null, "partial/full draft checkpoint restore %d" % count)
		if restored != null:
			check(SeasonSave.snapshot(restored) == data, "exact season roundtrip")
		check(
			SeasonSave._decode(data.get("checkpoint", {})) == null,
			"legacy envelope rejects rules build"
		)
		if count < 4:
			check(season.choose_player(season.offers()[0]), "draft selection")
	check(season.opponents.clubs.size() == 5, "five opponent builds")
	for club: Dictionary in season.opponents.clubs.values():
		check(
			club.build.league_context_valid() and club.build._bank.view().capacity.held == 3,
			"AI frozen context and capacity"
		)
	check(season.make_match() == null, "physical play remains gated")
	var old_path: String = SeasonSave.path
	SeasonSave.path = "user://league-stage-checkpoint.json"
	check(SeasonSave.save(season), "durable isolated checkpoint")
	check(SeasonSave._read(SeasonSave.path) != null, "cold checkpoint read")
	SeasonSave.path = old_path

	var before: Dictionary = season.build.to_data()
	season.build.migrate()
	check(season.build.to_data() == before, "migration cannot erase context")
	var forged: Dictionary = SeasonSave.snapshot(season)
	forged.league_rules = LeagueRules.capture("standard")
	check(SeasonSave._decode(forged) == null, "wrapper/body mismatch rejected")

	var stripped: SeasonState = SeasonState.create_closed_league(779, LeagueRules.capture("dugout"))
	stripped.league_rules.clear()
	check(not stripped.choose_player(stripped.offers()[0]), "stripped context cannot draft")
	check(stripped.make_match() == null, "stripped context cannot start match")
	check(SeasonSave.snapshot(stripped).is_empty(), "stripped context cannot save")
	check(not season._record_player_result(0, 1, 0), "closed profile result ingress rejected")

	var ai_data: Dictionary = SeasonSave.snapshot(season)
	var first_club: Dictionary = season.opponents.clubs["1"]
	first_club.build._league_rules = LeagueRules.capture("standard")
	check(SeasonSave.snapshot(season).is_empty(), "one divergent AI context refuses snapshot")
	check(SeasonSave._decode(ai_data) != null, "exported checkpoint isolated from live mutation")

	var standard: SeasonState = SeasonState.create(778, false, true, true)
	var career: ClubCareer = ClubCareer.new()
	check(career.start(standard), "ordinary Base career still starts")
	check(
		not career._pricing_matches(season), "existing Standard career cannot join closed profile"
	)
	check(not career.sync(season), "existing Standard career cannot sync closed profile")
