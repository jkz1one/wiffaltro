class_name SeasonSchoolShopUI
extends RefCounted


static func status(window: SeasonShopWindow) -> void:
	var view: Dictionary = window.app.season.build.view()
	if view.shop.get("union_credit", 0) > 0:
		window._label(
			(
				"Union Hall: 3 development credit, not Cash. Next loose card or fixed pack; "
				+ "expires on leaving. Acquisition mapping is an unapproved Proposal."
			)
		)
	var student: Dictionary = SeasonSchoolSponsors.scholarship(window.app.season.build)
	if not student.is_empty():
		window._label(
			(
				"Summer School student: %s • %d discounts remain • always 0 resale"
				% [window.app.season.player_definition(student.player).display_name, student.uses]
			)
		)


static func students(window: SeasonShopWindow, offer: String, old: Dictionary) -> void:
	window._clear()
	window._label("NOMINATE FIXED STUDENT • unapproved eligibility Proposal")
	window._label(SeasonSponsorCatalog.item("J10").effect)
	for id: String in window.app.season.build.roster():
		if not SeasonSchoolSponsors.eligible_student(window.app.season.build, id):
			continue
		var player: PlayerDefinition = window.app.season.player_definition(id)
		SeasonPlayerCard.ratings_card(window._body, player, player.display_name)
		var description: String = (
			"Activate Summer School for 6 Cash. Student: %s\n%s"
			% [player.display_name, SeasonSponsorCatalog.item("J10").effect]
		)
		if not old.is_empty():
			description += (
				"\nSell %s for %d Cash; no reserve retained."
				% [SeasonSponsorCatalog.item(old.item).name, SeasonSponsorCatalog.resale(old)]
			)
		(
			window
			. _button(
				"NOMINATE " + player.display_name,
				window._preview.bind(
					window._request(
						"sponsor_buy", {"offer": offer, "replace": old.get("id", ""), "student": id}
					),
					description
				)
			)
			. set_meta("student", id)
		)
	window._button("CANCEL NOMINATION", window._refresh)
	window._focus_first.call_deferred()


static func paired(
	window: SeasonShopWindow, offer: String, id: String, first: Dictionary = {}
) -> void:
	window._clear()
	var item: Dictionary = DevelopmentShopCatalog.item(id)
	window._label(
		"OPEN BOOK • %s • %d Cash total" % [item.name, SeasonSchoolSponsors.pair_price(item.price)]
	)
	(
		window
		. _label(
			(
				"Choose %s recipient and any replacement. Each player keeps their own remembered mastery."
				% ("first" if first.is_empty() else "second distinct")
			)
		)
	)
	for target: Dictionary in window.app.season.build.targets(id):
		if not first.is_empty() and target.player == first.player:
			continue
		var label: String = window._target_text(item, target)
		if first.is_empty():
			window._button(label, paired.bind(window, offer, id, target)).set_meta(
				"pair_first", target
			)
		else:
			var description: String = (
				"%s\n%s\n%s\nOne offer; base %d + %d for second learner."
				% [
					item.name,
					window._target_text(item, first),
					label,
					item.price,
					ceili(float(item.price) / 2)
				]
			)
			(
				window
				. _button(
					label,
					window._preview.bind(
						window._request(
							"lesson_pair", {"offer": offer, "first": first, "second": target}
						),
						description
					)
				)
				. set_meta("pair_second", target)
			)
	window._button("CANCEL PAIRING", window._refresh)
	window._focus_first.call_deferred()


static func choose_concession(
	window: SeasonShopWindow, command: Dictionary, description: String
) -> bool:
	if command.op != "buy" or command.has("concession"):
		return false
	var build: SeasonBuild = window.app.season.build
	var id: String = build.view().shop.offers.get(command.get("offer", ""), "")
	var options: Dictionary = SeasonSchoolSponsors.concessions(build, id, command)
	if options.size() < 2:
		return false
	window._clear()
	window._label("CHOOSE ONE CONCESSION • cannot stack")
	window._label(description)
	for kind: String in options:
		var selected: Dictionary = command.duplicate(true)
		selected["concession"] = kind
		var label: String = (
			"%s • pay %d Cash • retain the other allowance"
			% [
				"Union Hall" if kind == "union" else "Summer School",
				maxi(0, DevelopmentShopCatalog.item(id).price - options[kind])
			]
		)
		window._purchase(label, selected, description + "\n" + label).set_meta("concession", kind)
	window._button("CANCEL CONCESSION", window._refresh)
	window._focus_first.call_deferred()
	return true
