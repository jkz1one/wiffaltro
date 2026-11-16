class_name StadiumScoreboardModels
extends RefCounted
## Exact new model identities; never called by old saved-model factories.

const VERSION: int = 1
const MODELS: Dictionary = {"ST-039": "manual-v2", "ST-090": "electronic-v2", "ST-040": "video-v2"}


static func signature() -> String:
	var dimensions: Dictionary = {}
	var regions: Dictionary = {}
	for item: String in MODELS:
		var spec: Dictionary = StadiumScoreboardTiers.spec(StadiumScoreboardCatalog.TIERS[item])
		dimensions[item] = [spec.width, spec.height, 2]
		var slots: Dictionary = StadiumScoreboardTiers.readouts(StadiumScoreboardCatalog.TIERS[item])
		slots.merge(StadiumScoreboardTiers.detail_slots(StadiumScoreboardCatalog.TIERS[item]))
		for key: String in slots:
			var point: Vector3 = slots[key].point
			slots[key].point = [point.x, point.y, point.z]
		regions[item] = slots
	return JSON.stringify({"version": VERSION, "models": MODELS, "dimensions": dimensions,
		"art": StadiumScoreboardTiers.VERSION, "regions": regions,
		"visibility": StadiumScoreboardTierSites.VERSION, "sites": StadiumScoreboardSites.signature(),
		"collision": "none-after-terminal-only"}, "", true, true).sha256_text()


static func create(item: String, model: String) -> Node3D:
	if MODELS.get(item, "") != model or not MODELS.has(item):
		return null
	var result: Node3D = StadiumScoreboardTiers.create(StadiumScoreboardCatalog.TIERS[item])
	result.set_meta("stadium_item", item)
	result.set_meta("scoreboard_owned_model", model)
	return result


static func bounds(placement: Dictionary) -> AABB:
	if not placement.get("item") is String or not placement.get("model") is String \
		or not placement.get("site") is String or not MODELS.has(placement.item) \
		or placement.model != MODELS[placement.item] \
		or not StadiumScoreboardSites.SITES.has(placement.site) \
		or not StadiumScoreboardSites.SITES[placement.site].items.has(placement.item):
		return AABB()
	return StadiumScoreboardSites.pose(placement.site) * StadiumScoreboardTiers.envelope(
		StadiumScoreboardCatalog.TIERS[placement.item])
