class_name ClubCareerUI
extends RefCounted


static func badge(menu: SeasonMenu, parent: Node) -> void:
	if menu.app.has_method("_shared_career_badge") and menu.app.call("_shared_career_badge", parent):
		return
	if menu.app.season == null or menu.app.season.career == null:
		return
	var club: ClubCareer = menu.app.season.career
	SeasonPages.wrapped(parent, "CLUB BUCKS  •  %d  •  Persistent club balance" % club.balance())
	menu._button(parent, "CLUB RECORD", show.bind(menu, 0))


static func settlement(menu: SeasonMenu) -> void:
	if menu.app.has_method("_shared_career_settlement") and menu.app.call("_shared_career_settlement"):
		return
	var club: ClubCareer = menu.app.season.career
	if club == null or club.current == 0:
		return
	var receipt: Dictionary = club.runs[-1].receipt
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	if receipt.is_empty():
		SeasonPages.wrapped(card, "Club reward pending. Save this completed season to settle it.")
	else:
		menu._label(card, "+%d CLUB BUCKS • Season #%d settled" % [receipt.total, club.current], 24)
		SeasonPages.wrapped(card, tier_label(int(club.runs[-1].tier), str(club.runs[-1].league)))
		SeasonPages.wrapped(card, breakdown(receipt, str(club.runs[-1].league)))
	_pennant(menu, card, club.current)
	StadiumPlaqueUI.awards(menu, card, club.current)
	badge(menu, card)


static func breakdown(receipt: Dictionary, league: String = "standard") -> String:
	return (
		"Finish %d + regular-record bonus %d + first-title bonus %d. Working %s rewards."
		% [
			receipt.finish_award,
			receipt.record_bonus,
			receipt.first_bonus,
			tier_label(int(receipt.version) - 1, league)
		]
	)


static func tier_label(tier: int, league: String = "standard") -> String:
	var title: String = league.capitalize()
	return title + "/d%d" % tier if tier in [1, 2, 3, 4] else title + "/Base"


static func show(menu: SeasonMenu, page: int = 0) -> void:
	if menu.app.has_method("_show_league_career_record"):
		menu.app.call("_show_league_career_record", page)
		return
	show_ordinary(menu, page)


static func show_ordinary(menu: SeasonMenu, page: int = 0) -> void:
	var club: ClubCareer = menu.app.season.career
	if club == null:
		return
	var titles: Dictionary = club._title_history()
	var base_cleared: bool = bool(titles.get("0", false))
	var d1_cleared: bool = bool(titles.get("1", false))
	var d2_cleared: bool = bool(titles.get("2", false))
	var d3_cleared: bool = bool(titles.get("3", false))
	menu._screen("career", "CLUB RECORD", "History and Club Bucks survive new seasons")
	menu._label(menu._body, "CLUB BUCKS  •  %d" % club.balance(), 28)
	menu._button(menu._body, "STADIUM WORKSHOP", StadiumEditorUI.show.bind(menu, {}, -1))
	menu._button(menu._body, "PLAYERS & PACKS", ClubPlayersUI.show.bind(menu, "All", 0))
	menu._button(menu._body, "COLLECTION", ClubCollectionUI.show.bind(menu, "Gear", 0))
	menu._button(menu._body, "GEAR PROGRESSION", ClubGearProgressUI.show.bind(menu))
	menu._button(menu._body, "LEARNED ABILITIES", SeasonAbilityUI.show.bind(menu))
	menu._button(menu._body, "EARNED SPONSORS", ClubSponsorProgressUI.show.bind(menu))
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				"Working Base rewards: missed playoffs 35 • semifinal 65 • runner-up 95 • champion 180. "
				+ "Working d1 rewards: 36 • 68 • 99 • 189. "
				+ "Working d2 rewards: 38 • 71 • 104 • 198. "
				+ "Working d3 rewards: 40 • 74 • 109 • 207. "
				+ "Working d4 rewards: 42 • 78 • 114 • 216. "
				+ "Add up to 15 for your regular record and 25 once for each tier's first title."
			)
		)
	)
	SeasonPages.wrapped(
		menu._body,
		(
			"Season Cash never converts to Club Bucks. Abandonment pays nothing. "
			+ "Player packs use Club Bucks; stadium purchases are still in development."
		)
	)
	SeasonPages.wrapped(
		menu._body,
		(
			(
				"Standard/Base cleared • Standard/d1 is available. Base replays remain available. "
				+ "Working d1 rerolls cost 1 extra when paid; free rerolls stay free."
			)
			if base_cleared
			else "Standard rules • Base is available. Win a title to earn the next tier."
		)
	)
	menu._button(menu._body, "NEW STANDARD/BASE SEASON", menu.app.ask_progression_season.bind(0))
	if base_cleared:
		menu._button(menu._body, "NEW STANDARD/d1 SEASON", menu.app.ask_progression_season.bind(1))
	if d1_cleared:
		(
			SeasonPages
			. wrapped(
				menu._body,
				(
					"Standard/d1 cleared • Standard/d2 is available. Base and d1 replays remain available. "
					+ "Working d2 drafts prefer authored role stats; d1 reroll pricing is inherited."
				)
			)
		)
		menu._button(menu._body, "NEW STANDARD/d2 SEASON", menu.app.ask_progression_season.bind(2))
	if d2_cleared:
		SeasonPages.wrapped(
			menu._body,
			(
				"Standard/d2 cleared • Standard/d3 is available. Earlier tiers remain available. "
				+ "D3 inherits d1 reroll pricing and d2 drafts; marked sponsor copies return "
				+ "0 Cash on cancellation or replacement. Voluntary removal remains available."
			)
		)
		menu._button(menu._body, "NEW STANDARD/d3 SEASON", menu.app.ask_progression_season.bind(3))
	if d3_cleared:
		if ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED:
			(
				SeasonPages
				. wrapped(
					menu._body,
					(
						"Standard/d3 cleared • Standard/d4 is available. "
						+ "Marked short-term sponsors cover two completed club games, then expire for 0 Cash."
					)
				)
			)
			menu._button(
				menu._body, "NEW STANDARD/d4 SEASON", menu.app.ask_progression_season.bind(4)
			)
		else:
			SeasonPages.wrapped(
				menu._body,
				(
					"Standard/d3 cleared. Standard/d4 public entry is held "
					+ "pending Grandstand Gardens III acceptance. Earlier tiers remain available."
				)
			)
	if club.current == 0:
		SeasonPages.wrapped(menu._body, "Your current legacy season does not earn Club Bucks.")
	var last_page: int = maxi(0, int((club.runs.size() - 1) / 20.0))
	page = clampi(page, 0, last_page)
	menu._label(menu._body, "SEASONS • Page %d of %d" % [page + 1, last_page + 1], 22)
	var end: int = maxi(0, club.runs.size() - page * 20)
	for index in range(end - 1, maxi(-1, end - 21), -1):
		var run: Dictionary = club.runs[index]
		var record: Dictionary = ClubSeasonRecord.analyze(run.proof)
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		SeasonPages.wrapped(
			card,
			(
				"Season #%d • %s • %s • %d–%d • +%d CB"
				% [
					run.id,
					tier_label(int(run.tier), str(run.league)),
					run.receipt.get("finish", run.status).replace("_", " ").capitalize(),
					record.wins,
					record.games - record.wins,
					run.receipt.get("total", 0)
				]
			)
		)
		menu._button(card, "VIEW SEASON #%d" % run.id, detail.bind(menu, index, page))
	if page > 0:
		menu._button(menu._footer, "NEWER", show.bind(menu, page - 1))
	if page < last_page:
		menu._button(menu._footer, "OLDER", show.bind(menu, page + 1))
	menu._button(menu._footer, "CURRENT SEASON", menu.app.show_season)
	menu._button(menu._footer, "MAIN MENU", menu.show_home)


static func detail(menu: SeasonMenu, index: int, page: int) -> void:
	var run: Dictionary = menu.app.season.career.runs[index]
	menu._screen(
		"career_detail",
		"SEASON #%d" % run.id,
		tier_label(int(run.tier), str(run.league)) + " • " + run.status.capitalize()
	)
	if not run.receipt.is_empty():
		menu._label(menu._body, "%d CLUB BUCKS AWARDED" % run.receipt.total, 26)
		SeasonPages.wrapped(menu._body, breakdown(run.receipt, str(run.league)))
	elif run.status == "abandoned":
		SeasonPages.wrapped(menu._body, "Abandoned • No Club Bucks awarded.")
	else:
		SeasonPages.wrapped(menu._body, "In progress • Rewards settle when the season completes.")
	_pennant(menu, menu._body, int(run.id))
	StadiumPlaqueUI.awards(menu, menu._body, int(run.id))
	for score: Array in run.proof.scores:
		if 0 not in [int(score[1]), int(score[2])]:
			continue
		var stage: String = (
			"Regular season" if score[0] < 30 else ("Semifinal" if score[0] < 32 else "Final")
		)
		SeasonPages.wrapped(
			menu._body,
			(
				"%s • %s %d : %s %d"
				% [
					stage,
					SeasonState.TEAM_NAMES[int(score[1])],
					score[3],
					SeasonState.TEAM_NAMES[int(score[2])],
					score[4]
				]
			)
		)
	menu._button(menu._footer, "BACK TO CLUB RECORD", show.bind(menu, page))


static func _pennant(menu: SeasonMenu, parent: Node, season_id: int) -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(menu.app.season.career)
	var id: String = StadiumPennantRewards.key(season_id)
	if ledger == null or not ledger.construction().copies.has(id):
		return
	var earned: Dictionary = ledger.construction().copies[id].earned
	(
		SeasonPages
		. wrapped(
			parent,
			(
				(
					"CHAMPIONSHIP PENNANT EARNED • %s • Season %d • %s / %s. Your title-era name, crest "
					+ "and colors are preserved. Stored safely until you choose a compatible display."
				)
				% [earned.era.name, earned.season_number, earned.league_id, earned.difficulty_id]
			)
		)
	)
	menu._button(parent, "DISPLAY EARNED PENNANT", StadiumEditorUI.show.bind(menu, {}, -1))

	var banner_id: String = StadiumPennantRewards.mastery_key()
	if ledger.construction().copies.has(banner_id):
		var mastery: Dictionary = ledger.construction().copies[banner_id].earned
		if mastery.season_id == season_id:
			(
				SeasonPages
				. wrapped(
					parent,
					(
						(
							"LEAGUE MASTERY BANNER EARNED • %s • Standard tier 5 • First qualifying title, "
							+ "season %d. Your mastery-era identity is frozen; this season also earns its "
							+ "ordinary pennant. Store or display the exact banner at a compatible BANNER-WALL."
						)
						% [mastery.era.name, mastery.season_number]
					)
				)
			)
			menu._button(parent, "DISPLAY MASTERY BANNER", StadiumEditorUI.show.bind(menu, {}, -1))
