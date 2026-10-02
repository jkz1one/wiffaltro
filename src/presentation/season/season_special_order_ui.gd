class_name SeasonSpecialOrderUI
extends RefCounted


static func entry(window: SeasonShopWindow) -> void:
	var build: SeasonBuild = window.app.season.build
	var shop: Dictionary = build.view().shop
	if shop.get("unavailable_slots", 0) > 0:
		window._label("%d positions unavailable: focused pool exhausted." % shop.unavailable_slots)
	if SeasonSchoolSponsors.active(build, "J01").is_empty():
		return
	if shop.get("focused_used", false):
		window._label("Special Order used this visit. Ordinary rerolls remain available.")
		return
	window._button("SPECIAL ORDER • CHOOSE CATEGORY", choose.bind(window)).set_meta(
		"special_order", true
	)


static func choose(window: SeasonShopWindow) -> void:
	window._clear()
	window._label("SPECIAL ORDER • ONE FOCUSED REROLL THIS VISIT")
	(
		window
		. _label(
			(
				"Choose a category before paying. Pack, recruiting and an unbought Raincheck stay fixed. "
				+ "No duplicate identities; smaller pools leave unavailable positions. Working contract."
			)
		)
	)
	var build: SeasonBuild = window.app.season.build
	for category: String in SeasonSpecialOrder.CATEGORIES:
		var pool: Dictionary = SeasonSpecialOrder.pool(build, category)
		var protected: Dictionary = SeasonRaincheck.protected_offer(build)
		for id: String in protected.values():
			pool.erase(id)
		var slots: int = 4 - protected.size()
		var count: int = mini(slots, pool.size())
		var label: String = SeasonSpecialOrder.CATEGORIES[category]
		var button: Button = window._purchase(
			(
				"%s • %d / %d refreshed positions • %d Cash"
				% [label, count, slots, SeasonReclamation.price(build.view().shop)]
			),
			window._request("focused_reroll", {"category": category}),
			(
				(
					"Focus %s: up to %d distinct offers. Remaining positions are unavailable. "
					% [label, count]
				)
				+ "Uses this visit's one focused reroll and advances the ordinary reroll price. "
				+ "Pack and recruiting do not change. Existing Reclamation credit is consumed."
			)
		)
		button.disabled = button.disabled or count == 0
		button.set_meta("focus_category", category)
	window._label("Only categories with eligible offers can be selected.")
	window._button("BACK TO SHOP", window._refresh)
	window._focus_first.call_deferred()


static func progress(menu: SeasonMenu) -> void:
	var club: ClubCareer = menu.app.season.career
	var build: SeasonBuild = menu.app.season.build
	var unlocked: bool = club.order_access()
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(card, "Special Order Supply • " + ("SHOP ELIGIBLE" if unlocked else "LOCKED"), 22)
	SeasonPages.wrapped(
		card,
		(
			"Season: pay for three ordinary individual rerolls, each costing "
			+ "at least 1 actual Cash. Earned access survives abandonment; no free sponsor copy."
		)
	)
	var count: int = mini(3, build._paid_rerolls) if build != null else 0
	SeasonPages.wrapped(
		card, "This season: %d / 3 paid rerolls. 12 Season Cash • Uncommon • Working" % count
	)

	if build == null or build._order_start == null:
		SeasonPages.wrapped(
			card, "This older active save begins this tracking next Working season."
		)
	SeasonPages.wrapped(card, ClubCollectionUI.effect(menu, "J01"))
