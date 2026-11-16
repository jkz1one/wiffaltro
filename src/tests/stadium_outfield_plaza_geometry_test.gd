extends Node3D
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	for id: String in StadiumOutfieldPlazaRecipes.RECIPES:
		var recipe: Dictionary = StadiumOutfieldPlazaRecipes.definition(id)
		for shape: String in [
			"straight", "deeper_center", "left_loft", "right_shelf", "offset_gables"
		]:
			var graph: StadiumRecipeBoundary = (
				StadiumRecipeBoundary.create(shape)
				if shape in ["straight", "deeper_center"]
				else StadiumAdvancedWallManifest.graph(shape)
			)
			for reserve: AABB in StadiumOutfieldPlazaRecipes.reservations(id):
				check(StadiumProperty.contains("mogul", reserve), id + " land containment")
				check(
					StadiumGroundBoxItems._outside_play(reserve, graph),
					id + " " + shape + " out of play " + str(reserve)
				)
		for site: String in recipe.sites:
			var reserve: AABB = recipe.sites[site].box
			for lane: Rect2 in recipe.lanes + recipe.walls + recipe.beds:
				check(
					not StadiumPracticeFacilityItems._horizontal_overlap(
						reserve, StadiumOutfieldPlazaRecipes.box(lane)
					),
					id + " " + site + " clear lane/backdrop"
				)
			for other: String in recipe.sites:
				if other != site:
					check(
						not StadiumPracticeFacilityItems._horizontal_overlap(
							reserve, recipe.sites[other].box
						),
						id + " distinct pads"
					)
			for item: String in recipe.sites[site].items:
				var envelope: AABB = (
					StadiumRisingAppleItems.ENVELOPE
					if item == "ST-047"
					else (
						StadiumWaterfallItems.ENVELOPE
						if item == "ST-046"
						else StadiumLandscapeModels.envelope(item)
					)
				)
				check(
					reserve.encloses(
						AABB(envelope.position + recipe.sites[site].position, envelope.size)
					),
					id + " whole " + item + " envelope"
				)
		var model: Node3D = StadiumOutfieldPlazaModels.create(id)
		check(model != null, id + " model builds")
		if model != null:
			check(
				model.find_children("*", "CollisionObject3D", true, false).is_empty(),
				id + " no gameplay colliders"
			)
			check(
				model.find_children("*", "MeshInstance3D", true, false).size() > 30,
				id + " actual infrastructure meshes"
			)
			for mesh: MeshInstance3D in model.get_children():
				var enclosed: bool = false
				var bounds: AABB = mesh.transform * mesh.get_aabb()
				for reserve: AABB in StadiumOutfieldPlazaRecipes.reservations(id):
					enclosed = enclosed or reserve.grow(0.0001).encloses(bounds)
				check(enclosed, id + " complete visual mesh reserved " + mesh.name)
			model.free()
	check(StadiumOutfieldPlazaRecipes.definition("foreign").is_empty(), "unknown recipe rejects")
	print("PLAZA_GEOMETRY_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
