class_name ClubSponsorProgressUI
extends RefCounted


static func show(menu: SeasonMenu) -> void:
	var club: ClubCareer = menu.app.season.career
	if club == null:
		return
	menu._screen(
		"sponsor_progress",
		"EARNED SPONSORS",
		"Completed-game achievements survive season replacement"
	)
	var progress: SeasonSponsorProgress = SeasonSponsorProgress.new()
	progress.enabled = true
	progress.start = club.sponsor_state()
	SeasonPages.wrapped(
		menu._body,
		(
			"Working unlock requirements. Earned access adds future shop eligibility, "
			+ "never a free or guaranteed copy. Unfinished games give no progress."
		)
	)
	for id: String in SeasonEarnedSponsors.ITEMS:
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		var item: Dictionary = SeasonSponsorCatalog.item(id)
		menu._label(
			card,
			item.name + (" • SHOP ELIGIBLE" if progress.eligible().has(id) else " • LOCKED"),
			22
		)
		SeasonPages.wrapped(card, SeasonEarnedSponsors.REQUIREMENTS[id])
		if id == "E05":
			SeasonPages.wrapped(
				card,
				(
					"Credited hit types: %d / 3 • %s"
					% [
						mini(3, progress.start.hits.size()),
						(
							", ".join(progress.start.hits)
							if not progress.start.hits.is_empty()
							else "None yet"
						)
					]
				)
			)
		SeasonPages.wrapped(
			card, "%d Season Cash • %s • Working\n%s" % [item.price, item.rarity, item.effect]
		)
	SeasonPages.wrapped(
		menu._body,
		(
			"Other earned sponsors are not available yet. Older active saves begin "
			+ "this tracking with their next new Working season. Seasonal stamps and "
			+ "pitcher-return uses do not carry into a new season."
		)
	)
	menu._button(menu._footer, "BACK TO CLUB RECORD", ClubCareerUI.show.bind(menu, 0))
