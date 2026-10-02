class_name ClubCollectionUI
extends RefCounted

const PAGE_SIZE: int = 8
const CONCEALED: String = (
	"Acquire this item to reveal its effect here. Shop offers show full details."
)


static func effect(menu: SeasonMenu, id: String) -> String:
	var season: SeasonState = menu.app.season
	if ClubCollection.discoveries(season.career, season.build).has(id):
		return ClubCollection.catalog()[id].effect
	return CONCEALED


static func show(menu: SeasonMenu, category: String = "Gear", page: int = 0) -> void:
	var season: SeasonState = menu.app.season
	if season.career == null:
		return
	if category not in ["Gear", "Sponsors"]:
		category = "Gear"
	var catalog: Dictionary = ClubCollection.catalog()
	var discovered: Array[String] = ClubCollection.discoveries(season.career, season.build)
	var owned: Array[String] = ClubCollection.owned(season.build)
	var access: Array[String] = ClubCollection.access(season.career)
	var ids: Array[String] = []
	var count: int = 0
	for id: String in catalog:
		if catalog[id].category == category:
			ids.append(id)
			count += int(discovered.has(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return catalog[a].name < catalog[b].name)
	var last_page: int = maxi(0, int((ids.size() - 1) / float(PAGE_SIZE)))
	page = clampi(page, 0, last_page)
	menu._screen(
		"collection", "COLLECTION", "Acquisition reveals effects; ownership lasts this season"
	)
	var tabs: HBoxContainer = HBoxContainer.new()
	menu._body.add_child(tabs)
	for tab: String in ["Gear", "Sponsors"]:
		var button: Button = menu._button(tabs, tab.to_upper(), show.bind(menu, tab, 0))
		button.set_meta("collection_category", tab)
		button.toggle_mode = true
		button.set_pressed_no_signal(tab == category)
		if tab == category:
			ClubhouseTheme.primary(button)
	menu._label(menu._body, "%s • %d / %d acquired" % [category, count, ids.size()], 24)
	(
		SeasonPages
		. wrapped(
			menu._body,
			"Sold copies stay discovered. Duplicates add no discoveries. Access never grants a free copy."
		)
	)
	if season.career.runs.any(func(run: Dictionary) -> bool: return run.collection == null):
		SeasonPages.wrapped(menu._body, "Older archived seasons have no acquisition record.")
	for index in range(page * PAGE_SIZE, mini(ids.size(), (page + 1) * PAGE_SIZE)):
		var id: String = ids[index]
		var item: Dictionary = catalog[id]
		var card: VBoxContainer = SeasonPlayerCard.panel(menu._body, owned.has(id))
		card.set_meta("collection_item", id)
		SeasonPages.wrapped(card, item.name)
		SeasonPages.wrapped(
			card,
			(
				("ACQUIRED" if discovered.has(id) else "NOT ACQUIRED")
				+ " • "
				+ ("EQUIPPED" if owned.has(id) else "NOT OWNED THIS SEASON")
				+ " • "
				+ ("ACCESS EARNED" if access.has(id) else "LOCKED")
			)
		)
		SeasonPages.wrapped(card, "%d Season Cash • Working" % item.price)
		SeasonPages.wrapped(card, effect(menu, id))
		if not access.has(id):
			SeasonPages.wrapped(card, requirement(id))
	menu._label(menu._body, "Page %d of %d" % [page + 1, last_page + 1], 18)
	if page > 0:
		menu._button(menu._footer, "PREVIOUS", show.bind(menu, category, page - 1))
	if page < last_page:
		menu._button(menu._footer, "NEXT", show.bind(menu, category, page + 1))
	menu._button(menu._footer, "CLUB RECORD", ClubCareerUI.show.bind(menu, 0))


static func requirement(id: String) -> String:
	if id == SeasonFrozenRope.ID:
		return "Complete 20 qualifying games with Gap Driver equipped at the first pitch."
	if id == SeasonAlleyGear.GAP:
		return "Complete 10 qualifying games with Alley Bat equipped at the first pitch."
	if SeasonEarnedGear.ITEMS.has(id):
		var tier: int = int(id.right(2))
		var prior: String = id.left(-2) + "%02d" % (tier - 1)
		return (
			"Complete %d qualifying games with %s equipped at the first pitch."
			% [10 if tier == 2 else 20, SeasonGearCatalog.item(prior).name]
		)
	if SeasonEarnedSponsors.REQUIREMENTS.has(id):
		return SeasonEarnedSponsors.REQUIREMENTS[id]
	return (
		{
			"J01": "Season: pay at least 1 Cash for each of three ordinary individual rerolls.",
			"G01":
			"Buy one ordinary individual offer for at least 16 actual Cash. No packs or deals.",
			"F07": "Season: two current players each know a purchased season-learned pitch.",
			"E04": "Career: consume three tactical copies in completed games.",
			"G03": "Complete a game with a credited walk while an original Tape or Plan is active.",
			"J05": "Season: save five distinct Common sponsors active together in a legal loadout.",
			"E10":
			"Complete a game with a hitter recording a hit after two consecutive hitless at-bats.",
			"F06":
			"Complete a game with three opposite-side consecutive-own-PA transitions within halves.",
			"J04": "Complete a game with one Primary Fielder recording three clean fielded outs.",
			"G02": "Career: consume Grip Tape, Recovery Pack and Swing Plan in completed games.",
			"F08":
			"Complete a game with a strikeout after three or more actual pitches of one exact recipe.",
			"B01":
			"Season: six clean fielded outs across completed games. No Ks, fouls or prior bobbles.",
			"E09": "Season: save four distinct sponsors active together in a legal loadout.",
			"F09":
			"One Primary Fielder makes clean grounded and airborne outs in one completed game."
		}
		. get(id, "Initially eligible for future shop offers.")
	)
