extends SceneTree
## Load selected scenes without starting tests. Compiler errors remain fatal in verify.py.


func _initialize() -> void:
	var oracle: Resource = ResourceLoader.load("res://src/tests/stadium_catalog_signature_oracle.gd")
	var catalog: Resource = ResourceLoader.load("res://src/gameplay/stadium/stadium_catalog.gd")
	if not _catalog_signature_matches(oracle, catalog):
		push_error("Stadium catalog native signature resources or values are invalid or differ")
		quit(1)
		return
	var count: int = 0
	for path: String in OS.get_cmdline_user_args():
		if path in ["res://src/tests/stadium_receiver_geometry_rebuild_checks.gd", \
			"res://src/tests/stadium_floodlight_rebuild_checks.gd", \
			"res://src/tests/stadium_landscape_rebuild_checks.gd", \
			"res://src/tests/stadium_live_furnishing_rebuild_checks.gd", \
			"res://src/tests/stadium_small_yard_scenery_rebuild_checks.gd", \
			"res://src/tests/stadium_molded_seat_rebuild_checks.gd", \
			"res://src/tests/stadium_ground_box_rebuild_checks.gd", \
			"res://src/tests/stadium_practice_facility_rebuild_checks.gd", \
			"res://src/tests/stadium_treehouse_rebuild_checks.gd", \
			"res://src/tests/stadium_landmark_rebuild_checks.gd", \
			"res://src/tests/stadium_outfield_bleacher_rebuild_checks.gd", \
			"res://src/tests/stadium_rising_apple_rebuild_checks.gd", \
			"res://src/tests/stadium_wall_top_terrace_rebuild_checks.gd", \
			"res://src/tests/stadium_player_tunnel_rebuild_checks.gd", \
			"res://src/tests/stadium_mounted_display_rebuild_checks.gd", \
			"res://src/tests/stadium_mounted_display_close_views.gd"]:
			var helper: Resource = ResourceLoader.load(path)
			if not helper is GDScript or not helper.can_instantiate():
				push_error("Verification helper could not compile: " + path)
				quit(1)
				return
			print("Wiffaltro helper preflight passed: ", path)
			continue
		if not path.begins_with("res://src/tests/") or not path.ends_with(".tscn"):
			push_error("Unexpected verification scene path: " + path)
			quit(1)
			return
		if not ResourceLoader.load(path) is PackedScene:
			push_error("Verification scene could not load: " + path)
			quit(1)
			return
		count += 1
	print("Wiffaltro scene preflight passed: ", count, " scene resources loaded.")
	quit(0)


func _catalog_signature_matches(oracle: Variant, catalog: Variant) -> bool:
	if not oracle is GDScript or not catalog is GDScript:
		return false
	if not oracle.can_instantiate() or not catalog.can_instantiate():
		return false
	if not oracle.has_method("signature") or not catalog.has_method("signature"):
		return false
	var builder: Variant = oracle.call("signature")
	var generated: Variant = catalog.call("signature")
	return _valid_signature(builder) and _valid_signature(generated) and builder == generated


func _valid_signature(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true
