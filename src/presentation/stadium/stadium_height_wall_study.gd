class_name StadiumHeightWallStudy
extends RefCounted
## Art-only fixed-size candidate. No ownership, saved layout or collision activation.

const VERSION: int = 1
const SHAPES: Dictionary = StadiumHeightWallRecipes.SHAPES


static func rows(shape: String, item: String) -> Array[Dictionary]:
	return StadiumHeightWallRecipes.rows(shape, item)


static func create(item: String, width: float, height: float) -> Node3D:
	if not StadiumWallRecipes.BACK_IDS.has(item) or not _authored(width, height):
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
		"ST-065": StadiumWallPanelModels._padding(visual, size)
		"ST-077": StadiumWallPanelModels._brick(visual, size)
		"ST-078": StadiumWallPanelModels._chain(visual, size)
		_: StadiumWallPanelModels._wood(visual, size)
	if height > 3.25 and item in ["ST-024", "ST-078"]:
		StadiumWallPanelModels._box(visual, Vector3(width, 0.10, 0.10),
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


static func outline(shape: String) -> StadiumRecipeBoundary:
	if not SHAPES.has(shape):
		return null
	var points: PackedVector2Array = [Vector2(-8, -6), Vector2(8, -6), Vector2(24, 23.4),
		Vector2(StadiumWallRecipes.BACK_X, 23.4)]
	for section: Array in SHAPES[shape]:
		points.append(section[1])
	points.append(Vector2(-24, 23.4))
	return Outline.new(points)


class Outline extends StadiumRecipeBoundary:
	var _points: PackedVector2Array

	func _init(points: PackedVector2Array) -> void:
		_points = points

	func polygon() -> PackedVector2Array:
		return _points.duplicate()

	func identity() -> String:
		return "ART-ONLY-HEIGHT-STUDY"
