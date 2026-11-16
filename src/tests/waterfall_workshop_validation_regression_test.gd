extends Node
## Presentation-only synthetic ledger: no career authority, purchases or gameplay qualification.
var checks: int = 0
var failures: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _button(root: Node, label: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.text == label:
			return node
	return null

func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(216, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(paid.commit({"id": "ui-land-" + tier, "rev": paid.revision(),
			"op": "stadium_land", "tier": tier, "through": 40, "progress_through": 40,
			"price_version": 1}).ok, "synthetic paid land " + tier)
	check(paid.commit({"id": "ui-water", "rev": paid.revision(), "op": "stadium_buy",
		"item": "ST-046", "quantity": 1, "price_version": 32, "through": 40,
		"progress_through": 40}).ok, "synthetic paid waterfall copy")
	var copy: String = "purchase:ui-water:0"
	var layout: Dictionary = StadiumWaterfallLiveItems.place(paid.view().stadium_draft,
		paid.construction(), copy, "WF-LIVE-LF", 0, paid.surface_owned())
	layout = StadiumWaterfallAnimationLayout.select(layout, copy, true)
	check(StadiumEditorUI._checked(paid, layout).ok, "complete motion layout validates")
	SeasonSave.path = "user://waterfall-ui-validation.json"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	app.begin_surface_time_season("day", 51)
	var season_before: PackedByteArray = var_to_bytes(SeasonSave.snapshot(app.season))
	var file_before: String = FileAccess.get_file_as_string(SeasonSave.path)
	var paid_before: PackedByteArray = var_to_bytes(paid.to_data())
	StadiumWaterfallAnimationUI.show(app.menu, paid, layout, paid.revision())
	await get_tree().process_frame
	var previews: Array[Node] = app.menu.find_children("*", "SubViewportContainer", true, false)
	check(previews.size() == 1 and previews[0] is StadiumDraftPreview,
		"valid exact-owner motion draft still renders its preview")
	if previews.size() == 1 and previews[0] is StadiumDraftPreview:
		check(previews[0].preview_property is StadiumWaterfallAnimationProperty
			and previews[0].preview_property.props_intact(), "valid motion model remains intact")
	check(_button(app.menu, "SAVE DRAFT") != null and _button(app.menu, "APPLY LAYOUT") != null,
		"valid draft retains existing action controls; no transactions invoked")
	var invalids: Array[Dictionary] = [{"version": 47}, {"version": 47, "animation_base": 45}]
	for value: Variant in ["broken", null, {}, [], 45.5]:
		invalids.append({"version": 47, "animation_base": value})
	for invalid: Dictionary in invalids:
		StadiumWaterfallAnimationUI.show(app.menu, paid, invalid, paid.revision())
		await get_tree().process_frame
		check(app.menu.find_children("*", "SubViewport", true, false).is_empty(),
			"invalid motion schema allocates no world")
		check(_button(app.menu, "SAVE DRAFT") == null and _button(app.menu, "APPLY LAYOUT") == null,
			"invalid motion schema exposes no transaction controls")
		check(_button(app.menu, "RELOAD SAVED") != null
			and _button(app.menu, "CLUB RECORD") != null, "invalid motion retains recovery")
	check(paid_before == var_to_bytes(paid.to_data()), "presentation preserves exact supplied ledger")
	check(season_before == var_to_bytes(SeasonSave.snapshot(app.season))
		and file_before == FileAccess.get_file_as_string(SeasonSave.path),
		"presentation does not grant supplied ledger to career or mutate its save")
	app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	print("WATERFALL_WORKSHOP_VALIDATION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
