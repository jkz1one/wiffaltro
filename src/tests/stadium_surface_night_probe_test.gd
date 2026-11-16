extends "res://src/tests/stadium_lights_installed_test.gd"
## Isolated difficult-surface night diagnostic. It does not certify or enable layout12 night games.


const PROFILES: Dictionary = {
	"rough": ["dirt", "rough", "short", "", ""],
	"prepared": ["dirt", "prepared", "short", "", ""],
	"very_short": ["grass", "prepared", "very_short", "ST-063b", "ST-063g"],
	"short": ["grass", "prepared", "short", "ST-063b", "ST-063g"],
	"medium": ["grass", "prepared", "medium", "ST-063b", "ST-063g"],
	"long": ["grass", "prepared", "long", "ST-063b", "ST-063g"],
	"long_clay": ["grass", "prepared", "long", "ST-063b", "ST-063h"],
	"long_raked": ["grass", "prepared", "long", "ST-063b", "ST-063j"],
	"scuff": ["grass", "prepared", "short", "ST-063b", "ST-063e"],
	"plate_clay": ["grass", "prepared", "short", "ST-063b", "ST-063f"],
	"plate_sand": ["grass", "prepared", "short", "ST-063b", "ST-063i"],
	"plain": ["grass", "prepared", "short", "", "ST-063g"],
	"stripes": ["grass", "prepared", "short", "ST-063a", "ST-063g"],
	"diamonds": ["grass", "prepared", "short", "ST-063c", "ST-063g"],
	"arcs": ["grass", "prepared", "short", "ST-063d", "ST-063g"]}
var _profile: String = "long_raked"


func _init() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--surface-profile="):
			_profile = argument.trim_prefix("--surface-profile=")
	_check(PROFILES.has(_profile), "known isolated night study profile")


func _author_surface(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	var result: Dictionary = StadiumSurfaceLayout.upgrade(layout,
		StadiumSurfaceProgression.INITIAL_LEGACY, true)
	var row: Array = PROFILES.get(_profile, PROFILES.long_raked)
	result.surface = {"foundation": row[0], "condition": row[1], "height": row[2]}
	result.styles.grass = row[3]
	result.ground = row[4]
	for item: String in [row[3], row[4]]:
		if not item.is_empty() and not stock.styles.has(item):
			stock.styles.append(item)
	stock.styles.sort()
	if not result.ground.is_empty():
		var masks: Array = StadiumGroundModels.masks(result.ground) if (
			StadiumGroundModels.IDS.has(result.ground)) else StadiumInfieldModels.masks(result.ground)
		var point: Vector3 = _tracking_endpoints()[3]
		_check(StadiumGrassFinish._inside(Vector2(point.x, point.z), masks),
			"critical rolling sample actually lies inside its selected dirt treatment")
	return result


func _fixture_snapshot(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	var result: Dictionary = super._fixture_snapshot(layout, stock)
	result.version = 8
	result["surface_access"] = StadiumSurfaceProgression.INITIAL_LEGACY.duplicate()
	return result


func _night_expected() -> bool:
	return false


func _shot(name_value: String) -> void:
	await super._shot("surface-night-" + _profile + "-" + name_value)


func _tracking_endpoints() -> Array[Vector3]:
	# Include a real rolling-height endpoint inside the selected plate or infield treatment.
	var dirt_end: Vector3 = Vector3(-1, 0.0365, 0.75) if _profile == "scuff" else (
		Vector3(0, 0.0365, 1) if _profile in ["plate_clay", "plate_sand"]
		else Vector3(8.15, 0.0365, 9))
	return [Vector3(0, 0.0365, 23.3), Vector3(-17, 0.0365, 23.3), Vector3(17, 0.0365, 23.3),
		dirt_end, Vector3(-25, 1.8, 18), Vector3(25, 1.8, 18),
		Vector3(0, 7, 28), Vector3(0, 35, 25)]


func _night_scene(lab: PitchBatLab) -> void:
	super._night_scene(lab)
	var property: Node3D = lab.get_meta("stadium_property")
	var changed: bool = StadiumSurfaceNightPalette.apply(property)
	_check(changed == (_profile == "plate_sand"), "only pale plate sand gets the candidate palette")
	if changed:
		var mesh: MeshInstance3D = property.get_node("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
		var material: ShaderMaterial = mesh.material_override
		StadiumSurfaceNightPalette.apply(property)
		_check(is_equal_approx(material.get_shader_parameter("vertex_pigment_scale"), 0.6),
			"repeated night application cannot compound the pigment multiplier")
		StadiumSurfaceNightPalette.apply(property, false)
		_check(is_equal_approx(material.get_shader_parameter("vertex_pigment_scale"), 1.0),
			"day restoration retains the exact original palette")
		StadiumSurfaceNightPalette.apply(property)
