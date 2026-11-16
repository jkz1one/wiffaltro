class_name StadiumOffsetWallModels
extends RefCounted
## Whitelisted fixed closure meshes only. Existing full panels retain their frozen model.

const VERSION: int = 1


static func dimensions(item: String, span: String) -> Vector3:
	if not StadiumWallRecipes.BACK_IDS.has(item) or not StadiumOffsetWallRecipes.LENGTHS.has(span):
		return Vector3.ZERO
	return Vector3(StadiumOffsetWallRecipes.LENGTHS[span], 3.25, 0.35)


static func create(item: String, span: String) -> Node3D:
	if not StadiumWallRecipes.BACK_IDS.has(item) or not StadiumOffsetWallRecipes.LENGTHS.has(span):
		return null
	if span == "full":
		return StadiumWallPanelModels.create(item, span)
	var size: Vector3 = dimensions(item, span)
	var root: Node3D = Node3D.new()
	root.name = "OffsetClosure"
	root.set_meta("wall_item", item)
	root.set_meta("wall_span", span)
	root.set_meta("wall_authoring_family", "offset-gables")
	root.set_meta("wall_model_version", VERSION)
	root.set_meta("base_material_model_version", StadiumWallPanelModels.VERSION)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	match item:
		"ST-065": StadiumWallPanelModels._padding(visual, size)
		"ST-077": StadiumWallPanelModels._brick(visual, size)
		"ST-078": StadiumWallPanelModels._chain(visual, size)
		_: StadiumWallPanelModels._wood(visual, size)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PanelCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	collision.shape.size = size
	collision.position = Vector3(0, size.y / 2, -size.z / 2)
	body.add_child(collision)
	root.add_child(body)
	return root
