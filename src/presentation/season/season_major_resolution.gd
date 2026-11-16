class_name SeasonMajorResolution
extends ConfirmationDialog
## Nomination/forgetting choice precedes the existing final, atomic save review.

var build: SeasonBuild
var command: Dictionary
var accepted: Callable
var _player: OptionButton
var _forget: OptionButton


static func needed(request: Dictionary, error: String) -> bool:
	return not request.has("major") and error.contains("Double Major")


static func open(
	parent: Node, source: SeasonBuild, request: Dictionary, callback: Callable
) -> SeasonMajorResolution:
	var dialog: SeasonMajorResolution = SeasonMajorResolution.new()
	dialog.build = source
	dialog.command = request.duplicate(true)
	dialog.accepted = callback
	parent.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 340))
	dialog.get_cancel_button().grab_focus()
	return dialog


func _ready() -> void:
	title = "Double Major Academy"
	theme = ClubhouseTheme.create()
	transient = true
	exclusive = true
	get_ok_button().text = "REVIEW"
	get_ok_button().custom_minimum_size.y = 44
	get_cancel_button().custom_minimum_size.y = 44
	var body: VBoxContainer = VBoxContainer.new()
	add_child(body)
	SeasonPages.wrapped(
		body,
		(
			"One nominated player can learn two different Fielding abilities. Both "
			+ "must be paid for. Shared supply space falls by one. Nothing changes "
			+ "until you confirm and save the final review."
		)
	)
	_player = OptionButton.new()
	_player.custom_minimum_size.y = 44
	body.add_child(_player)
	if _nominating():
		_player.add_item("Choose beneficiary")
		_player.set_item_metadata(0, "")
		for id: String in build.roster():
			_player.add_item(build.definition(id).display_name)
			_player.set_item_metadata(_player.item_count - 1, id)
	else:
		_player.add_item("Remove the extra Fielding slot")
		_player.set_item_metadata(0, "")
		_player.disabled = true
	_forget = OptionButton.new()
	_forget.custom_minimum_size.y = 44
	body.add_child(_forget)
	_player.item_selected.connect(func(_index: int) -> void: _refresh())
	_forget.item_selected.connect(func(_index: int) -> void: _enabled())
	confirmed.connect(_accept)
	canceled.connect(queue_free)
	_refresh()


func _nominating() -> bool:
	if command.op == "major_assign":
		return true
	if command.op == "sponsor_buy":
		return build._visit.offers.get(command.offer) == "F09"
	if command.op == "wholesale":
		return (
			build._visit.offers.get(command.first.offer) == "F09"
			or build._visit.offers.get(command.second.offer) == "F09"
		)
	return false


func _refresh() -> void:
	_forget.clear()
	var changed: bool = str(_player.get_selected_metadata()) != build._major.player
	var rows: Array = build._abilities.in_slot(build._major.player, "Fielding")
	if changed and rows.size() > 1:
		_forget.add_item("Choose ability to forget • no refund")
		_forget.set_item_metadata(0, "")
		for row: Dictionary in rows:
			_forget.add_item("Forget " + SeasonAbilities.ITEMS[row.item].name)
			_forget.set_item_metadata(_forget.item_count - 1, row.id)
		_forget.disabled = false
	else:
		_forget.add_item("No excess ability to forget")
		_forget.set_item_metadata(0, "")
		_forget.disabled = true
	_enabled()


func _enabled() -> void:
	get_ok_button().disabled = (
		(_nominating() and _player.selected == 0)
		or (not _forget.disabled and _forget.selected == 0)
	)


func _accept() -> void:
	hide()
	var selected: Dictionary = command.duplicate(true)
	selected["major"] = {
		"player": str(_player.get_selected_metadata()),
		"forget": str(_forget.get_selected_metadata())
	}
	accepted.call_deferred(selected)
	queue_free()


func _input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	):
		hide()
		canceled.emit()
		get_viewport().set_input_as_handled()
