class_name SeasonTacticalCatalog
extends RefCounted
## Working core tactical contracts; the shared two-slot bag is Approved.

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


static func item(id: String) -> Dictionary:
	return ITEMS.get(id, {}).duplicate(true)


static func weights() -> Dictionary:
	return {"A10": 1.0, "C02": 1.0, "C03": 1.0}


static func signature() -> String:
	return JSON.stringify(ITEMS).sha256_text()


static func ownership_catalog() -> Dictionary:
	var result: Dictionary = {}
	for id: String in ITEMS:
		result[id] = {"kind": "held", "price": ITEMS[id].price, "sale": "zero"}
	return result


static func held(wallet: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for receipt: Dictionary in wallet.held:
		if ITEMS.has(receipt.item):
			result.append(receipt.duplicate(true))
	return result
