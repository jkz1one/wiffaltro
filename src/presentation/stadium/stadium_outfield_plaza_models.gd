class_name StadiumOutfieldPlazaModels
extends RefCounted
## Collider-free paid infrastructure; optional landmarks remain separately owned.
const VERSION: int = 1


static func create(recipe_id: String) -> Node3D:
	var recipe: Dictionary = StadiumOutfieldPlazaRecipes.definition(recipe_id)
	if recipe.is_empty():
		return null
	var root: Node3D = Node3D.new()
	root.name = "OutfieldConcourse"
	root.set_meta("stadium_item", "ST-112")
	root.set_meta("model_version", VERSION)
	root.set_meta("recipe", recipe_id)
	root.set_meta("physics_profile", StadiumOutfieldPlazaRecipes.ROLE)
	var index: int = 0
	for rect: Rect2 in recipe.paving:
		_slab(root, "Paving%02d" % index, rect, 0.02, 0.01, Color(recipe.color))
		var x: float = rect.position.x + 2
		while x < rect.end.x - 0.1:
			_slab(
				root,
				"Joint%02d_%02d" % [index, int(x * 10 + 1000)],
				Rect2(x, rect.position.y, 0.035, rect.size.y),
				0.003,
				0.022,
				Color("7e807a")
			)
			x += 3
		index += 1
	index = 0
	for rect: Rect2 in recipe.walls:
		var height: float = float(
			recipe.get("backdrop_height", 3.4 if recipe_id != "heritage_walk" else 1.15)
		)
		_slab(root, "Backdrop%02d" % index, rect, height, height / 2, Color("5d6668"))
		_slab(root, "Cap%02d" % index, rect.grow(0.06), 0.12, height + 0.06, Color("c8c2b4"))
		index += 1
	for rect: Rect2 in recipe.beds:
		_slab(root, "Earth", rect, 0.10, 0.05, Color("665342"))
		for edge: Rect2 in [
			Rect2(rect.position, Vector2(rect.size.x, 0.15)),
			Rect2(rect.position.x, rect.end.y - 0.15, rect.size.x, 0.15),
			Rect2(rect.position, Vector2(0.15, rect.size.y)),
			Rect2(rect.end.x - 0.15, rect.position.y, 0.15, rect.size.y)
		]:
			_slab(root, "BedEdge", edge, 0.25, 0.125, Color("a2a397"))
	for at: Vector3 in recipe.benches:
		_box(root, "BenchSeat", at + Vector3(0, 0.45, 0), Vector3(2.4, 0.12, 0.55), Color("977c54"))
		_box(
			root, "BenchBack", at + Vector3(0, 0.75, 0.25), Vector3(2.4, 0.5, 0.1), Color("977c54")
		)
		for side: float in [-0.9, 0.9]:
			_box(
				root,
				"BenchLeg",
				at + Vector3(side, 0.22, 0),
				Vector3(0.1, 0.44, 0.45),
				Color("444d50")
			)
	for key: String in recipe.sites:
		var reserve: AABB = recipe.sites[key].box
		var rect: Rect2 = Rect2(
			reserve.position.x, reserve.position.z, reserve.size.x, reserve.size.z
		)
		for edge: Rect2 in [
			Rect2(rect.position, Vector2(rect.size.x, 0.10)),
			Rect2(rect.position.x, rect.end.y - 0.10, rect.size.x, 0.10)
		]:
			_slab(root, "PadBorder_" + key, edge, 0.025, 0.0125, Color("c8c2b4"))
	return root


static func _slab(
	root: Node3D, id: String, rect: Rect2, height: float, y: float, color: Color
) -> void:
	_box(
		root,
		id,
		Vector3(rect.get_center().x, y, rect.get_center().y),
		Vector3(rect.size.x, height, rect.size.y),
		color
	)


static func _box(root: Node3D, id: String, at: Vector3, size: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = id
	part.mesh = mesh
	part.material_override = material
	part.position = at
	root.add_child(part)
