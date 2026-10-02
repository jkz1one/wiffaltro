class_name SeasonShopQuote
extends RefCounted
## Read-only quotes use the same transaction rules as the final purchase review.


static func button(
	window: SeasonShopWindow, text: String, command: Dictionary, description: String
) -> Button:
	var build: SeasonBuild = window.app.season.build
	# Preview records diagnostic errors; isolate those as well as candidate state.
	var quote: Dictionary = build._fork().preview(command)
	var available: bool = quote.ok
	var message: String
	if quote.ok:
		message = "Cash after confirmation: %d" % quote.after.wallet.cash
	else:
		var error: String = quote.error
		if SeasonMajorResolution.needed(command, error):
			available = true
			message = "Choose the beneficiary or ability to forget before the final quote."
		elif SeasonSponsorResolution.needed(build, command, error):
			available = true
			message = "Review additional sales or discards to resolve Cash and capacity."
		elif (
			command.op == "buy"
			and error == "Choose Union Hall or Summer School; they cannot stack."
		):
			available = true
			message = "Choose one concession to see the final Cash cost."
		else:
			message = error
			if error.contains("Insufficient") and error.contains("Cash"):
				message = "Not enough Season Cash for this action."
			elif error.contains("capacity") and command.op in ["buy", "tactical_buy"]:
				message = "Held supply bag is full. Use or discard a copy before buying."
	var status: Label = window._label(message)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override(
		"font_color", ClubhouseTheme.MUTED if quote.ok else ClubhouseTheme.GOLD
	)
	var action: Button = window._button(text, window._preview.bind(command, description))
	action.disabled = not available
	action.tooltip_text = description + "\n" + message
	action.set_meta("shop_quote", quote)
	action.set_meta("shop_command", command.duplicate(true))
	action.set_meta("shop_quote_message", message)
	return action
