class_name StadiumNpcMogulTwoHeightPanelV1
extends RefCounted
## Art-only fixed-size candidate. No ownership, saved layout or collision activation.

const VERSION: int = 1
const SHAPES: Dictionary = StadiumNpcMogulTwoHeightRecipesV1.SHAPES


static func rows(shape: String, item: String) -> Array[Dictionary]:
	return StadiumNpcMogulTwoHeightRecipesV1.rows(shape, item)


static func create(item: String, width: float, height: float) -> Node3D:
	if not StadiumNpcClubWallRecipesV1.BACK_IDS.has(item) or not _authored(width, height):
		return null
	var root: Node3D = Node3D.new()
	root.name = "HeightArtCandidate"
	root.set_meta("art_only", true)
	root.set_meta("wall_item", item)
	root.set_meta("height_study_version", VERSION)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var size: Vector3 = Vector3(width, height, 0.35)
	match item:
		"ST-065": StadiumNpcClubWallPanelV1._padding(visual, size)
		"ST-077": StadiumNpcClubWallPanelV1._brick(visual, size)
		"ST-078": StadiumNpcClubWallPanelV1._chain(visual, size)
		_: StadiumNpcClubWallPanelV1._wood(visual, size)
	if height > 3.25 and item in ["ST-024", "ST-078"]:
		StadiumNpcClubWallPanelV1._box(visual, Vector3(width, 0.10, 0.10),
			Vector3(0, height / 2, -0.17), "667477" if item == "ST-078" else "a67d50")
	return root


static func _authored(width: float, height: float) -> bool:
	for sections: Array in SHAPES.values():
		for section: Array in sections:
			if height != section[2]:
				continue
			for authored: float in section[3]:
				if width == authored:
					return true
	return false
