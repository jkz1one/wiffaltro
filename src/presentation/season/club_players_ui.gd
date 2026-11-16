class_name ClubPlayersUI
extends RefCounted

const PAGE_SIZE: int = 6
const FILTERS: Array[String] = ["All", "Owned", "Packs", "Earned"]


static func show(menu: SeasonMenu, filter_name: String = "All", page: int = 0) -> void:
	var context: Dictionary = _context(menu)
	if context.is_empty():
		return
	var view: Dictionary = context.ledger
	if not view.pending.is_empty():
		_pending(menu, view)
		return
	if not FILTERS.has(filter_name):
		filter_name = "All"
	var owned: Array[String] = []
	owned.assign(context.owned)
	var metrics: Dictionary = context.metrics
	var ids: Array[String] = SeasonPlayerCatalog.ids().filter(func(id: String) -> bool:
		return filter_name == "All" or (filter_name == "Owned" and owned.has(id)) \
			or (filter_name == "Packs" and ClubPlayerCatalog.PACK_POOL.has(id)) \
			or (filter_name == "Earned" and ClubPlayerCatalog.EARNED.has(id)))
	var last: int = maxi(0, int((ids.size() - 1) / float(PAGE_SIZE)))
	page = clampi(page, 0, last)
	menu._screen("players", "PLAYER COLLECTION", str(context.get("subtitle",
		"Permanent ownership • Fresh development each season")))
	menu._label(menu._body, "%d / 48 OWNED  •  %d CLUB BUCKS" % [owned.size(), view.balance], 24)
	SeasonPages.wrapped(menu._body, str(context.get("description",
		"Newly owned players enter the next season's draft and recruit pool. "
		+ "Current rosters stay intact.")))
	var tabs: HFlowContainer = HFlowContainer.new()
	menu._body.add_child(tabs)
	for label: String in FILTERS:
		var button: Button = menu._button(tabs, label.to_upper(), show.bind(menu, label, 0))
		button.set_meta("player_filter", label)
		button.toggle_mode = true
		button.set_pressed_no_signal(label == filter_name)
	var buy: Button = menu._button(menu._body,
		"REVIEW PLAYER PACK • %d CB" % view.pack_price, review.bind(menu))
	buy.set_meta("player_pack_review", true)
	buy.disabled = view.balance < view.pack_price or view.pack_remaining == 0
	SeasonPages.wrapped(menu._body, "18 pack characters • 18 earned-only • No duplicates. %s" % (
		"All pack characters owned." if view.pack_remaining == 0
		else "%d pack characters remain. Price is provisional." % view.pack_remaining))
	for index in range(page * PAGE_SIZE, mini(ids.size(), (page + 1) * PAGE_SIZE)):
		var id: String = ids[index]
		var card: VBoxContainer = _card(menu, id, owned.has(id))
		SeasonPages.wrapped(card, "OWNED PERMANENTLY" if owned.has(id) else "LOCKED")
		if ClubPlayerCatalog.EARNED.has(id):
			var progress: Dictionary = ClubPlayerCatalog.progress(id, metrics)
			SeasonPages.wrapped(card, "EARNED ONLY • %s" % progress.family)
			SeasonPages.wrapped(card, "%s  %d / %d" % [
				progress.requirement, progress.current, progress.goal])
		elif ClubPlayerCatalog.PACK_POOL.has(id):
			SeasonPages.wrapped(card, "PLAYER PACK • Reveal up to 3 unowned players; choose 1.")
		else:
			SeasonPages.wrapped(card, "STARTER • Available to every new club.")
		_profile(card, id)
	menu._label(menu._body, "Page %d of %d" % [page + 1, last + 1], 18)
	if page > 0:
		menu._button(menu._footer, "PREVIOUS", show.bind(menu, filter_name, page - 1))
	if page < last:
		menu._button(menu._footer, "NEXT", show.bind(menu, filter_name, page + 1))
	menu._button(menu._footer, "CLUB RECORD", ClubCareerUI.show.bind(menu, 0))


static func review(menu: SeasonMenu) -> void:
	var context: Dictionary = _context(menu)
	if context.is_empty():
		return
	var view: Dictionary = context.ledger
	if not view.pending.is_empty():
		_pending(menu, view)
		return
	menu._screen("player_pack_review", "PLAYER PACK", "Review before spending earned Club Bucks")
	menu._label(menu._body, "%d CB → %d CB" % [view.balance, view.balance - view.pack_price], 28)
	SeasonPages.wrapped(menu._body,
		"Pay %d Club Bucks. Reveal %d distinct unowned pack characters and choose one." % [
			view.pack_price, mini(3, view.pack_remaining)])
	SeasonPages.wrapped(menu._body,
		"Earned-only characters never appear. Cancel now costs nothing. After payment, your reveal "
		+ "is saved until you choose; leaving does not refund or reroll it. Working price.")
	var through: int = int(context.through)
	var request: Dictionary = {"id": "player-pack:%d" % view.revision,
		"rev": view.revision, "op": "player_pack_open", "through": through,
		"price_version": ClubPlayerCatalog.PRICE_VERSION}
	var pay: Button = menu._button(menu._footer, "PAY %d CB" % view.pack_price,
		_commit.bind(menu, request))
	pay.set_meta("player_pack_pay", true)
	pay.disabled = view.balance < view.pack_price or view.pack_remaining == 0
	menu._button(menu._footer, "CANCEL", show.bind(menu, "All", 0))


static func _pending(menu: SeasonMenu, view: Dictionary) -> void:
	menu._screen("player_pack", "CHOOSE ONE PLAYER", "Paid reveal saved • No duplicates")
	menu._label(menu._body, "%d CLUB BUCKS • Paid %d CB" % [view.balance, view.pending.paid], 24)
	SeasonPages.wrapped(menu._body,
		"Keep one permanently for future seasons. The other choices stay eligible for later packs.")
	for id: String in view.pending.choices:
		var card: VBoxContainer = _card(menu, id, false)
		_profile(card, id)
		var request: Dictionary = {"id": "player-pick:%d:%s" % [view.revision, id],
			"rev": view.revision, "op": "player_pack_pick", "pack": view.pending.id, "player": id}
		var button: Button = menu._button(card, "KEEP THIS PLAYER", _commit.bind(menu, request))
		button.set_meta("player_pack_pick", id)
	menu._button(menu._footer, "CHOOSE LATER", ClubCareerUI.show.bind(menu, 0))


static func _card(menu: SeasonMenu, id: String, owned: bool) -> VBoxContainer:
	var card: VBoxContainer = SeasonPlayerCard.panel(menu._body, owned)
	card.set_meta("permanent_player", id)
	menu._label(card, ContentDB.get_player(StringName(id)).display_name, 23)
	return card


static func _profile(card: VBoxContainer, id: String) -> void:
	var definition: PlayerDefinition = ProgressionMatchAdapter.player(
		SeasonDevelopment.new("base"), id)
	SeasonPages.wrapped(card,
		"Bats / Throws %s • Contact %d • Power %d • Fielding %d • Pitching %d" % [
		SeasonPlayerCard.hands(definition), definition.contact, definition.power,
		definition.fielding, definition.control])
	var names: PackedStringArray = []
	for pitch: PitchDefinition in definition.starting_pitches:
		names.append(pitch.display_name)
	SeasonPages.wrapped(card, "Starting pitches: " + ", ".join(names))
	SeasonPlayerCard.inspection_button(card, definition)


static func _commit(menu: SeasonMenu, request: Dictionary) -> void:
	var result: Dictionary = (
		menu.app._player_collection_transact(request)
		if menu.app.has_method("_player_collection_transact")
		else ClubPlayers.transact(menu.app.season, request)
	)
	menu.app.notice = str(result.get("notice", "Player pack saved." if request.op == "player_pack_open"
		else "Player permanently owned. Available from your next season.")) if result.ok else result.error
	show(menu)


static func career_view(career: ClubCareer) -> Dictionary:
	if career == null:
		return {}
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	if ledger == null:
		return {}
	return {"owned": ClubPlayers.owned(career), "metrics": ClubPlayerProgress.metrics(career.runs, not career._pitch_catalog.is_empty()),
		"ledger": ledger.view(), "through": ClubPlayers.income_through(career)}


static func _context(menu: SeasonMenu) -> Dictionary:
	if menu.app.has_method("_player_collection_view"):
		return menu.app._player_collection_view()
	return career_view(menu.app.season.career) if menu.app.season != null else {}
