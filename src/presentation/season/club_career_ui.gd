class_name ClubCareerUI
extends RefCounted


static func badge(menu: SeasonMenu, parent: Node) -> void:
	if menu.app.season == null or menu.app.season.career == null:
		return
	var club: ClubCareer = menu.app.season.career
	SeasonPages.wrapped(parent, "CLUB BUCKS  •  %d  •  Persistent club balance" % club.balance())
	menu._button(parent, "CLUB RECORD", show.bind(menu, 0))


static func settlement(menu: SeasonMenu) -> void:
	var club: ClubCareer = menu.app.season.career
	if club == null or club.current == 0:
		return
	var receipt: Dictionary = club.runs[-1].receipt
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	if receipt.is_empty():
		SeasonPages.wrapped(card, "Club reward pending. Save this completed season to settle it.")
	else:
		menu._label(card, "+%d CLUB BUCKS • Season #%d settled" % [receipt.total, club.current], 24)
		SeasonPages.wrapped(card, breakdown(receipt))
	badge(menu, card)


static func breakdown(receipt: Dictionary) -> String:
	return (
		"Finish %d + regular-record bonus %d + first-title bonus %d. Working reward values."
		% [receipt.finish_award, receipt.record_bonus, receipt.first_bonus]
	)


static func show(menu: SeasonMenu, page: int = 0) -> void:
	var club: ClubCareer = menu.app.season.career
	if club == null:
		return
	menu._screen("career", "CLUB RECORD", "History and Club Bucks survive new seasons")
	menu._label(menu._body, "CLUB BUCKS  •  %d" % club.balance(), 28)
	SeasonPages.wrapped(
		menu._body,
		(
			"Working rewards: missed playoffs 35 • semifinal 65 • runner-up 95 • champion 180. "
			+ "Add up to 15 for your regular record and 25 for the first Standard/Base title."
		)
	)
	SeasonPages.wrapped(
		menu._body,
		(
			"Season Cash never converts to Club Bucks. Abandonment pays nothing. "
			+ "Player packs and stadium purchases are not available yet."
		)
	)
	SeasonPages.wrapped(
		menu._body,
		(
			"Standard/Base cleared • Tier 1 earned; higher-tier gameplay is not available yet."
			if club.cleared()
			else "Standard rules • Base is available. Win a title to earn the next tier."
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
				"Season #%d • Standard/Base • %s • %d–%d • +%d CB"
				% [
					run.id,
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
		"career_detail", "SEASON #%d" % run.id, "Standard/Base • " + run.status.capitalize()
	)
	if not run.receipt.is_empty():
		menu._label(menu._body, "%d CLUB BUCKS AWARDED" % run.receipt.total, 26)
		SeasonPages.wrapped(menu._body, breakdown(run.receipt))
	elif run.status == "abandoned":
		SeasonPages.wrapped(menu._body, "Abandoned • No Club Bucks awarded.")
	else:
		SeasonPages.wrapped(menu._body, "In progress • Rewards settle when the season completes.")
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
