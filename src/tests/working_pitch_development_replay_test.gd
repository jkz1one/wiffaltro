extends Node
## Synthetic isolated domain inputs, not earned gameplay or persisted owner history.
const Fixture = preload("res://src/tests/working_exotic_access_test.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
var failures: int = 0


func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)


func _ready() -> void:
	var fresh: SeasonBuild = SeasonBuild.new(701, Fixture.ROSTER)
	check(fresh.enable_pitch_catalog() and fresh.enable_league_rules(LeagueRules.capture("dynasty")),
		"fresh current Dynasty context")
	check(not ClubPlayerProgress._development(fresh, true).is_empty(), "fresh Dynasty compact reconstruction")
	var paid: SeasonBuild = _paid(false, [])
	check(paid != null, "same-season proof precedes generated paid lesson")
	if paid != null:
		var progress: Dictionary = ClubPlayerProgress._development(paid, true)
		check(not progress.is_empty() and not progress.lessons.is_empty(), "same-season paid lesson captures")
		var before: Dictionary = paid.to_data()
		var current: Dictionary = paid._book.to_data()
		check(not ClubPlayerProgress._development(paid, true).is_empty()
			and ClubCareer.same(before, paid.to_data()) and ClubCareer.same(current, paid._book.to_data()),
			"capture has no source mutation")
		var inherited: SeasonBuild = _paid(true, [paid._book._exotic_current.duplicate(true)])
		check(inherited != null, "inherited exact proof permits generated paid lesson")
		if inherited != null:
			check(not ClubPlayerProgress._development(inherited, true).is_empty(), "inherited paid capture")
			inherited._book._exotic_start = []
			check(ClubPlayerProgress._development(inherited, true).is_empty(), "stripped inherited proof rejects cached access")
		var profile: Dictionary = Profile.capture_build(paid, "development-lineage", "development-fixture")
		var decayed: Dictionary = Profile.decay(profile)
		check(not decayed.is_empty(), "paid Exotic profile normal decay")
		if not decayed.is_empty():
			var carried: SeasonBuild = SeasonBuild.new(paid._seed, Fixture.ROSTER)
			check(carried.enable_pitch_catalog()
				and carried.enable_league_rules(LeagueRules.capture("dynasty"))
				and carried.enable_dynasty_start(decayed.profile), "carried Dynasty start")
			var evidence: Dictionary = ClubPlayerProgress._development(carried, true)
			check(not evidence.is_empty() and evidence.known >= 1, "carried Dynasty rules/profile reconstruction")
			var loaded: SeasonBuild = SeasonBuild.from_data(JSON.parse_string(JSON.stringify(carried.to_data())),
				paid._seed, Fixture.ROSTER)
			check(loaded != null and ClubCareer.same(evidence, ClubPlayerProgress._development(loaded, true)),
				"carried Dynasty JSON evidence replay")
		var late: SeasonBuild = paid._fork()
		var admission: Dictionary = {}
		for index in range(late._events.size() - 1, -1, -1):
			if late._events[index].op == "exotic_admit":
				admission = late._events.pop_at(index)
		late._events.append(admission)
		for index in range(late._events.size()): late._events[index].rev = index
		check(ClubPlayerProgress._development(late, true).is_empty(), "buy before proof fails despite final eligible book")
		var forged: SeasonBuild = paid._fork()
		for event: Dictionary in forged._events:
			if event.op == "exotic_admit": event.proof.games[0].strikeouts[0].called = false
		check(ClubPlayerProgress._development(forged, true).is_empty(), "altered admission cannot borrow cached eligibility")
		var cache: SeasonBuild = SeasonBuild.new(paid._seed, Fixture.ROSTER)
		check(cache.enable_pitch_catalog(), "fresh cache-negative book")
		cache._book.retain_exotic_current(paid._book._exotic_current)
		check(ClubPlayerProgress._development(cache, true).is_empty(), "unearned current proof cache rejects")
	print("Development replay fixture failures: %d; physical games and owner writes: 0" % failures)
	get_tree().quit(0 if failures == 0 else 1)


func _paid(inherited: bool, history: Array) -> SeasonBuild:
	for seed_value in range(128):
		var build: SeasonBuild = SeasonBuild.new(seed_value, Fixture.ROSTER)
		if not build.enable_pitch_catalog() or (inherited and not build._book.install_exotic_start(history)):
			return null
		var reward: Dictionary = Fixture.fixture_reward()
		if not build.commit(reward).ok: return null
		if not inherited:
			build = WorkingExoticAccess.finalized_candidate(build, [], Fixture.fixture_result(reward))
			if build == null: return null
		if not build.commit(Fixture.cmd(build, "open")).ok: return null
		for offer: String in build._visit.offers:
			var item: String = build._visit.offers[offer]
			if item != "lesson.pitch.switchback": continue
			var targets: Array = build.targets(item)
			if targets.is_empty(): continue
			var target: Dictionary = targets[0]
			if build.commit(Fixture.cmd(build, "buy", {"offer": offer, "mode": "use",
				"player": target.player, "pitch": target.pitch, "replace": target.replace})).ok:
				return build
	return null
