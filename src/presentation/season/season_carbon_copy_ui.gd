class_name SeasonCarbonCopyUI
extends RefCounted


static func add(menu: SeasonMenu, card: VBoxContainer, fixture: Dictionary) -> void:
	var app: SeasonApp = menu.app
	var build: SeasonBuild = app.season.build
	if build == null:
		return
	var game: int = int(fixture.id)
	if build._copy.selections.has(str(game)):
		var mark: Dictionary = build._copy.selections[str(game)]
		SeasonPages.wrapped(
			card,
			(
				"Carbon Copy locked: "
				+ (
					"no compatible source"
					if mark.item == ""
					else SeasonSponsorCatalog.item(mark.item).name
				)
				+ (
					" • source inactive"
					if mark.item != "" and SeasonCarbonCopy.target(build, game) == ""
					else ""
				)
				+ ". Restart cannot change this selection."
			)
		)
		return
	if SeasonSchoolSponsors.active(build, "E09").is_empty():
		return
	if build._pregames.has(str(game)):
		SeasonPages.wrapped(card, "Carbon Copy: this game's selection is closed. Choose next game.")
		return
	var sources: Array = SeasonCarbonCopy.sources(build)
	if sources.is_empty():
		SeasonPages.wrapped(
			card, "Carbon Copy: no active Deli or Take Your Base. No copied effect this game."
		)
		return
	if app.copy_game != game:
		app.copy_game = game
		app.copy_receipt = "?"
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Carbon Copy • Choose one active source. Play Game saves this choice for the whole game, "
				+ "including restarts. Both copies occupy their own slots. Working."
			)
		)
	)
	var picker: OptionButton = OptionButton.new()
	picker.name = "CarbonCopySource"
	picker.custom_minimum_size.y = 44
	picker.add_item("Choose Carbon Copy source…")
	picker.set_item_metadata(0, "?")
	for receipt: Dictionary in sources:
		picker.add_item(SeasonSponsorCatalog.item(receipt.item).name)
		picker.set_item_metadata(picker.item_count - 1, receipt.id)
	for index in range(picker.item_count):
		if picker.get_item_metadata(index) == app.copy_receipt:
			picker.select(index)
	picker.item_selected.connect(
		func(index: int) -> void: app.copy_receipt = picker.get_item_metadata(index)
	)
	card.add_child(picker)
