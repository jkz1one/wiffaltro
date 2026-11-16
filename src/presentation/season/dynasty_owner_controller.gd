extends RefCounted
## Closed owner orchestration. No public Dynasty enrollment or replacement credit.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var app: Node
var choice_window: ConfirmationDialog


func _init(owner_app: Node) -> void:
	app = owner_app


func found() -> Dictionary:
	return Store.inspect(SeasonSave._dynasty_owner_path) if SeasonSave.dynasty_owner_bound() else {}


func playable() -> bool:
	if not WorkingPitchDynastySave.public_playable(app.season):
		return false
	if not SeasonSave.dynasty_owner_bound():
		return true
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	return (
		current.get("status") == "ready"
		and not owner.is_empty()
		and not SeasonSave._dynasty_owner_content_blocked
		and (
			owner.selected == "other"
			or (owner.lineage.state == "active" and owner.get("pending_next", {}).is_empty())
		)
	)


func recover() -> bool:
	var current: Dictionary = found()
	if current.get("status") == "pending":
		Store.retry_pending(SeasonSave._dynasty_owner_path)
	elif current.get("status") == "recoverable":
		Store.repair(SeasonSave._dynasty_owner_path)
	return _promote(Store.restore(SeasonSave._dynasty_owner_path))


func _promote(outcome: Dictionary) -> bool:
	if outcome.get("status") != "committed":
		app.notice = str(outcome.get("reason", "The saved Dynasty session needs recovery."))
		return false
	var selected: Variant = outcome.get("qualified_selected_season")
	if not selected is SeasonState:
		var checked: Dictionary = Store.restore(SeasonSave._dynasty_owner_path)
		selected = checked.get("qualified_selected_season")
		if checked.get("status") != "committed" or not selected is SeasonState:
			SeasonSave._dynasty_owner_content_blocked = true
			app.notice = str(checked.get("reason", "The committed session could not be opened."))
			return false
		outcome = checked
	SeasonSave._dynasty_owner_content_blocked = false
	SeasonSave._bind_owner_season(selected, outcome)
	app.season = selected
	app.notice = ""
	return true


func _safe_hub() -> bool:
	if (
		app.lab != null
		or app._busy
		or app.season == null
		or (app.season.physical != null and not app.season.physical.pending.is_empty())
	):
		app.notice = "Finish or leave the current game first."
		return false
	if (
		app.season.build != null
		and not app.season.build._match_inventory.is_empty()
		and not SeasonInventoryRules.closed(app.season.build)
	):
		app.notice = "Leave the unfinished game before switching."
		return false
	return true


func _request(op: String, current: Dictionary, fields: Dictionary = {}) -> Dictionary:
	var request: Dictionary = fields.duplicate(true)
	request.op = op
	request.expected_revision = current.get("revision", 0)
	request.request_id = "owner:%s:%d" % [op, int(request.expected_revision)]
	return request


func transact(request: Dictionary) -> bool:
	if not _safe_hub():
		return false
	var outcome: Dictionary = Store.commit(request, SeasonSave._dynasty_owner_path)
	var ok: bool = _promote(outcome)
	if ok and app.menu != null:
		app.show_season()
	return ok


func switch_to(target: String, expected: int = -1, seed_value: int = -1) -> bool:
	if not _safe_hub():
		return false
	var current: Dictionary = found()
	if expected >= 0 and current.get("revision") != expected:
		app.notice = "This choice is out of date. Open it again."
		return false
	var owner: Dictionary = current.get("owner", {})
	if owner.is_empty():
		return false
	var fields: Dictionary = {"target": target}
	if target == "other" and owner.get("other", {}).is_empty():
		var seed: int = (
			(int(Time.get_unix_time_from_system()) & 0x7fffffff) if seed_value < 0 else seed_value
		)
		var candidate: SeasonState = SeasonState.create_closed_league(
			seed,
			LeagueRules.capture("standard"),
			true,
			owner.lineage.current_profile.get("access", {})
		)
		if candidate == null:
			return false
		fields.snapshot = SeasonSave.snapshot(candidate)
		fields.session_id = "standard:%d:%d" % [seed, int(current.revision)]
	return transact(_request("switch", current, fields))


func close_current(reason: String, expected: int = -1) -> bool:
	if not _safe_hub():
		return false
	var current: Dictionary = found()
	if expected >= 0 and current.get("revision") != expected:
		app.notice = "This choice is out of date. Open it again."
		return false
	var owner: Dictionary = current.get("owner", {})
	if owner.is_empty() or owner.selected != "dynasty":
		return false
	return transact(
		_request("close", current, {"session_id": owner.dynasty.session_id, "reason": reason})
	)


func begin_next(seed_value: int, expected: int = -1) -> bool:
	var current: Dictionary = found()
	if expected >= 0 and current.get("revision") != expected:
		app.notice = "This choice is out of date. Open it again."
		return false
	var ok: bool = transact(_request("begin_next", current, {"seed": seed_value}))
	if ok and not found().get("owner", {}).get("pending_next", {}).is_empty():
		show_choice()
	return ok


func choose_next(choices: Dictionary, pending_id: String, expected: int) -> bool:
	var current: Dictionary = found()
	if current.get("revision") != expected:
		app.notice = "This choice is out of date. Open it again."
		return false
	return transact(
		_request("choose_next", current, {"pending_id": pending_id, "choices": choices})
	)


func ask_switch(target: String) -> void:
	if not _safe_hub():
		return
	var current: Dictionary = found()
	var expected: int = int(current.get("revision", 0))
	app._confirm(
		(
			"Pause Dynasty and play Standard? Your team and season will be here when you return."
			if target == "other"
			else "Return to your Dynasty season?"
		),
		func() -> void: switch_to(target, expected)
	)
	app._dialog.get_cancel_button().grab_focus()


func ask_end() -> void:
	if not _safe_hub():
		return
	var current: Dictionary = found()
	var expected: int = int(current.get("revision", 0))
	var reason: String = "complete" if app.season.phase == SeasonState.Phase.COMPLETE else "abandon"
	app._confirm(
		(
			"Finish this season? Your roster stays."
			if reason == "complete"
			else "Abandon this season? Your roster stays. No season-completion rewards."
		),
		func() -> void: close_current(reason, expected)
	)
	app._dialog.get_cancel_button().grab_focus()


func ask_next() -> void:
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	if owner.is_empty():
		return
	if owner.selected != "dynasty":
		app.notice = "Return to Dynasty to start its next season."
		app.menu.show_home()
		return
	if not owner.get("pending_next", {}).is_empty():
		show_choice()
		return
	if owner.lineage.state != "closed":
		ask_end()
		return
	var expected: int = int(current.revision)
	var seed: int = int(Time.get_unix_time_from_system()) & 0x7fffffff
	app._confirm(
		"Start the next season with this roster? Development regresses and the season budget resets.",
		func() -> void: begin_next(seed, expected)
	)
	app._dialog.get_cancel_button().grab_focus()


func show_choice() -> void:
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	var pending: Dictionary = owner.get("pending_next", {})
	if pending.is_empty():
		return
	if is_instance_valid(choice_window):
		choice_window.hide()
		choice_window.queue_free()
	choice_window = ConfirmationDialog.new()
	choice_window.title = "CHOOSE AN ABILITY TO FORGET"
	choice_window.dialog_text = ""
	choice_window.theme = ClubhouseTheme.create()
	choice_window.get_ok_button().text = "FORGET & START"
	choice_window.get_ok_button().disabled = true
	# Bound content before wrapping the prompt. An unbounded VBox can report the
	# prompt's one-character-wide height before the dialog receives its width.
	var viewport_size: Vector2i = Vector2i(app.get_viewport().get_visible_rect().size)
	var content: ScrollContainer = ScrollContainer.new()
	content.name = "ChoiceScroll"
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.follow_focus = true
	content.custom_minimum_size.x = mini(520, maxi(0, viewport_size.x - 64))
	content.custom_minimum_size.y = mini(170, maxi(80, viewport_size.y - 160))
	choice_window.add_child(content)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	content.add_child(rows)
	var prompt: Label = Label.new()
	prompt.name = "ChoicePrompt"
	prompt.text = "One Fielding slot next season. Choose what to forget."
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(prompt)
	var choices: Dictionary = {}
	var needed: int = 0
	for id: String in owner.lineage.current_profile.roster:
		var learned: Array = owner.lineage.current_profile.players[id].abilities
		var fielding: Array = learned.filter(
			func(row: Dictionary) -> bool: return row.slot == "Fielding"
		)
		if fielding.size() < 2:
			continue
		needed += 1
		var group: ButtonGroup = ButtonGroup.new()
		for receipt: Dictionary in fielding:
			var button: CheckBox = CheckBox.new()
			button.text = (
				"%s: %s"
				% [
					app.season.player_definition(id).display_name,
					SeasonAbilities.ITEMS[receipt.item].name
				]
			)
			button.button_group = group
			button.set_meta("receipt", receipt.id)
			rows.add_child(button)
			button.toggled.connect(
				func(on: bool) -> void:
					if on:
						choices[id] = {"player": "", "forget": receipt.id}
						choice_window.get_ok_button().disabled = choices.size() != needed
			)
	var expected: int = int(current.revision)
	var pending_id: String = str(pending.get("request", {}).get("id", pending.get("id", "")))
	choice_window.confirmed.connect(func() -> void: choose_next(choices, pending_id, expected))
	app.add_child(choice_window)
	choice_window.popup_centered(
		Vector2i(mini(560, viewport_size.x - 48), mini(280, viewport_size.y - 80))
	)
	choice_window.get_cancel_button().grab_focus()


func add_controls(menu: SeasonMenu, parent: Control) -> void:
	if not SeasonSave.dynasty_owner_bound():
		return
	var current: Dictionary = found()
	var owner: Dictionary = current.get("owner", {})
	if owner.is_empty() or current.get("status") != "ready":
		menu._button(parent, "RECOVER DYNASTY", recover)
		return
	if owner.selected == "other":
		menu._button(parent, "RETURN TO DYNASTY", ask_switch.bind("dynasty"))
	else:
		menu._button(parent, "PLAY STANDARD", ask_switch.bind("other"))
		var label: String = (
			"NEXT SEASON"
			if owner.lineage.state == "closed"
			else (
				"FINISH SEASON"
				if app.season.phase == SeasonState.Phase.COMPLETE
				else "ABANDON SEASON"
			)
		)
		menu._button(parent, label, ask_next)
