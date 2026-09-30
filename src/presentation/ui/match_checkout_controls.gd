class_name MatchCheckoutControls
extends RefCounted
## Review inherited effects through the existing tactical readiness dialog.


static func add(ui: MatchTacticalControls) -> void:
	var state: MatchState = ui._lab._match_state
	var checkout: MatchLateCheckout = ui.team().tactics.checkout
	var options: Array[String] = checkout.options(state, ui.team())
	for item: String in options:
		var button: Button = Button.new()
		button.text = "LATE CHECKOUT • " + SeasonTacticalCatalog.item(item).name
		if item == "C03":
			button.text += " • " + String(checkout._swing).trim_prefix("swing.").capitalize()
		button.custom_minimum_size.y = 44
		button.set_meta("checkout", item)
		button.pressed.connect(select.bind(ui, item))
		ui._choices.add_child(button)
	if not options.is_empty():
		var decline: Button = Button.new()
		decline.text = "DECLINE THIS TRANSFER"
		decline.custom_minimum_size.y = 44
		decline.set_meta("checkout", "decline")
		decline.pressed.connect(select.bind(ui, "decline"))
		ui._choices.add_child(decline)


static func select(ui: MatchTacticalControls, item: String) -> void:
	if not ui.can_open():
		return
	var checkout: MatchLateCheckout = ui.team().tactics.checkout
	var options: Array[String] = checkout.options(ui._lab._match_state, ui.team())
	if options.is_empty() or (item != "decline" and not options.has(item)):
		return
	ui._checkout = item
	ui._pair.clear()
	ui._receipt = ""
	ui._player = ui._lab._match_state.batter().definition.id
	ui._detail.text = (
		"Decline this opportunity. Keep the once-game use for a later qualifying walk."
		if item == "decline"
		else (
			"Late Checkout • "
			+ SeasonTacticalCatalog.item(item).name
			+ "\n"
			+ ui._lab._match_state.batter().definition.display_name
			+ "\n"
			+ SeasonTacticalCatalog.item(item).effect
			+ "\n"
			+ (
				"Locked swing: " + String(checkout._swing).trim_prefix("swing.") + ". "
				if item == "C03"
				else ""
			)
			+ "No copy consumed. Uses your once-game transfer and this PA's supply allowance. "
			+ "Ends after this batter, including another walk."
		)
	)
	ui._dialog.get_ok_button().text = "DECLINE TRANSFER" if item == "decline" else "ACCEPT EFFECT"
	ui._dialog.get_ok_button().disabled = false


static func commit(ui: MatchTacticalControls) -> void:
	var state: MatchState = ui._lab._match_state
	if ui._player != state.batter().definition.id:
		return
	var checkout: MatchLateCheckout = ui.team().tactics.checkout
	var changed: bool = (
		checkout.decline(state, ui.team())
		if ui._checkout == "decline"
		else checkout.accept(state, ui.team(), ui._checkout)
	)
	if changed:
		ui._lab._refresh_config()
		ui._lab._refresh_markers()
	ui._checkout = ""
	ui._process(0.0)
