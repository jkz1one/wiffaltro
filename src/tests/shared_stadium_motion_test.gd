extends "res://src/tests/shared_stadium_structure_cards_test.gd"
## Synthetic paid progress and actual public cards; no physical or Night qualification.
func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index: int in range(40):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(71, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(paid.commit({"id": tier, "rev": paid.revision(), "op": "stadium_land", "tier": tier,
			"through": 40, "progress_through": 40, "price_version": StadiumLand.VERSION}).ok, "paid land " + tier)
	for item: String in ["ST-046", "ST-111", "ST-112"]:
		var command: Dictionary = {"id": item, "rev": paid.revision(), "op": "stadium_buy", "item": item,
			"quantity": 2 if item == "ST-046" else 1, "through": 40, "progress_through": 40,
			"price_version": ClubConstruction.copy_catalog(item).price_version}
		check(paid.commit(command).ok, "paid exact " + item)
		check(paid.commit(command).get("replayed", false), "one-debit retry " + item)
	var before: Dictionary = paid.to_data()
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
	var base: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), paid.surface_owned(), true)
	var live: Dictionary = {}
	for row: Array in [["ST-046", 1, 42], ["ST-046", 2, 45], ["ST-111", 1, 43], ["ST-111", 2, 43], ["ST-111", 3, 43], ["ST-111", 4, 43]]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		UI._assembly_card(row[0]).call(menu, panel, base, _copy(paid, row[0]), paid.revision(), true, paid, callback)
		var choice: OptionButton = panel.get_child(0)
		check(not choice.is_item_disabled(row[1]), "public placement available " + str(row))
		choice.item_selected.emit(row[1])
		if not result.has("layout"):
			continue
		var placed: Dictionary = result.layout
		var valid: Dictionary = UI._validate(placed, paid)
		check(valid.ok and placed.version == row[2] and Assets.layout_adapted(placed), "exact flat paid family " + str(row))
		check(not valid.get("night_qualified", false), "placement grants no Night authority")
		if row[2] == 45:
			live = placed.duplicate(true)
			check(valid.live_units == 4 and not StadiumHomeLayout.validate(placed, paid.construction(), "club").ok, "live waterfall consumes all four units and requires Mogul")
			var conflict: Dictionary = placed.duplicate(true)
			conflict.obstacles = [{"copy": _copy(paid, "ST-001"), "site": StadiumStarterLayout.SITES.keys()[0], "yaw": 0}]
			check(UI._validate(StadiumWaterfallLiveItems.store_copy(conflict, _copy(paid, "ST-046")), paid).ok, "companion is independently legal paid stock")
			check(not UI._validate(conflict, paid).ok, "live waterfall rejects live companion")
		var count: int = result.calls
		choice.item_selected.emit(-1)
		choice.item_selected.emit(99)
		choice.disabled = true
		choice.item_selected.emit(0)
		check(result.calls == count, "invalid and disabled selection ignored")
		var storage: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(storage)
		UI._assembly_card(row[0]).call(menu, storage, placed, _copy(paid, row[0]), paid.revision(), true, paid, callback)
		(storage.get_child(0) as OptionButton).item_selected.emit(0)
		check(UI._validate(result.layout, paid).ok and ClubCareer.same(before, paid.to_data()), "free exact-copy storage changes preview only")
		panel.queue_free()
		storage.queue_free()

	var exact: String = _copy(paid, "ST-046")
	StadiumWaterfallAnimationUI.offer(menu, paid, live, paid.revision(), true, callback)
	var offer: Button
	for child: Node in menu._body.find_children("*", "Button", true, false):
		if child.has_meta("waterfall_motion_enable"):
			offer = child
	check(offer != null, "motion offered to exact installed paid copy")
	offer.pressed.emit()
	var motion: Dictionary = result.layout.duplicate(true)
	check(motion.version == 47 and motion.animation_base == 45 and motion.waterfall_motion == [exact],
		"explicit public45 motion successor")
	check(Assets.layout_adapted(motion) and UI._validate(motion, paid).ok, "owned motion accepted")
	var original_motion: Dictionary = motion.duplicate(true)
	var forged: Dictionary = motion.duplicate(true)
	forged.animation_base = 46
	check(not Assets.layout_adapted(forged), "motion cannot bypass closed low-wall46")
	StadiumWaterfallAnimationUI.controls(menu, motion, paid.revision(), true, callback)
	var toggle: Button
	var storage: Button
	var underlying: Button
	for child: Node in menu._body.find_children("*", "Button", true, false):
		if child.has_meta("waterfall_motion_base"):
			underlying = child
		if child.has_meta("waterfall_motion_toggle"):
			toggle = child
		if child.has_meta("waterfall_motion_store"):
			storage = child
	toggle.pressed.emit()
	check(result.layout.version == 47 and result.layout.waterfall_motion.is_empty()
		and ClubCareer.same(StadiumWaterfallAnimationLayout.base(result.layout), live), "static keeps exact base")
	storage.pressed.emit()
	check(result.layout.waterfall_motion.is_empty() and UI._validate(result.layout, paid).ok
		and not StadiumWaterfallAnimationLayout.placed_copies(result.layout).has(exact), "store clears only copy motion")
	underlying.pressed.emit()
	check(ClubCareer.same(result.layout, live), "explicit underlying edit preserves every base field")
	check(ClubCareer.same(motion, original_motion) and ClubCareer.same(paid.to_data(), before), "previews mutate no paid state")
	StadiumWaterfallAnimationUI.controls(menu, motion, paid.revision(), false, callback)
	var calls: int = result.calls
	(menu._body.get_child(menu._body.get_child_count() - 1) as Button).pressed.emit()
	check(result.calls == calls, "disabled underlying callback ignored")
	check(paid.commit({"id": "motion-draft", "rev": paid.revision(), "op": "stadium_draft", "layout": motion}).ok,
		"exact motion draft journal")
	check(paid.commit({"id": "motion-apply", "rev": paid.revision(), "op": "stadium_apply", "layout": motion,
		"geometry": StadiumOwnedLayout.geometry(paid.view().land, motion)}).ok,
		"exact motion apply journal")
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(paid.to_data())), 71, credits, progress)
	check(cold != null and ClubCareer.same(cold.view().stadium_active, motion), "cold exact motion replay")
	await get_tree().process_frame
	menu.free()
	print("SHARED MOTION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
