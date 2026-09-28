class_name DevelopmentLab
extends Window
## Explicit sandbox for Working rows and proposed physical calibration.

signal exhibition_requested(state: MatchState)

const SESSION: String = "development-lab-v1"
const STAT_EFFECTS: Dictionary = {
	"contact": "Expands spatial contact tolerance and the existing batter read/correction window.",
	"power": "Raises the shared contact resolver's exit-speed multiplier by 0.03.",
	"fielding": "Movement +0.14 m/s, reaction −0.015 s, reach +0.024 m; handling improves.",
	"pitching": "Game-start stamina +19.44; command ceiling +0.014 and release tolerance improves."
}

var book: SeasonDevelopment
var save_path: String = "user://development-lab-v1.json"
var selected_player: String = "player.alex_finch"
var _body: VBoxContainer
var _confirm: ConfirmationDialog
var _pending: Dictionary = {}
var _notice: String = ""


func _ready() -> void:
	title = "Player growth playtest — Working"
	size = Vector2i(980, 650)
	min_size = Vector2i(650, 400)
	transient = true
	close_requested.connect(queue_free)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = ClubhouseTheme.create()
	add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm test grant"
	_confirm.confirmed.connect(_commit_pending)
	_confirm.canceled.connect(func() -> void: _pending.clear())
	add_child(_confirm)
	_reset()


func _reset() -> void:
	book = SeasonDevelopment.new(SESSION)
	_pending.clear()
	_notice = "Fresh authored profiles. Your saved test checkpoint is unchanged."
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_label("PLAYER GROWTH TEST LAB • WORKING ROSTER / CANDIDATE PHYSICS")
	_label("Synthetic grants. No Season Cash, inventory or season progress is changed.")
	_label(
		"Stats cap at 10 and pitches at 5. These caps are approved; balance is still in testing."
	)
	_label(_notice)
	var select: OptionButton = OptionButton.new()
	var ids: Array[String] = SeasonPlayerCatalog.ids()
	for id: String in ids:
		select.add_item(ContentDB.get_player(StringName(id)).display_name)
	select.selected = ids.find(selected_player)
	select.item_selected.connect(
		func(index: int) -> void:
			selected_player = ids[index]
			_pending.clear()
			_refresh()
	)
	_body.add_child(select)
	var definition: PlayerDefinition = ProgressionMatchAdapter.player(book, selected_player)
	SeasonPlayerCard.ratings_card(_body, definition, definition.display_name)
	var profile: Dictionary = book.player(selected_player)
	for stat: String in SeasonPlayerCatalog.STATS:
		var command: Dictionary = _request("stat", stat)
		_button(
			(
				"Test %s: %d → %d"
				% [stat.capitalize(), profile.stats[stat], mini(10, profile.stats[stat] + 1)]
			),
			_preview.bind(command, STAT_EFFECTS[stat])
		)
	_label("Active pitches: %d / capacity %d" % [profile.active.size(), profile.capacity])
	for pitch: PitchDefinition in definition.starting_pitches:
		var recipe: String = String(pitch.id)
		_button(
			"Test +1: %s (level %d)" % [pitch.display_name, pitch.mastery_level],
			_preview.bind(_request("mastery", recipe), PitchMastery.next_effect(pitch))
		)
		_button(
			"Test Round Out on " + pitch.display_name,
			_preview.bind(_request("round_out", recipe), PitchMastery.next_effect(pitch))
		)
	_learning(profile)
	var remembered: PackedStringArray = []
	for recipe: String in profile.mastery:
		if not profile.active.has(recipe):
			remembered.append(
				(
					"%s level %d"
					% [
						ContentDB.get_pitch(StringName(recipe)).display_name,
						profile.mastery[recipe]
					]
				)
			)
	if not remembered.is_empty():
		_label("Remembered, inactive mastery: " + ", ".join(remembered))
	_button("PLAY TEST EXHIBITION WITH THIS PLAYER", _play)
	_label("You pitch first. Both teams use the same Working profiles and shared physical rules.")
	_button("Save test growth", _save)
	_button("Reload test growth", _restore)
	_button("Reset all test growth", _reset)
	_button("Close", queue_free)


func _learning(profile: Dictionary) -> void:
	_label("Test a lesson: choose an exact recipe and an explicit replacement when full.")
	var recipe_choice: OptionButton = OptionButton.new()
	var recipes: Array = SeasonPlayerCatalog.RECIPES.values()
	for recipe: String in recipes:
		recipe_choice.add_item(ContentDB.get_pitch(StringName(recipe)).display_name)
	_body.add_child(recipe_choice)
	var replace_choice: OptionButton = OptionButton.new()
	replace_choice.add_item("Use a free capacity slot")
	for recipe: String in profile.active:
		replace_choice.add_item("Replace " + ContentDB.get_pitch(StringName(recipe)).display_name)
	_body.add_child(replace_choice)
	_button(
		"Preview test lesson",
		func() -> void:
			var command: Dictionary = _request("learn", recipes[recipe_choice.selected])
			command.replace = (
				""
				if replace_choice.selected == 0
				else (profile.active[replace_choice.selected - 1])
			)
			_preview(
				command,
				"New recipes start at 1. Relearning restores this player's remembered level."
			)
	)


func _request(op: String, target: String) -> Dictionary:
	return {
		"id": "test:%d" % book.revision(),
		"rev": book.revision(),
		"player": selected_player,
		"op": op,
		"target": target
	}


func _preview(command: Dictionary, effect: String) -> void:
	var preview: Dictionary = book.preview(command)
	if not preview.ok:
		_notice = preview.error
		_refresh()
		return
	_pending = command.duplicate(true)
	var target: String = command.target
	var before: Dictionary = book.player(command.player)
	var change: String
	if command.op == "stat":
		change = (
			"%s: %d → %d" % [target.capitalize(), before.stats[target], preview.after.stats[target]]
		)
	else:
		change = (
			"%s: level %d → %d"
			% [
				ContentDB.get_pitch(StringName(target)).display_name,
				before.mastery.get(target, 1),
				preview.after.mastery[target]
			]
		)
		if command.op == "learn":
			change += (
				"\nReplace: "
				+ (
					"none"
					if command.replace.is_empty()
					else (ContentDB.get_pitch(StringName(command.replace)).display_name)
				)
			)
	_confirm.dialog_text = (
		"%s\n%s\n\n%s\n\nTest grant only. Physical values are calibration candidates."
		% [ContentDB.get_player(StringName(command.player)).display_name, change, effect]
	)
	_confirm.popup_centered(Vector2i(660, 260))


func _commit_pending() -> void:
	var result: Dictionary = book.commit(_pending)
	_pending.clear()
	_notice = (
		"Test growth applied. Save to retain it; launch an exhibition to try it."
		if result.ok
		else result.error
	)
	_refresh()


func _save() -> void:
	var ok: bool = SeasonDevelopmentStore.save(book, save_path, SESSION)
	_notice = "Test growth saved." if ok else SeasonDevelopmentStore.last_error
	_refresh()


func _restore() -> void:
	var restored: SeasonDevelopment = SeasonDevelopmentStore.restore(save_path, SESSION)
	if restored != null:
		book = restored
	_notice = SeasonDevelopmentStore.last_error
	if _notice.is_empty():
		_notice = "Test growth restored."
	_pending.clear()
	_refresh()


func _play() -> void:
	var state: MatchState = ProgressionMatchAdapter.exhibition(book, selected_player)
	if state == null or not SeasonDevelopmentStore.save(book, save_path, SESSION):
		_notice = "Could not save test growth. The test session is still open."
		_refresh()
		return
	exhibition_requested.emit(state)
	queue_free()


func _label(text: String) -> void:
	var label: Label = SeasonPlayerCard.line(_body, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _button(text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	_body.add_child(button)
