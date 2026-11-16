extends Node
## Adjustable Sponsorship candidate; controlled transactions, not earned-game balance claims.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var rules: Dictionary = LeagueRules.capture("sponsorship")
	check(rules.profile == "league-sponsorship-candidate-16-10-v1", "explicit candidate profile")
	check(not LeagueRules.public_activation_enabled("sponsorship"), "no public admission")
	check(LeagueRules.capture("sponsorship", 1).is_empty(), "no higher tier composition")
	var bad: Dictionary = rules.duplicate(true)
	bad.win_cash = 99
	check(LeagueRules.normalized(bad).is_empty(), "no caller-selected rate")
	bad = rules.duplicate(true)
	bad.profile = LeagueRules.PROFILE
	check(LeagueRules.normalized(bad).is_empty(), "wrong immutable profile rejected")
	for league: String in ["standard", "dugout", "sponsorship"]:
		var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		check(bank.enable_league_rules(LeagueRules.capture(league)), "enable " + league)
		check(
			bank.view().capacity.sponsors == (6 if league == "sponsorship" else 5),
			"base sponsor capacity"
		)
		check(
			bank.view().capacity.held == (3 if league == "dugout" else 2),
			"held capacity independent"
		)
		var win: Dictionary = OwnershipFixtures.request(bank, "reward", {"game": 0, "win": true})
		check(
			bank.commit(win).ok and bank.cash() == (16 if league == "sponsorship" else 18),
			"ordinary win income"
		)
		var before: Dictionary = bank.to_data()
		var replay: Dictionary = bank.commit(win)
		check(
			replay.ok and replay.replayed and bank.to_data() == before,
			"same reward command replays without paying twice"
		)
		check(
			not (
				bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 0, "win": false})).ok
			),
			"new command cannot repay fixture"
		)
		check(bank.to_data() == before, "duplicate reward atomic")
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 1, "win": false})).ok,
			"ordinary loss accepted"
		)
		check(bank.cash() == (26 if league == "sponsorship" else 30), "win/loss totals")
		var restored: SeasonOwnership = SeasonOwnership.from_data(
			JSON.parse_string(JSON.stringify(bank.to_data())),
			SeasonSponsorCatalog.ownership_catalog()
		)
		check(restored != null and restored.to_data() == bank.to_data(), "cold wallet replay")
		check(bank.fork().to_data() == bank.to_data(), "fork frozen payout profile")
		var cash: int = bank.cash()
		check(
			(
				bank.commit(OwnershipFixtures.request(bank, "sponsor_income", {"amount": 21})).ok
				and bank.cash() == cash + 21
			),
			"existing sponsor aggregate unchanged"
		)
		check(
			not bank.commit(OwnershipFixtures.request(bank, "sponsor_income", {"amount": 22})).ok,
			"sponsor aggregate upper bound unchanged"
		)
	_capacity()
	_sponsor_triggers()
	_ai_sixth_slot()
	_builds_and_seasons()
	_preserve_retained()
	print("Sponsorship candidate checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _funded() -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(bank.enable_league_rules(LeagueRules.capture("sponsorship")), "funded candidate")
	for game in range(12):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic fixture funding"
		)
	return bank


func _buy(bank: SeasonOwnership, item: String) -> Dictionary:
	var offer: String = "offer:%d" % bank.revision()
	var stocked: Dictionary = bank.commit(
		OwnershipFixtures.request(bank, "stock", {"offers": {offer: item}})
	)
	check(stocked.ok, "stock real catalog item " + item)
	return bank.commit(OwnershipFixtures.buy(bank, offer))


func _capacity() -> void:
	var commons: Array[String] = []
	for id: String in SeasonSponsorCatalog.catalog():
		if SeasonSponsorCatalog.item(id).get("rarity") == "Common":
			commons.append(id)
	check(commons.size() >= 7, "seven existing Common sponsors available to fixture")
	var bank: SeasonOwnership = _funded()
	for index in range(6):
		check(_buy(bank, commons[index]).ok, "paid sponsor slot%d" % (index + 1))
	check(bank.view().sponsors.size() == 6, "six active paid sponsors")
	check(
		_buy(bank, "BAT-CON-01").ok and bank.view().gear.bat.item == "BAT-CON-01",
		"normal non-neutral bat remains eligible"
	)
	var attempted: Dictionary = _buy(bank, commons[6])
	check(not attempted.ok and bank.view().sponsors.size() == 6, "seventh ordinary slot refused")
	var association: SeasonOwnership = _funded()
	check(
		_buy(association, "J05").ok and association.view().capacity.sponsors == 8,
		"Association six plus two"
	)
	for index in range(7):
		check(_buy(association, commons[index]).ok, "Association Common fill")
	check(association.view().sponsors.size() == 8, "eight includes Association itself")
	var associated_before: Dictionary = association.to_data()
	var receipt: String = association.view().sponsors[0].id
	check(
		not (
			association
			. commit(
				OwnershipFixtures.request(association, "sell", {"receipt": receipt, "discard": []})
			)
			. ok
		),
		"Association removal requires overflow resolution"
	)
	check(association.to_data() == associated_before, "failed Association removal atomic")
	check(
		(
			association
			. commit(
				OwnershipFixtures.request(
					association,
					"sell",
					{"receipt": association.view().sponsors[1].id, "discard": []}
				)
			)
			. ok
		),
		"explicit extra sponsor sale"
	)
	check(
		(
			association
			. commit(
				OwnershipFixtures.request(association, "sell", {"receipt": receipt, "discard": []})
			)
			. ok
		),
		"Association removal after resolving overflow"
	)
	check(
		association.view().capacity.sponsors == 6 and association.view().sponsors.size() == 6,
		"Association removal returns to candidate six"
	)
	var restricted: SeasonOwnership = _funded()
	check(_buy(restricted, "J05").ok, "Association restriction fixture")
	check(not _buy(restricted, "G02").ok, "Association Common-only rule preserved")
	var batch: SeasonOwnership = _funded()
	check(
		_buy(batch, "G02").ok and batch.view().capacity.sponsors == 3,
		"Small Batch hardcaps at three"
	)
	check(batch.view().capacity.held == 3, "Small Batch shared carry delta")
	check(
		_buy(batch, "F09").ok and batch.view().capacity.held == 2, "Double Major changes held only"
	)
	check(batch.view().capacity.sponsors == 3, "combined sponsor cap stays three")


func _sponsor_triggers() -> void:
	# Credited-event sample and paid ownership are controlled fixtures, not a physical game.
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var rivals: Array = ["rival.a", "rival.b", "rival.c", "rival.d"]
	var stats: MatchPerformance = MatchPerformance.new()
	for outcome: String in ["walk", "walk", "walk", "double", "double", "triple", "hr", "single"]:
		stats.complete(StringName(roster[0]), StringName(rivals[0]), outcome, 0)
	for index in range(4):
		for strikeout in range(3):
			stats.complete(StringName(rivals[0]), StringName(roster[index]), "strikeout", 0)
	for id: String in Array(roster) + rivals:
		if not stats.players.has(id):
			stats.players[id] = MatchPerformance.empty_line()
	check(
		SeasonPerformance.valid(stats.players, Array(roster) + rivals), "credited sample validates"
	)
	var build: SeasonBuild = SeasonBuild.new(551, roster)
	check(build.enable_league_rules(LeagueRules.capture("sponsorship")), "trigger candidate")
	var bank: SeasonOwnership = _funded()
	for id: String in ["D01", "A08", "A09"]:
		check(_buy(bank, id).ok, "paid income sponsor")
	build._bank = bank
	var cash: int = build.cash()
	var command: Dictionary = SeasonOpponentPolicy.command(
		build, "reward", {"game": 12, "win": true, "performance": stats.players.duplicate(true)}
	)
	check(build.commit(command).ok, "credited Build reward settles")
	check(
		build.cash() == cash + 16 + 21, "ordinary sixteen plus unchanged twenty-one trigger income"
	)
	check(
		build.income_for_game(12) == {"D01": 4, "A08": 8, "A09": 9},
		"actual sponsor-trigger caps unchanged"
	)
	var before: Dictionary = build.to_data()
	check(
		build.commit(command).ok and build.to_data() == before,
		"reward retry never repeats sponsor income"
	)


func _ai_sixth_slot() -> void:
	# Controlled paid ownership/stock fixture, not deterministic whole-season purchase proof.
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var build: SeasonBuild = SeasonBuild.new(551, roster)
	build._market = 12
	check(build.enable_league_rules(LeagueRules.capture("sponsorship")), "AI policy candidate")
	var bank: SeasonOwnership = _funded()
	for id: String in ["D01", "A07", "B02", "B03", "F01"]:
		check(_buy(bank, id).ok, "AI five supported paid sponsors")
	build._bank = bank
	var club: Dictionary = {
		"profile": "Pitching / defense", "roles": {"pitcher": roster[0]}, "decisions": []
	}
	var targets: Array[String] = SeasonOpponentSponsors.targets(build, club)
	check(targets.has("F03"), "sixth target uses qualified supported fallback")
	build._visit.number = 1
	check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).ok,
		"AI controlled fixture opens actual shop"
	)
	build._visit.offers = {"controlled:sixth": "F03"}
	var cash: int = build.cash()
	check(
		SeasonOpponentSponsors.purchase(build, club, 12),
		"AI policy commits real sixth sponsor transaction: " + build.last_error
	)
	check(
		(
			build._bank.view().sponsors.size() == 6
			and build.cash() == cash - SeasonSponsorCatalog.item("F03").price
		),
		"sixth policy purchase pays full price"
	)
	check(
		club.decisions.size() == 1 and club.decisions[0].item == "F03",
		"sixth purchase records decision"
	)
	check(SeasonOpponentSponsors.targets(build, club).is_empty(), "no seventh target")


func _builds_and_seasons() -> void:
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for market: int in [0, 12]:
		var build: SeasonBuild = SeasonBuild.new(551, roster)
		build._market = market
		check(
			build.enable_league_rules(LeagueRules.capture("sponsorship")),
			"human/AI candidate build"
		)
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": 0, "win": true}))
				. ok
			),
			"human/AI win transaction"
		)
		check(build.cash() == 16, "human/AI equal win payment")
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": 1, "win": false}))
				. ok
			),
			"human/AI loss transaction"
		)
		check(build.cash() == 26, "human/AI equal loss payment")
		var restored: SeasonBuild = SeasonBuild.from_data(
			JSON.parse_string(JSON.stringify(build.to_data())), 551, roster
		)
		check(
			restored != null and restored.to_data() == build.to_data(),
			"candidate Build45 cold replay"
		)
		check(build._fork().to_data() == build.to_data(), "candidate build fork")
	var season: SeasonState = SeasonState.create_closed_league(
		551, LeagueRules.capture("sponsorship"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "candidate draft")
	check(season.build._bank.view().capacity.sponsors == 6, "human capacity bound")
	for club: Dictionary in season.opponents.clubs.values():
		check(
			club.build._bank.view().capacity.sponsors == 6 and club.build._market == 12,
			"AI capacity bound"
		)
	var data: Dictionary = SeasonSave.snapshot(season)
	check(data.version == 76, "candidate stays closed live wrapper")
	check(
		SeasonSave._decode(JSON.parse_string(JSON.stringify(data))) != null,
		"candidate whole cold draft restore"
	)
	check(
		PhysicalMatchRequest.capture(season.make_match()) != null,
		"normal bats and physical request allowed"
	)
	var wrong: Dictionary = data.duplicate(true)
	wrong.league_rules = LeagueRules.capture("dugout")
	check(SeasonSave._decode(wrong) == null, "candidate cannot replay under Dugout")


func _preserve_retained() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--retained="):
			path = argument.trim_prefix("--retained=")
	check(not path.is_empty(), "retained stage02 evidence supplied")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var season: SeasonState = SeasonSave._decode(saved)
	check(
		season != null and ClubCareer.same(SeasonSave.snapshot(season), saved),
		"stage02 completed Dugout journal remains byte-equivalent"
	)
