class_name StadiumScoreboardCatalog
extends RefCounted
## Versioned extension; catalog101 and all historic prices/IDs remain immutable.
## Electronic numerical values are Working defaults pending the final economy review.

const VERSION: int = 1
const ELECTRONIC: String = "ST-090"
const IDS: Array[String] = ["ST-039", "ST-090", "ST-040"]
const TIERS: Dictionary = {"ST-039": "manual", "ST-090": "electronic", "ST-040": "video"}
const MIDDLE: Dictionary = {"id": "ST-090", "name": "Electronic club scoreboard",
	"requires": {"seasons": 12, "wins": 35}, "blueprint_price": 540, "copy_price": 160,
	"kind": "copy", "requirement": "S>=12; W>=35", "annex": "working-scoreboard-tier-v1",
	"starter": false, "live_units": 0, "placement_verified": false}


static func item(id: String) -> Dictionary:
	return MIDDLE.duplicate(true) if id == ELECTRONIC else (
		StadiumCatalog.item(id) if IDS.has(id) else {})


static func eligible(id: String, progress: Dictionary) -> bool:
	if id != ELECTRONIC:
		return IDS.has(id) and StadiumCatalog.eligible(id, progress)
	for key: String in MIDDLE.requires:
		if not SeasonOwnership._whole(progress.get(key), int(MIDDLE.requires[key]), 1000000000):
			return false
	return true


static func signature() -> String:
	var rows: Dictionary = {}
	for id: String in IDS:
		var entry: Dictionary = item(id)
		rows[id] = [entry.requires, entry.blueprint_price, entry.copy_price, entry.kind]
	return JSON.stringify({"version": VERSION, "items": rows,
		"policy": "exact-item-blueprint-and-copy-v1"}, "", true, true).sha256_text()
