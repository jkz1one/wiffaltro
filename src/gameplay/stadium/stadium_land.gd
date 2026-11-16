class_name StadiumLand
extends RefCounted
## Incremental, prerequisite-ordered property purchases. No items or live capacity granted.

const VERSION: int = 1
const TIERS: Array[String] = ["backyard", "expanded", "club", "mogul"]
const NAMES: Dictionary = {"backyard": "Backyard", "expanded": "Expanded yard",
	"club": "Club grounds", "mogul": "Mogul grounds"}


static func signature() -> String:
	var shapes: Dictionary = {}
	for tier: String in TIERS:
		shapes[tier] = StadiumProperty.signature(tier)
	return JSON.stringify({"version": VERSION, "prices": StadiumCatalog.LAND,
		"shapes": shapes}, "", true, true).sha256_text()


static func next_tier(current: String) -> String:
	var index: int = TIERS.find(current)
	return TIERS[index + 1] if index >= 0 and index < TIERS.size() - 1 else ""


static func quote(current: String, target: String, progress: Dictionary,
	version: int = VERSION) -> Dictionary:
	if version != VERSION or target.is_empty() or target != next_tier(current):
		return ClubAssetLedger._error("Purchase the next property stage in order.")
	var row: Dictionary = StadiumCatalog.LAND[target]
	for key: String in ["seasons", "wins"]:
		if not SeasonOwnership._whole(progress.get(key), int(row[key]), 1000000000):
			return ClubAssetLedger._error("This property stage's career requirement has not been met.")
	return {"ok": true, "error": "", "from": current, "tier": target, "cost": int(row.price),
		"granted_copies": 0, "live_limit": 4, "field_changes": false}
