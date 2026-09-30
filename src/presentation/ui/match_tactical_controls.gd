class_name MatchTacticalControls
extends Node
## Owned-card choices at the existing first-pitch readiness boundary.

var _lab: PitchBatLab
var _entry: Button
var _dialog: ConfirmationDialog
var _scroll: ScrollContainer
var _choices: VBoxContainer
var _detail: Label
var _receipt: String = ""
var _swing: StringName = &""
var _pa: int = 0
var _player: StringName = &""
var _advance: Dictionary = {}
var _pair: Array[String] = []
var _checkout: String = ""


func build(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	_lab = lab
	_entry = Button.new()
	_entry.name = "TacticalSupplies"
	_entry.theme = ClubhouseTheme.create()
	_entry.custom_minimum_size = Vector2(440, 52)
	_entry.pressed.connect(_open)
	canvas.add_child(_entry)
	_entry.hide()
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Tactical supplies • Working"
	_dialog.theme = ClubhouseTheme.create()
	_dialog.transient = true
	_dialog.exclusive = true
	_dialog.get_label().hide()
	_dialog.get_ok_button().text = "USE SELECTED COPY"
	_dialog.get_ok_button().custom_minimum_size.y = 44
	_dialog.get_cancel_button().custom_minimum_size.y = 44
	_dialog.confirmed.connect(_commit)
	_dialog.canceled.connect(func() -> void: _receipt = "")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(560, 280)
	_dialog.add_child(_scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation", 8)
	_scroll.add_child(_choices)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.custom_minimum_size.y = 140
	_choices.add_child(_detail)
	add_child(_dialog)


func team() -> TeamMatchState:
	return _lab._match_state.home_team if _lab._player_home else _lab._match_state.away_team


func can_open() -> bool:
	if not _lab._match_mode or _lab._match_state == null or _lab._debug_paused:
		return false
	if _lab._match_presentation_director.blocks_gameplay():
		return false
	if (
		_lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or not _lab._match_state.between_batters
	):
		return false
	if _lab._player_is_batting():
		return _lab._awaiting_batter_confirm and not _lab._ai_pitch_preselected
	return MatchLabSupport.can_edit_pitch_plan(_lab)


func _process(_delta: float) -> void:
	if not _lab._match_mode or _lab._match_state == null:
		_entry.hide()
		_dialog.hide()
		return
	var tactics: MatchTactics = team().tactics
	var active: String = tactics.active(_lab._match_state)
	var transfer: bool = not tactics.checkout.options(_lab._match_state, team()).is_empty()
	_entry.position = Vector2(420, 526) if _lab._player_is_batting() else Vector2(420, 96)
	_entry.visible = (
		(not tactics.held.is_empty() or not active.is_empty() or transfer)
		and not _lab._match_presentation_director.blocks_gameplay()
	)
	_entry.disabled = not can_open() or (tactics.held.is_empty() and not transfer)
	_entry.text = "SUPPLIES • %d held" % tactics.held.size()
	if transfer:
		_entry.text += "\nLATE CHECKOUT AVAILABLE"
	if not active.is_empty():
		_entry.text += (
			"\n"
			+ (
				"Recovered stamina"
				if active == "C02"
				else (
					"Runner advanced"
					if active == SeasonTacticalCatalog.BASE
					else (
						(
							"Tape + Plan"
							if active == MatchTactics.COMBO
							else SeasonTacticalCatalog.item(active).name
						)
						+ " • this PA"
					)
				)
			)
		)
		if active in ["C03", MatchTactics.COMBO]:
			_entry.text += (
				" • "
				+ String(tactics.locked_swing(_lab._match_state)).trim_prefix("swing.").to_upper()
			)
	if _dialog.visible and (not can_open() or _pa != _lab._match_state.plate_appearance_number):
		_dialog.hide()
		_receipt = ""


func _open() -> void:
	if not can_open():
		return
	_receipt = ""
	_advance = {}
	_pair.clear()
	_checkout = ""
	_dialog.get_ok_button().text = "USE SELECTED COPY"
	_pa = _lab._match_state.plate_appearance_number
	_dialog.get_ok_button().disabled = true
	for child: Node in _choices.get_children():
		_choices.remove_child(child)
		if child != _detail:
			child.queue_free()
	for copy: Dictionary in team().tactics.held:
		var swings: Array = [&"swing.contact", &"swing.power"] if copy.item == "C03" else [&""]
		for swing: StringName in swings:
			var button: Button = Button.new()
			button.text = SeasonTacticalCatalog.item(copy.item).name
			if swing != &"":
				button.text += " • " + String(swing).trim_prefix("swing.").capitalize()
			button.custom_minimum_size.y = 44
			button.set_meta("tactical_receipt", copy.id)
			button.set_meta("tactical_swing", swing)
			button.tooltip_text = team().tactics.reason(_lab._match_state, team(), copy.id, swing)
			button.disabled = not button.tooltip_text.is_empty()
			button.pressed.connect(_select.bind(copy.id, swing))
			_choices.add_child(button)
	_add_combo_choices()
	MatchCheckoutControls.add(self)
	_detail.text = (
		"Choose a supply to review. One activation per club per PA.\n"
		+ "Disabled cards are unavailable for this role, pitcher or PA. "
		+ "Nothing is spent until you confirm."
	)
	_choices.add_child(_detail)
	_dialog.popup_centered(Vector2i(620, 390))
	_dialog.get_cancel_button().grab_focus()


func _select(receipt: String, swing: StringName) -> void:
	if not can_open():
		return
	var error: String = team().tactics.reason(_lab._match_state, team(), receipt, swing)
	if not error.is_empty():
		_detail.text = error
		_dialog.get_ok_button().disabled = true
		return
	_pair.clear()
	_checkout = ""
	_dialog.get_ok_button().text = "USE SELECTED COPY"
	_receipt = receipt
	_swing = swing
	var id: String = team().tactics._item(receipt)
	var player: PlayerMatchState = (
		_lab._match_state.pitcher()
		if id in ["C02", SeasonTacticalCatalog.HEAT]
		else _lab._match_state.batter()
	)
	_player = player.definition.id
	_detail.text = (
		"%s\n%s\n%s\nConsumes one copy; no refund for a walk or strikeout."
		% [
			SeasonTacticalCatalog.item(id).name,
			player.definition.display_name,
			SeasonTacticalCatalog.item(id).effect
		]
	)
	if id == "C02":
		_detail.text += (
			"\nStamina: %.1f → %.1f"
			% [
				player.stamina_remaining,
				minf(player.stamina_max, player.stamina_remaining + player.stamina_max * 0.10)
			]
		)
	elif id == SeasonTacticalCatalog.BASE:
		_advance = TacticalBaseAdvance.target(_lab._match_state.bases)
		_detail.text += "\n" + TacticalBaseAdvance.describe(_lab._match_state, _advance)
	elif id == "C03":
		_detail.text += "\nLocked swing: " + String(swing).trim_prefix("swing.").capitalize()
	_dialog.get_ok_button().disabled = false


func _commit() -> void:
	if not can_open() or _pa != _lab._match_state.plate_appearance_number:
		return
	if not _checkout.is_empty():
		MatchCheckoutControls.commit(self)
		return
	if not _pair.is_empty():
		_commit_combo()
		return
	var id: String = team().tactics._item(_receipt)
	var player: PlayerMatchState = (
		_lab._match_state.pitcher()
		if id in ["C02", SeasonTacticalCatalog.HEAT]
		else _lab._match_state.batter()
	)
	if (
		id == SeasonTacticalCatalog.BASE
		and _advance != TacticalBaseAdvance.target(_lab._match_state.bases)
	):
		return
	if player.definition.id != _player:
		return
	if team().tactics.activate(_lab._match_state, team(), _receipt, _swing):
		_lab._refresh_config()
		_lab._refresh_markers()
		if id == SeasonTacticalCatalog.BASE:
			_lab._status_label.text = _lab._match_state.last_event
			if _lab._match_state.phase == MatchState.Phase.GAME_END:
				PitchBatLabFeelSupport.begin_match_outro(_lab)
	_receipt = ""
	_process(0.0)


func _add_combo_choices() -> void:
	if not team().current_batter().definition.season_sponsors.get("E07", false):
		return
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var pair: Array[String] = team().tactics.combo_copies()
		var button: Button = Button.new()
		button.text = (
			"DOUBLE BOOKING • Tape + Plan • " + String(swing).trim_prefix("swing.").capitalize()
		)
		button.custom_minimum_size.y = 44
		button.set_meta("tactical_combo", swing)
		button.tooltip_text = team().tactics.combo_reason(_lab._match_state, team(), pair, swing)
		button.disabled = not button.tooltip_text.is_empty()
		button.pressed.connect(_select_combo.bind(pair, swing))
		_choices.add_child(button)


func _select_combo(pair: Array[String], swing: StringName) -> void:
	if (
		not can_open()
		or not team().tactics.combo_reason(_lab._match_state, team(), pair, swing).is_empty()
	):
		return
	_checkout = ""
	_pair = pair.duplicate()
	_swing = swing
	_player = _lab._match_state.batter().definition.id
	_detail.text = (
		(
			"Double Booking • %s\nConsumes this Tape and Plan together, once/game. "
			+ "Locks %s for this PA. Spatial radii ×1.08; fair exit ×0.95. "
			+ "At quality ≥0.65, Plan adds ×1.06 (combined ×1.007), after Gear. "
			+ "Both end on PA completion, including walks/Ks. No refund. "
			+ "Working contract; compatibility is a testing Proposal."
		)
		% [_lab._match_state.batter().definition.display_name, String(swing).trim_prefix("swing.")]
	)
	_dialog.get_ok_button().text = "USE BOTH COPIES"
	_dialog.get_ok_button().disabled = false


func _commit_combo() -> void:
	if _player != _lab._match_state.batter().definition.id:
		return
	if team().tactics.activate_combo(_lab._match_state, team(), _pair, _swing):
		_lab._refresh_config()
		_lab._refresh_markers()
	_pair.clear()
	_process(0.0)
