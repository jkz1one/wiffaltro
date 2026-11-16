extends "res://src/tests/stadium_low_wall_plaza_capture_test.gd"
## Exact all-low owned profile exposes the restrained empty heritage concourse.
func _views(layout_value: Dictionary, recipe: String) -> void:
	if recipe == "heritage_walk":
		await super._views(layout_value, recipe)
func _profile(_recipe: String) -> String:
	return "low_outfield"
