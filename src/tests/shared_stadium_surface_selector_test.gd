extends Node
## Synthetic paid selections only; no owner, save or physical qualification.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
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
	var stock: StadiumStock = StadiumStock.new_club()
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result.layout = next
		result.revision = revision
	var original: Dictionary = StadiumStarterLayout.empty()
	for access: Array in [[], ["ground_prep"], ["grass"], ["ground_prep", "grass"]]:
		var owned: Array[String] = []
		owned.assign(access)
		owned.sort()
		StadiumSurfaceUI._opt_in(menu, original, owned, 41, callback)
		var draft: Dictionary = result.layout.duplicate(true)
		check(draft.version == 12 and draft.family == StadiumSurfaceLayout.FAMILY, "explicit opt-in produces exact v12 surface")
		check(StadiumSurfaceLayout.owned(draft, owned), "opt-in requires only actual surface entitlement")
		check(original.version == 1 and result.revision == 41 and menu.page == "shared_stadium", "opt-in preserves source, revision and route")
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumSurfaceUI._choices(menu, panel, draft, owned, 41, true, callback)
		var foundation: OptionButton = panel.get_child(0)
		check(foundation.item_count == 1 + owned.size(), "only owned prepared dirt and grass options")
		for index: int in range(foundation.item_count):
			foundation.item_selected.emit(index)
			check(StadiumSurfaceLayout.owned(result.layout, owned), "selected foundation remains entitled")
			check(StadiumHomeLayout.validate(result.layout, stock).ok, "selected foundation validates")
		var count: int = result.calls
		foundation.item_selected.emit(-1)
		foundation.item_selected.emit(99)
		foundation.disabled = true
		foundation.item_selected.emit(0)
		check(result.calls == count, "disabled or invalid foundation signals ignored")
		if draft.surface.foundation == "grass":
			var height: OptionButton = panel.get_child(1)
			for index: int in range(4):
				height.item_selected.emit(index)
				check(result.layout.surface.height == StadiumSurfaceProgression.HEIGHTS[index], "exact free grass height")
			count = result.calls
			height.item_selected.emit(-1)
			height.item_selected.emit(4)
			height.disabled = true
			height.item_selected.emit(0)
			check(result.calls == count, "invalid and disabled height signals ignored")
		check(ClubCareer.same(draft, StadiumSurfaceLayout.upgrade(original, owned, owned.has("grass"))), "controls do not mutate captured draft")
		panel.queue_free()
	check(Assets.layout_enabled(12) and Assets.layout_enabled(11) and not Assets.layout_enabled(13)
		and not Assets.layout_enabled(46), "combined surface and complete-wall adapters keep advanced and low walls closed")
	var season: SeasonState = SeasonState.new()
	season.phase = SeasonState.Phase.DRAFT
	var request: Dictionary = {"op": "stadium_apply", "layout": result.layout}
	check(not Assets.allowed(season, request), "ordinary runtime admission still required")
	season.phase = SeasonState.Phase.COMPLETE
	check(Assets.allowed(season, request), "completed season may stage future surface")
	# Actual shared screen routing on an ordinary synthetic ledger, without owner I/O.
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.create(701, false, true, true)
	app.season.career = ClubCareer.new()
	check(app.season.career.start(app.season), "ordinary synthetic ledger starts")
	app.season.phase = SeasonState.Phase.COMPLETE
	app.menu = SeasonMenu.new()
	app.menu.build(app)
	add_child(app.menu)
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var surface: Dictionary = StadiumSurfaceLayout.upgrade(paid.view().stadium_draft, paid.surface_owned(), true)
	var before: Dictionary = paid.to_data()
	UI.show(app, surface, paid.revision())
	check(app.menu.page == "shared_stadium" and _surface(app.menu, "foundation") != null, "v12 reaches shared surface controls instead of Pool storage")
	var height: OptionButton = _surface(app.menu, "height")
	if height != null:
		height.item_selected.emit(3)
		check(app.menu.page == "shared_stadium" and _surface(app.menu, "height").selected == 3, "height callback stays in shared editor")
	check(ClubCareer.same(before, ClubPlayers.assets(app.season.career).to_data()), "surface preview never changes paid ledger")
	var pool_ui = load("res://src/presentation/stadium/shared_stadium_pool_ui.gd")
	surface.surface.height = "medium"
	pool_ui.show(app, surface, paid.revision())
	check(app.menu.page == "shared_stadium_pool", "explicit stored Pool view remains available")
	var field: Button = _button(app.menu, "FIELD FOUNDATION & APPEARANCE")
	check(field != null and not field.disabled, "Pool storage offers surface editor")
	if field != null:
		field.pressed.emit()
		check(app.menu.page == "shared_stadium" and _surface(app.menu, "height").selected == 2, "Pool storage returns exact unsaved surface preview to full editor")
	check(ClubCareer.same(before, ClubPlayers.assets(app.season.career).to_data()), "Pool navigation performs no save, purchase or discard")
	await get_tree().process_frame
	app.menu.queue_free()
	await get_tree().process_frame
	app.free()
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	print("SHARED_SURFACE_SELECTOR checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children():
		result.append_array(_nodes(child))
	return result
func _surface(root: Node, channel: String) -> OptionButton:
	for node: Node in _nodes(root):
		if node is OptionButton and node.get_meta("surface_choice", "") == channel:
			return node
	return null
func _button(root: Node, caption: String) -> Button:
	for node: Node in _nodes(root):
		if node is Button and node.text == caption:
			return node
	return null
