class_name SeasonSmallBatch
extends RefCounted
## Working G02. Career access records only the three original completed-game supplies.

const TYPES: Array = ["A10", "C02", "C03"]
const ITEMS: Dictionary = {
	"G02":
	{
		"name": "Small Batch Supply",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Three active sponsors maximum, including Small Batch; one extra shared held slot. "
			+ "No free supplies or extra activations. Explicitly resolve excess copies before removal."
		)
	}
}


static func combine(first: Array, second: Array) -> Array:
	var result: Array = []
	for id: String in TYPES:
		if first.has(id) or second.has(id):
			result.append(id)
	return result


static func valid(value: Variant) -> bool:
	return value is Array and value == combine(value, [])


static func access(club: ClubCareer, before_current: bool = false) -> Array:
	var result: Array = []
	for run: Dictionary in club.runs:
		if before_current and run.id == club.current:
			break
		if run.batch_used != null:
			result = combine(result, run.batch_used)
	return result


static func matches(club: ClubCareer, season: SeasonState, exact: bool) -> bool:
	var build: SeasonBuild = season.build
	var run: Dictionary = club.runs[-1]
	if (run.batch_used != null) != (build._batch_start != null):
		return false
	return (
		build._batch_start == null
		or (
			build._batch_start == access(club, true)
			and (not exact or run.batch_used == build._batch_used)
		)
	)


static func progress(menu: SeasonMenu) -> void:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	var used: Array = access(menu.app.season.career)
	menu._label(
		card, "Small Batch Supply • " + ("SHOP ELIGIBLE" if used.size() == 3 else "LOCKED"), 22
	)
	(
		SeasonPages
		. wrapped(
			card,
			(
				"Career: consume Grip Tape, Recovery Pack and Swing Plan in completed "
				+ (
					"games. %d / 3 types. Heat and Take a Base do not count. 12 Cash • Uncommon • Working. "
					% used.size()
				)
				+ ClubCollectionUI.effect(menu, "G02")
			)
		)
	)
	for id: String in TYPES:
		SeasonPages.wrapped(
			card, ("✓ " if used.has(id) else "○ ") + SeasonTacticalCatalog.item(id).name
		)
	if menu.app.season.build == null or menu.app.season.build._batch_start == null:
		SeasonPages.wrapped(card, "This older active save begins tracking next Working season.")
