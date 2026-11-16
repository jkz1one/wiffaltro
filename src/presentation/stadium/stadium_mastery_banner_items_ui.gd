class_name StadiumMasteryBannerItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Earned collection control only; deliberately absent from every shop.


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var next_base: Dictionary = StadiumMasteryBannerItems.upgrade(draft, ledger.surface_owned())
	var labels: Array[String] = ["Stored"]
	var choices: Array[Dictionary] = [{}]
	var selected: int = 0
	if not next_base.is_empty():
		for option: Dictionary in StadiumMasteryBannerItems.candidates(next_base, stock):
			choices.append(option)
			labels.append(option.host_site + " • BANNER-WALL • " + option.host)
			for placed: Dictionary in next_base.mastery_banners:
				if (
					placed.copy == copy
					and placed.host == option.host
					and placed.socket == option.socket
				):
					selected = choices.size() - 1
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	for index in range(1, choices.size()):
		var candidate: Dictionary = StadiumMasteryBannerItems.place(
			next_base, stock, copy, choices[index].host
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		choice.set_item_disabled(index, not checked.ok)
		if not checked.ok:
			choice.set_item_tooltip(index, checked.error)
	var earned: Dictionary = stock.copies[copy].earned
	SeasonPages.wrapped(
		panel,
		(
			"%s • Standard league mastery • Tier 5 • First qualifying season %d"
			% [earned.era.name, earned.season_number]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Historical crest and colors stay frozen. BANNER-WALL excludes the overlapping facade "
				+ "crest. Storing, moving or replacing the exact lower host stores this banner safely. "
				+ "No shop price, income or gameplay bonus."
			)
		)
	)
	if choices.size() == 1:
		(
			SeasonPages
			. wrapped(
				panel,
				"No compatible ST-029 lower-stand facade is installed. This earned banner remains in storage."
			)
		)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == selected or next_base.is_empty():
				return
			var next: Dictionary = (
				StadiumMasteryBannerItems.store_copy(next_base, copy)
				if index == 0
				else StadiumMasteryBannerItems.place(next_base, stock, copy, choices[index].host)
			)
			EditorAccess.editor_preview(menu, next, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
