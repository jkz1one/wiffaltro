class_name StadiumGrandIILightingV1
extends RefCounted
## Starting artistic recipe only. Upper-deck native readability qualification remains separate.

const VERSION: int = 1
const PROFILE: String = "GRAND-II-SIX-TOWER-LIGHTING-v1"
const SHADOW_SITES: Array[String] = ["MLIGHT-HL", "MLIGHT-HR", "MLIGHT-OL", "MLIGHT-OR"]


static func contract() -> Dictionary:
	var result: Dictionary = StadiumGrandILightingV1.contract()
	result.version = VERSION
	result.profile = PROFILE
	result.qualification = "grand-ii-upper-deck-native-readability-pending"
	return result


static func head_rays(site: String) -> Array[Dictionary]:
	return StadiumGrandILightingV1.head_rays(site)


static func apply(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> Dictionary:
	return StadiumGrandILightingV1.apply(lab, property, true)


static func installed(lab: PitchBatLab, lease: Dictionary) -> bool:
	return StadiumGrandILightingV1.installed(lab, lease, true)


static func restore(lab: PitchBatLab, lease: Dictionary) -> bool:
	return StadiumGrandILightingV1.restore(lab, lease, true)
