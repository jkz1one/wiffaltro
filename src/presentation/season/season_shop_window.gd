class_name SeasonShopWindow
extends Window

var app: SeasonApp
var _body: VBoxContainer
var _offer_body: VBoxContainer
var _heading: Label
var _balance: Label
var _capacity: Label
var _scroll: ScrollContainer
var _back: Button
var _confirm: ConfirmationDialog
var _review_scroll: ScrollContainer
var _review_text: Label
var _pending: Dictionary = {}
var _notice: String = ""


func _ready() -> void:
	title = "Season Shop"
	size = Vector2i(1000, 650)
	min_size = Vector2i(700, 400)
	transient = true
	exclusive = true
	theme = ClubhouseTheme.create()
	close_requested.connect(_close)
	size_changed.connect(func() -> void: _ensure_focus_visible.call_deferred())
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for edge: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	margin.add_theme_constant_override("margin_bottom", 60)
	panel.add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	margin.add_child(layout)
	layout.add_theme_constant_override("separation", 10)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	_heading = SeasonPlayerCard.line(header, "SEASON SHOP")
	_heading.add_theme_font_size_override("font_size", 24)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wallet_box: VBoxContainer = VBoxContainer.new()
	header.add_child(wallet_box)
	_balance = SeasonPlayerCard.line(wallet_box, "")
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_capacity = SeasonPlayerCard.line(wallet_box, "", 14)
	_capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance.add_theme_color_override("font_color", ClubhouseTheme.GREEN)
	_balance.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)
	_back = Button.new()
	_back.text = "BACK TO SEASON"
	_back.custom_minimum_size.y = 44
	_back.pressed.connect(_close)
	layout.add_child(_back)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm purchase or use"
	_confirm.dialog_autowrap = true
	_confirm.transient = true
	_confirm.exclusive = true
	_confirm.confirmed.connect(_commit)
	_confirm.canceled.connect(func() -> void: _pending.clear())
	add_child(_confirm)
	# Long replacement effects must not force the modal beyond a small shop window.
	_confirm.get_ok_button().custom_minimum_size.y = 44
	_confirm.get_cancel_button().custom_minimum_size.y = 44
	_review_scroll = ScrollContainer.new()
	_review_scroll.focus_mode = Control.FOCUS_ALL
	_review_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_review_scroll.custom_minimum_size.y = 170
	_confirm.add_child(_review_scroll)
	_review_text = Label.new()
	_review_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_scroll.add_child(_review_text)
	_refresh()
	var loadout: SeasonLoadoutUI = SeasonLoadoutUI.new()
	loadout.app = app
	loadout.shop = self
	add_child(loadout)


func _refresh() -> void:
	_clear()
	var view: Dictionary = app.season.build.view()
	var shop: Dictionary = view.shop
	_heading.text = "SEASON SHOP • VISIT %d" % shop.number
	_balance.text = "%d Cash" % view.wallet.cash
	_capacity.text = (
		"Held %d / %d • Sponsors %d / %d"
		% [
			view.wallet.held.size(),
			view.wallet.capacity.held,
			view.wallet.sponsors.size(),
			view.wallet.capacity.sponsors
		]
	)
	_label(_notice)
	if shop.pack_status == "open":
		_label("Choose one card, then its recipient. This pack is already paid; no extra charge.")
		for item_id: String in shop.cards:
			_label(_development_effect(DevelopmentShopCatalog.item(item_id)))
			var command: Dictionary = _request("pack_pick", {"item": item_id})
			_button(DevelopmentShopCatalog.item(item_id).name, _choose.bind(item_id, command))
		_button(
			"Skip this paid pack", _preview.bind(_request("pack_skip"), "Skip without a refund")
		)
	else:
		for offer: String in shop.offers:
			var item_id: String = shop.offers[offer]
			_offer_card(offer, item_id)
			if item_id == SeasonRetraining.ID:
				SeasonRetrainingUI.offer(self, offer)
				continue
			if not SeasonSponsorCatalog.item(item_id).is_empty():
				SeasonSponsorShopUI.offer(self, offer, item_id, view.wallet)
				continue
			if not SeasonGearCatalog.item(item_id).is_empty():
				SeasonGearShopUI.offer(self, offer, item_id, view.wallet.gear)
				continue
			if SeasonAbilities.ITEMS.has(item_id):
				SeasonAbilityUI.offer(self, offer, item_id)
				continue
			if SeasonTacticalCatalog.catalog().has(item_id):
				SeasonTacticalShopUI.offer(self, offer, item_id)
				continue
			var item: Dictionary = DevelopmentShopCatalog.item(item_id)
			_label("%s • %d Cash" % [item.name, item.price])
			_label(_development_effect(item))
			var command: Dictionary = _request("buy", {"offer": offer, "mode": "use"})
			_button("BUY AND USE", _choose.bind(item_id, command)).set_meta("offer", offer)
			if SeasonSchoolSponsors.pair_available(app.season.build, item_id):
				(
					_button(
						"OPEN BOOK • TEACH TWO",
						SeasonSchoolShopUI.paired.bind(self, offer, item_id)
					)
					. set_meta("pair_offer", offer)
				)
			if DevelopmentShopCatalog.CARDS.has(item_id):
				var hold: Dictionary = _request(
					"buy",
					{"offer": offer, "mode": "hold", "player": "", "pitch": "", "replace": ""}
				)
				_button("BUY AND HOLD", _preview.bind(hold, "Hold " + item.name))
		_offer_body = null
		_button(
			"Reroll individual offers • %d Cash" % SeasonReclamation.price(shop),
			_preview.bind(
				_request("reroll"),
				(
					(
						"Reroll unprotected offers; pack stays fixed. Base price %d; credit %d. "
						% [4 + 2 * shop.rerolls, SeasonReclamation.credit(shop)]
					)
					+ "Consumes the credit; future base prices still escalate normally."
				)
			)
		)
		if shop.pack_status == "sealed":
			var pack_button: Button = _button(
				(
					"Open fixed development pack • %d Cash • %d choices"
					% [8 - int(shop.get("union_credit", 0)), shop.choice_count]
				),
				_preview.bind(
					_request("pack_open"),
					(
						"Pay %d to reveal %d fixed choices (base 8; Union credit %d)"
						% [
							8 - int(shop.get("union_credit", 0)),
							shop.choice_count,
							shop.get("union_credit", 0)
						]
					)
				)
			)
			pack_button.disabled = shop.choice_count == 0
			if pack_button.disabled:
				pack_button.tooltip_text = "No eligible development remains; no Cash can be charged."
		else:
			_label("Development pack: " + str(shop.pack_status).capitalize())
		_label("SHOP SERVICES")
		if SeasonReclamation.credit(shop) > 0:
			_label("Reclamation credit: %d • Expires on leaving" % SeasonReclamation.credit(shop))
		SeasonTransferUI.entry(self)
		SeasonRaincheckUI.entry(self)
		SeasonSpecialOrderUI.entry(self)
		SeasonWholesaleUI.entry(self)
		SeasonSchoolShopUI.status(self)
		SeasonRetrainingUI.status(self)
		_recruit(shop)
		_label("YOUR SEASON INVENTORY • Earned access carries forward; copies last this season")
		SeasonGearShopUI.equipped(self, view.wallet.gear)
		SeasonSponsorShopUI.active(self, view.wallet)
		_held(view.wallet.held)
	_focus_first.call_deferred()


func _held(receipts: Array) -> void:
	_label("HELD SUPPLIES • shared development and tactical slots")
	for receipt: Dictionary in receipts:
		if SeasonTacticalCatalog.catalog().has(receipt.item):
			SeasonTacticalShopUI.held(self, receipt)
			continue
		var item: Dictionary = DevelopmentShopCatalog.item(receipt.item)
		_label("%s • paid %d" % [item.name, receipt.paid])
		_label(_development_effect(item))
		_button(
			"USE " + item.name, _choose.bind(receipt.item, _request("use", {"receipt": receipt.id}))
		)
		_button(
			"DISCARD " + item.name,
			_preview.bind(
				_request("discard", {"receipt": receipt.id}), "Discard without growth or refund"
			)
		)


func _recruit(shop: Dictionary) -> void:
	_label("FREE AGENCY • Closes after Game 6")
	if not shop.has("recruit"):
		_label("Recruiting starts at your next visit. This saved visit remains unchanged.")
		return
	var offer: Dictionary = shop.recruit
	if offer.is_empty():
		_label(
			(
				"Recruiting is closed."
				if shop.number > 6
				else "No recruit this visit. Ordinary rerolls do not change recruiting."
			)
		)
		return
	var player: PlayerDefinition = ProgressionMatchAdapter.from_profile(offer.profile)
	player.season_abilities = app.season.build._abilities.ids(offer.player)
	if offer.signed:
		_label("SIGNED • " + player.display_name)
		return
	SeasonPlayerCard.ratings_card(
		_body, player, "%s • %d Cash" % [player.display_name, offer.price]
	)
	_label(
		(
			"RETURNING PLAYER • Actual retained development; original signing-price reference."
			if offer.returning
			else "FRESH RECRUIT • Working %s-stage profile." % offer.stage
		)
	)
	_button("REVIEW RECRUIT REPLACEMENT", _choose_recruit)


func _choose_recruit() -> void:
	var offer: Dictionary = app.season.build.view().shop.get("recruit", {})
	if offer.is_empty() or offer.signed:
		_refresh()
		return
	_clear()
	var incoming: PlayerDefinition = ProgressionMatchAdapter.from_profile(offer.profile)
	incoming.season_abilities = app.season.build._abilities.ids(offer.player)
	_label("SIGN %s • %d Cash" % [incoming.display_name, offer.price])
	SeasonPlayerCard.ratings_card(_body, incoming, "INCOMING • " + incoming.display_name)
	_label(
		(
			"Choose one current player to release for 0 Cash. Team Gear and held cards stay. "
			+ "Player development stays with its owner; a later return is not guaranteed."
		)
	)
	for id: String in app.season.teams[0].roster:
		var outgoing: PlayerDefinition = app.season.player_definition(id)
		SeasonPlayerCard.ratings_card(_body, outgoing, "CURRENT • " + outgoing.display_name)
		var changes: PackedStringArray = []
		var old: Array[int] = SeasonPlayerCard.values(outgoing)
		var next: Array[int] = SeasonPlayerCard.values(incoming)
		for index in range(old.size()):
			changes.append(
				(
					"%s %+d"
					% [SeasonPlayerCard.rating_names(incoming)[index], next[index] - old[index]]
				)
			)
		_label("Incoming difference: " + " • ".join(changes))
		var description: String = (
			"Sign %s\nRelease %s for 0 Cash\nNo development transfers between players."
			% [incoming.display_name, outgoing.display_name]
		)
		(
			_button(
				"REPLACE " + outgoing.display_name,
				_preview.bind(_request("sign", {"offer": offer.id, "replace": id}), description)
			)
			. set_meta("recruit_replace", id)
		)
	_button("CANCEL TARGETING", _refresh)
	_focus_first.call_deferred()


func _choose(item_id: String, command: Dictionary) -> void:
	_clear()
	var item: Dictionary = DevelopmentShopCatalog.item(item_id)
	_label("CHOOSE RECIPIENT • " + item.name)
	_label(_development_effect(item))
	_label("Inspection and target selection spend nothing. Confirm the exact change next.")
	var targets: Array[Dictionary] = app.season.build.targets(item_id)
	var previous_player: String = ""
	for target: Dictionary in targets:
		var player: PlayerDefinition = app.season.player_definition(target.player)
		if target.player != previous_player:
			SeasonPlayerCard.ratings_card(_body, player, player.display_name)
			previous_player = target.player
		var selected: Dictionary = command.duplicate(true)
		selected.merge(target)
		var text: String = _target_text(item, target)
		_button(text, _preview.bind(selected, item.name + "\n" + text)).set_meta("target", target)
	if targets.is_empty():
		_label("No legal target remains. Nothing was charged or consumed.")
	_button("CANCEL TARGETING", _refresh)
	_focus_first.call_deferred()


func _development_effect(item: Dictionary) -> String:
	match item.op:
		"stat":
			return (
				"Raise one player's %s by 1 this season, up to %d."
				% [item.family.capitalize(), SeasonDevelopment.STAT_CAP]
			)
		"mastery":
			return (
				"Raise one active pitch's mastery by 1 this season, up to %d."
				% SeasonDevelopment.PITCH_CAP
			)
		"round_out":
			return (
				"Raise one of a player's lowest-mastery active pitches by 1, up to %d this season."
				% SeasonDevelopment.PITCH_CAP
			)
		"learn":
			return (
				"Teach this exact pitch this season. Choose a free slot or review a replacement. "
				+ "New pitches start at mastery 1; relearning preserves their previous mastery."
			)
	return ""


func _target_text(item: Dictionary, target: Dictionary) -> String:
	var profile: Dictionary = app.season.build.player(target.player)
	var name_text: String = app.season.player_definition(target.player).display_name
	if item.op == "stat":
		return (
			"%s • %s %d → %d"
			% [
				name_text,
				item.family.capitalize(),
				profile.stats[item.family],
				profile.stats[item.family] + 1
			]
		)
	if item.op == "learn":
		var replaced: String = (
			"free capacity slot"
			if target.replace.is_empty()
			else ("replace " + ContentDB.get_pitch(StringName(target.replace)).display_name)
		)
		return (
			"%s • %s • learned level %d"
			% [name_text, replaced, profile.mastery.get(item.recipe, 1)]
		)
	return (
		"%s • %s %d → %d"
		% [
			name_text,
			ContentDB.get_pitch(StringName(target.pitch)).display_name,
			profile.mastery[target.pitch],
			profile.mastery[target.pitch] + 1
		]
	)


func _preview(command: Dictionary, description: String) -> void:
	if SeasonSchoolShopUI.choose_concession(self, command, description):
		return
	var result: Dictionary = app.season.build.preview(command)
	if not result.ok:
		if SeasonMajorResolution.needed(command, result.error):
			SeasonMajorResolution.open(
				self,
				app.season.build,
				command,
				func(chosen: Dictionary) -> void: _preview(chosen, description)
			)
			return
		if SeasonSponsorResolution.needed(app.season.build, command, result.error):
			SeasonSponsorResolution.open(
				self,
				app.season.build,
				command,
				func(chosen: Dictionary) -> void: _preview(chosen, description)
			)
			return
		_notice = result.error
		_refresh()
		return
	_pending = command.duplicate(true)
	description += SeasonRaincheckUI.purchase_review(app.season.build, command, result)
	var effect: String = ""
	if command.get("player", "") != "" and command.op != "retrain_buy":
		var before: Dictionary = app.season.build.player(command.player)
		for stat: String in SeasonPlayerCatalog.STATS:
			if before.stats[stat] != result.player.stats[stat]:
				effect = DevelopmentLab.STAT_EFFECTS[stat]
		if command.get("pitch", "") != "":
			for pitch: PitchDefinition in (
				app.season.player_definition(command.player).starting_pitches
			):
				if String(pitch.id) == command.pitch:
					effect = PitchMastery.next_effect(pitch)
	description += SeasonDoubleMajor.review(app.season.build, command)
	description += SeasonAssociationShop.review(app.season.build.view().wallet, result.after.wallet)
	description += SeasonSchoolSponsors.review(app.season.build.view(), result.after)
	description += SeasonReclamation.review(app.season.build.view().shop, result.after.shop)
	_review_text.text = (
		"%s\nCash: %d → %d\nHeld: %d → %d\n%s\nConfirm and save?"
		% [
			description,
			result.before_cash,
			result.after.wallet.cash,
			app.season.build.view().wallet.held.size(),
			result.after.wallet.held.size(),
			effect
		]
	)
	_confirm.get_label().hide()
	_review_scroll.scroll_vertical = 0
	_confirm.popup_centered(Vector2i(mini(760, size.x - 32), mini(440, size.y - 48)))
	_focus_cancel.call_deferred()


func _commit() -> void:
	var departing: bool = _pending.get("op") == "reserve_offer"
	var ok: bool = app.commit_shop(_pending)
	_pending.clear()
	if ok and departing:
		_close()
		return
	_notice = "Saved. Your build is ready for the next game." if ok else app.notice
	_refresh()


func _request(op: String, fields: Dictionary = {}) -> Dictionary:
	var rev: int = app.season.build.revision()
	var result: Dictionary = {"id": "shop:%d" % rev, "rev": rev, "op": op}
	result.merge(fields)
	return result


func _close() -> void:
	if SeasonSchoolSponsors.has_credit(app.season.build.view().shop):
		if not app.commit_shop(_request("leave_shop")):
			_notice = app.notice
			_refresh()
			return
	app.show_season()
	queue_free()


func _clear() -> void:
	_offer_body = null
	_scroll.scroll_vertical = 0
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()


func _offer_card(offer: String, id: String) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.set_meta("shop_offer", offer)
	card.add_theme_stylebox_override("panel", ClubhouseTheme.surface(false, 14))
	_body.add_child(card)
	_offer_body = VBoxContainer.new()
	_offer_body.add_theme_constant_override("separation", 8)
	card.add_child(_offer_body)
	var category: String = "DEVELOPMENT"
	if not SeasonGearCatalog.item(id).is_empty():
		category = "GEAR • " + str(SeasonGearCatalog.item(id).slot).to_upper()
	elif not SeasonSponsorCatalog.item(id).is_empty():
		category = "SPONSOR"
	elif SeasonAbilities.ITEMS.has(id):
		category = "LEARNED ABILITY"
	elif SeasonTacticalCatalog.catalog().has(id):
		category = "TACTICAL SUPPLY"
	var tag: Label = SeasonPlayerCard.line(_offer_body, category)
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", ClubhouseTheme.GOLD)


func _label(text: String) -> void:
	if text.is_empty():
		return
	var label: Label = SeasonPlayerCard.line(_body if _offer_body == null else _offer_body, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	(_body if _offer_body == null else _offer_body).add_child(button)
	return button


func _ensure_focus_visible() -> void:
	if not is_inside_tree() or _scroll == null:
		return
	# Wrapped descriptions settle their container heights over two layout passes.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var focused: Control = gui_get_focus_owner()
	if focused != null and _body.is_ancestor_of(focused):
		_scroll.ensure_control_visible(focused)


func _focus_first() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	for child in _body.find_children("*", "Button", true, false):
		if child is Button and not child.disabled:
			child.grab_focus()
			_ensure_focus_visible()
			return
	_back.grab_focus()


func _focus_cancel() -> void:
	if is_inside_tree() and not is_queued_for_deletion() and _confirm.visible:
		_confirm.get_cancel_button().grab_focus()
