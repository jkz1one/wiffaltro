class_name StadiumClubItems
extends RefCounted
## Frozen club-display geometry, independent of its copy/blueprint prices.

const VERSION: int = 1
const LAYOUT_VERSION: int = 4


static func signature() -> String:
	var sites: Dictionary = {}
	for id: String in StadiumClubSites.SITES:
		var row: Dictionary = StadiumClubSites.SITES[id]
		sites[id] = {"item": row.item, "position": [row.position.x, row.position.y, row.position.z],
			"yaw": row.yaw}
	return JSON.stringify({"version": VERSION, "models": StadiumClubModels.VERSION,
		"sites_version": StadiumClubSites.VERSION, "sites": sites}, "", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumFieldStyles.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 3, 3):
		result.version = LAYOUT_VERSION
		result.family = "reference-club-displays-v4"
		result["displays"] = []
	return result
