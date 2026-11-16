extends Node3D
## Project actual unchanged wall geometry through both-handed batting cameras; check UI labels.

var _failures: int = 0


func _ready() -> void:
	var catalog: String = StadiumCatalog.signature()
	var field: FieldDefinition = FieldDefinition.new()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	var director: MatchCameraDirector = MatchCameraDirector.new()
	director.set_shot(MatchCameraDirector.Shot.BATTING)
	for left_handed: bool in [false, true]:
		director.set_batter_handedness(left_handed)
		camera.global_transform = director._desired_transform(Vector3.ZERO, 0.0)
		var center: float = camera.unproject_position(Vector3(0, 1, 20)).x
		for slot: String in ["left", "right"]:
			var rows: Array[Dictionary] = StadiumWallRecipes.side(slot == "left")
			var row: Dictionary = rows[8]
			var midpoint: Vector2 = (row.a + row.b) / 2.0
			var world: Vector3 = Vector3(midpoint.x, 1, midpoint.y)
			var index: int = 6 if slot == "left" else 8
			var name: String = "Right" if slot == "left" else "Left"
			_check(
				(
					signf(world.x) == signf(field.fielder_anchor(index).x)
					and field.fielder_anchor_name(index) == "Deep " + name
				),
				"wall presentation agrees with existing player field controls"
			)
			_check(
				(camera.unproject_position(world).x > center) == (name == "Right"),
				"both handed batting cameras project the named wall on its expected side"
			)
			_check(
				StadiumFieldLabels.wall(slot) == name.to_upper() + "-FIELD WALL",
				"wall heading maps player-side without changing stored slot"
			)
	_choices()
	var stock: StadiumStock = StadiumStock.new_club()
	stock.copies["purchase:side:0"] = {"item": "ST-022", "paid": 25, "source": "purchase-v1"}
	_check(
		(
			StadiumEditorUI.stored_summary(["purchase:side:0"], stock)
			== "Painted plywood right-field wall"
		),
		"storage summary uses the same player-side name"
	)
	_check(
		(
			StadiumCatalog.signature() == catalog
			and StadiumCatalog.item("ST-022").name == "Painted plywood left-field wall"
			and StadiumWallLayout.SIDES.left == "ST-022"
		),
		"presentation aliases preserve catalog signature, old identities and geometry"
	)
	viewport.free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro field labels passed: projected player sides, exact UI choices and frozen IDs."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _choices() -> void:
	var menu: SeasonMenu = SeasonMenu.new()
	for slot: String in ["left", "right", "back"]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu.add_child(panel)
		StadiumWallItemsUI._choices(
			menu, panel, StadiumStarterLayout.empty(), StadiumStock.new_club(), 0, slot, false
		)
		var heading: Label = panel.get_child(0)
		var choice: OptionButton = panel.get_child(1)
		_check(
			heading.text == StadiumFieldLabels.wall(slot) and choice.get_meta("wall_slot") == slot,
			"actual workshop heading changes without remapping callback slot"
		)
		if slot != "back":
			var item: String = StadiumWallLayout.SIDES[slot]
			_check(
				(
					choice.get_item_text(1).begins_with(StadiumWallItemsUI.SHORT_NAMES[item])
					and choice.get_item_text(1).contains(
						"Right-field" if slot == "left" else "Left-field"
					)
				),
				"actual copy choice agrees with its heading"
			)
	menu.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
