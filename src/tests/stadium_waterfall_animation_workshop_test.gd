extends Node
## Actual retained synthetic career, public Workshop callbacks and real cold file roundtrip.
var checks: int = 0
var failures: Array[String] = []
var app: SeasonApp


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("WATERFALL_MOTION_WORKSHOP " + label)


func _ready() -> void:
	await _run()
	print(
		(
			"WATERFALL_MOTION_WORKSHOP_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_career": true,
					"completed_games": 0,
					"public_callbacks": true
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var input: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--waterfall-workshop-save-input="):
			input = argument.trim_prefix("--waterfall-workshop-save-input=")
	check(
		input.is_absolute_path() and FileAccess.file_exists(input),
		"explicit retained41-season synthetic input"
	)
	if input.is_empty() or not FileAccess.file_exists(input):
		return
	var season: SeasonState = SeasonSave._decode(
		JSON.parse_string(FileAccess.get_file_as_string(input))
	)
	check(
		season != null and season.phase == SeasonState.Phase.COMPLETE,
		"completed paid career cold-validates"
	)
	if season == null:
		return
	SeasonSave.path = "user://waterfall-motion-workshop.json"
	PitchBatLabSettings.path = "user://waterfall-motion-workshop.cfg"
	check(SeasonSave.save(season), "isolated actual file saves before UI")
	if not failures.is_empty():
		return
	app = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	check(app.season != null, "ordinary app restores retained paid career")
	if app.season == null:
		app.free()
		return
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var original: Dictionary = paid.view().stadium_active.duplicate(true)
	var original_stock: Dictionary = paid.construction().to_data()
	var balance: int = paid.balance()
	var copy: String = original.live_waterfalls[0].copy
	StadiumEditorUI.show(app.menu)
	var enable: Button = _meta_button("waterfall_motion_enable", copy)
	check(
		enable != null and not enable.disabled,
		"ordinary static45 Workshop offers exact owned-copy opt-in"
	)
	if enable == null:
		app.free()
		return
	enable.pressed.emit()
	await get_tree().process_frame
	check(
		ClubCareer.same(ClubPlayers.assets(app.season.career).view().stadium_active, original),
		"preview opt-in cannot activate or migrate saved history"
	)
	var previews: Array[Node] = app.menu._body.find_children(
		"*", "SubViewportContainer", true, false
	)
	check(
		previews.size() == 1 and previews[0] is StadiumDraftPreview,
		"dedicated47 read-only preview is present"
	)
	if previews.size() == 1:
		var preview: StadiumDraftPreview = previews[0]
		preview.set_process(false)
		check(
			(
				preview.preview_property is StadiumWaterfallAnimationProperty
				and preview.preview_property.props_intact()
			),
			"complete paid-copy animated preview seals intact"
		)
		var lease: StadiumWaterfallAnimationLease = preview.preview_property._waterfall_animation
		var phase: float = lease.phase
		preview._process(0.1)
		check(
			lease.phase > phase and preview.preview_property.props_intact(),
			"private draft preview advances only declared uniforms"
		)
	check(_press("SAVE DRAFT"), "ordinary Save Draft callback available")
	await get_tree().process_frame
	paid = ClubPlayers.assets(app.season.career)
	check(
		paid.view().stadium_draft.version == 47 and paid.view().stadium_active.version == 45,
		"public saved draft leaves active static45 unchanged"
	)
	check(_press("APPLY LAYOUT"), "ordinary Apply callback available after Save")
	if app._dialog.visible:
		app._dialog.confirmed.emit()
		app._dialog.hide()
	await get_tree().process_frame
	paid = ClubPlayers.assets(app.season.career)
	check(
		(
			paid.view().stadium_active.version == 47
			and paid.view().stadium_active.waterfall_motion == [copy]
			and paid.balance() == balance
			and ClubCareer.same(paid.construction().to_data(), original_stock)
		),
		"public Apply keeps exact paid inventory and balance"
	)
	var cold: SeasonState = SeasonSave.restore()
	check(
		cold != null and ClubCareer.same(ClubPlayers.assets(cold.career).view(), paid.view()),
		"actual file cold-replays public animated draft and Apply"
	)
	var before_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var store: Button = _meta_button("waterfall_motion_store", copy)
	check(store != null and not store.disabled, "exact installed copy has Store control")
	if store != null:
		store.pressed.emit()
		await get_tree().process_frame
		check(
			FileAccess.get_file_as_string(SeasonSave.path) == before_bytes,
			"Store preview remains unsaved until explicit Save"
		)
		check(_press("SAVE DRAFT"), "Store draft saves through ordinary callback")
		await get_tree().process_frame
		check(_press("APPLY LAYOUT"), "Store Apply available after Save")
		if app._dialog.visible:
			app._dialog.confirmed.emit()
			app._dialog.hide()
		await get_tree().process_frame
	paid = ClubPlayers.assets(app.season.career)
	check(
		(
			paid.view().stadium_active.live_waterfalls.is_empty()
			and paid.view().stadium_active.waterfall_motion.is_empty()
			and paid.construction().copies.has(copy)
			and paid.balance() == balance
		),
		"Store removes motion/placement but preserves exact purchased copy and money"
	)
	var active: Dictionary = paid.view().stadium_active.duplicate(true)
	StadiumEditorUI.show(app.menu, active, paid.revision() - 1)
	check(
		_button("SAVE DRAFT").disabled and _button("APPLY LAYOUT").disabled,
		"stale47 revision disables Save and Apply"
	)
	var phase_before: int = app.season.phase
	# UI-only lock control, never saved or presented as an actual fixture.
	app.season.phase = SeasonState.Phase.REGULAR
	StadiumEditorUI.show(app.menu, active, paid.revision())
	check(
		_button("SAVE DRAFT").disabled and _button("APPLY LAYOUT").disabled,
		"ordinary drafting lock still disables47 editing"
	)
	var texts: String = ""
	for node: Label in app.menu._body.find_children("*", "Label", true, false):
		texts += node.text
	check(
		texts.contains("before choosing your draft roster"),
		"locked47 Workshop retains readable ordinary explanation"
	)
	app.season.phase = phase_before
	check(SeasonSave.restore() != null, "UI-only lock probe did not alter saved valid career")
	app.queue_free()
	await get_tree().process_frame


func _meta_button(key: String, value: String) -> Button:
	for button: Button in app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta(key, "") == value:
			return button
	return null


func _button(label: String) -> Button:
	for button: Button in app.menu._footer.find_children("*", "Button", true, false):
		if button.text == label:
			return button
	return null


func _press(label: String) -> bool:
	var button: Button = _button(label)
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true
