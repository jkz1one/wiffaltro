extends "res://src/tests/league_flat_home_replay_test.gd"
## Complete authored Standard histories with prospective rewards, not real wins.
const Mastery = preload("res://src/tests/stadium_mastery_reward_test.gd")

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flat-replay-output="): output = arg.trim_prefix("--flat-replay-output=")
	if not output.is_empty():
		if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(output)
	var history: ClubCareer = Mastery.fixture(12, false, true)
	if history != null:
		# Additional authored League receipts pay for the exact Club land and host.
		# No wallet injection or free asset copies. These are still synthetic wins.
		var extra: ClubCareer = Fixture.prefix([{ "league": "dugout", "tier": 0 }, { "league": "dugout", "tier": 1 }])
		for row: Dictionary in extra.runs:
			var next: Dictionary = row.duplicate(true)
			next.id = history.runs.size() + 1
			history.runs.append(next)
			history._pennants.eras[str(next.id)] = StadiumClubIdentity.current()
		history._assets = ClubAssetLedger.new_club(51, ClubPlayers.income(history), StadiumCareerProgress.capture(history), StadiumPennantRewards.awards(history)).to_data()
		if not check(StadiumPennantRewards.deliver(history), "prospective rewards replay from exact authored history"): return
		history = ClubCareer.from_data(history.to_data())
	var source: SeasonState = Mastery._ordinary_next(history) if history != null else null
	if check(source != null, "full authored Standard D4 physical-envelope and prospective reward source"):
		for pick in range(4): check(source.choose_player(source.offers()[0]), "normal authored reward source draft")
		var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "flat-earned-owner")
		var foreign: Dictionary = _seed_authority(false, "flat-earned-foreign")
		if check(not authority.is_empty() and not foreign.is_empty(), "full source reward authority"):
			_case(authority, foreign, "earned-banner-doubleheader", "doubleheader", 0, 41, "banner")
	check(exercised.size() == 1, "earned banner exact grant composition completes")
	_write("summary.json", {"checks": checks, "failures": failures, "cases": exercised, "physical_games": 0,
		"synthetic_titles": true, "prospective_reward_history": true})
	print("FLAT_EARNED_REPLAY checks=", checks, " failures=", failures, " cases=", exercised.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)
