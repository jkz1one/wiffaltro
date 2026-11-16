class_name SeasonOpponentSponsorsUI
extends RefCounted
## Read-only paid team sponsors, actual earnings and conservative buying qualifications.


static func preview(card: VBoxContainer, club: Dictionary) -> void:
	var sponsorship: bool = LeagueRules.sponsorship(club.build._league_rules)
	var choices: bool = club.build._market in [7, 8, 9, 10, 11, 12]
	var base_market: bool = club.build._market == 12
	if base_market:
		SeasonPages.wrapped(card, "Opponent stock includes development, normal Gear, learning, "
			+ "Take Your Base, Neighborhood Deli, Community College, Strikecraft, Cornerstone, "
			+ "Split Decision, Budget Bites and all five match supplies. "
			+ "Information sponsors and recruiting remain gated.")
	else:
		SeasonPages.wrapped(card, "Opponent stock adds Take Your Base, Neighborhood Deli, "
			+ "Community College and Strikecraft"
			+ (", plus Cornerstone and Split Decision" if choices else "")
			+ " to development, 13 initial Gear and learning. "
			+ ("Budget Bites and paid Tape, Plan, Recovery and Heat are supported; Base, information "
				+ "sponsors and recruiting remain gated." if club.build._market == 11 else
				"Paid Tape, Plan, Recovery and Heat are supported; Base, Budget Bites, other sponsors "
				+ "and recruiting remain gated." if club.build._market == 10 else
				"Other sponsors, supplies and recruiting remain gated." if club.build._market != 8
				else "Paid Grip Tape and Swing Plan are also supported; other supplies remain gated."))
	var box: VBoxContainer = SeasonPlayerCard.panel(card, false)
	SeasonPages.wrapped(box, "TEAM SPONSORS")
	var build: SeasonBuild = club.build
	var capacity: int = int(build._bank.view().capacity.sponsors) if (
		build._format == SeasonBuild.LEAGUE_VERSION and build.league_context_valid()) else 5
	SeasonPages.wrapped(box, "%d / %d active • Empty slots only; no replacements. " % [
		build._bank.view().sponsors.size(), capacity]
		+ "Bought after development and preferred Gear, before learning.").set_meta(
		"opponent_sponsor_slots", true)
	if sponsorship:
		SeasonPages.wrapped(box, "Sponsorship candidate: six base slots and 16/10 game Cash. "
			+ "After preferred sponsors, considers other already-supported qualified sponsors; "
			+ "no free copies or replacements. Sponsor income is unchanged.")
	var rule: String = "Take Your Base: a credited walk in the last two games, " \
		+ "with at least three regular games left."
	if club.profile == "Featured hitter":
		rule = "Deli first: at least two team Singles last game. " + rule
	elif club.profile == "Pitching / defense":
		rule = "College first: actual earned development; then Strikecraft: " \
			+ "primary arm knows at least three recipes. " + rule
	if choices:
		if club.profile == "Pitching / defense":
			rule = "College first: actual earned development; then Strikecraft: primary arm " \
				+ "knows three recipes; then Cornerstone (10 Cash). " + ("Take Your Base: "
				+ "credited walk in the last two games, at least three regular games left.")
		elif club.profile == "Featured hitter":
			rule = "Deli first: two team Singles last game; then Split Decision (10 Cash); " \
				+ "then Take Your Base: recent walk, at least three regular games left."
		else:
			rule = "Split Decision first (10 Cash); then Take Your Base: a credited walk " \
				+ "in the last two games, with at least three regular games left."
	if (build._market == 11 or base_market) and club.profile == "Distributed":
		rule = "Split Decision first; then Budget Bites (10 Cash) only if buying leaves at most " \
			+ "4 Cash and a free held slot; then qualified Take Your Base."
	SeasonPages.wrapped(box, rule)
	if build._market == 11 or base_market:
		SeasonPages.wrapped(box, "Budget Bites checks final Cash at game commitment: "
			+ "4 or less and a free slot grants one Swing Plan. Later purchases can fill the bag; "
			+ "full means no grant or delayed queue. Unused copies carry; restart grants no extra."
		).set_meta("opponent_budget_policy", true)
		for game: String in build._pregames:
			var grant: Dictionary = build._pregames[game]
			if grant.outcome != "inactive":
				SeasonPages.wrapped(box, "Budget Bites • game %s • %d Cash • %s" % [
					game, grant.cash, grant.outcome]).set_meta("opponent_budget_history", true)
	if build._bank.view().sponsors.is_empty():
		SeasonPages.wrapped(box, "No paid sponsor yet.")
	for receipt: Dictionary in build._bank.view().sponsors:
		var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
		SeasonPages.wrapped(box, "%s • paid %d Cash\n%s" % [item.name, receipt.paid, item.effect]
		).set_meta("opponent_sponsor_owned", true)
		var terms: String = SeasonSponsorCatalog.receipt_label(receipt)
		if not terms.is_empty():
			SeasonPages.wrapped(box, terms).set_meta("opponent_sponsor_terms", true)
		if choices and receipt.item in ["F01", "F03"]:
			SeasonPages.wrapped(box, ("AI chooses WIDE before every own plate appearance: "
				+ "Contact X ×1.10 / Y ×0.90 after Gear. Power and timing unchanged."
				if receipt.item == "F03" else "AI anchors the primary fielder at the current legal "
				+ "spot before each opposing plate appearance. No fair-ball travel; +0.12 s "
				+ "clean-control margin only after ordinary reach and reaction checks.")
			).set_meta("opponent_sponsor_choice", true)
		if receipt.item == "B02":
			SeasonPages.wrapped(box, "Current qualifying developed players: %d / 4" % [
				build._book.earned_players(build.roster()).size()])
	for row: Dictionary in club.decisions:
		if row.stat == "sponsor":
			SeasonPages.wrapped(box, "Bought %s • %d Cash • game %d" % [
				SeasonSponsorCatalog.item(row.item).name, row.paid, row.game]
			).set_meta("opponent_sponsor_purchase", true)
	for event: Dictionary in SeasonOpponentSponsors.history(build):
		var income: Dictionary = build.income_for_game(int(event.game))
		if income.has("D01"):
			SeasonPages.wrapped(box, "Take Your Base earned %d Cash • game %d • actual credited walks" % [
				income.D01, event.game]).set_meta("opponent_sponsor_income", true)
