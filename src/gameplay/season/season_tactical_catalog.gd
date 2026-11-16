class_name SeasonTacticalCatalog
extends RefCounted
## Working core tactical contracts; the shared two-slot bag is Approved.

const HEAT: String = "tactical.extra_heat"
const BASE: String = "tactical.take_base"

const ITEMS: Dictionary = {
	"A10":
	{
		"name": "Grip Tape",
		"price": 3,
		"effect": "One PA: Contact and Power coverage +8%; fair exit speed −5%.",
	},
	"C02":
	{
		"name": "Recovery Pack",
		"price": 4,
		"effect":
		(
			"Restore 10% of the active pitcher's game-start maximum stamina, capped at maximum. "
			+ "Once per pitcher per game."
		),
	},
	"C03":
	{
		"name": "Swing Plan",
		"price": 3,
		"effect":
		"Lock Contact or Power for one PA. Fair contact at quality ≥65% gets +6% exit speed.",
	},
}

const EXPANSION: Dictionary = {
	HEAT:
	{
		"name": "Extra Heat",
		"price": 5,
		"effect":
		(
			"Active pitcher: velocity parameter ×1.05 for one opposing PA. "
			+ "Ends on substitution. Normal fatigue and physical limits still apply."
		),
	},
	BASE:
	{
		"name": "Take a Base",
		"price": 8,
		"effect":
		(
			"Advance only the lowest occupied runner one base into a free destination. "
			+ "Third can score or walk off. No hit, walk or RBI credit."
		),
	},
}


static func catalog(version: int = 2) -> Dictionary:
	var result: Dictionary = ITEMS.duplicate(true)
	if version >= 2:
		result.merge(EXPANSION.duplicate(true))
	return result


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, EXPANSION.get(id, {})).duplicate(true)


static func weights(version: int = 2) -> Dictionary:
	var result: Dictionary = {"A10": 1.0, "C02": 1.0, "C03": 1.0}
	if version >= 2:
		result.merge({HEAT: 1.0, BASE: 4.0 / 19.0})
	return result


static func signature(version: int = 2) -> String:
	return JSON.stringify(catalog(version)).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = {}
	for id: String in catalog():
		result[id] = {"kind": "held", "price": item(id).price, "sale": "zero"}
	return result


static func held(wallet: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for receipt: Dictionary in wallet.held:
		if not item(receipt.item).is_empty():
			result.append(receipt.duplicate(true))
	return result
