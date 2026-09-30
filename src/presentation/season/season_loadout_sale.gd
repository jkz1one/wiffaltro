class_name SeasonLoadoutSale
extends ConfirmationDialog
## Exact saved-Cash quote. Cancel is focused, and failed writes leave runtime untouched.

var ui: SeasonLoadoutUI
var request: Dictionary = {}


func _ready() -> void:
	title = "Sell equipped item"
	theme = ClubhouseTheme.create()
	dialog_autowrap = true
	get_ok_button().text = "SELL"
	confirmed.connect(_commit)
	canceled.connect(_return_focus)


func review(receipt_id: String, item_name: String) -> void:
	var app: SeasonApp = ui.app
	if not SeasonMatchSales.available(app):
		return
	request = SeasonMatchSales.command(app, receipt_id)
	var quote: Dictionary = app.season.build.preview(request)
	if not quote.ok:
		ui.context.text = quote.error
		return
	var refund: int = quote.after.wallet.cash - quote.before_cash
	dialog_text = (
		(
			"Sell %s for %d Cash?\nCash: %d → %d\n\n"
			+ "The sale is saved immediately and remains sold if you leave or restart. "
			+ "During a plate appearance, its effect lasts until the next batter. "
			+ "Otherwise the effect ends now. Sold sponsors earn no postgame income. "
			+ "Live sales grant no shop reroll credit."
		)
		% [item_name, refund, quote.before_cash, quote.after.wallet.cash]
	)
	popup_centered(Vector2i(560, 260))
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
