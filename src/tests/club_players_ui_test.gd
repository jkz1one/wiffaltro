extends "res://src/tests/club_career_test.gd"
## Real viewport input around synthetic scored income; no invented production CB.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://player-ui-%d.json" % OS.get_process_id()
	var season: SeasonState = _new()
	_finish(season, "champion")
	_check(SeasonSave.save(season), "saved synthetic career earnings")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	ClubCareerUI.show(app.menu)
	await _click(_button(app.menu, "PLAYERS & PACKS"))
	_check(app.menu.page == "players", "actual club-record collection route")
	var seen: Array = []
	for page in range(8):
		await _bounds(app, "players-all-%d" % page)
		for card: Node in app.menu._body.find_children("*", "VBoxContainer", true, false):
			if card.has_meta("permanent_player"):
				var id: String = card.get_meta("permanent_player")
				_check(not seen.has(id), "one collection row per identity")
				seen.append(id)
		if page < 7:
			await _click(_button(app.menu, "NEXT"))
	_check(seen.size() == 48, "all 48 reachable by pagination")
	await _click(_button(app.menu, "EARNED"))
	_check(app.menu.page == "players", "earned-only filter")
	await _bounds(app, "players-earned")
	var before: int = app.season.career.balance()
	await _click(_button(app.menu, "REVIEW PLAYER PACK", true))
	_check(app.menu.page == "player_pack_review", "explicit payment review")
	await _click(_button(app.menu, "CANCEL"))
	_check(app.season.career.balance() == before, "cancel costs nothing")
	await _click(_button(app.menu, "REVIEW PLAYER PACK", true))
	get_window().size = Vector2i(700, 400)
	await _bounds(app, "player-pack-review-small")
	await _click(_button(app.menu, "PAY 80 CB"))
	_check(app.menu.page == "player_pack" and app.season.career.balance() == before - 80,
		"actual payment click saves reveal once")
	await _bounds(app, "player-pack-pending-small")
	var pending: Dictionary = ClubPlayers.assets(app.season.career).view().pending
	await _click(_button(app.menu, "CHOOSE LATER"))
	await _click(_button(app.menu, "PLAYERS & PACKS"))
	_check(app.menu.page == "player_pack", "return resumes paid choice")
	app.queue_free()
	await _frames()
	app = SeasonApp.new()
	add_child(app)
	await _frames()
	ClubPlayersUI.show(app.menu)
	_check(ClubPlayers.assets(app.season.career).view().pending == pending,
		"app restart preserves exact paid reveal")
	await _click(_button(app.menu, "KEEP THIS PLAYER"))
	var selected: String = pending.choices[0]
	_check(app.menu.page == "players" and ClubPlayers.owned(app.season.career).has(selected),
		"one chosen permanent player")
	get_window().size = Vector2i(1280, 720)
	app.notice = ""
	ClubPlayersUI.show(app.menu, "Owned")
	await _bounds(app, "players-owned")
	app.begin_season(81, true)
	_check(app.season.player_access.has(selected) and app.season.draft_pool.has(selected),
		"paid character enters next production draft")
	_check(app.season.player_access.has("player.rowan_chase"), "earned character enters next draft")
	_check(app.season.career.balance() == before - 80, "no new-season refund or duplicate charge")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro player UI checks passed: collection, review, restart and owned next draft.")
	get_tree().quit(0 if _failures == 0 else 1)


func _bounds(app: SeasonApp, label: String) -> void:
	await _frames()
	var visible: Rect2 = get_viewport().get_visible_rect()
	_check(visible.encloses(app.menu._footer.get_global_rect()), "navigation inside viewport")
	for node: Node in app.menu._body.find_children("*", "Control", true, false):
		if node.is_visible_in_tree():
			var bounds: Rect2 = node.get_global_rect()
			_check(bounds.position.x >= visible.position.x and bounds.end.x <= visible.end.x,
				"no horizontal clipping at " + label + ":" + node.name)
	_check(get_viewport().gui_get_focus_owner() != null, "keyboard focus after navigation")
	await _capture(get_viewport(), label)
