class_name SeasonLoadoutSale
extends ConfirmationDialog
## Exact saved-Cash quote. Cancel is focused, and failed writes leave runtime untouched.

var ui: SeasonLoadoutUI
var request: Dictionary = {}
var _review: Label


func _ready() -> void:
	title = "Sell equipped item"
	theme = ClubhouseTheme.create()
	dialog_autowrap = true
	get_ok_button().text = "SELL"
	confirmed.connect(_commit)
	canceled.connect(_return_focus)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 200
	add_child(scroll)
	_review = Label.new()
	_review.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_review)


func review(receipt_id: String, item_name: String) -> void:
	var app: SeasonApp = ui.app
	if not SeasonMatchSales.available(app):
		return
	_quote(SeasonMatchSales.command(app, receipt_id), item_name)


func _quote(chosen: Dictionary, item_name: String) -> void:
	var app: SeasonApp = ui.app
	request = chosen
	var quote: Dictionary = app.season.build.preview(request)
	if not quote.ok:
		if SeasonSponsorResolution.needed(app.season.build, request, quote.error):
			SeasonSponsorResolution.open(
				get_parent(),
				app.season.build,
				request,
				func(selected: Dictionary) -> void: _quote(selected, item_name),
				app
			)
			return
		ui.context.text = quote.error
		return
	var refund: int = quote.after.wallet.cash - quote.before_cash
	if not request.get("sales", []).is_empty():
		item_name = "%d selected sponsors" % (request.sales.size() + 1)
	var description: String = (
		(
			"Sell %s for %d Cash?\nCash: %d → %d\n\n"
			+ "The sale is saved immediately and remains sold if you leave or restart. "
			+ "During a plate appearance, its effect lasts until the next batter. "
			+ "Otherwise the effect ends now. Sold sponsors earn no postgame income. "
			+ "Live sales grant no shop reroll credit."
		)
		% [item_name, refund, quote.before_cash, quote.after.wallet.cash]
	)
	description += SeasonAssociationShop.review(app.season.build.view().wallet, quote.after.wallet)
	for id: String in request.get("discard", []):
		if id == SeasonFieldGrant.receipt(app._fixture_id):
			description += "\nDiscard generated Grip Tape • no refund."
	_review.text = description
	dialog_text = ""
	get_label().hide()
	popup_centered(Vector2i(560, 310))
	get_cancel_button().grab_focus()


func _commit() -> void:
	var app: SeasonApp = ui.app
	if app.sales.sell(app, request):
		ui.context.text = "SALE SAVED • %d Cash" % app.season.build.cash()
	else:
		ui.context.text = "SALE NOT SAVED • " + app.notice
	ui._rows = SeasonLoadoutData.pages(app)
	ui._select(ui._tab)
	_return_focus()


func _return_focus() -> void:
	ui.close_button.grab_focus()


func _input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventJoypadButton
		and event.pressed
		and event.button_index == JOY_BUTTON_B
	):
		hide()
		_return_focus()
		get_viewport().set_input_as_handled()
