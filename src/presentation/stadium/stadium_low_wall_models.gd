class_name StadiumLowWallModels
extends RefCounted
## Art for the exact new authored low profile. Collision belongs exclusively to the boundary.
const VERSION: int = 1


static func create(row: Dictionary) -> Node3D:
	if (
		row.get("item", "") not in StadiumWallRecipes.BACK_IDS
		or row.get("height", 0) not in [StadiumLowWallRecipes.LOW, StadiumLowWallRecipes.STANDARD]
	):
		return null
	var root: Node3D = Node3D.new()
	root.name = "OwnedLowWallPanel"
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	var size: Vector3 = Vector3(row.width, row.height, StadiumRecipeBoundary.THICKNESS)
	match row.item:
		"ST-065":
			StadiumWallPanelModels._padding(visual, size)
		"ST-077":
			StadiumWallPanelModels._brick(visual, size)
		"ST-078":
			StadiumWallPanelModels._chain(visual, size)
		_:
			StadiumWallPanelModels._wood(visual, size)
	root.set_meta("owned_copy", row.get("copy", ""))
	root.set_meta("piece_item", row.get("piece_item", ""))
	root.set_meta("wall_socket", row.socket)
	return root
