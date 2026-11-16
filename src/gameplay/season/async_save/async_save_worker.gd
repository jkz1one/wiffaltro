extends SceneTree
## No project-domain preloads/types here: autoloads must exist before validator compiles.
const VALIDATOR = "res://src/gameplay/season/async_save/async_save_validator.gd"

func _initialize() -> void:
	call_deferred("_boot")

func _boot() -> void:
	if not root.has_node("ContentDB"):
		printerr("ASYNC_SAVE_BOOTSTRAP_FAILED ContentDB autoload is unavailable")
		quit(1)
		return
	var script: Script = load(VALIDATOR) as Script
	if script == null or not script.can_instantiate():
		printerr("ASYNC_SAVE_BOOTSTRAP_FAILED validator cannot instantiate")
		quit(1)
		return
	var validator: Variant = script.new()
	if not validator is Node:
		printerr("ASYNC_SAVE_BOOTSTRAP_FAILED validator is not Node")
		quit(1)
		return
	root.add_child(validator)
