class_name StadiumScoreboardPropertyGeometry
extends StadiumAdvancedPropertyGeometry
## Complete owned assembly; frozen snapshot/report admission is controlled separately.

var board_objects: Dictionary = {}
var celebration: StadiumMountedScoreboardCelebration


func build_scoreboards(property_tier: String, layout: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	surface_access: Array[String]) -> bool:
	if not SeasonOwnership._whole(layout.get("version"), 14, 15):
		return false
	var checked: Dictionary = StadiumOwnedLayout.validate(layout, stock, pieces,
		surface_access, property_tier, boards)
	if get_child_count() != 0 or not checked.ok:
		return false
	if not build_owned(property_tier, StadiumScoreboardAssembly.base(layout),
		stock, pieces, surface_access):
		return _reset_boards()
	for placement: Dictionary in checked.board_placements:
		if objects.has(placement.copy):
			return _reset_boards()
		var model: Node3D = _make_board(placement)
		if model == null:
			return _reset_boards()
		model.name = "OwnedScoreboard%d" % board_objects.size()
		model.transform = StadiumScoreboardAssembly.pose(placement)
		model.set_meta("owned_copy", placement.copy)
		model.set_meta("site", placement.site)
		model.set_meta("surface_role", &"DECORATIVE_AFTER_TERMINAL")
		if placement.has("mount_profile"):
			model.set_meta("scoreboard_mount_profile", placement.mount_profile)
		add_child(model)
		objects[placement.copy] = model
		board_objects[placement.copy] = model
	set_meta("scoreboard_layout", layout.duplicate(true))
	set_meta("scoreboard_inventory", boards.to_data())
	set_meta("scoreboard_models", StadiumScoreboardModels.signature())
	if SeasonOwnership._whole(layout.get("version"), 15, 15):
		set_meta("scoreboard_mount_catalog", StadiumScoreboardMountCatalog.signature(1))
	else:
		set_meta("scoreboard_authoring_only", true)
	set_meta("property_signature", StadiumOwnedLayout.geometry(property_tier, layout))
	return true


func _make_board(placement: Dictionary) -> Node3D:
	return StadiumScoreboardAssembly.create(placement)


func _reset_boards() -> bool:
	if get_child_count() != 0 or not objects.is_empty() or boundary != null:
		_rollback()
	board_objects.clear()
	for key: StringName in [&"advanced_layout", &"advanced_stock", &"advanced_pieces",
		&"advanced_surface_access", &"scoreboard_layout", &"scoreboard_inventory",
		&"scoreboard_models", &"scoreboard_authoring_only", &"scoreboard_mount_catalog"]:
		if has_meta(key):
			remove_meta(key)
	return false


func rebind_displays(state: MatchState) -> void:
	if is_instance_valid(celebration):
		celebration.bind_match(state)
	super.rebind_displays(state)
	for copy: String in board_objects:
		var display: StadiumScoreboardTierDisplay = board_display(copy)
		if display != null:
			display.bind_match(state)


func board_display(copy: String) -> StadiumScoreboardTierDisplay:
	var layout: Dictionary = get_meta("scoreboard_layout", {})
	for row: Dictionary in layout.get("scoreboards", []):
		if row.copy == copy:
			return StadiumScoreboardAssembly.display(board_objects.get(copy), row)
	return null


func route_obstacles() -> Array[Dictionary]:
	var models: Dictionary = objects.duplicate()
	for copy: String in board_objects:
		models.erase(copy)
	return _route_obstacles(models)
