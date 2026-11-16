extends Node
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	var menu: SeasonMenu = SeasonMenu.new()
	menu.page = "shared_stadium"
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result.layout = next
		result.revision = revision
	for access: Array in [[], ["ground_prep"]]:
		var owned: Array[String] = []
		owned.assign(access)
		var flat: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), owned, false)
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(flat, owned)
		check(Assets.layout_adapted(terrain), "exact public terrain adapted")
		check(StadiumSurfaceLayout.validate_terrain(terrain, StadiumStock.new_club(), "backyard").ok, "terrain validates")
		var before: Dictionary = terrain.duplicate(true)
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumSurfaceUI._terrain_choices(menu, panel, terrain, owned, 41, true, callback)
		var picker: OptionButton
		var flat_button: Button
		for child: Node in panel.get_children():
			if child.has_meta("terrain_choice"):
				picker = child
			if child.has_meta("terrain_flat"):
				flat_button = child
		check(picker.item_count == 1 + owned.size(), "only paid leveling offered")
		for index: int in range(picker.item_count):
			picker.item_selected.emit(index)
			check(result.layout.version == 17 and result.revision == 41, "exact terrain version and revision")
			check(result.layout.surface.condition == ("prepared" if index == 1 else "rough"), "exact terrain selection")
			check(not StadiumSurfaceLayout.terrain_contract(result.layout).is_empty(), "physical terrain contract retained")
		var calls: int = result.calls
		picker.item_selected.emit(-1)
		picker.item_selected.emit(5)
		picker.disabled = true
		picker.item_selected.emit(0)
		check(result.calls == calls, "disabled and invalid signals ignored")
		flat_button.pressed.emit()
		check(ClubCareer.same(result.layout, flat), "explicit flat return only")
		check(ClubCareer.same(terrain, before), "input field immutable")
		var forged: Dictionary = terrain.duplicate(true)
		forged.family = "wrong"
		check(not Assets.layout_adapted(forged), "wrong terrain family denied")
	check(not Assets.layout_enabled(13) and not StadiumAdvancedWallLayout.RUNTIME_READY, "advanced walls stay gated")
	check(not Assets.layout_enabled(46) and not StadiumLowWallLayout.RUNTIME_READY, "low walls stay gated")
	check(not Assets.layout_adapted({"version": 47, "family": StadiumWaterfallAnimationLayout.FAMILY, "animation_base": 46}), "motion cannot promote closed low walls")
	await get_tree().process_frame
	menu.free()
	print("SHARED TERRAIN: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
