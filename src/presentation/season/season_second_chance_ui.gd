class_name SeasonSecondChanceUI
extends RefCounted

const OUTCOMES: Dictionary = {
	"restored": "One fresh copy restored. It has no active effect and no inherited insurance mark.",
	"not_used": "No restoration: the marked copy was not consumed while insured.",
	"skipped": "Insurance skipped for this game.",
	"full": "No restoration: inventory full at settlement. No copy was queued or item discarded."
}


static func add(menu: SeasonMenu, card: VBoxContainer, fixture: Dictionary) -> void:
	var app: SeasonApp = menu.app
	var build: SeasonBuild = app.season.build
	if build == null:
		return
	var game: String = str(int(fixture.id))
	if build._insurance.has(game):
		var mark: Dictionary = build._insurance[game]
		SeasonPages.wrapped(
			card,
			(
				"Second Chance locked: "
				+ (
					"skipped"
					if mark.receipt == ""
					else SeasonTacticalCatalog.catalog()[mark.item].name
				)
				+ ". Restart cannot change this selection."
			)
		)
		return
	if SeasonSchoolSponsors.active(build, "E04").is_empty():
		return
	if app.insurance_game != int(fixture.id):
		app.insurance_game = int(fixture.id)
		app.insurance_receipt = "?"
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Second Chance: choose one exact copy or skip. Play Game saves "
				+ "the selection. Only completed use while active can restore it, once, if the bag has room."
			)
		)
	)
	var picker: OptionButton = OptionButton.new()
	picker.name = "InsuranceCopy"
	picker.custom_minimum_size.y = 44
	picker.add_item("Choose insurance…")
	picker.set_item_metadata(0, "?")
	picker.add_item("Skip insurance this game")
	picker.set_item_metadata(1, "")
	var ordinal: int = 0
	for copy: Dictionary in build._bank.view().held:
		if copy.item not in SeasonSecondChance.ELIGIBLE:
			continue
		ordinal += 1
		picker.add_item("%s • Copy %d" % [SeasonTacticalCatalog.catalog()[copy.item].name, ordinal])
		picker.set_item_metadata(picker.item_count - 1, copy.id)
	for index in range(picker.item_count):
		if picker.get_item_metadata(index) == app.insurance_receipt:
			picker.select(index)
	picker.item_selected.connect(
		func(index: int) -> void: app.insurance_receipt = picker.get_item_metadata(index)
	)
	card.add_child(picker)


static func result(menu: SeasonMenu, game: int) -> void:
	var mark: Dictionary = menu.app.season.build._insurance.get(str(game), {})
	if not mark.is_empty():
		SeasonPages.wrapped(menu._body, "Second Chance: " + OUTCOMES.get(mark.outcome, "Pending"))


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var count: int = menu.app.season.career.supply_count()
	menu._label(card, "Second Chance Supply • " + ("SHOP ELIGIBLE" if count >= 3 else "LOCKED"), 22)
	SeasonPages.wrapped(
		card,
		(
			"Career: consume three tactical copies in completed games. "
			+ "Inherited effects, unfinished games and replay do not count. %d / 3. " % count
			+ "14 Season Cash • Uncommon • Working. "
			+ SeasonSecondChance.ITEMS.E04.effect
		)
	)
	var build: SeasonBuild = menu.app.season.build
	if build == null or build._supply_start == null:
		SeasonPages.wrapped(
			card, "This older active save begins this tracking next Working season."
		)
