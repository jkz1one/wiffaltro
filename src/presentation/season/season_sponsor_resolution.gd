class_name SeasonSponsorResolution
extends ConfirmationDialog
## Explicit extra sales, followed by the existing final confirmation/save flow.

var build: SeasonBuild
var live_app: SeasonApp
var command: Dictionary
var accepted: Callable
var _choices: VBoxContainer
var _summary: Label
var _extra: Array[String] = []
var _discard: Array[String] = []


static func needed(source: SeasonBuild, request: Dictionary, error: String) -> bool:
	if source._format < 28 or request.has("sales"):
		return false
	if request.op not in ["sponsor_buy", "sponsor_sell", "wholesale", "match_sell"]:
		return false
	if request.op == "wholesale":
		if SeasonWholesale.category(source._visit.offers.get(request.first.offer, "")) != "sponsor":
			return false
	if request.op == "match_sell":
		if SeasonOwnership._owned(source._bank.view(), request.receipt).get("kind") != "sponsor":
			return false
	return (
		error.contains("capacity")
		or error.contains("rarity")
		or error.contains("Insufficient Season Cash")
	)


static func open(
	parent: Node,
	source: SeasonBuild,
	request: Dictionary,
	callback: Callable,
	app: SeasonApp = null
) -> SeasonSponsorResolution:
	var dialog: SeasonSponsorResolution = SeasonSponsorResolution.new()
	dialog.build = source
	dialog.live_app = app
	dialog.command = request.duplicate(true)
	dialog.accepted = callback
	parent.add_child(dialog)
	dialog.popup_centered(Vector2i(580, 350))
	dialog.get_cancel_button().grab_focus()
	return dialog


func _ready() -> void:
	title = "Resolve your loadout"
	theme = ClubhouseTheme.create()
	transient = true
	exclusive = true
	get_ok_button().text = "REVIEW"
	get_ok_button().custom_minimum_size.y = 44
	get_cancel_button().custom_minimum_size.y = 44
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 250
	add_child(scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_choices)
	var intro: Label = Label.new()
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = (
		"Select sponsors to sell and any excess supplies to discard. "
		+ "Nothing changes until the final confirmation is saved."
	)
	_choices.add_child(intro)
	var required: Array = []
	if command.op in ["sponsor_sell", "match_sell"]:
		required.append(command.receipt)
	elif command.op == "sponsor_buy":
		required.append(command.replace)
	else:
		required.append_array([command.first.replace, command.second.replace])
	for receipt: Dictionary in build._bank.view().sponsors:
		var item: Dictionary = SeasonSponsorCatalog.item(receipt.item)
		var choice: CheckBox = CheckBox.new()
		choice.text = (
			"%s • %s • sell %d Cash"
			% [item.name, item.rarity, SeasonSponsorCatalog.resale(receipt)]
		)
		choice.tooltip_text = item.effect
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.clip_text = true
		choice.custom_minimum_size.y = 44
		choice.set_meta("sponsor_sale", receipt.id)
		choice.button_pressed = required.has(receipt.id)
		choice.disabled = choice.button_pressed
		choice.toggled.connect(_toggle.bind(receipt.id))
		_choices.add_child(choice)
	if build._format >= 32:
		for receipt: Dictionary in _held_choices():
			var choice: CheckBox = CheckBox.new()
			choice.text = (
				"Discard %s • no refund • saved copy removed"
				% SeasonAssociationShop.held_name(receipt.item)
			)
			if receipt.id.begins_with("field-supply:"):
				choice.text = "Discard generated Grip Tape • no refund"
			choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			choice.custom_minimum_size.y = 44
			if live_app != null and live_app.lab != null:
				var state: MatchState = live_app.lab._match_state
				var own: TeamMatchState = (
					state.home_team if live_app.lab._player_home else state.away_team
				)
				for action: Dictionary in own.tactics.consumed:
					if action.receipt == receipt.id:
						choice.text += " • used this game; current effect stays"
			choice.set_meta("supply_discard", receipt.id)
			choice.toggled.connect(_toggle_discard.bind(receipt.id))
			_choices.add_child(choice)
	_summary = SeasonPlayerCard.line(_choices, "")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmed.connect(_accept)
	canceled.connect(queue_free)
	_refresh()


func _toggle(value: bool, id: String) -> void:
	if value:
		_extra.append(id)
	else:
		_extra.erase(id)
	_refresh()


func _request() -> Dictionary:
	var result: Dictionary = command.duplicate(true)
	result["sales"] = _extra.duplicate()
	if build._format >= 32:
		result["discard"] = _discard.duplicate()
		if command.op == "match_sell":
			result["discarded_use"] = []
			var app: SeasonApp = live_app
			if app != null and app.lab != null:
				var state: MatchState = app.lab._match_state
				var own: TeamMatchState = (
					state.home_team if app.lab._player_home else state.away_team
				)
				for action: Dictionary in own.tactics.consumed:
					if _discard.has(action.receipt):
						result.discarded_use.append(action.duplicate(true))
	return result


func _refresh() -> void:
	var quote: Dictionary = build.preview(_request())
	get_ok_button().disabled = (
		not quote.ok and not SeasonMajorResolution.needed(_request(), quote.get("error", ""))
	)
	_summary.text = (
		quote.error
		if not quote.ok
		else (
			(
				"Cash: %d → %d\nActive sponsors: %d / %d\n"
				+ "Held supplies: %d / %d\nReview these exact changes next."
			)
			% [
				quote.before_cash,
				quote.after.wallet.cash,
				quote.after.wallet.sponsors.size(),
				quote.after.wallet.capacity.sponsors,
				quote.after.wallet.held.size(),
				quote.after.wallet.capacity.held
			]
		)
	)


func _accept() -> void:
	accepted.call_deferred(_request())
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


func _toggle_discard(value: bool, id: String) -> void:
	if value:
		_discard.append(id)
	else:
		_discard.erase(id)
	_refresh()


func _held_choices() -> Array:
	var held: Array = build._bank.view().held.duplicate(true)
	if live_app != null and live_app.lab != null:
		var state: MatchState = live_app.lab._match_state
		var own: TeamMatchState = state.home_team if live_app.lab._player_home else state.away_team
		for receipt: Dictionary in own.tactics.held:
			if SeasonOwnership._owned(build._bank.view(), receipt.id).is_empty():
				held.append(receipt.duplicate(true))
	return held
