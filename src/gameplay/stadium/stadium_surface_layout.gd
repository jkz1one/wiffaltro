class_name StadiumSurfaceLayout
extends RefCounted
## Versioned visual surface selection. Ownership is separately bound to the paid ledger prefix.

const VERSION: int = 12
const MODEL_VERSION: int = 1
const FAMILY: String = "reference-surface-finishes-v12"
const RUNTIME_READY: bool = true
const TERRAIN_VERSION: int = 17
const TERRAIN_FAMILY: String = "owned-dirt-terrain-v1"


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"model": MODEL_VERSION,
				"heights": StadiumGrassFinish.HEIGHTS,
				"spacing": StadiumGrassFinish.SPACING,
				"pattern_width": 1.2,
				"noise": [6100520, 6100521],
				"rake_pigment": 0.6,
				"physical_surface": "unchanged-flat-v1",
				"night_verified": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func upgrade(layout: Dictionary, owned: Array[String], grass: bool = false) -> Dictionary:
	var result: Dictionary = StadiumWallItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 11, 11):
		result.version = VERSION
		result.family = FAMILY
		result["surface"] = StadiumSurfaceProgression.selection(owned, grass)
	return result


static func base(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if SeasonOwnership._whole(result.get("version"), VERSION, VERSION):
		result.erase("surface")
		result.version = 11
		result.family = "reference-wall-recipes-v11"
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout,
			[
				"version",
				"family",
				"receiver",
				"obstacles",
				"seating",
				"styles",
				"displays",
				"ground",
				"bleachers",
				"target",
				"net",
				"lights",
				"bases",
				"walls",
				"surface"
			]
		)
		or layout.family != FAMILY
	):
		return StadiumStarterLayout._error("Unknown surface layout; preserve the original.")
	if not StadiumSurfaceProgression.valid_selection(
		layout.surface, StadiumSurfaceProgression.INITIAL_LEGACY
	):
		return StadiumStarterLayout._error("Unknown surface appearance selection.")
	var result: Dictionary = StadiumHomeLayout.validate(base(layout), stock, tier)
	if not result.ok:
		return result
	if (
		layout.surface.foundation == "dirt"
		and (not layout.styles.grass.is_empty() or not layout.ground.is_empty())
	):
		return StadiumStarterLayout._error("Full dirt has no grass to mow or cut into.")
	# No surface-finish night qualification has been measured yet.
	result.night_qualified = false
	return result


static func owned(layout: Dictionary, access: Array[String]) -> bool:
	if (
		not layout.get("surface") is Dictionary
		or not StadiumSurfaceProgression.valid_selection(layout.surface, access)
	):
		return false
	return (
		layout.get("ground", "").is_empty() or (access.has("grass") and access.has("ground_prep"))
	)


static func apply(
	property: StadiumPropertyGeometry, layout: Dictionary, stock: StadiumStock
) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	var original: Dictionary = base(layout)
	if not StadiumWallItems.apply(property, original, stock):
		return false
	var graph: StadiumRecipeBoundary = StadiumWallItems.graph_for(original)
	if graph == null:
		graph = StadiumRecipeBoundary.create("straight")
	# Preserve line and base choices; replace only the former ground and mowing meshes.
	for name_value: String in ["FieldStylePreview", "GroundTreatment", "InfieldTreatment"]:
		var previous: Node = property.get_node_or_null(NodePath(name_value))
		if previous != null:
			property.remove_child(previous)
			previous.queue_free()
	if not StadiumRecipeFieldStyles.apply(
		property, graph, {"line": layout.styles.line, "grass": ""}, "", stock
	):
		return false
	var foundation: String = (
		"grass"
		if layout.surface.foundation == "grass"
		else ("maintained_dirt" if layout.surface.condition == "prepared" else "rough_dirt")
	)
	var finish: Node3D = StadiumSurfaceFinish.build(
		graph, foundation, layout.surface.height, layout.styles.grass, layout.ground
	)
	if finish == null:
		return false
	finish.name = "OwnedSurfaceFinish"
	property.add_child(finish)
	return true


static func terrain_upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if (
		not SeasonOwnership._whole(result.get("version"), VERSION, VERSION)
		or result.get("family") != FAMILY
		or not result.get("surface") is Dictionary
		or result.surface.get("foundation") != "dirt"
		or not owned(result, access)
	):
		return {}
	result.version = TERRAIN_VERSION
	result.family = TERRAIN_FAMILY
	return result


static func terrain_base(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if (
		SeasonOwnership._whole(result.get("version"), TERRAIN_VERSION, TERRAIN_VERSION)
		and result.get("family") == TERRAIN_FAMILY
	):
		result.version = VERSION
		result.family = FAMILY
	return result


static func terrain_contract(layout: Dictionary) -> Dictionary:
	if (
		not SeasonOwnership._whole(layout.get("version"), TERRAIN_VERSION, TERRAIN_VERSION)
		or layout.get("family") != TERRAIN_FAMILY
		or not layout.get("surface") is Dictionary
		or layout.surface.get("foundation") != "dirt"
		or layout.surface.get("condition") not in ["rough", "prepared"]
	):
		return {}
	return StadiumSurfaceTerrain.contract(
		"leveled" if layout.surface.condition == "prepared" else "rough"
	)


static func validate_terrain(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if not StadiumProperty.BOUNDS.has(tier) or terrain_contract(layout).is_empty():
		return StadiumStarterLayout._error(
			"Physical dirt needs a supported property and the existing rough or leveled mode."
		)
	var result: Dictionary = validate(terrain_base(layout), stock, tier)
	if not result.ok:
		return result
	if (
		not layout.obstacles.is_empty()
		or not layout.lights.is_empty()
		or not ClubCareer.same(layout.walls, StadiumWallLayout.empty())
	):
		return StadiumStarterLayout._error(
			"Physical dirt requires the daylight field without live obstacles or paid walls."
		)
	result.night_qualified = false
	return result


static func terrain_geometry(tier: String, layout: Dictionary) -> String:
	var terrain: Dictionary = terrain_contract(layout)
	if terrain.is_empty():
		return ""
	return (
		JSON
		. stringify(
			[StadiumHomeLayout.geometry(tier, terrain_base(layout)), terrain], "", true, true
		)
		. sha256_text()
	)


static func apply_terrain(
	property: StadiumPropertyGeometry, layout: Dictionary, stock: StadiumStock
) -> bool:
	# Assembly happens off-tree. Never retrofit a live legacy property.
	if (
		property.is_inside_tree()
		or not validate_terrain(layout, stock, property.tier).ok
		or not apply(property, terrain_base(layout), stock)
	):
		return false
	for id: String in ["PropertyGround", "OwnedSurfaceFinish"]:
		var old: Node = property.get_node_or_null(NodePath(id))
		if old == null:
			return false
		property.remove_child(old)
		old.free()
	var terrain: Node3D = StadiumSurfaceTerrain.build(terrain_contract(layout).mode)
	if terrain == null:
		return false
	property.add_child(terrain)
	return property.restore_outer_ground()
