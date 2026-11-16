class_name StadiumWallPieceCatalog
extends RefCounted
## Working low/tall component identities. Exact unlock and purchase authority belongs to the ledger.

const VERSION: int = 1
const DATA: Dictionary = {
	"ST-024-L": ["ST-024", "low", 15], "ST-024-T": ["ST-024", "tall", 45],
	"ST-065-L": ["ST-065", "low", 20], "ST-065-T": ["ST-065", "tall", 55],
	"ST-077-L": ["ST-077", "low", 25], "ST-077-T": ["ST-077", "tall", 70],
	"ST-078-L": ["ST-078", "low", 15], "ST-078-T": ["ST-078", "tall", 45]}


static func item(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var row: Array = DATA[id]
	return {"id": id, "material": row[0], "height": row[1], "copy_price": row[2],
		"height_m": 1.625 if row[1] == "low" else 4.875,
		"name": row[1].capitalize() + " " + StadiumCatalog.item(row[0]).name.to_lower()}


static func identity(material: String, height: String) -> String:
	var candidate: String = material + ("-L" if height == "low" else "-T" if height == "tall" else "")
	return candidate if DATA.has(candidate) else ""


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "base_catalog": StadiumCatalog.signature(),
		"pieces": DATA, "heights": {"low": 1.625, "tall": 4.875}},
		"", true, true).sha256_text()
