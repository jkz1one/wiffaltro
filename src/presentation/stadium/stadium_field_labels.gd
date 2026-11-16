class_name StadiumFieldLabels
extends RefCounted
## Player-facing home-to-outfield names. Historical world-X IDs and geometry stay unchanged.


static func wall(slot: String) -> String:
	return {"left": "RIGHT-FIELD WALL", "right": "LEFT-FIELD WALL", "back": "OUTFIELD WALL"}.get(
		slot, "BOUNDARY WALL"
	)


static func item_name(id: String) -> String:
	if id == "ST-022":
		return "Painted plywood right-field wall"
	if id == "ST-023":
		return "Painted plywood left-field wall"
	if id == StadiumScoreboardCatalog.ELECTRONIC:
		return StadiumScoreboardCatalog.item(id).name
	if StadiumWallPieceCatalog.DATA.has(id):
		return StadiumWallPieceCatalog.item(id).name
	return str(StadiumCatalog.item(id).get("name", "Unknown item"))
