extends "res://src/tests/stadium_lights_installed_test.gd"
## Qualify all three dirt footprints and raised bases against the existing night visibility gates.

var _ground: String = "ST-063g"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for ground: String in StadiumInfieldModels.IDS:
		_ground = ground
		print("INFIELD_NIGHT_PROFILE ", ground)
		for left: bool in [false, true]:
			await _track(left)
			await _pitch_views(left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro infield night checks passed: all footprints, pitch views and tracking.")
	get_tree().quit(0 if _failures == 0 else 1)


func _author_surface(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	var result: Dictionary = StadiumInfieldStyles.upgrade(layout)
	result.ground = _ground
	result.bases = "ST-062d"
	for id: String in [_ground, "ST-062d"]:
		if not stock.styles.has(id):
			stock.styles.append(id)
	stock.styles.sort()
	return result


func _night_expected() -> bool:
	return StadiumInfieldStyles.NIGHT_VERIFIED


func _shot(name_value: String) -> void:
	await super._shot(_ground + "-" + name_value)


func _night_scene(lab: PitchBatLab) -> void:
	super._night_scene(lab)
	StadiumInfieldNightPresentation.apply(lab.get_meta("stadium_property"))
