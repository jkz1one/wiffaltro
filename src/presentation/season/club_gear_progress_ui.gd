class_name ClubGearProgressUI
extends RefCounted


static func show(menu: SeasonMenu) -> void:
	var club: ClubCareer = menu.app.season.career
	if club == null:
		return
	menu._screen("gear_progress", "GEAR PROGRESSION", "Earned access persists across seasons")
	SeasonPages.wrapped(
		menu._body,
		(
			"Finish 10 games using tier 1 to earn tier 2, then 20 using tier 2 to earn tier "
			+ "3. Wins are not required. Bat and Ball advance together."
		)
	)
	SeasonPages.wrapped(
		menu._body,
		(
			"Working use rule: the paid copy must be equipped at the first released pitch "
			+ "of a completed game. Menus, unfinished games and retries give no extra credit. "
			+ "Unlocks add shop eligibility; they never grant a free copy."
		)
	)
	var counts: Dictionary = club.gear_counts()
	for family: String in SeasonGearProgress.FAMILIES:
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
		menu._label(card, SeasonGearCatalog.item(family + "-01").name, 22)
		for tier: int in [2, 3]:
			var id: String = family + "-0%d" % tier
			var prior: String = family + "-0%d" % (tier - 1)
			var goal: int = 10 if tier == 2 else 20
			var count: int = counts.get(prior, 0)
			var item: Dictionary = SeasonGearCatalog.item(id)
			SeasonPages.wrapped(
				card,
				(
					"%s • %s • %d/%d with %s\n%d Season Cash • Working: %s"
					% [
						item.name,
						"SHOP ELIGIBLE" if count >= goal else "LOCKED",
						mini(count, goal),
						goal,
						SeasonGearCatalog.item(prior).name,
						item.price,
						ClubCollectionUI.effect(menu, id)
					]
				)
			)
	var alley: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(alley, "Alley Bat", 22)
	var uses: int = int(counts.get(SeasonAlleyGear.BASE, 0))
	SeasonPages.wrapped(
		alley,
		(
			"Gap Driver • %s • %d/10 with Alley Bat\n16 Season Cash • Working: %s"
			% [
				"SHOP ELIGIBLE" if uses >= 10 else "LOCKED",
				mini(uses, 10),
				ClubCollectionUI.effect(menu, SeasonAlleyGear.GAP)
			]
		)
	)
	SeasonPages.wrapped(
		alley,
		(
			"Gap Driver qualifying games: %d. Frozen Rope is not available yet."
			% int(counts.get(SeasonAlleyGear.GAP, 0))
		)
	)
	(
		SeasonPages
		. wrapped(
			menu._body,
			(
				"All seven Misc are initially eligible. Alley progression counts future completed games; "
				+ "older untracked games grant no retroactive credit."
			)
		)
	)
	menu._button(menu._footer, "BACK TO CLUB RECORD", ClubCareerUI.show.bind(menu, 0))
