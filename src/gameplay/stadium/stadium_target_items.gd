class_name StadiumTargetItems
extends RefCounted
## Target-only paid recipe. No catching net, chair/target stack or free receiver substitute.

const LAYOUT_VERSION: int = 7
const CONFIGURATION: String = "RX-TARGET-026-00"


static func signature() -> String:
	var box: AABB = StadiumTargetModels.ENVELOPE
	return JSON.stringify({"version": LAYOUT_VERSION, "configuration": CONFIGURATION,
		"models": StadiumTargetModels.VERSION, "presentation": StadiumTargetReceiver.VERSION,
		"render": StadiumReceiverVisibility.VERSION,
		"position": [StadiumTargetModels.POSITION.x,
			StadiumTargetModels.POSITION.y, StadiumTargetModels.POSITION.z],
		"bounds": [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z],
		"surfaces": StadiumTargetModels.surfaces(), "cleanup": StadiumTargetReceiver.TARGET_CLEANUP_Z},
		"", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumBleacherItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 6, 6):
		result.version = LAYOUT_VERSION
		result.family = "reference-target-v7"
		result["target"] = ""
	return result
