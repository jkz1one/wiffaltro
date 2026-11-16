class_name StadiumLowWallRecipes
extends RefCounted
## Additive immutable profiles, using distinct purchased low and standard wall pieces.
const VERSION: int = 1
const PROFILES: Array[String] = ["low_flanks", "low_outfield"]
const LOW: float = 1.625
const STANDARD: float = 3.25
const CENTER_HALF: float = 7.0


static func rows(profile: String, material: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile not in PROFILES or material not in StadiumWallRecipes.BACK_IDS:
		return result
	for original: Dictionary in StadiumWallRecipes.back("straight", material):
		var row: Dictionary = original.duplicate(true)
		var center: Vector2 = (row.a + row.b) * 0.5
		row["height"] = (
			STANDARD if profile == "low_flanks" and absf(center.x) < CENTER_HALF else LOW
		)
		row["width"] = row.a.distance_to(row.b)
		row["socket"] = "LOW46-" + profile + "-" + str(result.size())
		result.append(row)
	return result


static func requirements(profile: String, material: String) -> Dictionary:
	var result: Dictionary = {"low": 0, "standard": 0}
	for row: Dictionary in rows(profile, material):
		result["low" if row.height == LOW else "standard"] += 1
	return result


static func signature() -> String:
	var all: Dictionary = {}
	for profile: String in PROFILES:
		all[profile] = rows(profile, "ST-024")
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"profiles": all,
				"height_ownership": "distinct-paid-low-v1",
				"boundary": "straight-footprint-only"
			},
			"",
			true,
			true
		)
		. sha256_text()
	)
