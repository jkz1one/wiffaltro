class_name StadiumNetItems
extends RefCounted
## Two separately owned receiver copies at fixed, verified paired positions.

const LAYOUT_VERSION: int = 8
const CONFIGURATION: String = "RX-TARGET-NET-026025-v2"


static func signature() -> String:
	var box: AABB = StadiumNetModels.ENVELOPE
	return JSON.stringify({"version": LAYOUT_VERSION, "configuration": CONFIGURATION,
		"target": StadiumTargetItems.signature(), "blockout": StadiumNetModels.BLOCKOUT,
		"model": StadiumNetModels.VERSION, "presentation": StadiumPairedReceiver.PAIR_VERSION,
		"render": StadiumReceiverVisibility.VERSION,
		"position": [StadiumNetModels.POSITION.x, StadiumNetModels.POSITION.y,
			StadiumNetModels.POSITION.z],
		"bounds": [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z],
		"surfaces": StadiumNetModels.surfaces(), "cleanup": StadiumPairedReceiver.PAIR_CLEANUP_Z},
		"", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumTargetItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 7, 7):
		result.version = LAYOUT_VERSION
		result.family = "reference-paired-receiver-v8"
		result["net"] = ""
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if not SeasonOwnership._keys(layout, ["version", "family", "receiver", "obstacles",
		"seating", "styles", "displays", "ground", "bleachers", "target", "net"]) \
		or not layout.family is String or layout.family != "reference-paired-receiver-v8" \
		or not layout.net is String:
		return StadiumStarterLayout._error("Unknown paired receiver layout.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("net")
	base.version = 7
	base.family = "reference-target-v7"
	var result: Dictionary = StadiumHomeLayout.validate(base, stock, tier)
	if not result.ok or layout.net.is_empty():
		return result
	if layout.target.is_empty() or not stock.copies.has(layout.net) \
		or stock.copies[layout.net].item != "ST-025":
		return StadiumStarterLayout._error("The catching net needs a separately owned, installed target.")
	result.placements.append({"copy": layout.net, "item": "ST-025", "site": "RECEIVER-NET",
		"position": StadiumNetModels.POSITION, "yaw": 0, "role": "RECEIVER_CONTAINMENT_FOUL"})
	result.stored.erase(layout.net)
	return result
