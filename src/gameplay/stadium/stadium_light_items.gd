class_name StadiumLightItems
extends RefCounted
## Exact paid four-pole yard recipe with independently frozen presentation qualification.

const LAYOUT_VERSION: int = 9
const PROFILE: String = "YARD-FOUR-STRAIGHT-v1"
const COMPATIBLE_ITEMS: Array[String] = ["ST-001", "ST-003", "ST-079", "ST-080", "ST-027",
	"ST-028", "ST-026", "ST-025", "ST-039", "ST-041", "ST-037"]


static func signature() -> String:
	var sites: Dictionary = {}
	for site: String in StadiumYardLightModels.SITES:
		var point: Vector3 = StadiumYardLightModels.SITES[site]
		sites[site] = [point.x, point.y, point.z, StadiumYardLightSites.yaw(site)]
	return JSON.stringify({"version": LAYOUT_VERSION, "profile": PROFILE,
		"model": StadiumYardLightModels.VERSION, "night": StadiumYardNightPrototype.VERSION,
		"sites": sites, "compatible": COMPATIBLE_ITEMS, "environment_policy": 1,
		"ball_style": StadiumNightBallStyle.SOURCE.sha256_text()},
		"", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumNetItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 8, 8):
		result.version = LAYOUT_VERSION
		result.family = "reference-yard-lights-v9"
		result["lights"] = []
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if not SeasonOwnership._keys(layout, ["version", "family", "receiver", "obstacles",
		"seating", "styles", "displays", "ground", "bleachers", "target", "net", "lights"]) \
		or not layout.family is String or layout.family != "reference-yard-lights-v9":
		return StadiumStarterLayout._error("Unknown yard-light layout.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("lights")
	base.version = 8
	base.family = "reference-paired-receiver-v8"
	var result: Dictionary = StadiumHomeLayout.validate(base, stock, tier)
	if not result.ok:
		return result
	var lights: Dictionary = StadiumYardLightSites.validate(layout.lights, stock, tier)
	if not lights.ok:
		return lights
	for row: Dictionary in lights.placements:
		result.placements.append(row)
		result.stored.erase(row.copy)
	result.night_qualified = lights.complete and tier in ["backyard", "expanded"]
	for row: Dictionary in result.placements:
		if not COMPATIBLE_ITEMS.has(row.item):
			result.night_qualified = false
	return result
