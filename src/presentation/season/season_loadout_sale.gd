class_name SeasonLoadoutSale
extends ConfirmationDialog
## Exact saved-Cash quote. Cancel is focused, and failed writes leave runtime untouched.

const LIVE_SUPPLY_QUALIFIED: bool = true

var ui: SeasonLoadoutUI
var request: Dictionary = {}
var _review: Label


func _ready() -> void:
	title = "Sell equipped item"
	ClubhouseTheme.confirmation(self)
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
	if not ui.can_sell():
		return
	var command: Dictionary = command_for(ui, receipt_id)
	if command.is_empty():
		return
	_quote(command, item_name)


static func command_for(owner: SeasonLoadoutUI, receipt_id: String) -> Dictionary:
	var app: SeasonApp = owner.app
	if app == null or app.season == null or app.season.build == null:
		return {}
	var build: SeasonBuild = app.season.build
	var owned: Dictionary = SeasonMatchSales.copy_for(app, receipt_id)
	if owned.is_empty():
		return {}
	if SeasonInventoryResale.enabled(build._bank):
		if app.lab == null:
			if not SeasonInventoryRules.menu_available(build):
				return {}
			return {
				"id": "inventory-menu:%d" % build.revision(),
				"rev": build.revision(),
				"op": "inventory_sell",
				"receipt": receipt_id
			}
		if owned.kind == "held":
			return (
				SeasonMatchSales.command(app, receipt_id)
				if LIVE_SUPPLY_QUALIFIED and SeasonMatchSales.available(app)
				else {}
			)
		if (
			SeasonEquipment.is_spare(build, receipt_id)
			and (
				app.lab._match_state.phase
				in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]
			)
		):
			return {}
	if owner.shop != null:
		return owner.shop._request(
			"sell_gear" if owned.kind == "gear" else "sponsor_sell", {"receipt": receipt_id}
		)
	return SeasonMatchSales.command(app, receipt_id) if SeasonMatchSales.available(app) else {}


static func quote_for(owner: SeasonLoadoutUI, receipt: String) -> Dictionary:
	var app: SeasonApp = owner.app
	if app == null or app.season == null or app.season.build == null:
		return {"ok": false}
	var bank: SeasonOwnership = app.season.build._bank
	if not SeasonOwnership._owned(bank.view(), receipt).is_empty():
		return SeasonInventoryResale.quote(bank, receipt)
	if (
		not SeasonMatchSales.copy_for(app, receipt).is_empty()
		and receipt == SeasonFieldGrant.receipt(app._fixture_id)
	):
		return SeasonInventoryResale.field_quote(bank)
	return {"ok": false}


func _quote(chosen: Dictionary, item_name: String) -> void:
	var app: SeasonApp = ui.app
	request = chosen
	var quote: Dictionary = app.season.build.preview(request)
	if not quote.ok:
		if SeasonMajorResolution.needed(request, quote.error):
			SeasonMajorResolution.open(
				get_parent(),
				app.season.build,
				request,
				func(selected: Dictionary) -> void: _quote(selected, item_name)
			)
			return
		if SeasonSponsorResolution.needed(app.season.build, request, quote.error):
			SeasonSponsorResolution.open(
				get_parent(),
				app.season.build,
				request,
				func(selected: Dictionary) -> void: _quote(selected, item_name),
				app if ui.shop == null else null
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
	if ui.shop != null:
		description = (
			"Sell %s for %d Cash?\nCash: %d → %d\n\n"
			% [item_name, refund, quote.before_cash, quote.after.wallet.cash]
		)
		description += "The sale saves immediately and ends the effect. "
		description += "Your remaining shop offers stay fixed."
		description += SeasonReclamation.review(app.season.build.view().shop, quote.after.shop)
	description += SeasonDoubleMajor.review(app.season.build, request)
	description += SeasonAssociationShop.review(app.season.build.view().wallet, quote.after.wallet)
	for id: String in request.get("discard", []):
		if id == SeasonFieldGrant.receipt(app._fixture_id):
			description += "\nDiscard generated Grip Tape • no refund."
	if SeasonInventoryResale.enabled(app.season.build._bank):
		description = (
			"Sell %s for %d Cash?\nCash: %d → %d"
			% [item_name, refund, quote.before_cash, quote.after.wallet.cash]
		)
		description += SeasonDoubleMajor.review(app.season.build, request)
		var sold_copy: Dictionary = SeasonMatchSales.copy_for(app, str(request.get("receipt", "")))
		if sold_copy.get("kind") != "held":
			description += SeasonAssociationShop.review(
				app.season.build.view().wallet, quote.after.wallet
			)
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
	var saved: bool = (
		app.commit_inventory(request)
		if request.get("op") == "inventory_sell"
		else (app.commit_shop(request) if ui.shop != null else app.sales.sell(app, request))
	)
	if saved:
		ui.context.text = "SALE SAVED • %d Cash" % app.season.build.cash()
	else:
		ui.context.text = "SALE NOT SAVED • " + app.notice
	if saved and ui.shop != null:
		ui.shop._refresh()
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
