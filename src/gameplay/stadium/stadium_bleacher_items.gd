class_name StadiumBleacherItems
extends RefCounted
## Complete advanced bleachers remain separate owned assemblies on exclusive side sites.

const LAYOUT_VERSION: int = 6


static func signature() -> String:
	return JSON.stringify({"version": LAYOUT_VERSION, "models": StadiumBleacherModels.VERSION,
		"sites": StadiumBleacherSites.VERSION, "tiers": StadiumBleacherSites.TIERS,
		"old_sites": StadiumHomeLayout.signature()}, "", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumGroundStyles.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 5, 5):
		result.version = LAYOUT_VERSION
		result.family = "reference-bleachers-v6"
		result["bleachers"] = []
	return result
