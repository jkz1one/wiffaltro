extends "res://src/tests/dynasty_foundation_test.gd"
## Controlled compact offline checkpoint, not historical purchase authentication.


func _ready() -> void:
	var lineage: Dictionary = Lineage.create(semantic_profile())
	lineage = Lineage.close(lineage, "win")
	var advanced: Dictionary = Lineage.advance(
		lineage, Lineage.request_for(lineage, "rollover:1", 10902, overflow_choice())
	)
	check(not advanced.is_empty(), "controlled lineage advances with explicit overflow")
	if advanced.is_empty():
		_finish()
		return
	var start: Dictionary = advanced.lineage.start_profile
	var roster: Array[String] = []
	roster.assign(start.roster)
	var build: SeasonBuild = SeasonBuild.new(start.seed, roster)
	var rules: Dictionary = LeagueRules.capture("dynasty")
	check(build.enable_league_rules(rules), "closed Dynasty rules enable at empty journal")
	check(build.enable_dynasty_start(start), "immutable carried start seeds before events")
	check(
		build.revision() == 0 and build._bank.revision() == 0 and build._book.revision() == 0,
		"carry creates no synthetic events"
	)
	check(build.league_context_valid(), "start and book contexts agree")
	check(build.player(ALEX).stats == start.players[ALEX].stats, "raw carried ratings exact")
	check(build._abilities.ids(ALEX).size() == 2, "resolved retained learning installed")
	check(
		(
			build
			. commit({"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"inventory capability remains first event"
	)
	var data: Dictionary = cold(build.to_data())
	var restored: SeasonBuild = SeasonBuild.from_data(data, start.seed, roster)
	check(
		restored != null and ClubCareer.same(restored.to_data(), data),
		"carried Build cold replay exact"
	)
	var forked: SeasonBuild = build._fork()
	check(
		forked.league_context_valid() and ClubCareer.same(forked._dynasty_start, start),
		"fork retains immutable context"
	)
	var bad: Dictionary = cold(data)
	bad.erase("dynasty_start")
	check(
		SeasonBuild.from_data(bad, start.seed, roster) == null,
		"missing mandatory start header rejects"
	)
	bad = cold(data)
	bad.market = 12
	check(
		SeasonBuild.from_data(bad, start.seed, roster) == null,
		"AI market cannot borrow human carry"
	)
	bad = cold(data)
	bad.dynasty_start.seed += 1
	check(SeasonBuild.from_data(bad, start.seed, roster) == null, "foreign season start rejects")
	bad = cold(data)
	bad.dynasty_start.roster.reverse()
	check(
		SeasonBuild.from_data(bad, start.seed, roster) == null,
		"foreign initial roster order rejects"
	)
	var ai: SeasonBuild = SeasonBuild.new(111, roster)
	ai._market = 12
	check(
		ai.enable_league_rules(rules) and ai.to_data().dynasty_start.is_empty(),
		"fresh AI carries explicit empty start"
	)
	var ai_cold: SeasonBuild = SeasonBuild.from_data(cold(ai.to_data()), 111, roster)
	check(
		ai_cold != null and ai_cold._dynasty_start.is_empty(), "fresh AI cold header remains empty"
	)
	check(not ai.enable_dynasty_start(start), "AI cannot seed owner profile")
	forked._dynasty_start = {}
	check(not forked.league_context_valid(), "runtime header strip rejects book context")
	var raw: SeasonBuild = SeasonBuild.new(1, roster)
	raw._dynasty_start = start
	check(not raw.pricing_context_valid(), "ordinary Build rejects injected carry header")
	var ordinary: SeasonBuild = SeasonBuild.new(1, roster)
	check(not ordinary.to_data().has("dynasty_start"), "legacy serialization shape unchanged")
	var long_start: Dictionary = JSON.parse_string(
		JSON.stringify(start, "", true, true).replace("dynasty-fixture", "x".repeat(153))
	)
	check(
		not Profile.normalize(long_start).is_empty(),
		"inert long identity remains a semantic profile"
	)
	var long_build: SeasonBuild = SeasonBuild.new(start.seed, roster)
	check(
		long_build.enable_league_rules(rules) and not long_build.enable_dynasty_start(long_start),
		"playable admission rejects lineage unable to fit all ordinal namespaces"
	)
	_finish()


func _finish() -> void:
	print("Dynasty Build bridge checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
