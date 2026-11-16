class_name StadiumSmallYardSceneryItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Existing paid objects share one live/scenery/Stored selector; no new purchase identity.

const NIGHT_REASON: String = \
	("Small-yard scenery is daylight-only until its lighting and camera " + \
	"views are qualified. Store it to recover the prior supported layout.")


static func choices(item: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"mode": "stored", "site": "", "yaw": 0, "label": "Stored"}]
	if item in ["ST-001", "ST-003"]:
		for site: String in StadiumStarterLayout.SITES:
			for yaw: int in StadiumSmallYardSceneryItems.yaws(item):
				result.append(
					{
						"mode": "live",
						"site": site,
						"yaw": yaw,
						"label": "%s • Live • %d°" % [site, yaw]
					}
				)
	else:
		for site: String in StadiumGroundPropsItems.SITES:
			if StadiumGroundPropsItems.SITES[site].items.has(item):
				result.append({"mode": "live", "site": site, "yaw": 0, "label": site + " • Live"})
	for site: String in StadiumSmallYardSceneryItems.sites(item):
		for yaw: int in StadiumSmallYardSceneryItems.yaws(item):
			result.append(
				{
					"mode": "scenery",
					"site": site,
					"yaw": yaw,
					"label": "%s • Scenery • %d°" % [site, yaw]
				}
			)
	return result


static func proposal(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	choice: Dictionary,
	access: Array[String] = []
) -> Dictionary:
	if choice.mode == "stored":
		return StadiumSmallYardSceneryItems.store_copy(layout, copy)
	if choice.mode == "live":
		return StadiumSmallYardSceneryItems.place_live(
			layout, stock, copy, choice.site, choice.yaw, access
		)
	return StadiumSmallYardSceneryItems.place(layout, stock, copy, choice.site, choice.yaw, access)


static func holds_choice(
	layout: Dictionary, copy: String, item: String, choice: Dictionary
) -> bool:
	if choice.mode == "stored":
		for channel: String in ["yard_scenery", "obstacles", "props"]:
			for row: Dictionary in layout.get(channel, []):
				if row.copy == copy:
					return false
		return true
	var channel: String = (
		"yard_scenery"
		if choice.mode == "scenery"
		else "obstacles" if item in ["ST-001", "ST-003"] else "props"
	)
	for row: Dictionary in layout.get(channel, []):
		if row.copy == copy and row.site == choice.site and int(row.get("yaw", 0)) == choice.yaw:
			return true
	return false


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	item: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var options: Array[Dictionary] = choices(item)
	var names: Array[String] = []
	var selected: int = 0
	for index in range(options.size()):
		var option: Dictionary = options[index]
		names.append(option.label)
		var channel: String = (
			"yard_scenery"
			if option.mode == "scenery"
			else "obstacles" if item in ["ST-001", "ST-003"] else "props"
		)
		for row: Dictionary in draft.get(channel, []):
			if (
				row.copy == copy
				and row.site == option.site
				and int(row.get("yaw", 0)) == option.yaw
			):
				selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, options.size()):
		var candidate: Dictionary = proposal(
			draft, stock, copy, options[index], ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = holds_choice(candidate, copy, item, options[index])
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This existing layout does not support that scenery route."
				)
			)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"The same paid copy moves freely between its approved live site, yard scenery and "
				+ "storage. Scenery has no physical contact, scoring, route or live-capacity effect. "
				+ "Each yard cell reserves a full 1 m radius and 1.5 m height; conflicting occupants "
				+ "must be stored explicitly."
			)
		)
	)
	SeasonPages.wrapped(panel, NIGHT_REASON)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == selected:
				return
			var candidate: Dictionary = proposal(
				draft, stock, copy, options[index], ledger.surface_owned()
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)
