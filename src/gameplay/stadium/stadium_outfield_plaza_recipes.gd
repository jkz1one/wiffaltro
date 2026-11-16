class_name StadiumOutfieldPlazaRecipes
extends RefCounted
## Original game-scale concourses. No field boundary or historical layout changes.
const VERSION: int = 1
const RECIPES: Array[String] = ["promenade_court", "garden_plaza", "heritage_walk"]
const CURRENT_RECIPES: Array[String] = ["promenade_court", "garden_plaza", "heritage_walk_r2"]
const HERITAGE_REVISION: String = "heritage_walk_r2"
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const LANE_WIDTH: float = 3.0


static func definition(id: String) -> Dictionary:
	if id == HERITAGE_REVISION:
		var revised: Dictionary = definition("heritage_walk")
		revised.id = id
		revised["backdrop_height"] = 3.4
		revised["authored_revision"] = 2
		return revised
	if not RECIPES.has(id):
		return {}
	var result: Dictionary = {
		"id": id,
		"paving": [],
		"lanes": [],
		"walls": [],
		"benches": [],
		"beds": [],
		"sites": {},
		"color": "b5aba0"
	}
	result.paving = [Rect2(-30, 24, 4, 10), Rect2(26, 24, 4, 10), Rect2(-30, 30, 60, 4)]
	result.lanes = [Rect2(-30, 24, 3, 10), Rect2(27, 24, 3, 10), Rect2(-30, 30, 60, 4)]
	if id == "promenade_court":
		result.paving.append_array(
			[Rect2(-27, 34, 18, 18), Rect2(9, 34, 18, 18), Rect2(-27, 49, 54, 3)]
		)
		result.lanes.append_array(
			[Rect2(-27, 34, 3, 18), Rect2(24, 34, 3, 18), Rect2(-27, 49, 54, 3)]
		)
		result.walls = [
			Rect2(-29, 35, 0.4, 17),
			Rect2(28.6, 35, 0.4, 17),
			Rect2(-27, 52, 21, 0.4),
			Rect2(6, 52, 21, 0.4)
		]
		result.sites = {
			"PLAZA-W": _landmark(Vector3(-17.5, 0, 44)), "PLAZA-E": _landmark(Vector3(17.5, 0, 44))
		}
		result.benches = [Vector3(-12, 0, 35.5), Vector3(12, 0, 35.5)]
	elif id == "garden_plaza":
		result.color = "b6b29b"
		result.paving.append_array(
			[
				Rect2(-27, 34, 18, 18),
				Rect2(-9, 34, 34, 4),
				Rect2(-27, 49, 18, 3),
				Rect2(22, 38, 3, 14)
			]
		)
		result.lanes.append_array(
			[
				Rect2(-27, 34, 3, 18),
				Rect2(-27, 49, 18, 3),
				Rect2(-9, 34, 34, 3),
				Rect2(22, 37, 3, 15)
			]
		)
		result.walls = [Rect2(-29, 36, 0.4, 16), Rect2(-27, 52, 20, 0.4), Rect2(4, 52, 21, 0.4)]
		result.sites = {
			"PLAZA-W": _landmark(Vector3(-17.5, 0, 44)),
			"GARDEN-1": _landscape(Vector3(3, 0, 44)),
			"GARDEN-2": _landscape(Vector3(15, 0, 44))
		}
		result.beds = [Rect2(-7, 39, 4, 10), Rect2(8, 39, 3, 10)]
		result.benches = [Vector3(-12, 0, 35.5), Vector3(19, 0, 39)]
	else:
		result.color = "b4afa2"
		result.paving.append_array([Rect2(-26, 34, 13, 7), Rect2(13, 34, 13, 7)])
		result.lanes.append_array([Rect2(-26, 34, 13, 3), Rect2(13, 34, 13, 3)])
		result.walls = [Rect2(-25, 42, 11, 0.4), Rect2(14, 42, 11, 0.4)]
		result.sites = {
			"GARDEN-1": _landscape(Vector3(-19.5, 0, 46)),
			"GARDEN-2": _landscape(Vector3(19.5, 0, 46))
		}
		result.benches = [Vector3(-22, 0, 39), Vector3(22, 0, 39)]
	return result


static func _landmark(at: Vector3) -> Dictionary:
	return {
		"position": at,
		"items": ["ST-046", "ST-047"],
		"box": AABB(at + Vector3(-6.5, 0, -5), Vector3(13, 8, 10))
	}


static func _landscape(at: Vector3) -> Dictionary:
	return {
		"position": at, "items": ["ST-019"], "box": AABB(at + Vector3(-3, 0, -3), Vector3(6, 3, 6))
	}


static func box(rect: Rect2, height: float = 0.1) -> AABB:
	return AABB(
		Vector3(rect.position.x, 0, rect.position.y), Vector3(rect.size.x, height, rect.size.y)
	)


static func reservations(id: String) -> Array[AABB]:
	var result: Array[AABB] = []
	var recipe: Dictionary = definition(id)
	if recipe.is_empty():
		return result
	for rect: Rect2 in recipe.paving:
		result.append(box(rect))
	for rect: Rect2 in recipe.beds:
		result.append(box(rect, 0.25))
	for at: Vector3 in recipe.benches:
		result.append(AABB(at + Vector3(-1.2, 0, -0.3), Vector3(2.4, 1.0, 0.6)))
	for rect: Rect2 in recipe.walls:
		result.append(box(rect.grow(0.06), 3.52))
	for site: Dictionary in recipe.sites.values():
		result.append(site.box)
	return result


static func signature() -> String:
	var rows: Array = []
	for id: String in RECIPES:
		rows.append(definition(id))
	return (
		var_to_str({"version": VERSION, "rows": rows, "clear_lane": LANE_WIDTH, "role": ROLE})
		. sha256_text()
	)


static func supported(id: String) -> bool:
	return RECIPES.has(id) or id == HERITAGE_REVISION


static func revision_signature(id: String) -> String:
	if id != HERITAGE_REVISION:
		return ""
	return (
		var_to_str({"definition": definition(id), "model": 1, "cap": 0.12, "role": ROLE})
		. sha256_text()
	)
